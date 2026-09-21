// POST /functions/v1/otp-request  { msisdn, device_id? }
//
// Writes a hashed, single-use OTP to `otp_requests` and returns the resend
// cooldown so the client can render the countdown of PRD 6.1. The code
// itself is never returned and never stored in the clear.
//
// Delivery is the one piece still missing: `msisdn_prefix_routing` has the
// prefixes and carriers but every row is inactive with an empty endpoint,
// because PRD 7.2 defers the specifics to provider documentation. Until an
// operator fills one in, `OTP_FIXED_CODE` stands in for the SMS — see
// `resolveCode` below.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { hashSecret, otpPepper } from "../_shared/tokens.ts";
import { toE164 } from "../_shared/msisdn.ts";

// Must match `kOtpValidity` and `kOtpResendCooldown` in
// lib/domain/otp_policy.dart. That file says so too: a countdown longer than
// the real validity shows the user time they do not have.
const OTP_VALIDITY_SECONDS = 5 * 60;
const RESEND_COOLDOWN_SECONDS = 60;

/// The code to issue.
///
/// No SMS gateway is wired yet — every `msisdn_prefix_routing` row is
/// inactive with an empty endpoint — so there is nothing to deliver a random
/// code to. `DEV_FIXED_CODE` stands in for the SMS and verifies for every
/// number, which is the only way the flow can be exercised end to end today.
///
/// This is a universal password: anyone who can reach this URL can sign up
/// as any phone number. `OTP_FIXED_CODE` overrides it and an unset
/// `ALLOW_DEV_OTP` disables the fallback entirely, so the deployment that
/// faces real users is the one that leaves `ALLOW_DEV_OTP` unset — there the
/// code is random, undeliverable, and fails closed rather than open.
const DEV_FIXED_CODE = "123456";

function resolveCode(): string {
  const fixed = Deno.env.get("OTP_FIXED_CODE");
  if (fixed && /^\d{6}$/.test(fixed)) return fixed;

  if (Deno.env.get("ALLOW_DEV_OTP") === "true") {
    console.warn(`no SMS gateway — issuing the fixed development code`);
    return DEV_FIXED_CODE;
  }

  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: { msisdn?: string; device_id?: string; full_name?: string };
  try {
    body = await req.json();
  } catch {
    return fail(400, "bad_request", "body must be JSON");
  }

  const msisdn = toE164(body.msisdn ?? "");
  if (msisdn === null) return fail(400, "invalid_msisdn");

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  // A name means this came from the signup screen, which is the only caller
  // for which an existing account is a mistake rather than a login. Checked
  // before anything is written and before a code is issued, so a duplicate
  // signup costs nothing and leaves no OTP outstanding.
  //
  // Login and resend send no name and skip this, which is what keeps signup
  // and login the same underlying call everywhere else.
  const isSignup = (body.full_name ?? "").trim() !== "";

  if (isSignup) {
    const { data: existing, error: existingError } = await supabase
      .from("users")
      .select("id")
      .eq("msisdn", msisdn)
      .maybeSingle();

    if (existingError) {
      console.error("otp-request: account lookup failed", existingError);
      return fail(500, "server_error");
    }

    if (existing) return fail(409, "account_exists");
  }

  // Each SMS is a direct cost, so the cooldown is a spend control as much as
  // a security one, and the client's own timer cannot be trusted with it.
  const { data: recent, error: recentError } = await supabase
    .from("otp_requests")
    .select("created_at")
    .eq("msisdn", msisdn)
    .is("consumed_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (recentError) {
    console.error("otp-request: cooldown lookup failed", recentError);
    return fail(500, "server_error");
  }

  if (recent) {
    const elapsed = (Date.now() - new Date(recent.created_at).getTime()) / 1000;
    if (elapsed < RESEND_COOLDOWN_SECONDS) {
      return json(
        { hint: "cooldown_active", retry_after: Math.ceil(RESEND_COOLDOWN_SECONDS - elapsed) },
        429,
      );
    }
  }

  // Signup sends a name; login and a resend from the OTP screen do not. The
  // row is written before the code so a failure here cannot leave a live OTP
  // with no pending signup behind it, and `msisdn` is unique so a second
  // attempt overwrites rather than piling up.
  if (isSignup) {
    const { error: tempError } = await supabase
      .from("temp")
      .upsert(
        { msisdn, full_name: body.full_name!.trim() },
        { onConflict: "msisdn" },
      );

    if (tempError) {
      console.error("otp-request: pending signup write failed", tempError);
      return fail(500, "server_error");
    }
  }

  const code = resolveCode();
  const otpHash = await hashSecret(code, msisdn, otpPepper());

  const { error: insertError } = await supabase.from("otp_requests").insert({
    msisdn,
    otp_hash: otpHash,
    expires_at: new Date(Date.now() + OTP_VALIDITY_SECONDS * 1000).toISOString(),
    device_id: body.device_id ?? null,
    request_ip: req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
  });

  if (insertError) {
    console.error("otp-request: insert failed", insertError);
    return fail(500, "server_error");
  }

  // TODO: hand `code` to the gateway named by `msisdn_prefix_routing` for
  // this prefix once an operator endpoint is active (PRD 7.2).

  return json({
    cooldown_seconds: RESEND_COOLDOWN_SECONDS,
    expires_in: OTP_VALIDITY_SECONDS,
  });
});
