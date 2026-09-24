// POST /functions/v1/payment-status   (Authorization: Bearer <access token>)
//
// Resolves the caller's telco charging status and writes it to
// payment_status, the one record the app reads its tier from (PRD 7.1, 7.3,
// 9.2). The app calls this on open, behind its own one-hour debounce, and
// reads the result through get_entitlement straight after.
//
// Without it, Basic lasted exactly as long as the 24 hours otp-verify
// granted at sign-in: nothing renewed it, so a paying subscriber dropped to
// Free the next day, and one who unsubscribed kept Basic until then.
//
// The carrier is asked with subscriber-status, which the charging spec
// marks safe to retry. Its answer moves the row both ways - there is no
// grace period on either rail (PRD 12.4) - but a carrier that cannot answer
// changes nothing: downgrading a paying user over a failed status call is
// the worse mistake, and the client falls back to its cached entitlement.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { verifyAccessToken } from "../_shared/tokens.ts";
import { subscriberStatus, testBypass } from "../_shared/charging.ts";

/// A daily charge renews a day at a time. The extra two hours keep a
/// subscriber on Basic across the gap between one day's charge and the next
/// status check, rather than flickering to Free at the 24-hour mark.
const TELCO_VALIDITY_MS = 26 * 60 * 60 * 1000;

interface PaymentRow {
  tier: string;
  source: string | null;
  status: string;
  valid_until: string | null;
}

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const userId = token
    ? await verifyAccessToken(
      token,
      requireEnv("SUPABASE_JWT_SECRET", "APP_JWT_SECRET"),
    )
    : null;
  if (!userId) return fail(401, "unauthenticated");

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  const { data: user, error: userError } = await supabase
    .from("users")
    .select("msisdn, status")
    .eq("id", userId)
    .maybeSingle();

  if (userError) {
    console.error("payment-status: user lookup failed", userError);
    return fail(500, "server_error");
  }
  if (!user) return fail(401, "unauthenticated");
  if (user.status !== "active") return fail(403, "account_suspended");

  const { data: current, error: currentError } = await supabase
    .from("payment_status")
    .select("tier, source, status, valid_until")
    .eq("user_id", userId)
    .maybeSingle<PaymentRow>();

  if (currentError) {
    console.error("payment-status: status lookup failed", currentError);
    return fail(500, "server_error");
  }

  const unchanged = (reason: string) =>
    json({ ...describe(current), checked: false, reason });

  // A live store subscription is Pro or Pro+ and belongs to the RevenueCat
  // rail. The telco answer cannot raise it and must not lower it.
  if (
    current?.source === "revenuecat" && current.status === "active" &&
    (current.valid_until === null ||
      new Date(current.valid_until).getTime() > Date.now())
  ) {
    return unchanged("store_subscription");
  }

  // The development number never touches the carrier, here or at sign-in.
  const bypass = testBypass();
  if (bypass !== null && user.msisdn === bypass.msisdn) {
    return unchanged("test_number");
  }

  let subscription: string;
  try {
    subscription = await subscriberStatus(user.msisdn);
  } catch (error) {
    console.error("payment-status: carrier status unavailable", error);
    return unchanged("carrier_unavailable");
  }

  const now = new Date();
  let next: Record<string, unknown>;

  if (subscription === "REGISTERED") {
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
    .upsert({ user_id: userId, ...next }, { onConflict: "user_id" })
    .select("tier, source, status, valid_until")
    .single<PaymentRow>();

  if (writeError) {
    console.error("payment-status: write failed", writeError);
    return fail(500, "server_error");
  }

  return json({ ...describe(written), checked: true, subscription });
});

function describe(row: PaymentRow | null) {
  return {
    tier: row?.tier ?? "free",
    status: row?.status ?? "none",
    valid_until: row?.valid_until ?? null,
  };
}
