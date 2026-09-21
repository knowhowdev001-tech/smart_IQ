import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/supabase_config.dart';
import 'session_store.dart';

/// Renews an expiring access token against `/auth-refresh`.
///
/// Sessions are our own (PRD 4.4), so nothing renews them for us: the token
/// minted at sign-in simply expires after an hour, and without this the user
/// would be sent back to the landing screen roughly once a day of use.
///
/// Kept apart from `SupabaseAuthRepository` because it has to run before any
/// repository exists — the Supabase client asks for a token on its very first
/// request, which may be the one that restores the session.
// Named parameters cannot be private field formals, so the analyzer's
// suggestion to use `this._sessions` does not compile here.
// ignore_for_file: prefer_initializing_formals

class SessionRefresher {
  SessionRefresher({required SessionStore sessions, Dio? http})
      : _sessions = sessions,
        _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/functions/v1',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              // A refused refresh is a normal outcome, not an exception.
              validateStatus: (_) => true,
              headers: {
                'apikey': SupabaseConfig.anonKey,
                'Content-Type': 'application/json',
              },
            ));

  final SessionStore _sessions;
  final Dio _http;

  /// Returns true when a new token was stored.
  ///
  /// A session the server no longer recognises is cleared here, so the router
  /// sees a signed-out app and shows the landing screen once, rather than
  /// every screen failing separately. A network failure keeps the session:
  /// being offline is not being signed out.
  Future<bool> refresh() async {
    final userId = _sessions.userId;
    final refreshToken = await _sessions.refreshToken();
    if (userId == null || refreshToken == null) return false;

    try {
      final response = await _http.post<Map<String, dynamic>>(
        '/auth-refresh',
        data: {
          'user_id': userId,
          'refresh_token': refreshToken,
          'device_id': await _sessions.deviceId(),
        },
      );

      final status = response.statusCode ?? 0;
      final body = response.data ?? const {};

      if (status == 200) {
        await _sessions.save(
          accessToken: body['access_token'] as String,
          refreshToken: body['refresh_token'] as String,
          userId: body['user_id'] as String? ?? userId,
          expiresIn: Duration(seconds: (body['expires_in'] as num?)?.toInt() ?? 3600),
        );
        return true;
      }

      if (status == 401 || status == 403) {
        await _sessions.clear();
      }
      return false;
    } catch (error) {
      debugPrint('session refresh failed: $error');
      return false;
    }
  }
}
