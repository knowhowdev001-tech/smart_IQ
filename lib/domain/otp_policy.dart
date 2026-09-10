/// OTP timing, shared by the screen that counts down and the repository that
/// enforces it.
///
/// These live in the domain layer rather than in either of those because the
/// two must agree. A countdown longer than the real validity shows the user
/// time they do not have; a shorter one refuses a code that would still have
/// worked. When the OTP Edge Function of PRD 9.2 lands, it becomes the
/// authority and these values must be set to match what it writes to
/// `otp_requests.expires_at`.
library;

/// How long a code stays valid (PRD 6.1).
const Duration kOtpValidity = Duration(minutes: 3);

/// How long before a resend is allowed. Each SMS is a direct cost, so this
/// is a spend control as much as a security one.
const Duration kOtpResendCooldown = Duration(seconds: 60);
