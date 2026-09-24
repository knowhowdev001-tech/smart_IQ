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
import {
  ALREADY_REGISTERED,
  ChargingError,
  requestOtp,
  sendSms,
  subscriberStatus,
  testBypass,
} from "../_shared/charging.ts";
import { hashSecret, otpPepper } from "../_shared/tokens.ts";
import { toE164 } from "../_shared/msisdn.ts";

// Must match `kOtpValidity` and `kOtpResendCooldown` in
// lib/domain/otp_policy.dart. That file says so too: a countdown longer than
// the real validity shows the user time they do not have.
const OTP_VALIDITY_SECONDS = 5 * 60;
const RESEND_COOLDOWN_SECONDS = 60;

/// The SMS a code of our own goes out in.
///
/// Written per language rather than translated at the client, because the
/// client never sees this text: an English code to a Sinhala user would be
/// the one part of this product that ignores them.
function codeMessage(code: string, language: string): string {
  switch (language) {
    case "si":
      return `ඔබේ Smart IQ කේතය ${code} වේ. මිනිත්තු 5කින් කල් ඉකුත් වේ.`;
    case "ta":
      return `உங்கள் Smart IQ குறியீடு ${code}. 5 நிமிடங்களில் காலாவதியாகும்.`;
    default:
      return `${code} is your Smart IQ code. It expires in 5 minutes.`;
  }
}

/// Six digits, from the platform's cryptographic source.
function newCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, "0");
}

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: {
    msisdn?: string;
    device_id?: string;
    full_name?: string;
    login?: boolean;
    language?: string;
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

  // One number may skip the carrier entirely, so development does not cost
  // an SMS and a code per login. Both secrets have to be set for it to
  // exist at all, and it is one number with one code -- not the blanket
  // development code this replaced.
  const bypass = testBypass();
  const isTestNumber = bypass !== null && msisdn === bypass.msisdn;

  // Each SMS is a direct cost, so the cooldown is a spend control as much as
  // a security one, and the client's own timer cannot be trusted with it.
  // The test number pays for no SMS, so it waits for nothing.
  let recent: { created_at: string } | null = null;

  if (!isTestNumber) {
    const { data, error } = await supabase
      .from("otp_requests")
      .select("created_at")
      .eq("msisdn", msisdn)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error("otp-request: cooldown lookup failed", error);
      return fail(500, "server_error");
    }
    recent = data;
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

  // Which of the three ways this code is issued, and therefore how the
  // verify side will check it: the carrier holds it, we hold its hash, or
  // it is the test number and there is nothing to send at all.
  let referenceNo: string | null = "test-bypass";
  let otpHash: string | null = null;
  let baseline: string | null = null;

  if (isTestNumber) {
    console.warn(`otp-request: TEST BYPASS used for ${msisdn}`);
  } else {
    // Signup goes through the carrier, because that is where its
    // registration belongs. Login never does: the carrier's OTP is a
    // registration, so it refuses a number that has already been through
    // it, and every returning user is one of those.
    let carrierIssued = false;

    if (!isLogin) {
      try {
        referenceNo = await requestOtp(msisdn, body.application_hash);
        carrierIssued = true;
      } catch (error) {
        // "Already registered" is a fact about the number, not a failure:
        // fall through and send a code of our own. Anything else is a
        // carrier that cannot deliver, and must not look like success.
        const alreadyRegistered = error instanceof ChargingError &&
          error.statusCode === ALREADY_REGISTERED;

        if (!alreadyRegistered) {
          console.error("otp-request: carrier refused", error);
          if (error instanceof ChargingError) {
            return fail(502, "sms_failed", error.message);
          }
          return fail(502, "sms_failed");
        }

        console.warn(
          `otp-request: ${msisdn} is already registered with the carrier; ` +
            "sending a code of our own",
        );
      }
    }

    if (carrierIssued) {
      // Taken before the code is verified, because the carrier's verify may
      // subscribe the number and we need to know which of the two happened.
      // A failure here must not cost the user their signup, so it records
      // null and the verify side treats that as "unknown, leave it alone".
      try {
        baseline = await subscriberStatus(msisdn);
      } catch (error) {
        console.error("otp-request: subscriber status unavailable", error);
      }
    } else {
      // Ours to mint, ours to check. Only the hash is stored, so a leaked
      // row is not a code.
      const code = newCode();
      referenceNo = null;
      otpHash = await hashSecret(code, msisdn, otpPepper());

      try {
        await sendSms(msisdn, codeMessage(code, body.language ?? "en"));
      } catch (error) {
        console.error(`otp-request: sms failed for ${msisdn}`, error);
        if (error instanceof ChargingError) {
          return fail(502, "sms_failed", error.message);
        }
        return fail(502, "sms_failed");
      }
    }
  }

  const { error: insertError } = await supabase.from("otp_requests").insert({
    msisdn,
    reference_no: referenceNo,
    otp_hash: otpHash,
    subscriber_status: baseline,
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
