// POST /functions/v1/otp-verify  { msisdn, code, device_id, device_name? }
//
// The point where a signup becomes a row. Verifying the code creates the
// `users` record if this number has never been seen, records the device in
// `auth_sessions`, and mints the JWT every later request authenticates with.
//
// The profile is deliberately *not* created here. PRD 6.1 step 5 has a
// verified user without a profile, and `create_profile` is the RPC that
// makes one — so this returns null for a new number and the client calls
// that RPC straight after a signup verification.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import {
  hashSecret,
  mintAccessToken,
  newRefreshToken,
  otpPepper,
} from "../_shared/tokens.ts";
import {
  ChargingError,
  setSubscription,
  testBypass,
  verifyOtp,
} from "../_shared/charging.ts";
import { toE164 } from "../_shared/msisdn.ts";

const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;

/// Wrong guesses allowed against one code before it is burned. Six digits is
/// a million combinations, but a code is live for five minutes, so the cap is
/// what keeps that from being brute-forced within its own window.
const MAX_ATTEMPTS = 5;

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: {
    msisdn?: string;
    code?: string;
    device_id?: string;
    device_name?: string;
  };
  try {
    body = await req.json();
  } catch {
    return fail(400, "bad_request", "body must be JSON");
  }

  const msisdn = toE164(body.msisdn ?? "");
  if (msisdn === null) return fail(400, "invalid_msisdn");

  const code = (body.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) return fail(401, "otp_invalid");

  const deviceId = (body.device_id ?? "").trim();
  if (deviceId === "") return fail(400, "bad_request", "device_id is required");

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  // The newest unconsumed code wins. A resend therefore supersedes the
  // previous code in practice, which is what a user who asked for a new one
  // expects.
  const { data: otp, error: otpError } = await supabase
    .from("otp_requests")
    .select("id, reference_no, expires_at, attempt_count, subscriber_status")
    .eq("msisdn", msisdn)
    .is("consumed_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (otpError) {
    console.error("otp-verify: lookup failed", otpError);
    return fail(500, "server_error");
  }

  // No live code and an expired one are the same thing to the user: the
  // screen offers a resend either way.
  if (!otp || new Date(otp.expires_at).getTime() <= Date.now()) {
    return fail(410, "otp_expired");
  }

  if (otp.attempt_count >= MAX_ATTEMPTS) {
    await supabase
      .from("otp_requests")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", otp.id);
    return fail(429, "too_many_attempts");
  }

  // A row from before the carrier took delivery over has no reference to
  // check against, and its code was never sent anyway.
  if (!otp.reference_no) return fail(410, "otp_expired");

  // The row the test bypass wrote is checked against the secret instead of
  // the carrier. One number, one code, and only while both secrets are set.
  const bypass = testBypass();
  const isTestRow = otp.reference_no === "test-bypass";

  if (isTestRow) {
    if (!bypass || msisdn !== bypass.msisdn || code !== bypass.otp) {
      await supabase
        .from("otp_requests")
        .update({ attempt_count: otp.attempt_count + 1 })
        .eq("id", otp.id);
      return fail(401, "otp_invalid");
    }
    console.warn(`otp-verify: TEST BYPASS used for ${msisdn}`);
  }

  // The carrier owns the code and the comparison. The attempt cap above is
  // still ours: the service documents no cap of its own, and six digits is a
  // million guesses from someone else's account.
  let verified: Record<string, unknown> = {};
  try {
    if (!isTestRow) {
      verified = await verifyOtp({
        msisdn,
        referenceNo: otp.reference_no,
        otp: code,
      });
    }
  } catch (error) {
    await supabase
      .from("otp_requests")
      .update({ attempt_count: otp.attempt_count + 1 })
      .eq("id", otp.id);

    if (error instanceof ChargingError) {
      // The provider's codes are an open set, so a refusal is reported as a
      // wrong code and the actual reason is logged rather than guessed at.
      console.error(
        `otp-verify: carrier refused (${error.statusCode})`,
        error.message,
      );
      return fail(401, "otp_invalid");
    }

    console.error("otp-verify: carrier unreachable", error);
    return fail(502, "sms_failed");
  }

  // Single use. Burned before the session is minted so a replay of the same
  // request cannot mint a second one.
  const { data: consumed, error: consumeError } = await supabase
    .from("otp_requests")
    .update({ consumed_at: new Date().toISOString() })
    .eq("id", otp.id)
    .is("consumed_at", null)
    .select("id")
    .maybeSingle();

  if (consumeError) {
    console.error("otp-verify: consume failed", consumeError);
    return fail(500, "server_error");
  }
  if (!consumed) return fail(410, "otp_expired");

  const now = new Date().toISOString();

  // Signup and login are the same call: the number either has an account or
  // gets one here. `msisdn` is unique, so the conflict path is what makes a
  // returning user a login rather than a duplicate account.
  const { data: user, error: userError } = await supabase
    .from("users")
    .upsert(
      { msisdn, msisdn_verified_at: now, last_login_at: now },
      { onConflict: "msisdn" },
    )
    .select("id, status")
    .single();

  if (userError || !user) {
    console.error("otp-verify: user upsert failed", userError);
    return fail(500, "server_error");
  }

  if (user.status !== "active") return fail(403, "account_suspended");

  const registeredNow = verified.subscriptionStatus === "REGISTERED";
  const registeredBefore = otp.subscriber_status === "REGISTERED";

  // Logging in must never start a subscription. The charging spec is
  // ambiguous about whether its verify subscribes on its own; if it did,
  // this is the number that would be paying for a login it never asked to
  // be charged for, so it is put back.
  if (registeredNow && otp.subscriber_status === "UNREGISTERED") {
    console.error(
      "otp-verify: carrier subscribed this number during verification -- " +
        "undoing; the subscribe flow is the only thing allowed to do that",
    );
    try {
      await setSubscription(msisdn, false);
    } catch (error) {
      console.error("otp-verify: could not undo the subscription", error);
    }
  }

  // The carrier told us, in the verify reply, whether this number was
  // already subscribed. Acting on it here saves the user a day of free
  // limits while they wait for the nightly reconcile to notice.
  //
  // Only upwards, and only when the subscription predates this login: an
  // UNREGISTERED answer is left to the reconcile, because cancelling a
  // paying subscriber over one hiccuping status call is the worse mistake.
  if (registeredNow && registeredBefore) {
    const { error: statusError } = await supabase
      .from("payment_status")
      .upsert({
        user_id: user.id,
        tier: "basic",
        source: "telco",
        status: "active",
        valid_until: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        last_checked_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (statusError) {
      // Not fatal: the session is what this call is for, and the reconcile
      // will put the entitlement right.
      console.error("otp-verify: entitlement write failed", statusError);
    }
  }

  // The pending signup has served its purpose now that the number is proved
  // and the account exists. Deleted rather than left to expire because the
  // row is a name against an unverified number, and this is the moment it
  // stops being needed.
  //
  // A failure here is logged but not fatal: the account is already created
  // and refusing the session over a stale row would be a worse outcome than
  // the row surviving until the next sweep.
  const { error: tempError } = await supabase
    .from("temp")
    .delete()
    .eq("msisdn", msisdn);

  if (tempError) {
    console.error("otp-verify: pending signup cleanup failed", tempError);
  }

  const refreshToken = newRefreshToken();
  const refreshHash = await hashSecret(refreshToken, user.id, otpPepper());

  // One live row per device: `auth_sessions_live_device_idx` is unique on
  // (user_id, device_id) where revoked_at is null, so signing in again on the
  // same handset rotates its token rather than accumulating rows.
  //
  // This is an update-then-insert rather than an upsert because that index is
  // partial. Postgres only matches `ON CONFLICT` against a partial index when
  // the conflict target repeats the predicate, and PostgREST's `onConflict`
  // takes column names only — so an upsert here raises 42P10, "no unique or
  // exclusion constraint matching the ON CONFLICT specification".
  const { data: rotated, error: rotateError } = await supabase
    .from("auth_sessions")
    .update({
      device_name: body.device_name ?? null,
      refresh_token_hash: refreshHash,
      issued_at: now,
      last_seen_at: now,
    })
    .eq("user_id", user.id)
    .eq("device_id", deviceId)
    .is("revoked_at", null)
    .select("id")
    .maybeSingle();

  if (rotateError) {
    console.error("otp-verify: session rotate failed", rotateError);
    return fail(500, "server_error");
  }

  if (!rotated) {
    const { error: sessionError } = await supabase
      .from("auth_sessions")
      .insert({
        user_id: user.id,
        device_id: deviceId,
        device_name: body.device_name ?? null,
        refresh_token_hash: refreshHash,
        issued_at: now,
        last_seen_at: now,
        revoked_at: null,
      });

    if (sessionError) {
      console.error("otp-verify: session insert failed", sessionError);
      return fail(500, "server_error");
    }
  }

  // Null for a number that has verified but has no account behind it. The
  // client creates the profile straight after a signup verification, and
  // sends anyone else to signup rather than into the app.
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select(
      "user_id, full_name, language_preference, theme_preference, " +
        "current_status, education_level, created_at",
    )
    .eq("user_id", user.id)
    .maybeSingle();

  if (profileError) {
    console.error("otp-verify: profile lookup failed", profileError);
    return fail(500, "server_error");
  }

  return json({
    access_token: await mintAccessToken(
      user.id,
      requireEnv("SUPABASE_JWT_SECRET", "APP_JWT_SECRET"),
      ACCESS_TOKEN_TTL_SECONDS,
    ),
    refresh_token: refreshToken,
    expires_in: ACCESS_TOKEN_TTL_SECONDS,
    user_id: user.id,
    profile: profile ? { ...profile, msisdn } : null,
  });
});
