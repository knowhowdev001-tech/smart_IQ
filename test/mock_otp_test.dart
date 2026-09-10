import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/mock/mock_repositories.dart';

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

  test('expiry still beats a correct code', () async {
    await auth.requestOtp('0771234821');
    state.otpIssuedAt = DateTime.now().subtract(const Duration(minutes: 6));
    expect(
      () => auth.verifyOtp(msisdn: '0771234821', code: kMockOtpCode),
      throwsA(isA<OtpExpiredException>()),
    );
  });
}
