import 'dart:io';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/msisdn.dart';
import '../../domain/enums.dart';
import '../../domain/models/user_profile.dart';
import '../auth/session_store.dart';
import 'repositories.dart';
import 'supabase_guard.dart';

/// Phone + OTP authentication against our own identity tables.
///
/// Two different transports, for a reason. The OTP endpoints are Edge
/// Functions because they need the JWT signing secret and the OTP pepper,
/// neither of which can be in the app (PRD 4.4, and see
/// supabase/functions/_shared/tokens.dart). Everything after sign-in is
/// ordinary PostgREST, because by then there is a token and RLS is doing the
/// work.
// Named parameters cannot be private field formals, so the analyzer's
// suggestion to use `this._client` does not compile here.
// ignore_for_file: prefer_initializing_formals

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
    required SessionStore sessions,
    required AppLanguage Function() language,
    Dio? http,
  })  : _client = client,
        _sessions = sessions,
        _language = language,
        _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/functions/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              // Non-2xx is a normal outcome here - a wrong OTP is a 401 -
              // so it is read from the response rather than thrown.
              validateStatus: (_) => true,
              headers: {
                'apikey': SupabaseConfig.anonKey,
                'Content-Type': 'application/json',
              },
            ));

  final SupabaseClient _client;
  final SessionStore _sessions;

  /// The OTP's SMS is written server-side, so the language has to be sent
  /// with the request. Read at call time, not at construction: the user can
  /// change it between one code and the next.
  final AppLanguage Function() _language;

  final Dio _http;

  @override
  Future<int> requestOtp(
    String msisdn, {
    String? fullName,
    bool login = false,
  }) async {
    final trimmed = fullName?.trim();

    final response = await _post('/otp-request', {
      'msisdn': Msisdn.toE164(msisdn) ?? msisdn,
      'device_id': await _sessions.deviceId(),
      // Omitted rather than sent null on the login and resend paths, so the
      // function can tell "no name to record" from "name cleared".
      if (trimmed != null && trimmed.isNotEmpty) 'full_name': trimmed,
      // A resend sends neither flag, so it is checked as neither a signup
      // nor a login and simply reissues the code.
      if (login) 'login': true,
      // The SMS is written server-side, so the language has to travel: an
      // English code to a Sinhala user would be the one part of this
      // product that ignores them.
      'language': _language().code,
    });

    final body = _asMap(response.data);

    // The server owns the cooldown, so a resend asked for too early comes
    // back with the remaining seconds rather than an error the screen would
    // have to invent a number for.
    if (response.statusCode == 429) {
      return (body['retry_after'] as num?)?.toInt() ?? 60;
    }

    if (response.statusCode != 200) _throwFor(response.statusCode, body);

    return (body['cooldown_seconds'] as num?)?.toInt() ?? 60;
  }

  @override
  Future<UserProfile?> verifyOtp({
    required String msisdn,
    required String code,
  }) async {
    final response = await _post('/otp-verify', {
      'msisdn': Msisdn.toE164(msisdn) ?? msisdn,
      'code': code,
      'device_id': await _sessions.deviceId(),
      'device_name': _deviceName(),
    });

    final body = _asMap(response.data);
    if (response.statusCode != 200) _throwFor(response.statusCode, body);

    // Stored before the profile is read: the profile lookup and everything
    // after it authenticate with this token.
    await _sessions.save(
      accessToken: body['access_token'] as String,
      refreshToken: body['refresh_token'] as String,
      userId: body['user_id'] as String,
      // What the token actually carries, so the client can renew it just
      // before it expires rather than after a request has already failed.
      expiresIn: Duration(
        seconds: (body['expires_in'] as num?)?.toInt() ?? 3600,
      ),
    );

    final profile = body['profile'];
    // Null for a number that verified but never completed profile setup.
    // The caller routes those to the profile screen (PRD 6.1, step 5).
    if (profile == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(profile as Map));
  }

  @override
  Future<UserProfile> createProfile({
    required String fullName,
    required AppLanguage language,
  }) async {
    if (!_sessions.isSignedIn) throw const UnauthenticatedException();

    // An RPC rather than an insert because one profile per user is enforced
    // server-side, and because it is the same transaction that seeds the
    // free-tier payment status, the streak row and notification preferences.
    final result = await supabaseGuard(
      () => _client.rpc<dynamic>('create_profile', params: {
        'p_full_name': fullName,
        'p_language': language.code,
      }),
    );

    return UserProfile.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<UserProfile?> currentProfile() async {
    if (!_sessions.isSignedIn) return null;

    final rows = await supabaseGuard(
      () => _client
          .from('profiles')
          .select('user_id, full_name, language_preference, theme_preference, '
              'current_status, education_level, '
              'created_at, users!inner(msisdn)')
          .eq('user_id', _sessions.userId!)
          .limit(1),
    );

    if (rows.isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first);
    // The join arrives nested; the model wants msisdn flat alongside the
    // rest, which is also the shape the Edge Function returns.
    final joined = row.remove('users');
    if (joined is Map) row['msisdn'] = joined['msisdn'];

    return UserProfile.fromJson(row);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    if (!_sessions.isSignedIn) throw const UnauthenticatedException();

    await supabaseGuard(
      () => _client.from('profiles').update({
        'full_name': profile.fullName,
        'language_preference': profile.language.code,
        'theme_preference': profile.theme.name,
        'current_status': profile.currentStatus,
        'education_level': profile.educationLevel,
      }).eq('user_id', _sessions.userId!),
    );

    return profile;
  }

  @override
  Future<List<DeviceSession>> activeSessions() async {
    if (!_sessions.isSignedIn) throw const UnauthenticatedException();

    final currentDevice = await _sessions.deviceId();
    final rows = await supabaseGuard(
      () => _client
          .from('auth_sessions')
          .select('id, device_id, device_name, last_seen_at')
          .isFilter('revoked_at', null)
          .order('last_seen_at', ascending: false),
    );

    return rows
        .map((row) => DeviceSession(
              id: row['id'] as String,
              deviceName: row['device_name'] as String? ?? 'Unknown device',
              lastSeenAt: DateTime.parse(row['last_seen_at'] as String),
              isCurrent: row['device_id'] == currentDevice,
            ))
        .toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    if (!_sessions.isSignedIn) throw const UnauthenticatedException();

    // Stamping revoked_at is the whole mechanism: the unique index only
    // covers live rows, and a revoked row is refused on refresh. The RPC is
    // the only writer, so a client can revoke but never un-revoke.
    await supabaseGuard(
      () => _client.rpc<dynamic>(
        'revoke_session',
        params: {'p_session_id': sessionId},
      ),
    );
  }

  @override
  Future<void> signOut() async {
    if (_sessions.isSignedIn) {
      final deviceId = await _sessions.deviceId();
      // Best effort. The local session is dropped either way - a user who
      // asked to sign out must not stay signed in because the network was
      // down - and the server row expires on its own.
      // First, while the token still works: a phone that has signed out must
      // stop receiving this user's streak and billing pushes.
      try {
        await _client.from('device_tokens').delete().eq('device_id', deviceId);
      } catch (_) {}
      try {
        final live = await _client
            .from('auth_sessions')
            .select('id')
            .eq('device_id', deviceId)
            .isFilter('revoked_at', null);
        for (final row in live) {
          await _client.rpc<dynamic>(
            'revoke_session',
            params: {'p_session_id': row['id']},
          );
        }
      } catch (_) {}
    }

    await _sessions.clear();
  }

  @override
  Future<void> deleteAccount() async {
    if (!_sessions.isSignedIn) throw const UnauthenticatedException();

    await supabaseGuard(() => _client.rpc<void>('delete_account'));
    await _sessions.clear();
  }

  // ------------------------------------------------------------ plumbing --

  Future<Response<dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _http.post<dynamic>(path, data: body);
    } on DioException catch (error) {
      // PRD 12 rules out offline mode, so a dead connection is a first-class
      // state every screen already renders, not a generic failure.
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.error is SocketException) {
        throw const OfflineException();
      }
      rethrow;
    }
  }

  /// Maps the Edge Function hint onto the exceptions the screens catch.
  Never _throwFor(int? status, Map<String, dynamic> body) {
    switch (body['hint']) {
      case 'otp_invalid':
        throw const OtpInvalidException();
      // Expired, already consumed and burned by wrong guesses all leave the
      // user with no live code, which is one situation with one remedy.
      case 'otp_expired':
      case 'too_many_attempts':
        throw const OtpExpiredException();
      case 'account_exists':
        throw const AccountExistsException();
      case 'no_account':
        throw const NoAccountException();
      case 'sms_failed':
        throw const SmsDeliveryException();
      case 'account_suspended':
        throw const UnauthenticatedException();
    }
    throw Exception('auth request failed ($status): ${body['message']}');
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  /// What the user sees in their active-devices list, so it has to read as a
  /// device rather than as a platform id: `Platform.operatingSystem` returns
  /// the bare string "ios", which is not a name anyone recognises as their
  /// own phone.
  String _deviceName() {
    try {
      if (Platform.isAndroid) return 'Android device';
      if (Platform.isIOS) return 'iOS device';
      return Platform.operatingSystem;
    } catch (_) {
      // `Platform` throws on web, where dart:io has no implementation.
      return 'Unknown device';
    }
  }
}
