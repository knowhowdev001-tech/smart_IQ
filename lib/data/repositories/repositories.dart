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

/// Raised when the tier does not include the feature at all, as opposed to
/// having spent its allowance. PRD 7.7: the prompt is an upgrade, not a
/// "come back tomorrow".
class UpgradeRequiredException implements Exception {
  const UpgradeRequiredException();
}

/// Raised when the question bank has nothing left to serve for the chosen
/// filter -- every question seen recently, or no content published yet.
class EmptyPracticeSetException implements Exception {
  const EmptyPracticeSetException();
}

/// Raised when a session has already been scored. A retry after a dropped
/// connection lands here, so it reads as "already done", not as an error.
class AlreadySubmittedException implements Exception {
  const AlreadySubmittedException();
}

/// Raised when a request needs a session the client does not have.
class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
}

/// Raised when the submitted OTP does not match the live code.
class OtpInvalidException implements Exception {
  const OtpInvalidException();
}

/// Raised when there is no live code left to check — expired, already used,
/// or burned by too many wrong guesses. The screen offers a resend for all
/// of these, so they are one exception rather than three.
class OtpExpiredException implements Exception {
  const OtpExpiredException();
}

/// Raised when signup is attempted with a number that already has an account.
///
/// Only the signup screen can see this. Login deliberately cannot: there,
/// an existing account is the expected case, and `otp-verify` treats signup
/// and login as one call precisely so a returning user is never turned away.
class AccountExistsException implements Exception {
  const AccountExistsException();
}

/// Raised when login is attempted with a number that has no account.
///
/// The mirror of [AccountExistsException], and only the login screen can see
/// it: signup is where a number without an account belongs. Checked before
/// the code is issued, so a stranger's number costs no SMS and is never sent
/// one.
class NoAccountException implements Exception {
  const NoAccountException();
}

/// Raised when the carrier could not send the code.
///
/// Distinct from [OfflineException]: the user's connection is fine and
/// retrying may well work, but nothing arrived and telling them to check
/// their network would send them looking in the wrong place.
class SmsDeliveryException implements Exception {
  const SmsDeliveryException();
}

/// Phone + OTP authentication against our own schema.
///
/// Supabase Auth is not used at all (PRD 4.4): OTP goes out through a local
/// SMS gateway from an Edge Function, and that function mints our own JWT.
abstract interface class AuthRepository {
  /// Issues an OTP to [msisdn]. Returns the seconds until a resend is
  /// allowed, so the client can render the cooldown countdown (PRD 6.1).
  ///
  /// [fullName] is set only by the signup screen, which is the one caller
  /// that has a name to give. It is held server-side against the unverified
  /// number and cleared once the code is checked. Login and a resend pass
  /// nothing and leave any pending row alone.
  ///
  /// [login] is set only by the login screen, and makes an account a
  /// precondition: an unknown number raises [NoAccountException] instead of
  /// being sent a code. A resend sets neither flag, because the caller there
  /// has already been through whichever check applied.
  Future<int> requestOtp(
    String msisdn, {
    String? fullName,
    bool login = false,
  });

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

  /// Everything held about the signed-in user, as one JSON document
  /// (`rpc/export_my_data`, PRD 6.1). Credentials and question text are
  /// left out server-side.
  Future<Map<String, dynamic>> exportData();
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

  /// A set built from the user's wrong-answer bank: [questionIds] when
  /// given, such as a session's mistakes, otherwise whatever is due.
  Future<PracticeSet> wrongAnswerDrill({List<String>? questionIds});

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

  /// The user's own figures over [window] for the results dashboard:
  /// accuracy, time, skips, accuracy per sub-topic and the days behind the
  /// trend bars.
  Future<RangeStats> rangeStats(ResultsWindow window);

  Future<List<SavedQuestion>> bookmarks();

  Future<void> setBookmark({required String questionId, required bool saved});

  Future<List<SavedQuestion>> wrongAnswerBank();

  /// Full questions, answer and explanation included, for review outside a
  /// session. The server returns only questions the user has already seen,
  /// bookmarked or banked; anything else is silently left out.
  Future<List<Question>> questionsByIds(List<String> ids);
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
  ///
  /// [topic] picks the endpoint's IQ or GK mode. [questionId] is set on the
  /// first message of an "Explain this" thread, whose [content] then carries
  /// the question's context (see `explainPrompt`).
  Stream<ChatMessage> send({
    required String threadId,
    required String content,
    required AppLanguage language,
    required TutorTopic topic,
    String? questionId,
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

  /// Records this install's push token against the signed-in user, taking it
  /// away from any other account that last signed in on the same phone.
  Future<void> registerDevice(String pushToken, {required String platform});
}
