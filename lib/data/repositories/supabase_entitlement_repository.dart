import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums.dart';
import '../../domain/models/entitlement.dart';
import 'repositories.dart';
import 'supabase_guard.dart';

/// The resolved tier, its limits and today's usage, in one call.
///
/// Neither billing rail is read here (PRD 7.1): `get_entitlement` returns
/// what `payment_status` already resolved to, so a telco charge and a
/// RevenueCat renewal look identical to the app.
// ignore_for_file: prefer_initializing_formals

class SupabaseEntitlementRepository implements EntitlementRepository {
  SupabaseEntitlementRepository({
    required SupabaseClient client,
    required SharedPreferences prefs,
    required String? userId,
  })  : _client = client,
        _prefs = prefs,
        _userId = userId;

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Whose entitlement this is. The cache on disk outlives sign-out, so it
  /// is stamped with its owner and read back only for the same user; another
  /// number signing in on this phone never starts on the last one's tier.
  final String? _userId;

  static const _cacheKey = 'entitlement.last';
  static const _cachedAtKey = 'entitlement.checked_at';
  static const _cachedForKey = 'entitlement.user';

  Entitlement? _inMemory;

  @override
  Future<Entitlement> resolve({bool force = false}) async {
    // PRD 7.3 checks on every app open but debounces a successful check for
    // an hour, so resume does not cost a round trip each time.
    final current = _inMemory;
    if (!force && current != null && !current.needsRefresh) return current;

    // The status check itself: payment-status asks the charging rail and
    // writes payment_status, which get_entitlement then reads. Best-effort,
    // because a rail that cannot answer changes nothing server-side, and the
    // tier already on record is still the right answer to show.
    try {
      await _client.functions.invoke('payment-status');
    } catch (_) {}

    final json = await supabaseGuard(
      () => _client.rpc<dynamic>('get_entitlement'),
    );
    final map = Map<String, dynamic>.from(json as Map);
    final entitlement = Entitlement.fromJson(map).copyWith(
      lastCheckedAt: DateTime.now(),
    );

    await _prefs.setString(_cacheKey, jsonEncode(map));
    await _prefs.setString(_cachedAtKey, DateTime.now().toIso8601String());
    if (_userId != null) await _prefs.setString(_cachedForKey, _userId);
    _inMemory = entitlement;
    return entitlement;
  }

  /// The last successful answer, kept across restarts. The caller decides
  /// whether it is still fresh enough to stand in for a live check; an
  /// expired one drops the user to Free Fallback rather than extending a
  /// tier the server never confirmed.
  @override
  Future<Entitlement?> cached() async {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || _prefs.getString(_cachedForKey) != _userId) {
      return _inMemory;
    }

    try {
      final map = Map<String, dynamic>.from(
          jsonDecode(raw) as Map<String, dynamic>);
      final checkedAt = DateTime.tryParse(_prefs.getString(_cachedAtKey) ?? '');
      return Entitlement.fromJson(map).copyWith(
        fromCache: true,
        lastCheckedAt: checkedAt,
      );
    } catch (_) {
      return _inMemory;
    }
  }

  @override
  Future<QuotaUsage> usage() async {
    final entitlement = await resolve(force: true);
    return entitlement.usage;
  }

  /// No billing rail exists yet: `msisdn_prefix_routing` has no active
  /// endpoint and the RevenueCat webhook is not built, so there is nothing
  /// honest to call. The plan sheet surfaces this rather than pretending a
  /// subscription started.
  @override
  Future<void> startSubscription(Tier tier) async {
    throw UnsupportedError('billing is not connected yet');
  }
}
