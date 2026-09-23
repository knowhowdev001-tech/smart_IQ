// The Mobile Charging API: OTP delivery, subscriptions and SMS, across both
// carriers.
//
// One URL for everything. The action is a field in the body, not a path, and
// every call carries the API key as a header *and* the secret in the body --
// either missing is a 401. Routing between Dialog and Mobitel is decided by
// the service from the subscriber number, so nothing here picks a carrier.
//
// The credentials never leave the server: this key can subscribe numbers and
// send SMS, and an APK is decompilable.

const REQUEST_TIMEOUT_MS = 30_000;

/// The provider's own "it worked" code. HTTP 200 with `success: true` only
/// means the request reached the provider, so this is the second gate every
/// call has to pass (spec section 3).
const PROVIDER_OK = "S1000";

/// A call that reached the provider and was refused by it.
///
/// `statusCode` is the provider's own code -- `E1325` for a malformed
/// number, and an open set beyond that, which is why nothing here switches
/// on it exhaustively.
export class ChargingError extends Error {
  constructor(
    readonly endpoint: string,
    readonly statusCode: string | null,
    message: string,
  ) {
    super(message);
    this.name = "ChargingError";
  }
}

function config(): { baseUrl: string; apiKey: string; secret: string } {
  const baseUrl = Deno.env.get("CHARGING_BASE_URL");
  const apiKey = Deno.env.get("CHARGING_API_KEY");
  const secret = Deno.env.get("CHARGING_SECRET");

  // Fails closed. An unset credential must stop the flow, not fall back to
  // issuing a code nobody can receive.
  if (!baseUrl || !apiKey || !secret) {
    throw new Error(
      "missing charging configuration: set CHARGING_BASE_URL, " +
        "CHARGING_API_KEY and CHARGING_SECRET",
    );
  }

  return { baseUrl, apiKey, secret };
}

/// The number shape the service wants: `tel:94XXXXXXXXX`, no `+`, no
/// leading zero. Ours are stored E.164 as `+94XXXXXXXXX`.
export function toTel(msisdn: string): string {
  const digits = msisdn.replace(/\D/g, "").replace(/^0+/, "");
  return `tel:${digits.startsWith("94") ? digits : `94${digits}`}`;
}

/// Calls one action and returns its `data`, having checked both gates.
///
/// Throws [ChargingError] when the provider refused, and a plain Error when
/// the service itself could not be reached -- the caller needs to tell "your
/// code was wrong" from "we are down".
export async function call(
  endpoint: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const { baseUrl, apiKey, secret } = config();

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response: Response;
  let body: {
    success?: boolean;
    error?: string;
    message?: string;
    data?: Record<string, unknown>;
  };

  try {
    response = await fetch(baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": apiKey,
      },
      body: JSON.stringify({ endpoint, secret, ...payload }),
      signal: controller.signal,
    });
    body = await response.json();
  } catch (error) {
    throw new Error(`charging ${endpoint} unreachable: ${error}`);
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok || body.success !== true) {
    throw new ChargingError(
      endpoint,
      (body.data?.statusCode as string) ?? null,
      body.message ?? body.error ?? `HTTP ${response.status}`,
    );
  }

  const data = body.data ?? {};
  const statusCode = data.statusCode as string | undefined;

  // The provider can refuse inside a 200. E1325 -- a number that is not in
  // `tel:94XXXXXXXXX` form -- arrives this way.
  if (statusCode && statusCode !== PROVIDER_OK) {
    throw new ChargingError(
      endpoint,
      statusCode,
      (data.statusDetail as string) ?? body.message ?? statusCode,
    );
  }

  return data;
}

/// Sends an OTP and returns the reference the verify step needs.
export async function requestOtp(
  msisdn: string,
  applicationHash?: string,
): Promise<string> {
  const data = await call("otp-request", {
    subscriberId: toTel(msisdn),
    // Lets Android's SMS retriever read the code without the user leaving
    // the app; the service defaults it when we have none.
    ...(applicationHash ? { applicationHash } : {}),
  });

  const reference = data.referenceNo as string | undefined;
  if (!reference) {
    throw new ChargingError("otp-request", null, "no referenceNo returned");
  }
  return reference;
}

/// Verifies a code against its reference. Returns the provider's view of the
/// subscriber, including `subscriptionStatus`.
export async function verifyOtp(args: {
  msisdn: string;
  referenceNo: string;
  otp: string;
}): Promise<Record<string, unknown>> {
  return await call("otp-verify", {
    referenceNo: args.referenceNo,
    otp: args.otp,
    // Not sent upstream by the service; it needs the number only to route.
    subscriberId: toTel(args.msisdn),
  });
}

/// `REGISTERED` or `UNREGISTERED`. Safe to retry.
export async function subscriberStatus(msisdn: string): Promise<string | null> {
  const data = await call("subscriber-status", { subscriberId: toTel(msisdn) });
  return (data.subscriptionStatus as string) ?? null;
}

/// Subscribes (`true`) or unsubscribes (`false`) the number.
export async function setSubscription(
  msisdn: string,
  subscribed: boolean,
): Promise<Record<string, unknown>> {
  return await call("user-subscription", {
    subscriberId: toTel(msisdn),
    action: subscribed ? "1" : "0",
  });
}
