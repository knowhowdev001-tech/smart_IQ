// OTP hashing and JWT minting.
//
// PRD 4.4 does not use Supabase Auth, so this is where a session actually
// comes from: an HS256 token signed with the project JWT secret, with `sub`
// set to `users.id`. That is the whole reason `app.current_user_id()` and
// therefore every RLS policy keeps working against our own identity tables
// (see supabase/README.md).
//
// HS256 is done against Web Crypto directly rather than through a JWT
// library: it is a signature over two base64url segments, and the project
// has no other use for the dependency.

const encoder = new TextEncoder();

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64urlJson(value: unknown): string {
  return base64url(encoder.encode(JSON.stringify(value)));
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

function fromBase64url(segment: string): Uint8Array<ArrayBuffer> {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/") +
    "===".slice((segment.length + 3) % 4);
  return Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
}

/// Mints the access token PostgREST will accept.
///
/// `role` is what PostgREST switches the database role to, so it must be
/// `authenticated` for the grants on `create_profile` and the RLS policies
/// to apply.
export async function mintAccessToken(
  userId: string,
  secret: string,
  ttlSeconds: number,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64urlJson({ alg: "HS256", typ: "JWT" });
  const payload = base64urlJson({
    sub: userId,
    role: "authenticated",
    aud: "authenticated",
    iss: "smart_iq",
    iat: now,
    exp: now + ttlSeconds,
  });

  const signature = await crypto.subtle.sign(
    "HMAC",
    await hmacKey(secret),
    encoder.encode(`${header}.${payload}`),
  );

  return `${header}.${payload}.${base64url(new Uint8Array(signature))}`;
}

/// Checks an access token [mintAccessToken] issued and returns its `sub`,
/// or null for anything that is not one: a bad signature, another
/// algorithm, an expired or malformed token.
///
/// Used by functions the signed-in app calls. They check the token here
/// rather than leaning on the gateway's own JWT check, which follows the
/// project's signing-key setup rather than the secret these are minted with.
export async function verifyAccessToken(
  token: string,
  secret: string,
): Promise<string | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [header, payload, signature] = parts;

  try {
    const head = JSON.parse(new TextDecoder().decode(fromBase64url(header)));
    if (head.alg !== "HS256") return null;

    const valid = await crypto.subtle.verify(
      "HMAC",
      await hmacKey(secret),
      fromBase64url(signature),
      encoder.encode(`${header}.${payload}`),
    );
    if (!valid) return null;

    const claims = JSON.parse(new TextDecoder().decode(fromBase64url(payload)));
    if (typeof claims.exp !== "number" || claims.exp * 1000 <= Date.now()) {
      return null;
    }
    return typeof claims.sub === "string" && claims.sub !== ""
      ? claims.sub
      : null;
  } catch {
    return null;
  }
}

/// A refresh token the client stores and the server only ever sees hashed.
export function newRefreshToken(): string {
  return base64url(crypto.getRandomValues(new Uint8Array(32)));
}

/// SHA-256 over the value plus a server-side pepper.
///
/// OTPs are six digits, so an unpeppered hash of one is trivially reversed
/// by enumeration. The pepper lives only in the function's environment, which
/// is what makes a leaked `otp_requests` table useless on its own.
export async function hashSecret(
  value: string,
  salt: string,
  pepper: string,
): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(`${salt}:${value}:${pepper}`),
  );
  return base64url(new Uint8Array(digest));
}

/// Constant-time comparison, so a mismatch tells an attacker nothing about
/// how much of the hash was right.
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/// The pepper `hashSecret` is called with.
///
/// `OTP_PEPPER` remains what a real deployment sets. The constant below only
/// stands in when it is unset, so the OTP flow can be exercised on a project
/// with no secrets configured.
///
/// It is not a secret — it is in this repository. A build running on the
/// fallback gives `otp_requests` no protection at all: six digits is a
/// million combinations, and anyone with this file can enumerate them
/// against a leaked row. Set `OTP_PEPPER` before the table holds a real
/// user's number.
const DEV_PEPPER = "smart-iq-development-pepper-not-a-secret";

export function otpPepper(): string {
  const pepper = Deno.env.get("OTP_PEPPER");
  if (pepper) return pepper;

  console.warn("OTP_PEPPER unset — falling back to the development pepper");
  return DEV_PEPPER;
}
