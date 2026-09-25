import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/providers/app_providers.dart';
import 'package:smart_iq/data/repositories/repositories.dart';
import 'package:smart_iq/data/repositories/supabase_entitlement_repository.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/entitlement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PRD 7.3: every app open asks the charging rail, and the tier is read only
/// after that answer has been written. payment-status is what asks;
/// get_entitlement is what reads.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const entitlement = {
    'tier': 'basic',
    'source': 'telco',
    'limits': {'tier': 'basic', 'questions_per_day': 50},
  };

  /// A client whose server answers payment-status with [statusCode] and
  /// records every path it was asked for, in order.
  (SupabaseEntitlementRepository, List<String>) build({
    int statusCode = 200,
    String userId = 'user-a',
  }) {
    final calls = <String>[];
    final http.Client fake = MockClient((request) async {
      final path = request.url.path;
      calls.add(path);
      if (path.endsWith('/functions/v1/payment-status')) {
        return http.Response(
          jsonEncode({'tier': 'basic', 'checked': statusCode == 200}),
          statusCode,
          headers: {'content-type': 'application/json'},
          // postgrest reads the method back off the response.
          request: request,
        );
      }
      if (path.endsWith('/rest/v1/rpc/get_entitlement')) {
        return http.Response(
          jsonEncode(entitlement),
          200,
          headers: {'content-type': 'application/json'},
          // postgrest reads the method back off the response.
          request: request,
        );
      }
      return http.Response('not found', 404, request: request);
    });

    final repository = SupabaseEntitlementRepository(
      client: SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: fake,
      ),
      prefs: prefs,
      userId: userId,
    );
    return (repository, calls);
  }

  test('asks the charging rail before reading the tier', () async {
    final (repository, calls) = build();

    final resolved = await repository.resolve(force: true);

    expect(resolved.tier, Tier.basic);
    expect(calls, hasLength(2));
    expect(calls.first, endsWith('/functions/v1/payment-status'));
    expect(calls.last, endsWith('/rest/v1/rpc/get_entitlement'));
  });

  test('still resolves when the status check fails', () async {
    final (repository, calls) = build(statusCode: 500);

    final resolved = await repository.resolve(force: true);

    expect(resolved.tier, Tier.basic);
    expect(calls.last, endsWith('/rest/v1/rpc/get_entitlement'));
  });

  test('a fresh answer is reused within the hour', () async {
    final (repository, calls) = build();

    await repository.resolve(force: true);
    await repository.resolve();

    // One status check and one read, not two of each.
    expect(calls, hasLength(2));
  });

  test('the last answer is kept for the same user', () async {
    final (first, _) = build();
    await first.resolve(force: true);

    final (reopened, _) = build();
    final cached = await reopened.cached();

    expect(cached?.tier, Tier.basic);
    expect(cached?.fromCache, isTrue);
  });

  test('another user never starts on the previous tier', () async {
    final (first, _) = build();
    await first.resolve(force: true);

    final (other, _) = build(userId: 'user-b');

    expect(await other.cached(), isNull);
  });

  group('EntitlementController', () {
    test('opens on the cached tier while the status check runs', () async {
      final repository = _SlowRepository(
        cachedValue: _basic.copyWith(lastCheckedAt: DateTime.now()),
      );
      final controller = EntitlementController(repository, signedIn: true);
      await pumpEventQueue();

      expect(controller.state.valueOrNull?.tier, Tier.basic);
      expect(controller.state.valueOrNull?.fromCache, isTrue);

      repository.answer.complete(Entitlement.freeFallback);
      await pumpEventQueue();

      // The live answer wins, in either direction.
      expect(controller.state.valueOrNull?.tier, Tier.free);
      expect(controller.state.valueOrNull?.fromCache, isFalse);
    });

    test('does not open on a cache past its TTL', () async {
      final repository = _SlowRepository(
        cachedValue: _basic.copyWith(
          lastCheckedAt: DateTime.now().subtract(const Duration(hours: 7)),
        ),
      );
      final controller = EntitlementController(repository, signedIn: true);
      await pumpEventQueue();

      expect(controller.state.isLoading, isTrue);
    });

    test('signed out, it is Free and asks nothing', () async {
      final repository = _SlowRepository();
      final controller = EntitlementController(repository, signedIn: false);
      await controller.refresh();

      expect(controller.state.valueOrNull?.tier, Tier.free);
      expect(repository.resolves, 0);
    });
  });
}

final _basic = Entitlement(
  tier: Tier.basic,
  limits: TierLimits.defaults[Tier.basic]!,
  fromCache: true,
);

/// A repository whose live check waits on [answer], so a test can look at
/// the controller while the status round trip is still in flight.
class _SlowRepository implements EntitlementRepository {
  _SlowRepository({this.cachedValue});

  final Entitlement? cachedValue;
  final answer = Completer<Entitlement>();
  int resolves = 0;

  @override
  Future<Entitlement> resolve({bool force = false}) {
    resolves++;
    return answer.future;
  }

  @override
  Future<Entitlement?> cached() async => cachedValue;

  @override
  Future<QuotaUsage> usage() async => const QuotaUsage();

  @override
  Future<void> startSubscription(Tier tier) async {}
}
