// The client normalises to the local `0XXXXXXXXX` form, but `users.msisdn`
// is constrained to E.164 (`+94` plus nine digits). Normalising again here
// rather than trusting what arrived is what stops two spellings of one
// number from becoming two accounts.

const MOBILE_PREFIXES = new Set([
  "70", "71", "72", "74", "75", "76", "77", "78",
]);

/// Returns `+94XXXXXXXXX`, or null when the input is not a Sri Lankan
/// mobile number in any of the forms users actually type.
export function toE164(input: string): string | null {
  let digits = (input ?? "").replace(/[^\d+]/g, "");

  if (digits.startsWith("+94")) {
    digits = digits.slice(3);
  } else if (digits.startsWith("94") && digits.length === 11) {
    digits = digits.slice(2);
  } else if (digits.startsWith("0")) {
    digits = digits.slice(1);
  }

  digits = digits.replace(/\D/g, "");

  if (digits.length !== 9) return null;
  if (!MOBILE_PREFIXES.has(digits.slice(0, 2))) return null;

  return `+94${digits}`;
}
