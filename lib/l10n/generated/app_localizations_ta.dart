// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppL10nTa extends AppL10n {
  AppL10nTa([String locale = 'ta']) : super(locale);

  @override
  String get appName => 'Smart IQ';

  @override
  String get appTagline => 'பொது அறிவு மற்றும் திறனறி தேர்வுத் தயாரிப்பு';

  @override
  String get actionContinue => 'தொடரவும்';

  @override
  String get actionBack => 'பின்செல்';

  @override
  String get actionClose => 'மூடு';

  @override
  String get actionRetry => 'மீண்டும் முயற்சி';

  @override
  String get actionCancel => 'ரத்து';

  @override
  String get actionSave => 'சேமி';

  @override
  String get actionUpgrade => 'மேம்படுத்து';

  @override
  String get actionChange => 'மாற்று';

  @override
  String get landingWelcome => 'வரவேற்கிறோம்';

  @override
  String get landingBlurb =>
      'இலங்கை அரசாங்க மற்றும் போட்டித் தேர்வுகளுக்கான பொது அறிவு மற்றும் திறனறிப் பயிற்சியை உங்கள் மொழியில் செய்யுங்கள்.';

  @override
  String get landingGetStarted => 'தொடங்கு';

  @override
  String get landingHaveAccount => 'ஏற்கனவே கணக்கு உள்ளதா?';

  @override
  String get landingLogIn => 'உள்நுழை';

  @override
  String get authLoginTitle => 'மீண்டும் வரவேற்கிறோம்';

  @override
  String get authLoginSubtitle => 'உங்கள் கைபேசி எண்ணால் உள்நுழையவும்';

  @override
  String get authSignupTitle => 'கணக்கை உருவாக்கு';

  @override
  String get authSignupSubtitle => 'ஒரு நிமிடத்திற்கும் குறைவு';

  @override
  String get authOtpTitle => 'எண்ணை உறுதிப்படுத்து';

  @override
  String get authOtpSubtitle => 'நாங்கள் அனுப்பிய குறியீட்டை உள்ளிடவும்';

  @override
  String get fieldMobileNumber => 'கைபேசி எண்';

  @override
  String get fieldMobileHint => 'உங்கள் கைபேசி எண்ணை உள்ளிடவும்';

  @override
  String get fieldUserName => 'பயனர் பெயர்';

  @override
  String get fieldUserNameHint => 'உங்கள் பெயரை உள்ளிடவும்';

  @override
  String get authOtpNoteLogin =>
      'இந்த எண்ணுக்கு 6 இலக்கக் குறியீட்டை அனுப்புவோம்.';

  @override
  String get authOtpNoteSignup =>
      'இந்த எண்ணை உறுதிப்படுத்த 6 இலக்கக் குறியீட்டை அனுப்புவோம்.';

  @override
  String get authSendOtp => 'OTP அனுப்பு';

  @override
  String get authSignupAction => 'பதிவு செய்';

  @override
  String get authNoAccount => 'கணக்கு இல்லையா?';

  @override
  String get authHasAccount => 'ஏற்கனவே கணக்கு உள்ளதா?';

  @override
  String get authTermsConsent => 'தொடர்வதன் மூலம் நீங்கள் ஒப்புக்கொள்வது';

  @override
  String get authTermsConsentBold =>
      'பயன்பாட்டு விதிமுறைகள் மற்றும் தனியுரிமைக் கொள்கை.';

  @override
  String get authReadTerms => 'விதிமுறைகளைப் படி';

  @override
  String get otpEnterTitle => 'OTP உள்ளிடவும்';

  @override
  String otpSentTo(String number) {
    return '$number க்கு அனுப்பப்பட்டது';
  }

  @override
  String get otpHelp => 'வட்டங்களைத் தட்டி 6 இலக்கங்களைத் தட்டச்சு செய்யவும்';

  @override
  String otpExpiresIn(String time) {
    return '$time இல் காலாவதியாகும்';
  }

  @override
  String get otpExpired => 'குறியீடு காலாவதியானது';

  @override
  String get otpVerify => 'உறுதிப்படுத்து';

  @override
  String get otpResend => 'OTP மீண்டும் அனுப்பு';

  @override
  String otpResendIn(int seconds) {
    return '$seconds வினாடிகளில் மீண்டும் அனுப்பு';
  }

  @override
  String get otpErrorInvalid =>
      'அந்தக் குறியீடு சரியில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get otpErrorExpired =>
      'அந்தக் குறியீடு காலாவதியானது. புதியது ஒன்றைக் கோரவும்.';

  @override
  String get errorEnterMobile => 'உங்கள் கைபேசி எண்ணை உள்ளிடவும்.';

  @override
  String get errorInvalidMobile =>
      'செல்லுபடியாகும் இலங்கை கைபேசி எண்ணை உள்ளிடவும்.';

  @override
  String get errorEnterName => 'உங்கள் பெயரை உள்ளிடவும்.';

  @override
  String get errorOffline => 'இணைய இணைப்பு இல்லை.';

  @override
  String get errorOfflineBody =>
      'வினாக்களை ஏற்ற Smart IQ க்கு இணைப்பு தேவை. உங்கள் இணையத்தைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get errorGeneric => 'ஏதோ தவறு நடந்தது.';

  @override
  String get greetingMorning => 'காலை வணக்கம்';

  @override
  String get greetingAfternoon => 'மதிய வணக்கம்';

  @override
  String get greetingEvening => 'மாலை வணக்கம்';

  @override
  String get statStreak => 'தொடர்ச்சி';

  @override
  String get statReadiness => 'தயார்நிலை';

  @override
  String get statExamIn => 'தேர்வுக்கு';

  @override
  String statDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count நாட்கள்',
      one: '1 நாள்',
    );
    return '$_temp0';
  }

  @override
  String statDaysShort(int count) {
    return '$count நா';
  }

  @override
  String get statNoExamDate => 'அமைக்கவில்லை';

  @override
  String quotaQuestionsToday(String tier) {
    return '$tier · இன்றைய வினாக்கள்';
  }

  @override
  String quotaUsedOf(int used, String total) {
    return 'இன்று $total இல் $used பயன்படுத்தப்பட்டது';
  }

  @override
  String get quotaLeft => 'மீதம்';

  @override
  String get quotaUnlimited => 'வரம்பற்றது';

  @override
  String get quotaResetsAt => 'நள்ளிரவில் (SLT) மீள்அமைக்கப்படும்';

  @override
  String get dailyChallengeLabel => 'தினசரி சவால்';

  @override
  String get dailyChallengeTitle => 'இன்றைய 10 வினாத் தொகுப்பு';

  @override
  String get dailyChallengeBlurb =>
      'கலவையான பொது அறிவு, திறனறி மற்றும் நடப்பு நிகழ்வுகள் · 00:00 SLT இல் மீள்அமைக்கப்படும்';

  @override
  String get dailyChallengeStart => 'சவாலைத் தொடங்கு';

  @override
  String get dailyChallengeDone => 'இன்று முடிக்கப்பட்டது';

  @override
  String get homePracticeByCategory => 'பிரிவு வாரியான பயிற்சி';

  @override
  String get homePerformance => 'செயல்திறன்';

  @override
  String get homeWeakAreasEmpty =>
      'நீங்கள் எங்கே பலவீனமாக இருக்கிறீர்கள் என்பதைக் காண ஒரு பயிற்சி அமர்வை முடிக்கவும்.';

  @override
  String get practiceModeQuick => 'விரைவு';

  @override
  String get practiceModeQuickMeta => '10 வினாக்கள்';

  @override
  String get practiceModeTimed => 'நேர வரம்பு';

  @override
  String get practiceModeTimedMeta => 'கடிகாரத்திற்கு எதிராக';

  @override
  String get practiceModeSpeed => 'வேகப் பயிற்சி';

  @override
  String get practiceModeSpeedMeta => 'குறைந்த நேரம்';

  @override
  String get practiceModeAdaptive => 'தகவமைவு';

  @override
  String get practiceModeAdaptiveMeta => 'உங்கள் நிலைக்கு ஏற்ப';

  @override
  String get practiceSubTopics => 'துணைத் தலைப்புகள்';

  @override
  String get practiceStart => 'பயிற்சியைத் தொடங்கு';

  @override
  String get practiceNoSubTopics =>
      'இந்தப் பிரிவில் துணைத் தலைப்புகள் இன்னும் வெளியிடப்படவில்லை.';

  @override
  String lockedTitle(String feature) {
    return '$feature உங்கள் திட்டத்தில் இல்லை';
  }

  @override
  String lockedBody(String tier) {
    return 'அதைத் திறக்க மேம்படுத்தவும். உங்கள் தற்போதைய திட்டம் $tier.';
  }

  @override
  String get quizCheckAnswer => 'விடையைச் சரிபார்';

  @override
  String get quizNextQuestion => 'அடுத்த வினா';

  @override
  String get quizFinish => 'முடி';

  @override
  String get quizVerdictCorrect => 'சரி';

  @override
  String get quizVerdictIncorrect => 'சரியில்லை';

  @override
  String get quizExplainWithAi => 'AI ஆசிரியருடன் விளக்கு';

  @override
  String get quizBookmark => 'புத்தகக்குறி';

  @override
  String get quizBookmarked => 'குறிக்கப்பட்டது';

  @override
  String quizCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get quizQuitTitle => 'இந்த அமர்வை விட்டு வெளியேறவா?';

  @override
  String get quizQuitBody =>
      'இதுவரையான உங்கள் முன்னேற்றம் சேமிக்கப்படும், மீண்டும் தொடரலாம்.';

  @override
  String get quizQuitConfirm => 'வெளியேறு';

  @override
  String get quizQuitStay => 'பயிற்சியைத் தொடர்';

  @override
  String get quizDifficultyEasy => 'எளிது';

  @override
  String get quizDifficultyMedium => 'நடுத்தரம்';

  @override
  String get quizDifficultyHard => 'கடினம்';

  @override
  String get quizImageFailed =>
      'இந்த வினாவின் படத்தை ஏற்ற முடியவில்லை, எனவே அது தவிர்க்கப்பட்டது.';

  @override
  String get quizTapToZoom => 'பெரிதாக்கத் தட்டவும்';

  @override
  String get resultsThisSession => 'இந்த அமர்வு';

  @override
  String resultsScoreLine(int correct, int total) {
    return '$total இல் $correct சரி';
  }

  @override
  String get resultsShowing => 'காட்டுவது';

  @override
  String get resultsRangeSession => 'அமர்வு';

  @override
  String get resultsRangeToday => 'இன்று';

  @override
  String get resultsRangeWeek => '7 நாட்கள்';

  @override
  String get resultsStatCorrect => 'சரி';

  @override
  String get resultsStatWrong => 'தவறு';

  @override
  String get resultsStatSkipped => 'தவிர்த்தது';

  @override
  String get resultsStatTime => 'சராசரி நேரம்';

  @override
  String get resultsBreakdown => 'துணைத் தலைப்பு வாரியான துல்லியம்';

  @override
  String get resultsNoBreakdown =>
      'இன்று இன்னும் விடைகள் இல்லை. துணைத் தலைப்புத் துல்லியத்தைக் காண ஒரு பயிற்சி அமர்வை முடிக்கவும்.';

  @override
  String get resultsHistoryTitle => 'உங்கள் சொந்த முந்தைய அமர்வுகளுடன்';

  @override
  String get resultsPrivacyNote =>
      'முன்னேற்றம் தனிப்பட்டது. இங்கு எதுவும் உங்களை மற்றொரு பயனருடன் ஒப்பிடவில்லை.';

  @override
  String get resultsDrillWrong => 'தவறான விடைகளைப் பயிற்சி செய்';

  @override
  String get resultsHome => 'முகப்பு';

  @override
  String get tutorTitle => 'AI ஆசிரியர்';

  @override
  String get tutorNewThread => 'புதிய உரையாடல்';

  @override
  String get tutorInputHint => 'சிங்களம், தமிழ் அல்லது ஆங்கிலத்தில் கேளுங்கள்';

  @override
  String tutorQuotaLine(int used, String total) {
    return 'இன்று $total இல் $used பயன்படுத்தப்பட்டது';
  }

  @override
  String get tutorExhaustedTitle => 'தினசரி AI செய்திகள் முடிந்தன';

  @override
  String tutorExhaustedBody(String total) {
    return 'உங்கள் திட்டம் நாளொன்றுக்கு $total செய்திகளை அனுமதிக்கிறது. மேலும் தேவைப்பட்டால் மேம்படுத்தவும், அல்லது நள்ளிரவுக்குப் பிறகு வரவும்.';
  }

  @override
  String get tutorEmptyTitle => 'எதையும் கேளுங்கள்';

  @override
  String get tutorEmptyBody =>
      'தவறான விடையை விளக்கச் சொல்லுங்கள், குறிப்பு கேளுங்கள், அல்லது பயிற்சித் தொகுப்பு கோருங்கள் — சிங்களம், தமிழ் அல்லது ஆங்கிலத்தில்.';

  @override
  String get tutorThinking => 'சிந்திக்கிறது…';

  @override
  String get tutorError =>
      'ஆசிரியரைத் தொடர்பு கொள்ள முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get profileTitle => 'சுயவிவரம்';

  @override
  String get profileVerified => 'உறுதிப்படுத்தப்பட்டது';

  @override
  String get profileCurrentPlan => 'தற்போதைய திட்டம்';

  @override
  String get profileStudyMaterial => 'உங்கள் படிப்புப் பொருள்';

  @override
  String get profileStatAnswered => 'விடையளித்தது';

  @override
  String get profileStatAccuracy => 'துல்லியம்';

  @override
  String get profileStatSessions => 'அமர்வுகள்';

  @override
  String get profileRowBookmarks => 'புத்தகக்குறிகள்';

  @override
  String get profileRowBookmarksMeta => 'நீங்கள் சேமித்த வினாக்கள்';

  @override
  String get profileRowWrongBank => 'தவறான விடை வங்கி';

  @override
  String get profileRowWrongBankMeta =>
      'இடைவெளி மீள்பயிற்சியால் மீண்டும் வரும்';

  @override
  String get profileRowMastery => 'தலைப்புத் தேர்ச்சி';

  @override
  String get profileRowMasteryMeta => 'துணைத் தலைப்புக்கான துல்லியம்';

  @override
  String get profileRowSettings => 'அமைப்புகள்';

  @override
  String get profileRowSettingsMeta => 'மொழி, தோற்றம் மற்றும் கணக்கு';

  @override
  String get settingsTitle => 'அமைப்புகள்';

  @override
  String get settingsLanguage => 'மொழி';

  @override
  String get settingsTheme => 'தோற்றம்';

  @override
  String get settingsThemeLight => 'ஒளி';

  @override
  String get settingsThemeDark => 'இருள்';

  @override
  String get settingsThemeSystem => 'அமைப்பு';

  @override
  String get settingsThemeNote =>
      'முதல் தொடக்கத்தில் அமைப்பு இயல்பானது, முதல் சட்டகத்திற்கு முன் பயன்படுத்தப்படும்.';

  @override
  String get settingsLegal => 'சட்டபூர்வம்';

  @override
  String get settingsTerms => 'விதிமுறைகளும் நிபந்தனைகளும்';

  @override
  String get settingsTermsMeta => 'சந்தா, கட்டணம் மற்றும் தரவுப் பயன்பாடு';

  @override
  String get settingsAccount => 'கணக்கு';

  @override
  String get settingsDevices => 'செயலில் உள்ள சாதனங்கள்';

  @override
  String get settingsDevicesMeta => 'மற்ற சாதனங்களிலிருந்து வெளியேறு';

  @override
  String get settingsNotifications => 'அறிவிப்புகள்';

  @override
  String get settingsExportData => 'என் தரவை ஏற்றுமதி செய்';

  @override
  String get settingsDeleteAccount => 'கணக்கை நீக்கு';

  @override
  String get settingsDeleteConfirmTitle => 'உங்கள் கணக்கை நீக்கவா?';

  @override
  String get settingsDeleteConfirmBody =>
      'இது உங்கள் சுயவிவரம், முன்னேற்றம் மற்றும் உரையாடல் வரலாற்றை நிரந்தரமாக நீக்கும். இதை மீட்டெடுக்க முடியாது.';

  @override
  String get settingsSignOut => 'வெளியேறு';

  @override
  String get notificationsTitle => 'அறிவிப்புகள்';

  @override
  String get notificationsMarkAllRead => 'அனைத்தையும் படித்ததாகக் குறி';

  @override
  String get notificationsEmpty => 'இப்போது புதிதாக எதுவும் இல்லை.';

  @override
  String get notificationPrefDaily => 'தினசரி சவால்';

  @override
  String get notificationPrefStreak => 'தொடர்ச்சி நினைவூட்டல்கள்';

  @override
  String get notificationPrefDigest => 'நடப்பு நிகழ்வுச் சுருக்கம்';

  @override
  String get notificationPrefBilling => 'சந்தா மற்றும் கட்டணம்';

  @override
  String get notificationPrefInactivity =>
      'நீங்கள் விலகி இருக்கும்போது நினைவூட்டல்கள்';

  @override
  String get navHome => 'முகப்பு';

  @override
  String get navPractice => 'பயிற்சி';

  @override
  String get navTutor => 'ஆசிரியர்';

  @override
  String get navProfile => 'சுயவிவரம்';

  @override
  String get planSheetTitle => 'உங்கள் திட்டத்தைத் தேர்வுசெய்';

  @override
  String get planSheetBlurb =>
      'Basic க்கு தினசரி தொலைத்தொடர்புக் கட்டணம், Pro மற்றும் Pro+ க்கு அட்டைக் கட்டணம். முதல் நாளிலிருந்தே கட்டணம் தொடங்கும் — இலவச சோதனை இல்லை.';

  @override
  String get planCurrent => 'தற்போதைய';

  @override
  String get tierFree => 'இலவசம்';

  @override
  String get tierBasic => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String get tierProPlus => 'Pro+';

  @override
  String get tierFreeBlurb =>
      'கட்டணம் தோல்வியடைந்தது அல்லது இல்லை. நாளொன்றுக்கு இரண்டு வினாக்கள், இரண்டு AI செய்திகள் — செயலி நன்றாக இருப்பதை நினைவில் வைக்கப் போதுமானது, தயாராகப் போதாது.';

  @override
  String get tierBasicBlurb =>
      'தினசரி தொலைத்தொடர்புக் கட்டணம். தினசரி சவால், நாளொன்றுக்கு 50 வினாக்கள், 10 AI செய்திகள், மாதம் 2 மாதிரித் தேர்வுகள்.';

  @override
  String get tierProBlurb =>
      'மாதாந்திர அட்டைக் கட்டணம். தகவமைவு சிரமம், படிப்புத் திட்டம், வேகப் பயிற்சிகள், 90 நாள் உரையாடல் வரலாறு.';

  @override
  String get tierProPlusBlurb =>
      'அனைத்தும் அதிகபட்ச வரம்புகளில்: வரம்பற்ற பயிற்சி, வரம்பற்ற மாதிரித் தேர்வுகள், வரம்பற்ற உரையாடல் வரலாறு.';

  @override
  String planPriceDaily(String amount) {
    return 'ரூ. $amount/நாள்';
  }

  @override
  String planPriceMonthly(String amount) {
    return 'ரூ. $amount/மாதம்';
  }

  @override
  String get planPriceFree => 'இலவசம்';

  @override
  String get termsTitle => 'விதிமுறைகளும் நிபந்தனைகளும்';

  @override
  String termsUpdated(String date) {
    return 'கடைசியாகப் புதுப்பிக்கப்பட்டது $date';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSinhala => 'සිංහල';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get loadingEntitlement => 'உங்கள் சந்தாவைச் சரிபார்க்கிறது…';

  @override
  String get loading => 'ஏற்றுகிறது…';
}
