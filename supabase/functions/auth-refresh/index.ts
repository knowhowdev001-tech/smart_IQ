// POST /functions/v1/auth-refresh  { user_id, refresh_token, device_id }
//
// Exchanges a refresh token for a new access token, so a returning user is
// not asked for an OTP every hour. Without this endpoint the access token
// minted by `otp-verify` simply expired and the app fell back to the landing
// screen (PRD 6.1: signing in again should be the exception, not the routine).
//
// Public like the OTP endpoints, for the same reason: the caller's access
// token has expired by definition, so there is nothing to verify a JWT
// against. The refresh token itself is the credential, and it is only ever
// stored hashed.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { fail, json, requireEnv, serve } from "../_shared/http.ts";
import { hashSecret, mintAccessToken, newRefreshToken, otpPepper } from "../_shared/tokens.ts";

// Must match otp-verify: the client's countdown to a refresh is derived from
// this, and a longer claim than the token actually carries means requests
// start failing before the app thinks it should refresh.
const ACCESS_TOKEN_TTL_SECONDS = 60 * 60;

// A handset that has not opened the app in this long has to sign in again.
// Rotation alone would otherwise keep a stolen refresh token alive forever.
const IDLE_LIMIT_DAYS = 90;

serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method_not_allowed");

  let body: { user_id?: string; refresh_token?: string; device_id?: string };
  try {
    body = await req.json();
  } catch {
    return fail(400, "bad_request", "body must be JSON");
  }

  const userId = body.user_id?.trim();
  const refreshToken = body.refresh_token?.trim();
  const deviceId = body.device_id?.trim();
  if (!userId || !refreshToken || !deviceId) {
    return fail(400, "bad_request", "user_id, refresh_token and device_id are required");
  }

  const supabase = createClient(
    requireEnv("SUPABASE_URL"),
    requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  // The stored hash is salted with the user id, exactly as otp-verify wrote
  // it, which is why the client sends its user id alongside the token.
  const hash = await hashSecret(refreshToken, userId, otpPepper());

  const { data: session, error } = await supabase
    .from("auth_sessions")
    .select("id, last_seen_at")
    .eq("user_id", userId)
    .eq("device_id", deviceId)
    .eq("refresh_token_hash", hash)
    .is("revoked_at", null)
    .maybeSingle();

  if (error) {
    console.error("auth-refresh: session lookup failed", error);
    return fail(500, "server_error");
  }

  // One answer for every way a session can be gone -- revoked from another
  // device, rotated away, or never real. The client's remedy is the same.
  if (!session) return fail(401, "session_expired");

  const idleMs = Date.now() - new Date(session.last_seen_at).getTime();
  if (idleMs > IDLE_LIMIT_DAYS * 24 * 60 * 60 * 1000) {
    await supabase
      .from("auth_sessions")
      .update({ revoked_at: new Date().toISOString() })
      .eq("id", session.id);
    return fail(401, "session_expired");
  }

  const { data: user, error: userError } = await supabase
    .from("users")
    .select("status")
    .eq("id", userId)
    .maybeSingle();

  if (userError) {
    console.error("auth-refresh: user lookup failed", userError);
    return fail(500, "server_error");
  }
  if (!user || user.status !== "active") return fail(403, "account_suspended");

  // Rotate on every use: a refresh token is single-use, so a copy that leaks
  // stops working the moment the real device refreshes again.
  const nextRefresh = newRefreshToken();
  const nextHash = await hashSecret(nextRefresh, userId, otpPepper());
  const now = new Date().toISOString();

  const { error: rotateError } = await supabase
    .from("auth_sessions")
    .update({ refresh_token_hash: nextHash, last_seen_at: now })
    .eq("id", session.id);

  if (rotateError) {
    console.error("auth-refresh: rotate failed", rotateError);
    return fail(500, "server_error");
  }

  return json({
    access_token: await mintAccessToken(
      userId,
      requireEnv("SUPABASE_JWT_SECRET", "APP_JWT_SECRET"),
      ACCESS_TOKEN_TTL_SECONDS,
    ),
    refresh_token: nextRefresh,
    expires_in: ACCESS_TOKEN_TTL_SECONDS,
    user_id: userId,
  });
});
