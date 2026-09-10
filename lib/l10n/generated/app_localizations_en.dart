// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Smart IQ';

  @override
  String get appTagline => 'GK & IQ exam preparation';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionBack => 'Back';

  @override
  String get actionClose => 'Close';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionUpgrade => 'Upgrade';

  @override
  String get actionChange => 'Change';

  @override
  String get landingWelcome => 'Welcome';

  @override
  String get landingBlurb =>
      'Practise general knowledge and aptitude for Sri Lankan government and competitive exams, in your own language.';

  @override
  String get landingGetStarted => 'Get started';

  @override
  String get landingHaveAccount => 'Have an account?';

  @override
  String get landingLogIn => 'Log in';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authLoginSubtitle => 'Log in with your mobile number';

  @override
  String get authSignupTitle => 'Create account';

  @override
  String get authSignupSubtitle => 'It takes less than a minute';

  @override
  String get authOtpTitle => 'Verify your number';

  @override
  String get authOtpSubtitle => 'Enter the code we sent you';

  @override
  String get fieldMobileNumber => 'Mobile Number';

  @override
  String get fieldMobileHint => 'enter your mobile number';

  @override
  String get fieldUserName => 'User Name';

  @override
  String get fieldUserNameHint => 'enter your name';

  @override
  String get authOtpNoteLogin => 'We will send a 6-digit code to this number.';

  @override
  String get authOtpNoteSignup =>
      'We will send a 6-digit code to verify this number.';

  @override
  String get authSendOtp => 'Send OTP';

  @override
  String get authSignupAction => 'Signup';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authTermsConsent => 'By continuing, you agree to';

  @override
  String get authTermsConsentBold => 'Terms of Use and Privacy Policy.';

  @override
  String get authReadTerms => 'Read Terms & Conditions';

  @override
  String get otpEnterTitle => 'Enter OTP';

  @override
  String otpSentTo(String number) {
    return 'Sent to $number';
  }

  @override
  String get otpHelp => 'Tap the circles and type the 6 digits';

  @override
  String otpExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get otpExpired => 'Code expired';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Resend OTP';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpErrorInvalid => 'That code is not correct. Try again.';

  @override
  String get otpErrorExpired => 'That code has expired. Request a new one.';

  @override
  String get errorEnterMobile => 'Enter your mobile number.';

  @override
  String get errorInvalidMobile => 'Enter a valid Sri Lankan mobile number.';

  @override
  String get errorEnterName => 'Enter your name.';

  @override
  String get errorOffline => 'No internet connection.';

  @override
  String get errorOfflineBody =>
      'Smart IQ needs a connection to load questions. Check your network and try again.';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get statStreak => 'Streak';

  @override
  String get statReadiness => 'Readiness';

  @override
  String get statExamIn => 'Exam in';

  @override
  String statDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String statDaysShort(int count) {
    return '$count d';
  }

  @override
  String get statNoExamDate => 'Not set';

  @override
  String quotaQuestionsToday(String tier) {
    return '$tier · questions today';
  }

  @override
  String quotaUsedOf(int used, String total) {
    return '$used of $total used today';
  }

  @override
  String get quotaLeft => 'left';

  @override
  String get quotaUnlimited => 'Unlimited';

  @override
  String get quotaResetsAt => 'Resets at midnight SLT';

  @override
  String get dailyChallengeLabel => 'Daily challenge';

  @override
  String get dailyChallengeTitle => 'Today\'s 10-question set';

  @override
  String get dailyChallengeBlurb =>
      'Mixed GK, aptitude and current affairs · resets 00:00 SLT';

  @override
  String get dailyChallengeStart => 'Start challenge';

  @override
  String get dailyChallengeDone => 'Completed today';

  @override
  String get homePracticeByCategory => 'Practice by category';

  @override
  String get homePerformance => 'Performance';

  @override
  String get homeWeakAreasEmpty =>
      'Finish a practice session to see where you are weakest.';

  @override
  String get practiceModeQuick => 'Quick';

  @override
  String get practiceModeQuickMeta => '10 questions';

  @override
  String get practiceModeTimed => 'Timed';

  @override
  String get practiceModeTimedMeta => 'Against the clock';

  @override
  String get practiceModeSpeed => 'Speed drill';

  @override
  String get practiceModeSpeedMeta => 'Reduced time';

  @override
  String get practiceModeAdaptive => 'Adaptive';

  @override
  String get practiceModeAdaptiveMeta => 'Matches your level';

  @override
  String get practiceSubTopics => 'Sub-topics';

  @override
  String get practiceStart => 'Start practice';

  @override
  String get practiceNoSubTopics =>
      'No sub-topics published in this category yet.';

  @override
  String lockedTitle(String feature) {
    return '$feature is not on your plan';
  }

  @override
  String lockedBody(String tier) {
    return 'Upgrade to unlock it. Your current plan is $tier.';
  }

  @override
  String get quizCheckAnswer => 'Check answer';

  @override
  String get quizNextQuestion => 'Next question';

  @override
  String get quizFinish => 'Finish';

  @override
  String get quizVerdictCorrect => 'Correct';

  @override
  String get quizVerdictIncorrect => 'Not quite';

  @override
  String get quizExplainWithAi => 'Explain with AI tutor';

  @override
  String get quizBookmark => 'Bookmark';

  @override
  String get quizBookmarked => 'Bookmarked';

  @override
  String quizCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get quizQuitTitle => 'Leave this session?';

  @override
  String get quizQuitBody =>
      'Your progress so far is saved and you can resume it.';

  @override
  String get quizQuitConfirm => 'Leave';

  @override
  String get quizQuitStay => 'Keep practising';

  @override
  String get quizDifficultyEasy => 'Easy';

  @override
  String get quizDifficultyMedium => 'Medium';

  @override
  String get quizDifficultyHard => 'Hard';

  @override
  String get quizImageFailed =>
      'This question\'s image could not be loaded, so it was skipped.';

  @override
  String get quizTapToZoom => 'Tap to zoom';

  @override
  String get resultsThisSession => 'This session';

  @override
  String resultsScoreLine(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get resultsShowing => 'Showing';

  @override
  String get resultsRangeSession => 'Session';

  @override
  String get resultsRangeToday => 'Today';

  @override
  String get resultsRangeWeek => '7 days';

  @override
  String get resultsStatCorrect => 'Correct';

  @override
  String get resultsStatWrong => 'Wrong';

  @override
  String get resultsStatSkipped => 'Skipped';

  @override
  String get resultsStatTime => 'Avg time';

  @override
  String get resultsBreakdown => 'Accuracy by sub-topic';

  @override
  String get resultsNoBreakdown =>
      'No answers today yet. Finish a practice session to see your sub-topic accuracy.';

  @override
  String get resultsHistoryTitle => 'Against your own last sessions';

  @override
  String get resultsPrivacyNote =>
      'Progress is private. Nothing here compares you to another user.';

  @override
  String get resultsDrillWrong => 'Drill wrong answers';

  @override
  String get resultsHome => 'Home';

  @override
  String get tutorTitle => 'AI Tutor';

  @override
  String get tutorNewThread => 'New thread';

  @override
  String get tutorInputHint => 'Ask in Sinhala, Tamil or English';

  @override
  String tutorQuotaLine(int used, String total) {
    return '$used of $total messages used today';
  }

  @override
  String get tutorExhaustedTitle => 'Daily AI messages used up';

  @override
  String tutorExhaustedBody(String total) {
    return 'Your plan allows $total messages a day. Upgrade for more, or come back after midnight SLT.';
  }

  @override
  String get tutorEmptyTitle => 'Ask anything';

  @override
  String get tutorEmptyBody =>
      'Explain a wrong answer, ask for a hint, or request a practice set — in Sinhala, Tamil or English.';

  @override
  String get tutorThinking => 'Thinking…';

  @override
  String get tutorError => 'The tutor could not be reached. Try again.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileVerified => 'verified';

  @override
  String get profileCurrentPlan => 'Current plan';

  @override
  String get profileStudyMaterial => 'Your study material';

  @override
  String get profileStatAnswered => 'Answered';

  @override
  String get profileStatAccuracy => 'Accuracy';

  @override
  String get profileStatSessions => 'Sessions';

  @override
  String get profileRowBookmarks => 'Bookmarks';

  @override
  String get profileRowBookmarksMeta => 'Questions you saved';

  @override
  String get profileRowWrongBank => 'Wrong-answer bank';

  @override
  String get profileRowWrongBankMeta => 'Resurfaced by spaced repetition';

  @override
  String get profileRowMastery => 'Topic mastery';

  @override
  String get profileRowMasteryMeta => 'Accuracy per sub-topic';

  @override
  String get profileRowSettings => 'Settings';

  @override
  String get profileRowSettingsMeta => 'Language, theme and account';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeNote =>
      'System is the default on first launch and is applied before the first frame.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsTerms => 'Terms & Conditions';

  @override
  String get settingsTermsMeta => 'Subscription, charging and data use';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsDevices => 'Active devices';

  @override
  String get settingsDevicesMeta => 'Sign out of other devices';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsExportData => 'Export my data';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteConfirmTitle => 'Delete your account?';

  @override
  String get settingsDeleteConfirmBody =>
      'This removes your profile, progress and chat history permanently. It cannot be undone.';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsEmpty => 'Nothing new right now.';

  @override
  String get notificationPrefDaily => 'Daily challenge';

  @override
  String get notificationPrefStreak => 'Streak reminders';

  @override
  String get notificationPrefDigest => 'Current affairs digest';

  @override
  String get notificationPrefBilling => 'Subscription and charging';

  @override
  String get notificationPrefInactivity => 'Reminders when you are away';

  @override
  String get navHome => 'Home';

  @override
  String get navPractice => 'Practice';

  @override
  String get navTutor => 'Tutor';

  @override
  String get navProfile => 'Profile';

  @override
  String get planSheetTitle => 'Choose your plan';

  @override
  String get planSheetBlurb =>
      'Telco daily charging for Basic, card billing for Pro and Pro+. Charging starts on day one — no trial.';

  @override
  String get planCurrent => 'Current';

  @override
  String get tierFree => 'Free Fallback';

  @override
  String get tierBasic => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String get tierProPlus => 'Pro+';

  @override
  String get tierFreeBlurb =>
      'Charging failed or absent. Two questions and two AI messages a day — enough to remember the app is good, not enough to prepare with.';

  @override
  String get tierBasicBlurb =>
      'Telco daily charging. Daily challenge, 50 questions a day, 10 AI messages, 2 mock exams a month.';

  @override
  String get tierProBlurb =>
      'Monthly card billing. Adaptive difficulty, study-plan generator, speed drills, 90-day chat history.';

  @override
  String get tierProPlusBlurb =>
      'Everything at the highest limits: unlimited practice, unlimited mock exams, unlimited chat history.';

  @override
  String planPriceDaily(String amount) {
    return 'Rs. $amount/day';
  }

  @override
  String planPriceMonthly(String amount) {
    return 'Rs. $amount/month';
  }

  @override
  String get planPriceFree => 'Free';

  @override
  String get termsTitle => 'Terms & Conditions';

  @override
  String termsUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get actionSkip => 'Skip for now';

  @override
  String get profileSetupTitle => 'Almost done';

  @override
  String get profileSetupSubtitle =>
      'A little detail helps us pace your study plan';

  @override
  String get profileSetupOptionalNote =>
      'All of this is optional and you can change it later in Settings.';

  @override
  String get fieldDistrict => 'District';

  @override
  String get fieldTargetExamDate => 'Target exam date';

  @override
  String get labelOptional => 'Optional';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSinhala => 'සිංහල';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get loadingEntitlement => 'Checking your subscription…';

  @override
  String get loading => 'Loading…';
}
