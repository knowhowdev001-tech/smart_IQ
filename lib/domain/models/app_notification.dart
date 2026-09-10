import 'package:flutter/foundation.dart';

import '../enums.dart';

/// An entry in the notification inbox.
///
/// The v1 trigger set is fixed by PRD 6.8 and every type is individually
/// toggleable in settings.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.unread = true,
    this.route,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: NotificationKind.fromKey(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        unread: json['unread'] as bool? ?? true,
        route: json['route'] as String?,
      );

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool unread;

  /// Deep-link target for the push payload, routed through go_router.
  final String? route;

  AppNotification copyWith({bool? unread}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        unread: unread ?? this.unread,
        route: route,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification && other.id == id && other.unread == unread;

  @override
  int get hashCode => Object.hash(id, unread);
}

/// Per-type push preferences (PRD 6.8).
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.dailyChallenge = true,
    this.streak = true,
    this.digest = true,
    this.billing = true,
    this.inactivity = true,
  });

  final bool dailyChallenge;
  final bool streak;
  final bool digest;
  final bool billing;
  final bool inactivity;

  bool enabledFor(NotificationKind kind) => switch (kind) {
        NotificationKind.dailyChallenge => dailyChallenge,
        NotificationKind.streak => streak,
        NotificationKind.digest => digest,
        NotificationKind.chargeFailed || NotificationKind.renewal => billing,
        NotificationKind.inactivity => inactivity,
      };

  NotificationPreferences copyWith({
    bool? dailyChallenge,
    bool? streak,
    bool? digest,
    bool? billing,
    bool? inactivity,
  }) =>
      NotificationPreferences(
        dailyChallenge: dailyChallenge ?? this.dailyChallenge,
        streak: streak ?? this.streak,
        digest: digest ?? this.digest,
        billing: billing ?? this.billing,
        inactivity: inactivity ?? this.inactivity,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          other.dailyChallenge == dailyChallenge &&
          other.streak == streak &&
          other.digest == digest &&
          other.billing == billing &&
          other.inactivity == inactivity;

  @override
  int get hashCode =>
      Object.hash(dailyChallenge, streak, digest, billing, inactivity);
}
