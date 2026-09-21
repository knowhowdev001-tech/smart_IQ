import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/auth/session_store.dart';
import 'package:smart_iq/data/repositories/repositories.dart';
import 'package:smart_iq/data/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

/// The contract between the OTP Edge Functions and the screens.
///
/// The screens branch on exception type — "wrong code" offers a retry,
/// "expired" offers a resend — so the mapping from the function's `hint` onto
/// those types is what decides which message the user sees. Getting it wrong
/// is silent: the call still fails, just with the unhelpful message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late SupabaseAuthRepository auth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _FakeAdapter();

    auth = SupabaseAuthRepository(
      // Never called by these tests: everything here is an Edge Function
      // request, which is the Dio half of the repository.
      client: SupabaseClient('http://localhost:54321', 'test-key'),
      sessions: SessionStore(),
      http: Dio(BaseOptions(
        baseUrl: 'http://localhost/functions/v1',
        validateStatus: (_) => true,
      ))
        ..httpClientAdapter = adapter,
    );
  });

  group('verifyOtp maps the hint onto the exception the screen catches', () {
    test('a wrong code is invalid, not expired', () {
      adapter.reply(401, {'hint': 'otp_invalid'});
      expect(
        () => auth.verifyOtp(msisdn: '0771234821', code: '000000'),
        throwsA(isA<OtpInvalidException>()),
      );
    });

    test('an expired code offers a resend', () {
      adapter.reply(410, {'hint': 'otp_expired'});
      expect(
        () => auth.verifyOtp(msisdn: '0771234821', code: '123456'),
        throwsA(isA<OtpExpiredException>()),
      );
    });

    // Burning the code after too many guesses leaves the user in exactly the
    // position an expiry does — no live code — so it must route to the same
    // remedy rather than to a dead end.
    test('a burned code reads as expired', () {
      adapter.reply(429, {'hint': 'too_many_attempts'});
      expect(
        () => auth.verifyOtp(msisdn: '0771234821', code: '123456'),
        throwsA(isA<OtpExpiredException>()),
      );
    });

    test('a suspended account is unauthenticated', () {
      adapter.reply(403, {'hint': 'account_suspended'});
      expect(
        () => auth.verifyOtp(msisdn: '0771234821', code: '123456'),
        throwsA(isA<UnauthenticatedException>()),
      );
    });
  });

  test('a verified new number returns no profile but stores the session',
      () async {
    final sessions = SessionStore();
    final repository = SupabaseAuthRepository(
      client: SupabaseClient('http://localhost:54321', 'test-key'),
      sessions: sessions,
      http: Dio(BaseOptions(
        baseUrl: 'http://localhost/functions/v1',
        validateStatus: (_) => true,
      ))
        ..httpClientAdapter = adapter,
    );

    adapter.reply(200, {
      'access_token': 'header.payload.signature',
      'refresh_token': 'refresh',
      'user_id': '11111111-2222-3333-4444-555555555555',
      'profile': null,
    });

    // Null is what sends a brand new signup to the profile screen rather
    // than into the app (PRD 6.1, step 5).
    expect(await repository.verifyOtp(msisdn: '0771234821', code: '123456'),
        isNull);

    // The session has to be stored even though there is no profile yet, or
    // `create_profile` on the next screen has nothing to authenticate with.
    expect(sessions.isSignedIn, isTrue);
    expect(sessions.userId, '11111111-2222-3333-4444-555555555555');
  });

  group('requestOtp', () {
    test('returns the cooldown the server set', () async {
      adapter.reply(200, {'cooldown_seconds': 60});
      expect(await auth.requestOtp('0771234821'), 60);
    });

    // A resend asked for too early is not an error the screen should show —
    // the server owns the cooldown, so its remaining seconds just drive the
    // countdown.
    test('a refused resend returns the remaining seconds, not an error',
        () async {
      adapter.reply(429, {'hint': 'cooldown_active', 'retry_after': 42});
      expect(await auth.requestOtp('0771234821'), 42);
    });

    // The name reaches the `temp` row only if it is actually in the body, and
    // only signup has one to send. Sending it on a resend would overwrite a
    // pending row with whatever the resend screen happened to hold.
    test('signup sends the name; login and resend do not', () async {
      adapter.reply(200, {'cooldown_seconds': 60});
      await auth.requestOtp('0771234821', fullName: 'Nimal Perera');
      expect(adapter.lastBody, contains('full_name: Nimal Perera'));

      adapter.reply(200, {'cooldown_seconds': 60});
      await auth.requestOtp('0771234821');
      expect(adapter.lastBody, isNot(contains('full_name')));
    });

    // A field of spaces would fail the table's non-empty constraint and turn
    // a signup into a 500, so it is dropped rather than forwarded.
    test('a blank name is omitted rather than sent', () async {
      adapter.reply(200, {'cooldown_seconds': 60});
      await auth.requestOtp('0771234821', fullName: '   ');
      expect(adapter.lastBody, isNot(contains('full_name')));
    });

    // The signup screen tells the user to log in instead, so this has to
    // arrive as its own type rather than collapsing into the generic
    // failure that every other non-200 becomes.
    test('a taken number raises AccountExistsException', () {
      adapter.reply(409, {'hint': 'account_exists'});
      expect(
        () => auth.requestOtp('0771234821', fullName: 'Nimal Perera'),
        throwsA(isA<AccountExistsException>()),
      );
    });
  });

  test('the number is sent in the E.164 form the users table constrains to',
      () async {
    adapter.reply(200, {'cooldown_seconds': 60});
    await auth.requestOtp('0771234821');
    expect(adapter.lastBody, contains('+94771234821'));
  });
}

/// Stands in for the Edge Function, so the mapping can be tested without a
/// network or a deployed project.
class _FakeAdapter implements HttpClientAdapter {
  int _status = 200;
  String _body = '{}';
  String? lastBody;

  void reply(int status, Map<String, dynamic> body) {
    _status = status;
    _body = jsonEncode(body);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastBody = options.data.toString();
    return ResponseBody.fromString(
      _body,
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
