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
