// Firebase Cloud Messaging over the HTTP v1 API.
//
// v1 authenticates with a short-lived Google OAuth token rather than the
// retired server key. The token comes from an RS256 JWT signed with the
// service account's private key, done against Web Crypto directly for the
// same reason `tokens.ts` does HS256 that way: it is one signature, and the
// firebase-admin SDK does not run on Deno Deploy.

const encoder = new TextEncoder();

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlJson(value: unknown): string {
  return base64url(encoder.encode(JSON.stringify(value)));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0),
  );
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

let cached: { token: string; expiresAt: number } | null = null;

async function accessToken(account: ServiceAccount): Promise<string> {
  // Isolates are reused between invocations, so a warm dispatcher skips the
  // token round trip. Refreshed five minutes early to avoid racing expiry.
  if (cached && cached.expiresAt > Date.now() + 5 * 60_000) return cached.token;

  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64urlJson({ alg: "RS256", typ: "JWT" })}.${
    base64urlJson({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  }`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await importPrivateKey(account.private_key),
    encoder.encode(unsigned),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(new Uint8Array(signature))}`,
    }),
  });
  if (!res.ok) {
    throw new Error(`google oauth failed: ${res.status} ${await res.text()}`);
  }

  const { access_token, expires_in } = await res.json();
  cached = { token: access_token, expiresAt: Date.now() + expires_in * 1000 };
  return access_token;
}

export interface PushMessage {
  title: string;
  body: string;
  /// Android notification channel; one per notification kind so the user
  /// can also silence a kind from system settings.
  channel: string;
  /// String-only, as FCM requires. Carries the deep-link route.
  data: Record<string, string>;
}

/// What happened to one token.
///
/// `dead` means FCM will never accept the token again (app uninstalled,
/// token rotated) and the row should be deleted. `retry` is a transient
/// failure worth another attempt. `failed` is our own fault and will fail
/// the same way on retry.
export type SendOutcome = "sent" | "dead" | "retry" | "failed";

export class FcmClient {
  private readonly account: ServiceAccount;

  /// Takes the service account key as raw JSON or base64-encoded JSON.
  /// Base64 exists because shells mangle JSON on the way into
  /// `supabase secrets set`: PowerShell and cmd strip the quotes, which
  /// leaves `{type:service_account,...}`. Base64 has no characters for a
  /// shell to eat.
  constructor(serviceAccount: string) {
    const value = serviceAccount.trim();
    const json = value.startsWith("{") ? value : atob(value);
    try {
      this.account = JSON.parse(json);
    } catch {
      throw new Error(
        "FCM_SERVICE_ACCOUNT is not valid JSON; set it from the dashboard or as base64",
      );
    }
  }

  async send(token: string, message: PushMessage): Promise<SendOutcome> {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${this.account.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await accessToken(this.account)}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              priority: "high",
              notification: {
                channel_id: message.channel,
                icon: "ic_stat_notify",
              },
            },
            apns: {
              payload: { aps: { sound: "default" } },
            },
          },
        }),
      },
    );

    if (res.ok) return "sent";

    const detail = await res.text();
    // 404 UNREGISTERED is the documented "this install is gone" answer;
    // 400 INVALID_ARGUMENT on the token field means it was never valid.
    if (res.status === 404 || (res.status === 400 && detail.includes("registration token"))) {
      return "dead";
    }
    console.warn(`fcm ${res.status}: ${detail}`);
    if (res.status >= 500 || res.status === 429) return "retry";
    // Anything else (401/403 credentials, a malformed payload) is our fault,
    // not the device's, so the token stays and the row is marked failed.
    return "failed";
  }
}
