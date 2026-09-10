import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/mock/mock_repositories.dart';
import 'package:smart_iq/domain/otp_policy.dart';

/// Pins the fixed development OTP. When the real server-side check of PRD 6.1
/// lands these tests should be deleted, not adjusted.
void main() {
  late MockBackendState state;
  late MockAuthRepository auth;

  setUp(() {
    state = MockBackendState();
    auth = MockAuthRepository(state);
  });

  test('the fixed code verifies', () async {
    await auth.requestOtp('0771234821');
    await auth.verifyOtp(msisdn: '0771234821', code: kMockOtpCode);
    expect(state.signedIn, isTrue);
  });

  test('any other six digits are rejected', () async {
    await auth.requestOtp('0771234821');
    expect(
      () => auth.verifyOtp(msisdn: '0771234821', code: '000000'),
      throwsA(isA<OtpInvalidException>()),
    );
    expect(state.signedIn, isFalse);
  });

  test('a correct code just inside the window still verifies', () async {
    await auth.requestOtp('0771234821');
    state.otpIssuedAt =
        DateTime.now().subtract(kOtpValidity - const Duration(seconds: 5));
    await auth.verifyOtp(msisdn: '0771234821', code: kMockOtpCode);
    expect(state.signedIn, isTrue);
  });

  test('expiry still beats a correct code', () async {
    await auth.requestOtp('0771234821');
    state.otpIssuedAt =
        DateTime.now().subtract(kOtpValidity + const Duration(seconds: 5));
    expect(
      () => auth.verifyOtp(msisdn: '0771234821', code: kMockOtpCode),
      throwsA(isA<OtpExpiredException>()),
    );
  });

  // The screen counts down from the same constant it is enforced against.
  // A mismatch would either show time the user does not have or refuse a
  // code that was still valid.
  test('the code outlives the resend cooldown', () {
    expect(kOtpValidity, greaterThan(kOtpResendCooldown));
  });
}
