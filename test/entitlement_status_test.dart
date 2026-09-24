import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/data/repositories/supabase_entitlement_repository.dart';
import 'package:smart_iq/domain/enums.dart';
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
  (SupabaseEntitlementRepository, List<String>) build({int statusCode = 200}) {
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
}
