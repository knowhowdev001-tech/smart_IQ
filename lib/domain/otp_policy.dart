/// OTP timing, shared by the screen that counts down and the repository that
/// enforces it.
///
/// These live in the domain layer rather than in either of those because the
/// two must agree. A countdown longer than the real validity shows the user
/// time they do not have; a shorter one refuses a code that would still have
/// worked. The authority is now `supabase/functions/otp-request`, which is
/// what actually writes `otp_requests.expires_at` and enforces the resend
/// cooldown; these are its values mirrored for the countdown, so a change
/// there has to be made here too.
library;

/// How long a code stays valid (PRD 6.1).
const Duration kOtpValidity = Duration(minutes: 5);

/// How long before a resend is allowed. Each SMS is a direct cost, so this
/// is a spend control as much as a security one.
const Duration kOtpResendCooldown = Duration(seconds: 60);
