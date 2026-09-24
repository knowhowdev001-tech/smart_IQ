import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/core/utils/relative_time.dart';
import 'package:smart_iq/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppL10nEn();
  final now = DateTime(2026, 9, 24, 23, 0);

  group('relativeTime', () {
    test('counts back in minutes, hours, then days', () {
      expect(relativeTime(l10n, now, now: now), 'just now');
      expect(
        relativeTime(l10n, now.subtract(const Duration(minutes: 5)), now: now),
        '5 min ago',
      );
      expect(
        relativeTime(l10n, now.subtract(const Duration(hours: 3)), now: now),
        '3 hours ago',
      );
      expect(
        relativeTime(l10n, now.subtract(const Duration(days: 1)), now: now),
        'yesterday',
      );
      expect(
        relativeTime(l10n, now.subtract(const Duration(days: 9)), now: now),
        '9 days ago',
      );
    });
  });

  group('relativeFuture', () {
    test('counts calendar days, not 24-hour blocks', () {
      // Two hours away but past midnight is tomorrow, not "later today".
      expect(
        relativeFuture(l10n, DateTime(2026, 9, 25, 1, 0), now: now),
        'tomorrow',
      );
      expect(
        relativeFuture(l10n, DateTime(2026, 9, 24, 23, 30), now: now),
        'later today',
      );
      expect(
        relativeFuture(l10n, DateTime(2026, 9, 28, 9, 0), now: now),
        'in 4 days',
      );
    });
  });
}
