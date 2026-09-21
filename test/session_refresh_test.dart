import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/auth/session_refresher.dart';
import 'package:smart_iq/data/auth/session_store.dart';

/// Staying signed in is the whole point of the refresh endpoint: the access
/// token lasts an hour, so without renewal a returning user is asked for an
/// OTP again roughly every day of use.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAdapter adapter;
  late SessionStore sessions;
  late SessionRefresher refresher;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _FakeAdapter();
    sessions = SessionStore();
    refresher = SessionRefresher(
      sessions: sessions,
      http: Dio(BaseOptions(
        baseUrl: 'http://localhost/functions/v1',
        validateStatus: (_) => true,
      ))
        ..httpClientAdapter = adapter,
    );
    sessions.attachRefresher(refresher.refresh);
  });

  Future<void> signIn({required Duration expiresIn}) => sessions.save(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        userId: 'user-1',
        expiresIn: expiresIn,
      );

  test('a fresh token is used as it is', () async {
    await signIn(expiresIn: const Duration(hours: 1));

    expect(sessions.isExpiring, isFalse);
    expect(await sessions.freshAccessToken(), 'old-access');
    expect(adapter.calls, 0, reason: 'nothing to renew yet');
  });

  test('an expiring token is renewed before the request goes out', () async {
    // Inside the refresh margin, so still valid but not for much longer.
    await signIn(expiresIn: const Duration(minutes: 2));
    expect(sessions.isExpiring, isTrue);

    adapter.reply(200, {
      'access_token': 'new-access',
      'refresh_token': 'new-refresh',
      'user_id': 'user-1',
      'expires_in': 3600,
    });

    expect(await sessions.freshAccessToken(), 'new-access');
    expect(await sessions.refreshToken(), 'new-refresh');
    expect(sessions.isExpiring, isFalse);
  });

  test('concurrent requests share one refresh', () async {
    // The refresh token rotates on use, so a second refresh would invalidate
    // the first and sign the user out.
    await signIn(expiresIn: const Duration(minutes: 1));
    adapter.reply(200, {
      'access_token': 'new-access',
      'refresh_token': 'new-refresh',
      'user_id': 'user-1',
      'expires_in': 3600,
    });

    final tokens = await Future.wait([
      sessions.freshAccessToken(),
      sessions.freshAccessToken(),
      sessions.freshAccessToken(),
    ]);

    expect(tokens, everyElement('new-access'));
    expect(adapter.calls, 1);
  });

  test('a session the server rejects signs the user out', () async {
    await signIn(expiresIn: Duration.zero);
    adapter.reply(401, {'hint': 'session_expired'});

    expect(await sessions.freshAccessToken(), isNull);
    expect(sessions.isSignedIn, isFalse);
    expect(await sessions.refreshToken(), isNull);
  });

  test('being offline is not being signed out', () async {
    await signIn(expiresIn: Duration.zero);
    adapter.fail();

    await sessions.freshAccessToken();
    expect(sessions.isSignedIn, isTrue,
        reason: 'a network failure must not discard the session');
    expect(await sessions.refreshToken(), 'old-refresh');
  });

  test('a restored session keeps its expiry across a restart', () async {
    await signIn(expiresIn: const Duration(hours: 1));

    final reopened = SessionStore();
    await reopened.restore();

    expect(reopened.isSignedIn, isTrue);
    expect(reopened.userId, 'user-1');
    expect(reopened.isExpiring, isFalse);
  });

  test('a session stored before expiry was tracked refreshes once', () async {
    // Upgrade path: tokens saved by the previous build have no expiry, so
    // they are treated as due for renewal rather than trusted forever.
    await sessions.save(
      accessToken: 'legacy',
      refreshToken: 'legacy-refresh',
      userId: 'user-1',
    );

    expect(sessions.isExpiring, isTrue);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, dynamic> body = const {};
  bool throwOnSend = false;
  int calls = 0;

  void reply(int code, Map<String, dynamic> payload) {
    status = code;
    body = payload;
    throwOnSend = false;
  }

  void fail() => throwOnSend = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (throwOnSend) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
