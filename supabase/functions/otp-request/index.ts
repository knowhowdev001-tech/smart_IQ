// POST /functions/v1/otp-request  { msisdn, device_id?, full_name?, login? }
//
// Asks the carrier to send an OTP and records that it did. The code itself
// is the carrier's: it delivers the SMS and checks the answer, and hands
// back a reference we quote at verify time.
//
// This function stays in front of that because the carrier knows nothing
// about the things an account needs -- whether the number may sign up or may
// log in, the pending name a signup carries, the resend cooldown that keeps
// an SMS from being a free repeat, and the attempt cap on the row.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { ChargingError, requestOtp } from "../_shared/charging.ts";
import { toE164 } from "../_shared/msisdn.ts";

// Must match `kOtpValidity` and `kOtpResendCooldown` in
// lib/domain/otp_policy.dart. That file says so too: a countdown longer than
// the real validity shows the user time they do not have.
const OTP_VALIDITY_SECONDS = 5 * 60;
const RESEND_COOLDOWN_SECONDS = 60;

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: {
    msisdn?: string;
    device_id?: string;
    full_name?: string;
    login?: boolean;
    application_hash?: string;
  };
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

  // A name means this came from the signup screen, and `login` means it came
  // from the login screen. Each has the opposite precondition: signup needs
  // the number to be free, login needs it to have an account. Both are
  // checked before anything is written and before a code is issued, so a
  // wrong door costs no SMS and leaves no OTP outstanding.
  //
  // A resend from the OTP screen sends neither flag: whichever check applied
  // has already passed, and repeating it would fail a signup whose account
  // does not exist yet.
  const isSignup = (body.full_name ?? "").trim() !== "";
  const isLogin = body.login === true;

  if (isSignup || isLogin) {
    // An account is a *profile*, not merely a users row. A number that
    // verified but never finished signup is half a signup, not an account:
    // calling it one would lock it out of login (no profile to load) and out
    // of signup (number taken) at the same time.
    const { data: account, error: accountError } = await supabase
      .from("users")
      .select("id, profiles!inner(user_id)")
      .eq("msisdn", msisdn)
      .maybeSingle();

    if (accountError) {
      console.error("otp-request: account lookup failed", accountError);
      return fail(500, "server_error");
    }

    if (isSignup && account) return fail(409, "account_exists");
    if (isLogin && !account) return fail(404, "no_account");
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

  // The carrier sends the SMS and owns the code. A failure here is the end
  // of the attempt: no row is written, so the user can try again at once
  // rather than waiting out a cooldown for a code that never arrived.
  let referenceNo: string;
  try {
    referenceNo = await requestOtp(msisdn, body.application_hash);
  } catch (error) {
    console.error("otp-request: carrier refused", error);
    if (error instanceof ChargingError) {
      return fail(502, "sms_failed", error.message);
    }
    return fail(502, "sms_failed");
  }

  const { error: insertError } = await supabase.from("otp_requests").insert({
    msisdn,
    reference_no: referenceNo,
    expires_at: new Date(Date.now() + OTP_VALIDITY_SECONDS * 1000).toISOString(),
    device_id: body.device_id ?? null,
    request_ip: req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
  });

  if (insertError) {
    console.error("otp-request: insert failed", insertError);
    return fail(500, "server_error");
  }

  return json({
    cooldown_seconds: RESEND_COOLDOWN_SECONDS,
    expires_in: OTP_VALIDITY_SECONDS,
  });
});
