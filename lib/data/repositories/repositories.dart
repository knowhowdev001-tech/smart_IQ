import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/content.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/models/practice.dart';
import '../../domain/models/user_profile.dart';

/// Raised when the device has no usable connection.
///
/// PRD 12 rules out offline mode entirely: there is no local question pack
/// and no answer queue awaiting sync. Every screen renders a connection
/// state and a retry instead of degrading to a local mode.
class OfflineException implements Exception {
  const OfflineException();
}

/// Raised when the server refuses a quota-consuming action.
///
/// The server is the authoritative enforcer (PRD 7.6); the client shows
/// remaining quota and gates the UI, but this is what actually stops an
/// action, and it drives the in-context upgrade prompt (PRD 7.7).
class QuotaExceededException implements Exception {
  const QuotaExceededException({
    required this.tier,
    required this.limit,
    this.resetsAt,
  });

  final Tier tier;
  final int limit;
  final DateTime? resetsAt;
}

/// Raised when a request needs a session the client does not have.
class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
}

/// Phone + OTP authentication against our own schema.
///
/// Supabase Auth is not used at all (PRD 4.4): OTP goes out through a local
/// SMS gateway from an Edge Function, and that function mints our own JWT.
abstract interface class AuthRepository {
  /// Issues an OTP to [msisdn]. Returns the seconds until a resend is
  /// allowed, so the client can render the cooldown countdown (PRD 6.1).
  Future<int> requestOtp(String msisdn);

  /// Verifies [code] and establishes a session. Returns null for a new user
  /// who must still create a profile, or the existing profile otherwise.
  Future<UserProfile?> verifyOtp({
    required String msisdn,
    required String code,
  });

  /// First-sign-in profile creation. Enforces one profile per user
  /// server-side via `rpc/create_profile`.
  Future<UserProfile> createProfile({
    required String fullName,
    required AppLanguage language,
    String? district,
    DateTime? targetExamDate,
  });

  /// The profile for the stored session, or null when signed out.
  Future<UserProfile?> currentProfile();

  Future<UserProfile> updateProfile(UserProfile profile);

  Future<List<DeviceSession>> activeSessions();

  /// Revokes another device's refresh token.
  Future<void> revokeSession(String sessionId);

  Future<void> signOut();

  /// Cascading deletion under a single transaction (`rpc/delete_account`).
  Future<void> deleteAccount();
}

/// Read-only reference content served under RLS (PRD 9.4, class A).
abstract interface class ContentRepository {
  Future<List<Category>> categories();

  Future<List<SubTopic>> subTopics(String categoryKey);

  Future<List<CurrentAffairsItem>> currentAffairs();

  /// Builds a public Storage URL from a stored object path. Paths are stored,
  /// never URLs, so the storage host can change without a data migration.
  String mediaUrl(String path);
}

/// The practice engine.
///
/// Every method here maps to a SECURITY DEFINER database function, not a
/// table read. PRD 9.3 is explicit that questions are never served by plain
/// select: doing so would let a modified client page the whole bank without
/// touching a quota counter.
abstract interface class PracticeRepository {
  /// Checks quota, increments it atomically, and returns the set.
  Future<PracticeSet> practiceSet({
    required PracticeMode mode,
    String? subTopicId,
    String? categoryKey,
    int? size,
  });

  Future<PracticeSet> dailyChallenge();

  Future<PracticeSet> mockExam({required int length});

  /// A set built from the user's wrong-answer bank.
  Future<PracticeSet> wrongAnswerDrill();

  /// Scores server-side, writes answers, updates mastery and the
  /// wrong-answer bank.
  Future<SessionResult> submitSession({
    required String sessionId,
    required List<SessionAnswer> answers,
  });

  /// An interrupted set the user can resume (PRD 6.3).
  Future<PracticeSet?> resumableSession();

  Future<void> discardResumableSession();

  Future<ProgressSummary> progress();

  Future<List<SavedQuestion>> bookmarks();

  Future<void> setBookmark({required String questionId, required bool saved});

  Future<List<SavedQuestion>> wrongAnswerBank();
}

/// Thin client over the external AI endpoint.
///
/// The app never calls the endpoint directly. All traffic goes through an
/// Edge Function proxy, which keeps the credential off the device and makes
/// quota enforcement authoritative (PRD 4.5).
abstract interface class TutorRepository {
  Future<List<ChatThread>> threads();

  Future<ChatThread> createThread({String? sourceQuestionId, String? topic});

  /// Sends a message and yields the reply. The endpoint decides whether to
  /// stream, so this is a stream either way and a non-streaming reply simply
  /// arrives as a single event (PRD 6.4).
  Stream<ChatMessage> send({
    required String threadId,
    required String content,
    required AppLanguage language,
  });

  /// "Explain this", invoked from a question with its context attached.
  Future<ChatThread> explainQuestion({
    required Question question,
    required AppLanguage language,
    String? selectedOptionId,
  });

  Future<void> deleteThread(String threadId);
}

/// The unified entitlement layer. Neither billing rail is read directly.
abstract interface class EntitlementRepository {
  /// Resolves charging status and tier. Called on every app open, cold start
  /// and resume alike, subject to the one-hour debounce in PRD 7.3.
  Future<Entitlement> resolve({bool force = false});

  /// The last known entitlement, used while a check is in flight and as the
  /// fallback when the status API is unreachable.
  Future<Entitlement?> cached();

  Future<QuotaUsage> usage();

  /// Opens the appropriate billing rail for [tier]: telco daily for Basic,
  /// RevenueCat for Pro and Pro+.
  Future<void> startSubscription(Tier tier);
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> inbox();

  Future<void> markAllRead();

  Future<void> markRead(String id);

  Future<NotificationPreferences> preferences();

  Future<void> savePreferences(NotificationPreferences prefs);
}
