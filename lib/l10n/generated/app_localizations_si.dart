// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppL10nSi extends AppL10n {
  AppL10nSi([String locale = 'si']) : super(locale);

  @override
  String get appName => 'Smart IQ';

  @override
  String get appTagline => 'සාමාන්‍ය දැනීම හා බුද්ධි විභාග සූදානම';

  @override
  String get actionContinue => 'ඉදිරියට';

  @override
  String get actionBack => 'ආපසු';

  @override
  String get actionClose => 'වසන්න';

  @override
  String get actionRetry => 'නැවත උත්සාහ කරන්න';

  @override
  String get actionCancel => 'අවලංගු කරන්න';

  @override
  String get actionSave => 'සුරකින්න';

  @override
  String get actionUpgrade => 'උසස් කරන්න';

  @override
  String get actionChange => 'වෙනස් කරන්න';

  @override
  String get landingWelcome => 'ආයුබෝවන්';

  @override
  String get landingBlurb =>
      'ශ්‍රී ලංකා රාජ්‍ය හා තරඟකාරී විභාග සඳහා සාමාන්‍ය දැනීම හා බුද්ධි පරීක්ෂණ ඔබේ භාෂාවෙන් අභ්‍යාස කරන්න.';

  @override
  String get landingGetStarted => 'ආරම්භ කරන්න';

  @override
  String get landingHaveAccount => 'දැනටමත් ගිණුමක් තිබේද?';

  @override
  String get landingLogIn => 'පිවිසෙන්න';

  @override
  String get authLoginTitle => 'නැවත සාදරයෙන් පිළිගනිමු';

  @override
  String get authLoginSubtitle => 'ඔබේ ජංගම දුරකථන අංකයෙන් පිවිසෙන්න';

  @override
  String get authSignupTitle => 'ගිණුමක් සාදන්න';

  @override
  String get authSignupSubtitle => 'මිනිත්තුවකටත් අඩු කාලයක්';

  @override
  String get authOtpTitle => 'අංකය සත්‍යාපනය කරන්න';

  @override
  String get authOtpSubtitle => 'අපි එවූ කේතය ඇතුළත් කරන්න';

  @override
  String get fieldMobileNumber => 'ජංගම දුරකථන අංකය';

  @override
  String get fieldMobileHint => 'ඔබේ ජංගම අංකය ඇතුළත් කරන්න';

  @override
  String get fieldUserName => 'පරිශීලක නාමය';

  @override
  String get fieldUserNameHint => 'ඔබේ නම ඇතුළත් කරන්න';

  @override
  String get authOtpNoteLogin => 'අපි මෙම අංකයට ඉලක්කම් 6ක කේතයක් එවන්නෙමු.';

  @override
  String get authOtpNoteSignup =>
      'මෙම අංකය සත්‍යාපනය කිරීමට ඉලක්කම් 6ක කේතයක් එවන්නෙමු.';

  @override
  String get authSendOtp => 'OTP එවන්න';

  @override
  String get authSignupAction => 'ලියාපදිංචි වන්න';

  @override
  String get authNoAccount => 'ගිණුමක් නොමැතිද?';

  @override
  String get authHasAccount => 'දැනටමත් ගිණුමක් තිබේද?';

  @override
  String get authTermsConsent => 'ඉදිරියට යාමෙන් ඔබ එකඟ වන්නේ';

  @override
  String get authTermsConsentBold => 'භාවිත නියම හා රහස්‍යතා ප්‍රතිපත්තියටයි.';

  @override
  String get authReadTerms => 'නියම හා කොන්දේසි කියවන්න';

  @override
  String get otpEnterTitle => 'OTP ඇතුළත් කරන්න';

  @override
  String otpSentTo(String number) {
    return '$number වෙත එවන ලදී';
  }

  @override
  String get otpHelp => 'කවයන් තට්ටු කර ඉලක්කම් 6 ටයිප් කරන්න';

  @override
  String otpExpiresIn(String time) {
    return '$time කින් කල් ඉකුත් වේ';
  }

  @override
  String get otpExpired => 'කේතය කල් ඉකුත් විය';

  @override
  String get otpVerify => 'සත්‍යාපනය කරන්න';

  @override
  String get otpResend => 'OTP නැවත එවන්න';

  @override
  String otpResendIn(int seconds) {
    return 'තත්පර $seconds කින් නැවත එවන්න';
  }

  @override
  String get otpErrorInvalid => 'එම කේතය නිවැරදි නැත. නැවත උත්සාහ කරන්න.';

  @override
  String get otpErrorExpired => 'එම කේතය කල් ඉකුත් වී ඇත. නව එකක් ඉල්ලන්න.';

  @override
  String get errorEnterMobile => 'ඔබේ ජංගම අංකය ඇතුළත් කරන්න.';

  @override
  String get errorInvalidMobile =>
      'වලංගු ශ්‍රී ලාංකික ජංගම අංකයක් ඇතුළත් කරන්න.';

  @override
  String get errorEnterName => 'ඔබේ නම ඇතුළත් කරන්න.';

  @override
  String get errorOffline => 'අන්තර්ජාල සම්බන්ධතාවයක් නැත.';

  @override
  String get errorOfflineBody =>
      'ප්‍රශ්න පූරණය කිරීමට Smart IQ හට සම්බන්ධතාවයක් අවශ්‍යයි. ඔබේ ජාලය පරීක්ෂා කර නැවත උත්සාහ කරන්න.';

  @override
  String get errorGeneric => 'යම් දෝෂයක් ඇති විය.';

  @override
  String get greetingMorning => 'සුබ උදෑසනක්';

  @override
  String get greetingAfternoon => 'සුබ දහවලක්';

  @override
  String get greetingEvening => 'සුබ සැන්දෑවක්';

  @override
  String get statStreak => 'අඛණ්ඩතාව';

  @override
  String get statReadiness => 'සූදානම';

  @override
  String get statExamIn => 'විභාගයට';

  @override
  String statDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'දින $count',
      one: 'දින 1',
    );
    return '$_temp0';
  }

  @override
  String statDaysShort(int count) {
    return 'දින $count';
  }

  @override
  String get statNoExamDate => 'සකසා නැත';

  @override
  String quotaQuestionsToday(String tier) {
    return '$tier · අද ප්‍රශ්න';
  }

  @override
  String quotaUsedOf(int used, String total) {
    return 'අද $total න් $used ක් භාවිත කර ඇත';
  }

  @override
  String get quotaLeft => 'ඉතිරියි';

  @override
  String get quotaUnlimited => 'සීමා රහිත';

  @override
  String get quotaResetsAt => 'මධ්‍යම රාත්‍රියේ (SLT) යළි සකසේ';

  @override
  String get dailyChallengeLabel => 'දෛනික අභියෝගය';

  @override
  String get dailyChallengeTitle => 'අද ප්‍රශ්න 10 ක කට්ටලය';

  @override
  String get dailyChallengeBlurb =>
      'මිශ්‍ර සාමාන්‍ය දැනීම, බුද්ධි හා තත්කාලීන කරුණු · 00:00 SLT ට යළි සකසේ';

  @override
  String get dailyChallengeStart => 'අභියෝගය අරඹන්න';

  @override
  String get dailyChallengeDone => 'අද සම්පූර්ණයි';

  @override
  String get homePracticeByCategory => 'ප්‍රවර්ග අනුව අභ්‍යාස';

  @override
  String get homePerformance => 'කාර්ය සාධනය';

  @override
  String get homeWeakAreasEmpty =>
      'ඔබ දුර්වල කොතැනදැයි බැලීමට අභ්‍යාස සැසියක් සම්පූර්ණ කරන්න.';

  @override
  String get practiceModeQuick => 'ඉක්මන්';

  @override
  String get practiceModeQuickMeta => 'ප්‍රශ්න 10';

  @override
  String get practiceModeTimed => 'කාල සීමිත';

  @override
  String get practiceModeTimedMeta => 'ඔරලෝසුවට එරෙහිව';

  @override
  String get practiceModeSpeed => 'වේග අභ්‍යාසය';

  @override
  String get practiceModeSpeedMeta => 'අඩු කාලයක්';

  @override
  String get practiceModeAdaptive => 'අනුවර්තී';

  @override
  String get practiceModeAdaptiveMeta => 'ඔබේ මට්ටමට ගැලපේ';

  @override
  String get practiceSubTopics => 'උප මාතෘකා';

  @override
  String get practiceStart => 'අභ්‍යාසය අරඹන්න';

  @override
  String get practiceNoSubTopics =>
      'මෙම ප්‍රවර්ගයේ උප මාතෘකා තවම ප්‍රකාශයට පත් කර නැත.';

  @override
  String lockedTitle(String feature) {
    return '$feature ඔබේ සැලසුමේ නැත';
  }

  @override
  String lockedBody(String tier) {
    return 'එය විවෘත කිරීමට උසස් කරන්න. ඔබේ වත්මන් සැලසුම $tier වේ.';
  }

  @override
  String get quizCheckAnswer => 'පිළිතුර පරීක්ෂා කරන්න';

  @override
  String get quizNextQuestion => 'ඊළඟ ප්‍රශ්නය';

  @override
  String get quizFinish => 'අවසන් කරන්න';

  @override
  String get quizVerdictCorrect => 'නිවැරදියි';

  @override
  String get quizVerdictIncorrect => 'වැරදියි';

  @override
  String get quizExplainWithAi => 'AI උපදේශකයෙන් විස්තර කරන්න';

  @override
  String get quizBookmark => 'සලකුණු කරන්න';

  @override
  String get quizBookmarked => 'සලකුණු කර ඇත';

  @override
  String quizCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get quizQuitTitle => 'මෙම සැසියෙන් ඉවත් වන්නද?';

  @override
  String get quizQuitBody =>
      'මේ දක්වා ඔබේ ප්‍රගතිය සුරකින අතර නැවත ආරම්භ කළ හැක.';

  @override
  String get quizQuitConfirm => 'ඉවත් වන්න';

  @override
  String get quizQuitStay => 'අභ්‍යාසය කරගෙන යන්න';

  @override
  String get quizDifficultyEasy => 'පහසු';

  @override
  String get quizDifficultyMedium => 'මධ්‍යම';

  @override
  String get quizDifficultyHard => 'අසීරු';

  @override
  String get quizImageFailed =>
      'මෙම ප්‍රශ්නයේ රූපය පූරණය කළ නොහැකි වූ බැවින් එය මඟ හරින ලදී.';

  @override
  String get quizTapToZoom => 'විශාල කිරීමට තට්ටු කරන්න';

  @override
  String get resultsThisSession => 'මෙම සැසිය';

  @override
  String resultsScoreLine(int correct, int total) {
    return '$total න් $correct ක් නිවැරදියි';
  }

  @override
  String get resultsShowing => 'පෙන්වන්නේ';

  @override
  String get resultsRangeSession => 'සැසිය';

  @override
  String get resultsRangeToday => 'අද';

  @override
  String get resultsRangeWeek => 'දින 7';

  @override
  String get resultsStatCorrect => 'නිවැරදි';

  @override
  String get resultsStatWrong => 'වැරදි';

  @override
  String get resultsStatSkipped => 'මඟ හැරි';

  @override
  String get resultsStatTime => 'සාමාන්‍ය කාලය';

  @override
  String get resultsBreakdown => 'උප මාතෘකා අනුව නිරවද්‍යතාව';

  @override
  String get resultsNoBreakdown =>
      'අද තවම පිළිතුරු නැත. උප මාතෘකා නිරවද්‍යතාව බැලීමට අභ්‍යාස සැසියක් සම්පූර්ණ කරන්න.';

  @override
  String get resultsHistoryTitle => 'ඔබේම පෙර සැසිවලට එරෙහිව';

  @override
  String get resultsPrivacyNote =>
      'ප්‍රගතිය පෞද්ගලිකයි. මෙහි කිසිවක් ඔබ වෙනත් පරිශීලකයෙකු සමඟ සසඳන්නේ නැත.';

  @override
  String get resultsDrillWrong => 'වැරදි පිළිතුරු අභ්‍යාස කරන්න';

  @override
  String get resultsHome => 'මුල් පිටුව';

  @override
  String get tutorTitle => 'AI උපදේශක';

  @override
  String get tutorNewThread => 'නව සංවාදය';

  @override
  String get tutorInputHint => 'සිංහල, දෙමළ හෝ ඉංග්‍රීසියෙන් අසන්න';

  @override
  String tutorQuotaLine(int used, String total) {
    return 'අද $total න් $used ක් භාවිත කර ඇත';
  }

  @override
  String get tutorExhaustedTitle => 'දෛනික AI පණිවිඩ අවසන්';

  @override
  String tutorExhaustedBody(String total) {
    return 'ඔබේ සැලසුම දිනකට පණිවිඩ $total ක් ලබා දේ. තවත් අවශ්‍ය නම් උසස් කරන්න, නැතහොත් මධ්‍යම රාත්‍රියෙන් පසු නැවත එන්න.';
  }

  @override
  String get tutorEmptyTitle => 'ඕනෑම දෙයක් අසන්න';

  @override
  String get tutorEmptyBody =>
      'වැරදි පිළිතුරක් විස්තර කරන්න, ඉඟියක් ඉල්ලන්න, හෝ අභ්‍යාස කට්ටලයක් ඉල්ලන්න — සිංහල, දෙමළ හෝ ඉංග්‍රීසියෙන්.';

  @override
  String get tutorThinking => 'සිතමින්…';

  @override
  String get tutorError =>
      'උපදේශක වෙත සම්බන්ධ විය නොහැකි විය. නැවත උත්සාහ කරන්න.';

  @override
  String get profileTitle => 'පැතිකඩ';

  @override
  String get profileVerified => 'සත්‍යාපිතයි';

  @override
  String get profileCurrentPlan => 'වත්මන් සැලසුම';

  @override
  String get profileStudyMaterial => 'ඔබේ අධ්‍යයන ද්‍රව්‍ය';

  @override
  String get profileStatAnswered => 'පිළිතුරු දුන්';

  @override
  String get profileStatAccuracy => 'නිරවද්‍යතාව';

  @override
  String get profileStatSessions => 'සැසි';

  @override
  String get profileRowBookmarks => 'සලකුණු';

  @override
  String get profileRowBookmarksMeta => 'ඔබ සුරැකි ප්‍රශ්න';

  @override
  String get profileRowWrongBank => 'වැරදි පිළිතුරු බැංකුව';

  @override
  String get profileRowWrongBankMeta => 'පරතර පුනරාවර්තනයෙන් යළි ඉදිරිපත් වේ';

  @override
  String get profileRowMastery => 'මාතෘකා ප්‍රවීණතාව';

  @override
  String get profileRowMasteryMeta => 'උප මාතෘකාවකට නිරවද්‍යතාව';

  @override
  String get profileRowSettings => 'සැකසුම්';

  @override
  String get profileRowSettingsMeta => 'භාෂාව, තේමාව හා ගිණුම';

  @override
  String get settingsTitle => 'සැකසුම්';

  @override
  String get settingsLanguage => 'භාෂාව';

  @override
  String get settingsTheme => 'තේමාව';

  @override
  String get settingsThemeLight => 'දීප්ත';

  @override
  String get settingsThemeDark => 'අඳුරු';

  @override
  String get settingsThemeSystem => 'පද්ධතිය';

  @override
  String get settingsThemeNote =>
      'පළමු දියත් කිරීමේදී පද්ධතිය පෙරනිමි වන අතර පළමු රාමුවට පෙර යොදනු ලැබේ.';

  @override
  String get settingsLegal => 'නීතිමය';

  @override
  String get settingsTerms => 'නියම හා කොන්දේසි';

  @override
  String get settingsTermsMeta => 'දායකත්වය, අය කිරීම් හා දත්ත භාවිතය';

  @override
  String get settingsAccount => 'ගිණුම';

  @override
  String get settingsDevices => 'සක්‍රීය උපාංග';

  @override
  String get settingsDevicesMeta => 'වෙනත් උපාංගවලින් ඉවත් වන්න';

  @override
  String get settingsNotifications => 'දැනුම්දීම්';

  @override
  String get settingsExportData => 'මගේ දත්ත නිර්යාත කරන්න';

  @override
  String get settingsDeleteAccount => 'ගිණුම මකන්න';

  @override
  String get settingsDeleteConfirmTitle => 'ඔබේ ගිණුම මකන්නද?';

  @override
  String get settingsDeleteConfirmBody =>
      'මෙය ඔබේ පැතිකඩ, ප්‍රගතිය හා සංවාද ඉතිහාසය ස්ථිරව ඉවත් කරයි. එය පසුව හරවා ගත නොහැක.';

  @override
  String get settingsSignOut => 'ඉවත් වන්න';

  @override
  String get notificationsTitle => 'දැනුම්දීම්';

  @override
  String get notificationsMarkAllRead => 'සියල්ල කියවූ ලෙස සලකුණු කරන්න';

  @override
  String get notificationsEmpty => 'දැනට අලුත් දෙයක් නැත.';

  @override
  String get notificationPrefDaily => 'දෛනික අභියෝගය';

  @override
  String get notificationPrefStreak => 'අඛණ්ඩතා මතක් කිරීම්';

  @override
  String get notificationPrefDigest => 'තත්කාලීන කරුණු සාරාංශය';

  @override
  String get notificationPrefBilling => 'දායකත්වය හා අය කිරීම්';

  @override
  String get notificationPrefInactivity => 'ඔබ ඈත් වූ විට මතක් කිරීම්';

  @override
  String get navHome => 'මුල් පිටුව';

  @override
  String get navPractice => 'අභ්‍යාස';

  @override
  String get navTutor => 'උපදේශක';

  @override
  String get navProfile => 'පැතිකඩ';

  @override
  String get planSheetTitle => 'ඔබේ සැලසුම තෝරන්න';

  @override
  String get planSheetBlurb =>
      'Basic සඳහා දෛනික ටෙල්කෝ අය කිරීම, Pro හා Pro+ සඳහා කාඩ්පත් අය කිරීම. පළමු දිනයේ සිට අය කිරීම ආරම්භ වේ — නොමිලේ අත්හදා බැලීමක් නැත.';

  @override
  String get planCurrent => 'වත්මන්';

  @override
  String get tierFree => 'නොමිලේ';

  @override
  String get tierBasic => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String get tierProPlus => 'Pro+';

  @override
  String get tierFreeBlurb =>
      'අය කිරීම අසාර්ථකයි හෝ නොමැත. දිනකට ප්‍රශ්න දෙකක් හා AI පණිවිඩ දෙකක් — යෙදුම හොඳ බව මතක තබා ගැනීමට ප්‍රමාණවත්, සූදානම් වීමට නොවේ.';

  @override
  String get tierBasicBlurb =>
      'දෛනික ටෙල්කෝ අය කිරීම. දෛනික අභියෝගය, දිනකට ප්‍රශ්න 50, AI පණිවිඩ 10, මාසයකට ආදර්ශ විභාග 2.';

  @override
  String get tierProBlurb =>
      'මාසික කාඩ්පත් අය කිරීම. අනුවර්තී දුෂ්කරතාව, අධ්‍යයන සැලසුම, වේග අභ්‍යාස, දින 90 සංවාද ඉතිහාසය.';

  @override
  String get tierProPlusBlurb =>
      'සියල්ල ඉහළම සීමාවන්හි: සීමා රහිත අභ්‍යාස, සීමා රහිත ආදර්ශ විභාග, සීමා රහිත සංවාද ඉතිහාසය.';

  @override
  String planPriceDaily(String amount) {
    return 'රු. $amount/දිනකට';
  }

  @override
  String planPriceMonthly(String amount) {
    return 'රු. $amount/මසකට';
  }

  @override
  String get planPriceFree => 'නොමිලේ';

  @override
  String get termsTitle => 'නියම හා කොන්දේසි';

  @override
  String termsUpdated(String date) {
    return 'අවසන් වරට යාවත්කාලීන $date';
  }

  @override
  String get actionSkip => 'දැනට මඟ හරින්න';

  @override
  String get profileSetupTitle => 'තව ටිකයි';

  @override
  String get profileSetupSubtitle =>
      'සුළු තොරතුරු කිහිපයක් ඔබේ අධ්‍යයන සැලසුම සැකසීමට උපකාරී වේ';

  @override
  String get profileSetupOptionalNote =>
      'මේ සියල්ල විකල්ප වන අතර පසුව සැකසුම් තුළ වෙනස් කළ හැක.';

  @override
  String get fieldDistrict => 'දිස්ත්‍රික්කය';

  @override
  String get fieldTargetExamDate => 'විභාග දිනය';

  @override
  String get labelOptional => 'විකල්ප';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSinhala => 'සිංහල';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get loadingEntitlement => 'ඔබේ දායකත්වය පරීක්ෂා කරමින්…';

  @override
  String get loading => 'පූරණය වෙමින්…';
}
