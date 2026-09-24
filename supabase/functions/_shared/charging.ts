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
  readonly statusCode: string | null;

  constructor(
    readonly endpoint: string,
    statusCode: string | null,
    message: string,
  ) {
    super(message);
    this.name = "ChargingError";
    // The provider does not always put its code in `data.statusCode`. E1343
    // arrived with that field null and the code only inside the message
    // ("... (code: E1343)"), so a caller matching on a code -- the signup
    // fallback matches on E1351 -- would miss it and dead-end the user.
    this.statusCode = statusCode ?? message.match(/\b([ES]\d{4})\b/)?.[1] ??
      null;
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

/// The one number allowed to skip the carrier, and the code it accepts.
///
/// Null unless both secrets are set, which is what makes unsetting either
/// one the kill switch, with no deploy. Deliberately not a constant in this
/// file: a fixed code in a public repository is a password for every
/// account, which is what the development OTP was before it was removed.
export function testBypass(): { msisdn: string; otp: string } | null {
  const msisdn = Deno.env.get("TEST_MSISDN");
  const otp = Deno.env.get("TEST_OTP");
  return msisdn && otp ? { msisdn, otp } : null;
}

/// The number shape the service wants: `tel:94XXXXXXXXX`, no `+`, no
/// leading zero. Ours are stored E.164 as `+94XXXXXXXXX`.
export function toTel(msisdn: string): string {
  const digits = msisdn.replace(/\D/g, "").replace(/^0+/, "");
  return `tel:${digits.startsWith("94") ? digits : `94${digits}`}`;
}

/// The reply shape common to every action. `errors` is `send-sms`'s alone:
/// the routes a batch was *not* delivered to.
interface ChargingBody {
  success?: boolean;
  /// The route the service took: `dialog` or `mobitel`.
  carrier?: string;
  error?: string;
  message?: string;
  data?: Record<string, unknown>;
  errors?: Record<string, unknown>;
}

/// One POST to the service, with the HTTP status kept.
///
/// [call] reduces this to `data`, which is all a flat reply has. `send-sms`
/// answers with per-route groups and a `207`, and needs both.
async function post(
  endpoint: string,
  payload: Record<string, unknown>,
): Promise<{ status: number; body: ChargingBody }> {
  const { baseUrl, apiKey, secret } = config();

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": apiKey,
      },
      body: JSON.stringify({ endpoint, secret, ...payload }),
      signal: controller.signal,
    });
    return { status: response.status, body: await response.json() };
  } catch (error) {
    throw new Error(`charging ${endpoint} unreachable: ${error}`);
  } finally {
    clearTimeout(timer);
  }
}

function accepted(status: number, body: ChargingBody): boolean {
  return status >= 200 && status < 300 && body.success === true;
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
  return (await callRouted(endpoint, payload)).data;
}

/// [call], plus the route the service took. A masked subscriber id no
/// longer shows which network it belongs to, so whoever keeps one has to
/// keep this with it.
async function callRouted(
  endpoint: string,
  payload: Record<string, unknown>,
): Promise<{ data: Record<string, unknown>; carrier: string | null }> {
  const { status, body } = await post(endpoint, payload);

  if (!accepted(status, body)) {
    throw new ChargingError(
      endpoint,
      (body.data?.statusCode as string) ?? null,
      body.message ?? body.error ?? `HTTP ${status}`,
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

  return { data, carrier: body.carrier ?? null };
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

/// What the carrier's verify says about the subscriber it just checked.
export interface VerifiedSubscriber {
  /// `REGISTERED` once the verify has subscribed the number.
  subscriptionStatus: string | null;

  /// The id the carrier knows this subscriber by, masked where the provider
  /// hides numbers from apps. Anything sent to the subscriber later is
  /// addressed to it.
  subscriberId: string | null;

  /// The route that issued [subscriberId], which calls made with it name.
  carrier: string | null;
}

/// Verifies a code against its reference. The verify also completes the
/// subscription, so its reply is the subscriber's identity from here on.
export async function verifyOtp(args: {
  msisdn: string;
  referenceNo: string;
  otp: string;
}): Promise<VerifiedSubscriber> {
  const { data, carrier } = await callRouted("otp-verify", {
    referenceNo: args.referenceNo,
    otp: args.otp,
    // Not sent upstream by the service; it needs the number only to route.
    subscriberId: toTel(args.msisdn),
  });

  return {
    subscriptionStatus: (data.subscriptionStatus as string) ?? null,
    subscriberId: (data.subscriberId as string) ?? null,
    carrier,
  };
}

/// Who an SMS goes to. The carrier addresses a subscriber by the id its
/// verify returned; the phone number is the fallback for one we never got.
export interface SmsRecipient {
  msisdn: string;
  subscriberId?: string | null;
  carrier?: string | null;
}

/// The carrier refuses a second OTP for a number it has already registered.
///
/// Its OTP is a subscription registration, not a repeatable login: a number
/// goes through it once and is "already registered" from then on. Signup
/// falls back to a code of our own when it sees this; nothing else should
/// treat it as a failure either, since it is a statement of fact.
export const ALREADY_REGISTERED = "E1351";

/// Sends one plain SMS. No subscription semantics -- this is the action a
/// code of our own goes out through.
///
/// Not routed through [call], because `send-sms` does not answer like the
/// others: it splits a batch by route and reports each group separately, so
/// the flat `data.statusCode` gate has nothing to read and a message
/// delivered to nobody comes back looking like a success. A login whose code
/// was refused must say so, not leave the user watching an inbox.
export async function sendSms(
  to: SmsRecipient,
  message: string,
): Promise<void> {
  // The name the code arrives from. Read here rather than in `config()`
  // because it is not in the same class as the credentials: those fail
  // closed, since without them nothing can be sent at all, while an unset
  // mask just sends as the route's default. There is no fallback value on
  // purpose -- a mask has to be registered with the provider before it is
  // accepted, so a guessed one would turn every login SMS into a refusal.
  const mask = Deno.env.get("CHARGING_SMS_MASK");

  // The masked id goes out exactly as the carrier gave it: toTel would
  // strip it to digits. It carries no network prefix to route on, so the
  // carrier that issued it is named alongside.
  const masked = to.subscriberId ?? null;

  const { status, body } = await post("send-sms", {
    message,
    destinationAddresses: [masked ?? toTel(to.msisdn)],
    ...(masked && to.carrier ? { carrier: to.carrier } : {}),
    ...(mask ? { sourceAddress: mask } : {}),
  });

  const data = body.data ?? {};
  const failures = body.errors ?? {};
  const groups = (data.byCarrier ?? {}) as Record<
    string,
    { statusCode?: string; statusDetail?: string } | null
  >;

  /// Everything the reply says about why, in one line.
  ///
  /// `errors` and `byCarrier` are the two places this action puts the truth,
  /// and neither is where a flat reply would put it. Quoting both on every
  /// refusal is what stops a real reason being reduced to "HTTP 207" --
  /// which is exactly what reached the log before, leaving the cause unknown.
  const detail = () =>
    [
      body.message ?? body.error,
      Object.keys(failures).length ? `errors: ${JSON.stringify(failures)}` : null,
      Object.keys(groups).length ? `byCarrier: ${JSON.stringify(groups)}` : null,
    ].filter(Boolean).join(" -- ") || `HTTP ${status}`;

  if (!accepted(status, body)) {
    throw new ChargingError(
      "send-sms",
      (data.statusCode as string) ?? null,
      detail(),
    );
  }

  // 207 means some routes took it and some did not, with the refusals under
  // a top-level `errors`. We send to one number, so partly delivered is not
  // delivered.
  if (status === 207 || Object.keys(failures).length > 0) {
    throw new ChargingError("send-sms", null, detail());
  }

  for (const [carrier, group] of Object.entries(groups)) {
    const code = group?.statusCode;
    if (code && code !== PROVIDER_OK) {
      throw new ChargingError(
        "send-sms",
        code,
        `${carrier}: ${group?.statusDetail ?? code}`,
      );
    }
  }

  // A reply that confirms nothing is not proof of anything, but the shape of
  // this one is the provider's to change, so it is logged rather than thrown:
  // refusing every SMS over an unrecognised success would be the worse
  // failure. The body is here so the next one tells us which it was.
  if (Object.keys(groups).length === 0 && !data.statusCode) {
    console.error(
      "charging send-sms: accepted with no per-route result",
      JSON.stringify(body),
    );
    return;
  }

  console.log(`charging send-sms: ${JSON.stringify(groups)}`);
}

/// Mobitel answers "not subscribed" with an error code rather than a
/// status, and pairs it with "invalid address" in the same code. We build
/// the address ourselves in [toTel], so between the two readings the
/// unregistered one is the only one that can be true here.
const NOT_REGISTERED = "E1951";

/// `REGISTERED` or `UNREGISTERED`. Safe to retry.
///
/// Never throws for a subscriber who simply is not subscribed: that is an
/// answer, and the billing rail treats it as one.
export async function subscriberStatus(msisdn: string): Promise<string> {
  try {
    const data = await call("subscriber-status", {
      subscriberId: toTel(msisdn),
    });
    return (data.subscriptionStatus as string) ?? "UNREGISTERED";
  } catch (error) {
    if (error instanceof ChargingError && error.statusCode === NOT_REGISTERED) {
      return "UNREGISTERED";
    }
    throw error;
  }
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
