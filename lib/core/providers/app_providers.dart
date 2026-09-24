import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth/session_store.dart';
import '../../data/mock/mock_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/supabase_content_repository.dart';
import '../../data/repositories/supabase_entitlement_repository.dart';
import '../../data/repositories/supabase_notification_repository.dart';
import '../../data/repositories/supabase_practice_repository.dart';
import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/content.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/models/user_profile.dart';
import '../config/supabase_config.dart';
import '../settings/app_settings.dart';

/// Shared state behind the mock repositories.
///
/// This is the seam where Supabase lands: each repository provider below is
/// overridden with its Supabase implementation and nothing above this file
/// changes, because every screen depends on the interface rather than on
/// what is behind it.
final mockBackendProvider = Provider<MockBackendState>(
  (ref) => MockBackendState(tier: Tier.basic),
);

/// Whether the Supabase client has been initialised and a session store is
/// available. main() overrides this to true; widget tests leave it alone and
/// get the mocks, which is what lets them run with no network and no
/// keystore.
final backendReadyProvider = Provider<bool>((ref) => false);

/// The stored session. Overridden in main() with the instance that was
/// restored before the first frame, so nothing has to wait on the keystore.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('sessionStoreProvider was not overridden'),
);

/// Auth is the first repository to leave the mocks behind: signup now writes
/// a real `users` row and a real profile. The rest still run in memory, which
/// is exactly what the seam above was for - this provider changed, and no
/// screen did.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!ref.watch(backendReadyProvider)) {
    return MockAuthRepository(ref.watch(mockBackendProvider));
  }
  return SupabaseAuthRepository(
    client: Supabase.instance.client,
    sessions: ref.watch(sessionStoreProvider),
    language: () => ref.read(languageProvider),
  );
});

/// The Supabase content repository, also used by the practice repository:
/// the catalogue RPCs take a category uuid while every screen works in keys,
/// and this instance holds the map between them.
final _supabaseContentProvider = Provider<SupabaseContentRepository>(
  (ref) => SupabaseContentRepository(client: Supabase.instance.client),
);

/// Practice, its catalogue and its quota move together: served sample
/// questions with server-side quota, or server questions with sample quota,
/// would each be a state no user is ever in. See
/// SupabaseConfig.practiceFromBackend for why they are currently sampled.
bool _practiceOnServer(Ref ref) =>
    ref.watch(backendReadyProvider) && SupabaseConfig.practiceFromBackend;

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  if (!_practiceOnServer(ref)) {
    return MockContentRepository(ref.watch(mockBackendProvider));
  }
  return ref.watch(_supabaseContentProvider);
});

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  if (!_practiceOnServer(ref)) {
    return MockPracticeRepository(ref.watch(mockBackendProvider));
  }
  return SupabasePracticeRepository(
    client: Supabase.instance.client,
    sessions: ref.watch(sessionStoreProvider),
    content: ref.watch(_supabaseContentProvider),
    // Read on use, not captured: a result opened after the user switches
    // language should read in the language they switched to.
    language: () => ref.read(languageProvider),
  );
});

final tutorRepositoryProvider = Provider<TutorRepository>(
  (ref) => MockTutorRepository(ref.watch(mockBackendProvider)),
);

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  if (!_practiceOnServer(ref)) {
    return MockEntitlementRepository(ref.watch(mockBackendProvider));
  }
  return SupabaseEntitlementRepository(
    client: Supabase.instance.client,
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (!ref.watch(backendReadyProvider)) {
    return MockNotificationRepository(ref.watch(mockBackendProvider));
  }
  return SupabaseNotificationRepository(
    client: Supabase.instance.client,
    sessions: ref.watch(sessionStoreProvider),
  );
});

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

/// The devices signed in to this account, this one included (PRD 6.1).
final activeSessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>(
  (ref) => ref.watch(authRepositoryProvider).activeSessions(),
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
