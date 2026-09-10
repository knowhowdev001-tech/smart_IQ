import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Smart IQ'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'GK & IQ exam preparation'**
  String get appTagline;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get actionUpgrade;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @landingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get landingWelcome;

  /// No description provided for @landingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Practise general knowledge and aptitude for Sri Lankan government and competitive exams, in your own language.'**
  String get landingBlurb;

  /// No description provided for @landingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get landingGetStarted;

  /// No description provided for @landingHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Have an account?'**
  String get landingHaveAccount;

  /// No description provided for @landingLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get landingLogIn;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in with your mobile number'**
  String get authLoginSubtitle;

  /// No description provided for @authSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignupTitle;

  /// No description provided for @authSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It takes less than a minute'**
  String get authSignupSubtitle;

  /// No description provided for @authOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent you'**
  String get authOtpSubtitle;

  /// No description provided for @fieldMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get fieldMobileNumber;

  /// No description provided for @fieldMobileHint.
  ///
  /// In en, this message translates to:
  /// **'enter your mobile number'**
  String get fieldMobileHint;

  /// No description provided for @fieldUserName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get fieldUserName;

  /// No description provided for @fieldUserNameHint.
  ///
  /// In en, this message translates to:
  /// **'enter your name'**
  String get fieldUserNameHint;

  /// No description provided for @authOtpNoteLogin.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to this number.'**
  String get authOtpNoteLogin;

  /// No description provided for @authOtpNoteSignup.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to verify this number.'**
  String get authOtpNoteSignup;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get authSendOtp;

  /// No description provided for @authSignupAction.
  ///
  /// In en, this message translates to:
  /// **'Signup'**
  String get authSignupAction;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authTermsConsent.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to'**
  String get authTermsConsent;

  /// No description provided for @authTermsConsentBold.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use and Privacy Policy.'**
  String get authTermsConsentBold;

  /// No description provided for @authReadTerms.
  ///
  /// In en, this message translates to:
  /// **'Read Terms'**
  String get authReadTerms;

  /// No description provided for @otpEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get otpEnterTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {number}'**
  String otpSentTo(String number);

  /// No description provided for @otpHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the circles and type the 6 digits'**
  String get otpHelp;

  /// No description provided for @otpExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String otpExpiresIn(String time);

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get otpExpired;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct. Try again.'**
  String get otpErrorInvalid;

  /// No description provided for @otpErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Request a new one.'**
  String get otpErrorExpired;

  /// No description provided for @errorEnterMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number.'**
  String get errorEnterMobile;

  /// No description provided for @errorInvalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Sri Lankan mobile number.'**
  String get errorInvalidMobile;

  /// No description provided for @errorEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get errorEnterName;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorOffline;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Smart IQ needs a connection to load questions. Check your network and try again.'**
  String get errorOfflineBody;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statStreak;

  /// No description provided for @statReadiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get statReadiness;

  /// No description provided for @statExamIn.
  ///
  /// In en, this message translates to:
  /// **'Exam in'**
  String get statExamIn;

  /// No description provided for @statDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String statDays(int count);

  /// No description provided for @statDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String statDaysShort(int count);

  /// No description provided for @statNoExamDate.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get statNoExamDate;

  /// No description provided for @quotaQuestionsToday.
  ///
  /// In en, this message translates to:
  /// **'{tier} · questions today'**
  String quotaQuestionsToday(String tier);

  /// No description provided for @quotaUsedOf.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used today'**
  String quotaUsedOf(int used, String total);

  /// No description provided for @quotaLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get quotaLeft;

  /// No description provided for @quotaUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get quotaUnlimited;

  /// No description provided for @quotaResetsAt.
  ///
  /// In en, this message translates to:
  /// **'Resets at midnight SLT'**
  String get quotaResetsAt;

  /// No description provided for @dailyChallengeLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily challenge'**
  String get dailyChallengeLabel;

  /// No description provided for @dailyChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s 10-question set'**
  String get dailyChallengeTitle;

  /// No description provided for @dailyChallengeBlurb.
  ///
  /// In en, this message translates to:
  /// **'Mixed GK, aptitude and current affairs · resets 00:00 SLT'**
  String get dailyChallengeBlurb;

  /// No description provided for @dailyChallengeStart.
  ///
  /// In en, this message translates to:
  /// **'Start challenge'**
  String get dailyChallengeStart;

  /// No description provided for @dailyChallengeDone.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get dailyChallengeDone;

  /// No description provided for @homePracticeByCategory.
  ///
  /// In en, this message translates to:
  /// **'Practice by category'**
  String get homePracticeByCategory;

  /// No description provided for @homePerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get homePerformance;

  /// No description provided for @homeWeakAreasEmpty.
  ///
  /// In en, this message translates to:
  /// **'Finish a practice session to see where you are weakest.'**
  String get homeWeakAreasEmpty;

  /// No description provided for @practiceModeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get practiceModeQuick;

  /// No description provided for @practiceModeQuickMeta.
  ///
  /// In en, this message translates to:
  /// **'10 questions'**
  String get practiceModeQuickMeta;

  /// No description provided for @practiceModeTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get practiceModeTimed;

  /// No description provided for @practiceModeTimedMeta.
  ///
  /// In en, this message translates to:
  /// **'Against the clock'**
  String get practiceModeTimedMeta;

  /// No description provided for @practiceModeSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed drill'**
  String get practiceModeSpeed;

  /// No description provided for @practiceModeSpeedMeta.
  ///
  /// In en, this message translates to:
  /// **'Reduced time'**
  String get practiceModeSpeedMeta;

  /// No description provided for @practiceModeAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get practiceModeAdaptive;

  /// No description provided for @practiceModeAdaptiveMeta.
  ///
  /// In en, this message translates to:
  /// **'Matches your level'**
  String get practiceModeAdaptiveMeta;

  /// No description provided for @practiceSubTopics.
  ///
  /// In en, this message translates to:
  /// **'Sub-topics'**
  String get practiceSubTopics;

  /// No description provided for @practiceStart.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get practiceStart;

  /// No description provided for @practiceNoSubTopics.
  ///
  /// In en, this message translates to:
  /// **'No sub-topics published in this category yet.'**
  String get practiceNoSubTopics;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'{feature} is not on your plan'**
  String lockedTitle(String feature);

  /// No description provided for @lockedBody.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to unlock it. Your current plan is {tier}.'**
  String lockedBody(String tier);

  /// No description provided for @quizCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get quizCheckAnswer;

  /// No description provided for @quizNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get quizNextQuestion;

  /// No description provided for @quizFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get quizFinish;

  /// No description provided for @quizVerdictCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get quizVerdictCorrect;

  /// No description provided for @quizVerdictIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get quizVerdictIncorrect;

  /// No description provided for @quizExplainWithAi.
  ///
  /// In en, this message translates to:
  /// **'Explain with AI tutor'**
  String get quizExplainWithAi;

  /// No description provided for @quizBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get quizBookmark;

  /// No description provided for @quizBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get quizBookmarked;

  /// No description provided for @quizCounter.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String quizCounter(int current, int total);

  /// No description provided for @quizQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this session?'**
  String get quizQuitTitle;

  /// No description provided for @quizQuitBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress so far is saved and you can resume it.'**
  String get quizQuitBody;

  /// No description provided for @quizQuitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get quizQuitConfirm;

  /// No description provided for @quizQuitStay.
  ///
  /// In en, this message translates to:
  /// **'Keep practising'**
  String get quizQuitStay;

  /// No description provided for @quizDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get quizDifficultyEasy;

  /// No description provided for @quizDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get quizDifficultyMedium;

  /// No description provided for @quizDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get quizDifficultyHard;

  /// No description provided for @quizImageFailed.
  ///
  /// In en, this message translates to:
  /// **'This question\'s image could not be loaded, so it was skipped.'**
  String get quizImageFailed;

  /// No description provided for @quizTapToZoom.
  ///
  /// In en, this message translates to:
  /// **'Tap to zoom'**
  String get quizTapToZoom;

  /// No description provided for @resultsThisSession.
  ///
  /// In en, this message translates to:
  /// **'This session'**
  String get resultsThisSession;

  /// No description provided for @resultsScoreLine.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String resultsScoreLine(int correct, int total);

  /// No description provided for @resultsShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get resultsShowing;

  /// No description provided for @resultsRangeSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get resultsRangeSession;

  /// No description provided for @resultsRangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get resultsRangeToday;

  /// No description provided for @resultsRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get resultsRangeWeek;

  /// No description provided for @resultsStatCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get resultsStatCorrect;

  /// No description provided for @resultsStatWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get resultsStatWrong;

  /// No description provided for @resultsStatSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get resultsStatSkipped;

  /// No description provided for @resultsStatTime.
  ///
  /// In en, this message translates to:
  /// **'Avg time'**
  String get resultsStatTime;

  /// No description provided for @resultsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Accuracy by sub-topic'**
  String get resultsBreakdown;

  /// No description provided for @resultsNoBreakdown.
  ///
  /// In en, this message translates to:
  /// **'No answers today yet. Finish a practice session to see your sub-topic accuracy.'**
  String get resultsNoBreakdown;

  /// No description provided for @resultsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Against your own last sessions'**
  String get resultsHistoryTitle;

  /// No description provided for @resultsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Progress is private. Nothing here compares you to another user.'**
  String get resultsPrivacyNote;

  /// No description provided for @resultsDrillWrong.
  ///
  /// In en, this message translates to:
  /// **'Drill wrong answers'**
  String get resultsDrillWrong;

  /// No description provided for @resultsHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get resultsHome;

  /// No description provided for @tutorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor'**
  String get tutorTitle;

  /// No description provided for @tutorNewThread.
  ///
  /// In en, this message translates to:
  /// **'New thread'**
  String get tutorNewThread;

  /// No description provided for @tutorInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask in Sinhala, Tamil or English'**
  String get tutorInputHint;

  /// No description provided for @tutorQuotaLine.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} messages used today'**
  String tutorQuotaLine(int used, String total);

  /// No description provided for @tutorExhaustedTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily AI messages used up'**
  String get tutorExhaustedTitle;

  /// No description provided for @tutorExhaustedBody.
  ///
  /// In en, this message translates to:
  /// **'Your plan allows {total} messages a day. Upgrade for more, or come back after midnight SLT.'**
  String tutorExhaustedBody(String total);

  /// No description provided for @tutorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything'**
  String get tutorEmptyTitle;

  /// No description provided for @tutorEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Explain a wrong answer, ask for a hint, or request a practice set — in Sinhala, Tamil or English.'**
  String get tutorEmptyBody;

  /// No description provided for @tutorThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get tutorThinking;

  /// No description provided for @tutorError.
  ///
  /// In en, this message translates to:
  /// **'The tutor could not be reached. Try again.'**
  String get tutorError;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileVerified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get profileVerified;

  /// No description provided for @profileCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get profileCurrentPlan;

  /// No description provided for @profileStudyMaterial.
  ///
  /// In en, this message translates to:
  /// **'Your study material'**
  String get profileStudyMaterial;

  /// No description provided for @profileStatAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get profileStatAnswered;

  /// No description provided for @profileStatAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get profileStatAccuracy;

  /// No description provided for @profileStatSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get profileStatSessions;

  /// No description provided for @profileRowBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get profileRowBookmarks;

  /// No description provided for @profileRowBookmarksMeta.
  ///
  /// In en, this message translates to:
  /// **'Questions you saved'**
  String get profileRowBookmarksMeta;

  /// No description provided for @profileRowWrongBank.
  ///
  /// In en, this message translates to:
  /// **'Wrong-answer bank'**
  String get profileRowWrongBank;

  /// No description provided for @profileRowWrongBankMeta.
  ///
  /// In en, this message translates to:
  /// **'Resurfaced by spaced repetition'**
  String get profileRowWrongBankMeta;

  /// No description provided for @profileRowMastery.
  ///
  /// In en, this message translates to:
  /// **'Topic mastery'**
  String get profileRowMastery;

  /// No description provided for @profileRowMasteryMeta.
  ///
  /// In en, this message translates to:
  /// **'Accuracy per sub-topic'**
  String get profileRowMasteryMeta;

  /// No description provided for @profileRowSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileRowSettings;

  /// No description provided for @profileRowSettingsMeta.
  ///
  /// In en, this message translates to:
  /// **'Language, theme and account'**
  String get profileRowSettingsMeta;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeNote.
  ///
  /// In en, this message translates to:
  /// **'System is the default on first launch and is applied before the first frame.'**
  String get settingsThemeNote;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get settingsTerms;

  /// No description provided for @settingsTermsMeta.
  ///
  /// In en, this message translates to:
  /// **'Subscription, charging and data use'**
  String get settingsTermsMeta;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsDevices.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get settingsDevices;

  /// No description provided for @settingsDevicesMeta.
  ///
  /// In en, this message translates to:
  /// **'Sign out of other devices'**
  String get settingsDevicesMeta;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsExportData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get settingsExportData;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your profile, progress and chat history permanently. It cannot be undone.'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing new right now.'**
  String get notificationsEmpty;

  /// No description provided for @notificationPrefDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily challenge'**
  String get notificationPrefDaily;

  /// No description provided for @notificationPrefStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak reminders'**
  String get notificationPrefStreak;

  /// No description provided for @notificationPrefDigest.
  ///
  /// In en, this message translates to:
  /// **'Current affairs digest'**
  String get notificationPrefDigest;

  /// No description provided for @notificationPrefBilling.
  ///
  /// In en, this message translates to:
  /// **'Subscription and charging'**
  String get notificationPrefBilling;

  /// No description provided for @notificationPrefInactivity.
  ///
  /// In en, this message translates to:
  /// **'Reminders when you are away'**
  String get notificationPrefInactivity;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get navPractice;

  /// No description provided for @navTutor.
  ///
  /// In en, this message translates to:
  /// **'Tutor'**
  String get navTutor;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @planSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get planSheetTitle;

  /// No description provided for @planSheetBlurb.
  ///
  /// In en, this message translates to:
  /// **'Telco daily charging for Basic, card billing for Pro and Pro+. Charging starts on day one — no trial.'**
  String get planSheetBlurb;

  /// No description provided for @planCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get planCurrent;

  /// No description provided for @tierFree.
  ///
  /// In en, this message translates to:
  /// **'Free Fallback'**
  String get tierFree;

  /// No description provided for @tierBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get tierBasic;

  /// No description provided for @tierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get tierPro;

  /// No description provided for @tierProPlus.
  ///
  /// In en, this message translates to:
  /// **'Pro+'**
  String get tierProPlus;

  /// No description provided for @tierFreeBlurb.
  ///
  /// In en, this message translates to:
  /// **'Charging failed or absent. Two questions and two AI messages a day — enough to remember the app is good, not enough to prepare with.'**
  String get tierFreeBlurb;

  /// No description provided for @tierBasicBlurb.
  ///
  /// In en, this message translates to:
  /// **'Telco daily charging. Daily challenge, 50 questions a day, 10 AI messages, 2 mock exams a month.'**
  String get tierBasicBlurb;

  /// No description provided for @tierProBlurb.
  ///
  /// In en, this message translates to:
  /// **'Monthly card billing. Adaptive difficulty, study-plan generator, speed drills, 90-day chat history.'**
  String get tierProBlurb;

  /// No description provided for @tierProPlusBlurb.
  ///
  /// In en, this message translates to:
  /// **'Everything at the highest limits: unlimited practice, unlimited mock exams, unlimited chat history.'**
  String get tierProPlusBlurb;

  /// No description provided for @planPriceDaily.
  ///
  /// In en, this message translates to:
  /// **'Rs. {amount}/day'**
  String planPriceDaily(String amount);

  /// No description provided for @planPriceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Rs. {amount}/month'**
  String planPriceMonthly(String amount);

  /// No description provided for @planPriceFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planPriceFree;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsTitle;

  /// No description provided for @termsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String termsUpdated(String date);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSinhala.
  ///
  /// In en, this message translates to:
  /// **'සිංහල'**
  String get languageSinhala;

  /// No description provided for @languageTamil.
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get languageTamil;

  /// No description provided for @loadingEntitlement.
  ///
  /// In en, this message translates to:
  /// **'Checking your subscription…'**
  String get loadingEntitlement;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'si':
      return AppL10nSi();
    case 'ta':
      return AppL10nTa();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
