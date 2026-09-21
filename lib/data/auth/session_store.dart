import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The signed-in session, held in the platform keystore.
///
/// PRD 4.4 does not use Supabase Auth, so nothing else is persisting this for
/// us: the access token minted by the OTP Edge Function is what every later
/// request authenticates with, and losing it on restart would sign the user
/// out every cold start.
///
/// Secure storage rather than SharedPreferences because these are bearer
/// credentials — on Android that is the Keystore-backed EncryptedSharedPrefs,
/// not a world-readable XML file in the app sandbox.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'siq.access_token';
  static const _refreshTokenKey = 'siq.refresh_token';
  static const _userIdKey = 'siq.user_id';
  static const _deviceIdKey = 'siq.device_id';
  static const _expiresAtKey = 'siq.expires_at';

  /// Refresh this far ahead of expiry, so a request that leaves the phone
  /// with a valid token does not arrive with an expired one.
  static const _refreshMargin = Duration(minutes: 5);

  String? _accessToken;
  String? _userId;
  DateTime? _expiresAt;

  /// Set by whoever can actually call the refresh endpoint. Returns true when
  /// a new token was stored. Kept as a hook so this class stays pure storage
  /// and does not reach for the network itself.
  Future<bool> Function()? _refresher;

  /// In-flight refresh, shared by every caller that arrives while it runs:
  /// the token rotates on use, so two concurrent refreshes would invalidate
  /// each other and sign the user out.
  Future<bool>? _refreshing;

  /// The current access token, or null when signed out.
  ///
  /// Held in memory as well as in storage because the Supabase client asks
  /// for it on every single request, and a keystore read per request is a
  /// cost with nothing to show for it.
  String? get accessToken => _accessToken;

  String? get userId => _userId;

  bool get isSignedIn => _accessToken != null;

  /// True when the stored token is expired, or close enough that it will be
  /// by the time a request lands.
  bool get isExpiring {
    final expiry = _expiresAt;
    if (_accessToken == null) return false;
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(_refreshMargin));
  }

  void attachRefresher(Future<bool> Function() refresher) =>
      _refresher = refresher;

  /// The token to send with a request, renewed first when it is about to
  /// expire. This is what the Supabase client calls on every request, and
  /// what keeps a returning user signed in rather than bouncing them to the
  /// landing screen an hour after they logged in.
  Future<String?> freshAccessToken() async {
    if (_accessToken == null || !isExpiring) return _accessToken;

    final refresher = _refresher;
    if (refresher == null) return _accessToken;

    _refreshing ??= refresher().whenComplete(() => _refreshing = null);
    await _refreshing;
    return _accessToken;
  }

  /// Reads the stored session. Call once before the first frame so the app
  /// already knows whether it is signed in when it paints.
  Future<void> restore() async {
    _accessToken = await _read(_accessTokenKey);
    _userId = await _read(_userIdKey);
    _expiresAt = DateTime.tryParse(await _read(_expiresAtKey) ?? '');
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    Duration? expiresIn,
  }) async {
    _accessToken = accessToken;
    _userId = userId;
    _expiresAt = expiresIn == null ? null : DateTime.now().add(expiresIn);

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(
      key: _expiresAtKey,
      value: _expiresAt?.toIso8601String(),
    );
  }

  Future<String?> refreshToken() => _read(_refreshTokenKey);

  Future<void> clear() async {
    _accessToken = null;
    _userId = null;
    _expiresAt = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _expiresAtKey);
    // The device id deliberately survives a sign-out: it identifies the
    // handset, not the person, and keeping it stable is what stops "sign out
    // other devices" from filling up with ghosts of this same phone.
  }

  /// A stable identifier for this installation.
  ///
  /// `auth_sessions` is unique on (user_id, device_id) for live rows, so this
  /// is what makes signing in again on the same handset rotate that row
  /// instead of adding another entry to the user's device list (PRD 6.1).
  Future<String> deviceId() async {
    final existing = await _read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final generated = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  /// Secure storage throws rather than returning null when the keystore
  /// entry cannot be decrypted — after a restore to a new device, for
  /// instance. A session we cannot read is a session we do not have.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }
}
