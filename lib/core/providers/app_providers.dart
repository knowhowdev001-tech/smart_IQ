import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/content.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/models/user_profile.dart';

/// Shared state behind the mock repositories.
///
/// This is the seam where Supabase lands: each repository provider below is
/// overridden with its Supabase implementation and nothing above this file
/// changes, because every screen depends on the interface rather than on
/// what is behind it.
final mockBackendProvider = Provider<MockBackendState>(
  (ref) => MockBackendState(tier: Tier.basic),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(ref.watch(mockBackendProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => MockContentRepository(ref.watch(mockBackendProvider)),
);

final practiceRepositoryProvider = Provider<PracticeRepository>(
  (ref) => MockPracticeRepository(ref.watch(mockBackendProvider)),
);

final tutorRepositoryProvider = Provider<TutorRepository>(
  (ref) => MockTutorRepository(ref.watch(mockBackendProvider)),
);

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => MockEntitlementRepository(ref.watch(mockBackendProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => MockNotificationRepository(ref.watch(mockBackendProvider)),
);

/// The signed-in user's profile, or null when signed out.
class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final AuthRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.currentProfile);
  }

  Future<void> save(UserProfile profile) async {
    state = AsyncValue.data(await _repository.updateProfile(profile));
  }

  void set(UserProfile? profile) => state = AsyncValue.data(profile);

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>(
  (ref) => ProfileController(ref.watch(authRepositoryProvider)),
);

/// Resolves the charging status and tier.
///
/// PRD 7.3 calls this on every app open, cold start and resume alike, with a
/// one-hour debounce on successful checks. When the status API cannot be
/// reached the cached entitlement stands for a short TTL rather than
/// downgrading a paying user on a flaky connection; once that expires the
/// user drops to Free Fallback.
class EntitlementController extends StateNotifier<AsyncValue<Entitlement>> {
  EntitlementController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final EntitlementRepository _repository;

  Future<void> refresh({bool force = false}) async {
    try {
      state = AsyncValue.data(await _repository.resolve(force: force));
    } catch (_) {
      final cached = await _repository.cached();
      // A cache that has outlived its TTL is no better than no answer at
      // all, so it drops to Free Fallback rather than silently extending a
      // tier the server never confirmed.
      state = AsyncValue.data(
        cached != null && !cached.cacheExpired
            ? cached
            : Entitlement.freeFallback,
      );
    }
  }

  /// Called after a quota-consuming action so the displayed remaining count
  /// tracks what the server actually recorded.
  Future<void> syncUsage() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(usage: await _repository.usage()),
    );
  }

  Future<void> subscribe(Tier tier) async {
    await _repository.startSubscription(tier);
    await refresh(force: true);
  }
}

final entitlementProvider =
    StateNotifierProvider<EntitlementController, AsyncValue<Entitlement>>(
  (ref) => EntitlementController(ref.watch(entitlementRepositoryProvider)),
);

/// The resolved entitlement, falling back to Free while a check is in
/// flight. Screens gate on this rather than on the async value directly.
final currentEntitlementProvider = Provider<Entitlement>(
  (ref) =>
      ref.watch(entitlementProvider).valueOrNull ?? Entitlement.freeFallback,
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(contentRepositoryProvider).categories(),
);

final subTopicsProvider =
    FutureProvider.family<List<SubTopic>, String>(
  (ref, categoryKey) =>
      ref.watch(contentRepositoryProvider).subTopics(categoryKey),
);

final progressProvider = FutureProvider(
  (ref) => ref.watch(practiceRepositoryProvider).progress(),
);

/// The notification inbox, kept as a controller so the unread dot on the
/// home header updates the moment the list is read.
class NotificationsController
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationsController(this._repository)
      : super(const AsyncValue.loading()) {
    load();
  }

  final NotificationRepository _repository;

  Future<void> load() async {
    state = await AsyncValue.guard(_repository.inbox);
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    await load();
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    await load();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsController,
    AsyncValue<List<AppNotification>>>(
  (ref) => NotificationsController(ref.watch(notificationRepositoryProvider)),
);

final unreadCountProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).valueOrNull?.where((n) => n.unread).length ??
      0,
);
