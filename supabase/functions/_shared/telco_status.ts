// What a subscriber-status answer does to the account.
//
// One place, because two functions ask: payment-status on every app open,
// and otp-verify straight after a signup whose verify reply did not already
// say REGISTERED. Both must land the user on the same tier for the same
// answer.
//
// The rule (PRD 7.2, 12.4): only REGISTERED is the telco rail's Basic.
// Anything else -- UNREGISTERED, or an in-between state the carrier sends,
// such as a first charge still pending -- is Free, straight away, with no
// grace period.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { SubscriberStatus } from "./charging.ts";

/// A daily charge renews a day at a time. The extra two hours keep a
/// subscriber on Basic across the gap between one day's charge and the next
/// status check, rather than flickering to Free at the 24-hour mark.
const TELCO_VALIDITY_MS = 26 * 60 * 60 * 1000;

/// Sri Lanka is UTC+5:30 all year; quotas and charge days both turn over at
/// its midnight (PRD 7.6), not the server's.
const SLT_OFFSET_MS = 5.5 * 60 * 60 * 1000;

export interface PaymentRow {
  tier: string;
  source: string | null;
  status: string;
  valid_until: string | null;
}

/// Writes [result] to payment_status and to the day's telco_charges row,
/// and returns the entitlement as it now stands.
///
/// A live store subscription (Pro, Pro+) belongs to the RevenueCat rail: the
/// telco answer is still recorded for the day, but cannot raise or lower it.
export async function recordTelcoStatus(
  supabase: SupabaseClient,
  user: { id: string; msisdn: string },
  carrier: string | null,
  result: SubscriberStatus,
): Promise<PaymentRow> {
  const now = new Date();
  const registered = result.status === "REGISTERED";

  const { data: current, error: currentError } = await supabase
    .from("payment_status")
    .select("tier, source, status, valid_until")
    .eq("user_id", user.id)
    .maybeSingle<PaymentRow>();
  if (currentError) throw currentError;

  // The record of the day, whatever the tier does. Carriers give no charge
  // events, so the day's status answer is what there is to keep; a second
  // check the same day replaces the first (telco_charges_user_day_idx).
  const { error: chargeError } = await supabase
    .from("telco_charges")
    .upsert({
      user_id: user.id,
      msisdn: user.msisdn,
      provider: carrier ?? "unknown",
      charge_date: new Date(now.getTime() + SLT_OFFSET_MS)
        .toISOString()
        .slice(0, 10),
      status: result.status.toLowerCase(),
      raw_callback: result.raw,
      received_at: now.toISOString(),
    }, { onConflict: "user_id,charge_date" });
  if (chargeError) {
    // The day's record is bookkeeping; the tier below is what the user
    // feels, so a failure here is logged rather than allowed to stop it.
    console.error("telco-status: daily record failed", chargeError);
  }

  const storeLive = current?.source === "revenuecat" &&
    current.status === "active" &&
    (current.valid_until === null ||
      new Date(current.valid_until).getTime() > now.getTime());
  if (storeLive) return current!;

  let next: Record<string, unknown>;
  if (registered) {
    next = {
      tier: "basic",
      source: "telco",
      status: "active",
      valid_until: new Date(now.getTime() + TELCO_VALIDITY_MS).toISOString(),
      last_checked_at: now.toISOString(),
    };
  } else if (current?.source === "telco" && current.status === "active") {
    // Was paying, is not now: Free Fallback immediately (PRD 7.2).
    next = {
      tier: "free",
      source: "telco",
      status: "cancelled",
      valid_until: now.toISOString(),
      last_checked_at: now.toISOString(),
    };
  } else {
    // Never subscribed, or already lapsed: only the check itself is news.
    next = {
      tier: current?.tier ?? "free",
      source: current?.source ?? null,
      status: current?.status ?? "none",
      valid_until: current?.valid_until ?? null,
      last_checked_at: now.toISOString(),
    };
  }

  const { data: written, error: writeError } = await supabase
    .from("payment_status")
    .upsert({ user_id: user.id, ...next }, { onConflict: "user_id" })
    .select("tier, source, status, valid_until")
    .single<PaymentRow>();
  if (writeError) throw writeError;

  return written;
}
