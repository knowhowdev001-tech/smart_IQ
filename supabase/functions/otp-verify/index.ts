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
  timingSafeEqual,
} from "../_shared/tokens.ts";
import {
  ChargingError,
  type SubscriberStatus,
  subscriberStatus,
  testBypass,
  type VerifiedSubscriber,
  verifyOtp,
} from "../_shared/charging.ts";
import { recordTelcoStatus } from "../_shared/telco_status.ts";
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
    .select(
      "id, reference_no, otp_hash, expires_at, attempt_count, subscriber_status",
    )
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

  // Each row says how it is checked. A carrier row quotes its reference
  // back; one of ours is checked against the hash we kept; the test row is
  // checked against the secret. A row from before any of this has neither
  // and cannot be verified at all.
  const bypass = testBypass();
  const isTestRow = otp.reference_no === "test-bypass";
  const isCarrierRow = !isTestRow && otp.reference_no !== null;

  if (!isTestRow && !isCarrierRow && !otp.otp_hash) {
    return fail(410, "otp_expired");
  }

  /// Counts the wrong guess and reports it as one. Six digits is a million
  /// combinations, and the cap above is what keeps that out of reach.
  const wrongCode = async () => {
    await supabase
      .from("otp_requests")
      .update({ attempt_count: otp.attempt_count + 1 })
      .eq("id", otp.id);
    return fail(401, "otp_invalid");
  };

  // Only a carrier row is verified by the carrier, and only its reply says
  // who the subscriber is.
  let verified: VerifiedSubscriber | null = null;

  if (isTestRow) {
    if (!bypass || msisdn !== bypass.msisdn || code !== bypass.otp) {
      return await wrongCode();
    }
    console.warn(`otp-verify: TEST BYPASS used for ${msisdn}`);
  } else if (isCarrierRow) {
    try {
      verified = await verifyOtp({
        msisdn,
        referenceNo: otp.reference_no!,
        otp: code,
      });
    } catch (error) {
      if (error instanceof ChargingError) {
        // The provider's codes are an open set, so a refusal is reported as
        // a wrong code and the actual reason is logged rather than guessed.
        console.error(
          `otp-verify: carrier refused (${error.statusCode})`,
          error.message,
        );
        return await wrongCode();
      }

      await supabase
        .from("otp_requests")
        .update({ attempt_count: otp.attempt_count + 1 })
        .eq("id", otp.id);
      console.error("otp-verify: carrier unreachable", error);
      return fail(502, "sms_failed");
    }
  } else {
    // Ours: the code was sent as a plain SMS and only its hash was kept.
    const candidate = await hashSecret(code, msisdn, otpPepper());
    if (!timingSafeEqual(candidate, otp.otp_hash!)) return await wrongCode();
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
  //
  // A carrier code is a signup's, and its verify subscribed the number: the
  // reply's subscriberId is the (masked) id the carrier addresses this
  // subscriber by from now on, and the login code is sent to it. Our own
  // codes (login) say nothing about it and leave it as it was.
  const { data: user, error: userError } = await supabase
    .from("users")
    .upsert(
      {
        msisdn,
        msisdn_verified_at: now,
        last_login_at: now,
        ...(verified?.subscriberId
          ? {
            Masked_subscriberId: verified.subscriberId,
            carrier: verified.carrier,
          }
          : {}),
      },
      { onConflict: "msisdn" },
    )
    .select("id, status")
    .single();

  if (userError || !user) {
    console.error("otp-verify: user upsert failed", userError);
    return fail(500, "server_error");
  }

  if (user.status !== "active") return fail(403, "account_suspended");

  // Signup is the telco rail's subscribe step. The carrier's verify
  // completes the subscription (the charging spec says so), and its reply
  // says how far it got: REGISTERED is a Basic subscriber from this moment,
  // charged from day one with no trial (PRD 7.2). Anything else -- the first
  // charge still pending, say -- is asked again once, by the masked id the
  // reply just gave us, so a subscription that settles in those seconds is
  // not left to the next app open.
  //
  // An own-code signup happens only when the carrier refused a second OTP
  // because the number is already registered; otp-request recorded that, so
  // it is Basic too. A login row grants nothing here: payment-status keeps
  // an existing subscriber's tier current from the app.
  //
  // Whatever the answer, it goes through the same recorder payment-status
  // uses, so the tier and the day's telco_charges row match on both paths.
  let telco: SubscriberStatus | null = null;

  if (isCarrierRow && verified) {
    console.log(
      `otp-verify: carrier verify says ${verified.subscriptionStatus} ` +
        `(${verified.carrier})`,
    );
    telco = verified.subscriptionStatus === "REGISTERED"
      ? { status: "REGISTERED", raw: verified.raw }
      : null;

    if (!telco) {
      try {
        telco = await subscriberStatus({
          msisdn,
          subscriberId: verified.subscriberId,
          carrier: verified.carrier,
        });
      } catch (error) {
        // Not fatal: payment-status asks again on the first app open.
        console.error("otp-verify: status re-check failed", error);
      }
    }
  } else if (!isTestRow && otp.subscriber_status === "REGISTERED") {
    telco = {
      status: "REGISTERED",
      raw: { source: "otp-request", note: "carrier refused OTP: already registered" },
    };
  }

  if (telco) {
    try {
      await recordTelcoStatus(
        supabase,
        { id: user.id, msisdn },
        verified?.carrier ?? null,
        telco,
      );
    } catch (error) {
      // Not fatal: the session is what this call is for, and payment-status
      // will put the entitlement right on the next app open.
      console.error("otp-verify: entitlement write failed", error);
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
    // One literal, not a concatenation: the client infers the row's type
    // from the string, and a computed one leaves it unknown.
    .select(
      "user_id, full_name, language_preference, theme_preference, current_status, education_level, created_at",
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
