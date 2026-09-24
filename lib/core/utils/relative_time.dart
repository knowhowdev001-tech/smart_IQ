import '../../l10n/generated/app_localizations.dart';

/// "just now", "5 min ago", "yesterday"... in the user's language.
///
/// [now] is a parameter only so tests can pin it.
String relativeTime(AppL10n l10n, DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays == 1) return l10n.timeYesterday;
  return l10n.timeDaysAgo(diff.inDays);
}

/// "later today", "tomorrow", "in 3 days" for a date still ahead, counted in
/// calendar days so a review at 09:00 tomorrow reads as tomorrow even at
/// 23:00 tonight.
String relativeFuture(AppL10n l10n, DateTime at, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final days = _dateOnly(at).difference(today).inDays;
  if (days <= 0) return l10n.timeLaterToday;
  if (days == 1) return l10n.timeTomorrow;
  return l10n.timeInDays(days);
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
