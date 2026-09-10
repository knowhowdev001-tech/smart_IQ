import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/content.dart';
import '../../domain/models/localized_text.dart';
import '../../domain/models/user_profile.dart';

/// Seed content standing in for the Supabase question bank.
///
/// This mirrors the content shape the backend will serve — three languages
/// on every stem, option and explanation — so the screens are exercised
/// against realistic data. It is replaced wholesale by the Supabase
/// repositories; nothing outside `data/mock` refers to it.
abstract final class MockContent {
  static final categories = <Category>[
    Category(
      id: 'cat-gk',
      key: 'gk',
      name: const LocalizedText(
        en: 'General Knowledge',
        si: 'සාමාන්‍ය දැනීම',
        ta: 'பொது அறிவு',
      ),
      meta: const LocalizedText(
        en: '8 topics · 1,240 questions',
        si: 'මාතෘකා 8 · ප්‍රශ්න 1,240',
        ta: '8 தலைப்புகள் · 1,240 வினாக்கள்',
      ),
      sortOrder: 0,
      questionCount: 1240,
    ),
    Category(
      id: 'cat-ca',
      key: 'ca',
      name: const LocalizedText(
        en: 'Current Affairs',
        si: 'තත්කාලීන කරුණු',
        ta: 'நடப்பு நிகழ்வுகள்',
      ),
      meta: const LocalizedText(
        en: 'Daily · weekly · monthly',
        si: 'දෛනික · සතිපතා · මාසික',
        ta: 'தினசரி · வாராந்திர · மாதாந்திர',
      ),
      sortOrder: 1,
      questionCount: 320,
    ),
    Category(
      id: 'cat-iq',
      key: 'iq',
      name: const LocalizedText(
        en: 'IQ / Aptitude',
        si: 'බුද්ධි පරීක්ෂණ',
        ta: 'திறனறி',
      ),
      meta: const LocalizedText(
        en: '5 families · 30 sub-topics',
        si: 'කුල 5 · උප මාතෘකා 30',
        ta: '5 குடும்பங்கள் · 30 துணைத் தலைப்புகள்',
      ),
      sortOrder: 2,
      questionCount: 3000,
    ),
    Category(
      id: 'cat-mock',
      key: 'mock',
      name: const LocalizedText(
        en: 'Mock exams',
        si: 'ආදර්ශ විභාග',
        ta: 'மாதிரித் தேர்வுகள்',
      ),
      meta: const LocalizedText(
        en: 'Timed · negative marking',
        si: 'කාල සීමිත · ඍණ ලකුණු',
        ta: 'நேர வரம்பு · எதிர்மறை மதிப்பெண்',
      ),
      sortOrder: 3,
      questionCount: 0,
    ),
  ];

  /// Tier 1 sub-topics from PRD Appendix A, with the Sinhala labels as
  /// supplied there. Tamil labels are the appendix's drafts and are flagged
  /// in that document as needing content-team review.
  static final subTopics = <String, List<SubTopic>>{
    'gk': [
      _sub('gk-history', 'gk', 'Sri Lankan history', 'ශ්‍රී ලංකා ඉතිහාසය',
          'இலங்கை வரலாறு', 72),
      _sub('gk-politics', 'gk', 'Politics and constitution',
          'දේශපාලනය හා ව්‍යවස්ථාව', 'அரசியலும் அரசியலமைப்பும்', 54),
      _sub('gk-geography', 'gk', 'Geography', 'භූගෝල විද්‍යාව',
          'புவியியல்', 81),
      _sub('gk-economy', 'gk', 'Economy', 'ආර්ථිකය', 'பொருளாதாரம்', 46),
      _sub('gk-science', 'gk', 'Science and technology',
          'විද්‍යාව හා තාක්ෂණය', 'அறிவியலும் தொழில்நுட்பமும்', 63),
      _sub('gk-sports', 'gk', 'Sports', 'ක්‍රීඩා', 'விளையாட்டு', null),
      _sub('gk-literature', 'gk', 'Literature', 'සාහිත්‍යය', 'இலக்கியம்', null),
      _sub('gk-world', 'gk', 'World affairs', 'ලෝක කටයුතු',
          'உலக விவகாரங்கள்', 58),
    ],
    'ca': [
      _sub('ca-daily', 'ca', 'Daily digest', 'දෛනික සාරාංශය',
          'தினசரிச் சுருக்கம்', null),
      _sub('ca-weekly', 'ca', 'Weekly digest', 'සතිපතා සාරාංශය',
          'வாராந்திரச் சுருக்கம்', null),
      _sub('ca-monthly', 'ca', 'Monthly compilation', 'මාසික සම්පාදනය',
          'மாதாந்திரத் தொகுப்பு', null),
    ],
    'iq': [
      _sub('iq-age', 'iq', 'Age-related problems', 'වයස් සම්බන්ධ ගැටලු',
          'வயது சார்ந்த கணக்குகள்', 68),
      _sub('iq-ratio', 'iq', 'Ratio and proportion', 'අනුපාත සම්බන්ධ ගැටලු',
          'விகிதம் சார்ந்த கணக்குகள்', 74),
      _sub('iq-speed', 'iq', 'Distance, speed and time', 'දුර වේගය කාලය',
          'தூரம், வேகம், நேரம்', 52),
      _sub('iq-direction', 'iq', 'Direction sense', 'දිශා ආශ්‍රිත ගැටලු',
          'திசை சார்ந்த கணக்குகள்', 61),
      _sub('iq-coding', 'iq', 'Coding and decoding', 'රහස් භාෂා',
          'இரகசிய மொழி', 45),
      _sub('iq-blood', 'iq', 'Blood relations', 'නෑදෑකම් ආශ්‍රිත ගැටලු',
          'உறவுமுறை சார்ந்த கணக்குகள்', 57),
      _sub('iq-calendar', 'iq', 'Calendars', 'දින දර්ශන', 'நாட்காட்டி', null),
      _sub('iq-clocks', 'iq', 'Clocks and angles', 'ඕරලෝසු හා කෝණික ගැටලු',
          'கடிகாரமும் கோணங்களும்', 38),
      // Spatial sub-topics cannot render without their diagram (PRD A.6).
      _sub('iq-triangles', 'iq', 'Counting triangles', 'ත්‍රිකෝණ ගණන සෙවීම',
          'முக்கோணங்களை எண்ணுதல்', 43, requiresImage: true),
      _sub('iq-squares', 'iq', 'Counting squares', 'සමචතුරස්‍ර ගණන සෙවීම',
          'சதுரங்களை எண்ணுதல்', null, requiresImage: true),
      _sub('iq-dice', 'iq', 'Dice problems', 'දාදු කැට ගැටලු',
          'பகடை கணக்குகள்', null, requiresImage: true),
      _sub('iq-probability', 'iq', 'Probability', 'සම්භාවිතාව',
          'நிகழ்தகவு', 66),
      _sub('iq-sets', 'iq', 'Sets and Venn diagrams', 'කුලක හා වෙන් රූප',
          'கணங்களும் வென் படங்களும்', null, requiresImage: true),
    ],
    'mock': [
      _sub('mock-full', 'mock', 'Full paper · 100 questions',
          'සම්පූර්ණ ප්‍රශ්න පත්‍රය', 'முழுத் தாள் · 100 வினாக்கள்', null),
      _sub('mock-half', 'mock', 'Half paper · 50 questions',
          'අර්ධ ප්‍රශ්න පත්‍රය', 'அரைத் தாள் · 50 வினாக்கள்', null),
    ],
  };

  static SubTopic _sub(
    String id,
    String category,
    String en,
    String si,
    String ta,
    int? mastery, {
    bool requiresImage = false,
  }) =>
      SubTopic(
        id: id,
        categoryKey: category,
        name: LocalizedText(en: en, si: si, ta: ta),
        mastery: mastery,
        requiresImage: requiresImage,
        questionCount: 40,
      );

  /// The five worked questions from the design prototype, in all three
  /// languages with full explanations.
  static final questions = <Question>[
    Question(
      id: 'q-age-1',
      subTopicId: 'iq-age',
      categoryKey: 'iq',
      difficulty: Difficulty.medium,
      categoryName: const LocalizedText(
          en: 'IQ / Aptitude', si: 'බුද්ධි පරීක්ෂණ', ta: 'திறனறி'),
      subTopicName: const LocalizedText(
        en: 'Age-related problems',
        si: 'වයස් සම්බන්ධ ගැටලු',
        ta: 'வயது சார்ந்த கணக்குகள்',
      ),
      stem: const LocalizedText(
        en: 'Kamal is four times as old as his son. In six years he will be '
            '2.5 times as old as his son. How old is Kamal now?',
        si: 'කමල් ඔහුගේ පුතාට වඩා වයසින් හතර ගුණයක් වැඩිය. වර්ෂ හයකින් ඔහු '
            'පුතාට වඩා 2.5 ගුණයක් වැඩි වේ. කමල්ගේ දැන් වයස කීයද?',
        ta: 'கமல் தன் மகனை விட நான்கு மடங்கு வயதுடையவர். ஆறு ஆண்டுகளில் அவர் '
            'தன் மகனை விட 2.5 மடங்கு வயதுடையவராக இருப்பார். கமலின் தற்போதைய '
            'வயது என்ன?',
      ),
      options: _numericOptions(['20', '24', '28', '32']),
      correctOptionId: 'opt-b',
      explanation: const LocalizedText(
        en: 'Let the son be s. Kamal = 4s. In six years 4s + 6 = 2.5(s + 6), '
            'so 4s + 6 = 2.5s + 15, 1.5s = 9, s = 6. Kamal is 24.',
        si: 'පුතාගේ වයස s නම් කමල් = 4s. වර්ෂ 6කින්: 4s + 6 = 2.5(s + 6) → '
            '1.5s = 9 → s = 6. එබැවින් කමල් වයස 24 වේ.',
        ta: 'மகனின் வயது s எனில் கமல் = 4s. ஆறு ஆண்டுகளில்: '
            '4s + 6 = 2.5(s + 6) → 1.5s = 9 → s = 6. எனவே கமலின் வயது 24.',
      ),
      shuffleOptions: false,
    ),
    Question(
      id: 'q-direction-1',
      subTopicId: 'iq-direction',
      categoryKey: 'iq',
      difficulty: Difficulty.easy,
      categoryName: const LocalizedText(
          en: 'IQ / Aptitude', si: 'බුද්ධි පරීක්ෂණ', ta: 'திறனறி'),
      subTopicName: const LocalizedText(
        en: 'Direction sense',
        si: 'දිශා ආශ්‍රිත ගැටලු',
        ta: 'திசை சார்ந்த கணக்குகள்',
      ),
      stem: const LocalizedText(
        en: 'A man walks 5 km north, turns right and walks 3 km, then turns '
            'right and walks 5 km. How far is he from his starting point?',
        si: 'මිනිසෙක් උතුරට කි.මී. 5 ගමන් කර, දකුණට හැරී කි.මී. 3 ගමන් කර, '
            'නැවත දකුණට හැරී කි.මී. 5 ගමන් කරයි. ඔහු ආරම්භක ස්ථානයේ සිට '
            'කොපමණ දුරින්ද?',
        ta: 'ஒருவர் வடக்கே 5 கி.மீ. நடந்து, வலப்புறம் திரும்பி 3 கி.மீ. '
            'நடந்து, மீண்டும் வலப்புறம் திரும்பி 5 கி.மீ. நடக்கிறார். '
            'தொடக்கப் புள்ளியிலிருந்து அவர் எவ்வளவு தூரத்தில் இருக்கிறார்?',
      ),
      options: _numericOptions(['3 km', '5 km', '8 km', '13 km']),
      correctOptionId: 'opt-a',
      explanation: const LocalizedText(
        en: 'The two 5 km legs are north then south and cancel exactly. Only '
            'the 3 km eastward leg is left, so he is 3 km east of the start.',
        si: 'කි.මී. 5 ගමන් දෙක උතුරට හා දකුණට වන බැවින් එකිනෙක අවලංගු වේ. '
            'ඉතිරි වන්නේ නැගෙනහිරට කි.මී. 3 පමණි.',
        ta: 'இரு 5 கி.மீ. பயணங்கள் வடக்கும் தெற்கும் என ஒன்றையொன்று ரத்து '
            'செய்கின்றன. மீதம் கிழக்கே 3 கி.மீ. மட்டுமே.',
      ),
      shuffleOptions: false,
    ),
    Question(
      id: 'q-triangles-1',
      subTopicId: 'iq-triangles',
      categoryKey: 'iq',
      difficulty: Difficulty.hard,
      categoryName: const LocalizedText(
          en: 'IQ / Aptitude', si: 'බුද්ධි පරීක්ෂණ', ta: 'திறனறி'),
      subTopicName: const LocalizedText(
        en: 'Counting triangles',
        si: 'ත්‍රිකෝණ ගණන සෙවීම',
        ta: 'முக்கோணங்களை எண்ணுதல்',
      ),
      stem: const LocalizedText(
        en: 'How many triangles are there in the figure below?',
        si: 'පහත රූපයේ ත්‍රිකෝණ කීයක් තිබේද?',
        ta: 'கீழே உள்ள படத்தில் எத்தனை முக்கோணங்கள் உள்ளன?',
      ),
      // The design renders this diagram as inline vector art rather than a
      // bitmap, so it stays crisp at every device scale. The path is the
      // marker the quiz screen matches on.
      stemMedia: const QuestionMedia(
        path: 'builtin:triangles',
        alt: LocalizedText(
          en: 'A large triangle divided by two lines from its apex to its '
              'base, forming three small triangles.',
          si: 'මුදුනේ සිට පාදයට රේඛා දෙකකින් බෙදුණු විශාල ත්‍රිකෝණයක්.',
          ta: 'உச்சியிலிருந்து அடிப்பகுதிக்கு இரு கோடுகளால் பிரிக்கப்பட்ட '
              'ஒரு பெரிய முக்கோணம்.',
        ),
      ),
      options: _numericOptions(['4', '5', '6', '8']),
      correctOptionId: 'opt-c',
      explanation: const LocalizedText(
        en: 'Three small triangles sit along the base. Adjacent pairs make '
            'two more, and the whole outline is the sixth. 3 + 2 + 1 = 6.',
        si: 'පාදය දිගේ කුඩා ත්‍රිකෝණ තුනක් ඇත. යාබද යුගල දෙකකින් තව දෙකක්, '
            'සම්පූර්ණ රූපය හයවැන්නයි. 3 + 2 + 1 = 6.',
        ta: 'அடிப்பகுதியில் மூன்று சிறிய முக்கோணங்கள். அடுத்தடுத்த இணைகள் '
            'இரண்டு, முழு உருவம் ஆறாவது. 3 + 2 + 1 = 6.',
      ),
      shuffleOptions: false,
    ),
    Question(
      id: 'q-history-1',
      subTopicId: 'gk-history',
      categoryKey: 'gk',
      difficulty: Difficulty.easy,
      categoryName: const LocalizedText(
          en: 'General Knowledge', si: 'සාමාන්‍ය දැනීම', ta: 'பொது அறிவு'),
      subTopicName: const LocalizedText(
        en: 'Sri Lankan history',
        si: 'ශ්‍රී ලංකා ඉතිහාසය',
        ta: 'இலங்கை வரலாறு',
      ),
      stem: const LocalizedText(
        en: 'In which year was the Kandyan Convention signed?',
        si: 'උඩරට ගිවිසුම අත්සන් කරන ලද වර්ෂය කුමක්ද?',
        ta: 'கண்டி உடன்படிக்கை கையெழுத்திடப்பட்ட ஆண்டு எது?',
      ),
      options: _numericOptions(['1802', '1815', '1818', '1832']),
      correctOptionId: 'opt-b',
      explanation: const LocalizedText(
        en: 'The Kandyan Convention was signed on 2 March 1815, ceding the '
            'Kandyan Kingdom to the British Crown.',
        si: 'උඩරට ගිවිසුම 1815 මාර්තු 2 වන දින අත්සන් කරන ලදී.',
        ta: 'கண்டி உடன்படிக்கை 1815 மார்ச் 2 அன்று கையெழுத்திடப்பட்டது.',
      ),
      shuffleOptions: false,
    ),
    Question(
      id: 'q-probability-1',
      subTopicId: 'iq-probability',
      categoryKey: 'iq',
      difficulty: Difficulty.medium,
      categoryName: const LocalizedText(
          en: 'IQ / Aptitude', si: 'බුද්ධි පරීක්ෂණ', ta: 'திறனறி'),
      subTopicName: const LocalizedText(
        en: 'Probability',
        si: 'සම්භාවිතාව',
        ta: 'நிகழ்தகவு',
      ),
      stem: const LocalizedText(
        en: 'A bag holds 4 red and 6 blue balls. One ball is drawn at random. '
            'What is the probability that it is red?',
        si: 'මල්ලක රතු බෝල 4ක් සහ නිල් බෝල 6ක් ඇත. අහඹු ලෙස එක් බෝලයක් ගනු '
            'ලැබේ. එය රතු වීමේ සම්භාවිතාව කුමක්ද?',
        ta: 'ஒரு பையில் 4 சிவப்பு மற்றும் 6 நீல பந்துகள் உள்ளன. ஒரு பந்து '
            'சமவாய்ப்பு முறையில் எடுக்கப்படுகிறது. அது சிவப்பாக இருக்கும் '
            'நிகழ்தகவு என்ன?',
      ),
      options: _numericOptions(['2/5', '3/5', '2/3', '1/2']),
      correctOptionId: 'opt-a',
      explanation: const LocalizedText(
        en: 'There are 10 balls in total and 4 are red, so '
            'P(red) = 4/10 = 2/5.',
        si: 'මුළු බෝල 10ක් අතර රතු 4ක් ඇති බැවින් P(රතු) = 4/10 = 2/5.',
        ta: 'மொத்தம் 10 பந்துகளில் 4 சிவப்பு, எனவே '
            'P(சிவப்பு) = 4/10 = 2/5.',
      ),
      shuffleOptions: false,
    ),
  ];

  /// Numeric and short-form answers are the same string in every language,
  /// which is exactly what LocalizedText.same is for.
  static List<QuestionOption> _numericOptions(List<String> values) {
    const keys = ['A', 'B', 'C', 'D'];
    const ids = ['opt-a', 'opt-b', 'opt-c', 'opt-d'];
    return [
      for (var i = 0; i < values.length; i++)
        QuestionOption(
          id: ids[i],
          optionKey: keys[i],
          text: LocalizedText.same(values[i]),
          sortOrder: i,
        ),
    ];
  }

  static List<AppNotification> notifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        kind: NotificationKind.dailyChallenge,
        title: 'Daily challenge is live',
        body: "Today's 10-question mixed set is ready. Practising keeps your "
            '12-day streak alive.',
        createdAt: now.subtract(const Duration(minutes: 8)),
        route: '/quiz/daily',
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.streak,
        title: 'Your streak breaks in 3 hours',
        body: 'Answer at least one question before midnight SLT to keep it.',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.digest,
        title: 'New current affairs digest',
        body: 'September week 1 — economy, appointments and sport.',
        createdAt: now.subtract(const Duration(days: 1)),
        route: '/practice/ca',
      ),
      AppNotification(
        id: 'n4',
        kind: NotificationKind.chargeFailed,
        title: 'Daily charge failed',
        body: 'We could not charge Rs. 10.00 from your Dialog number. You are '
            'on Free Fallback limits until the next successful charge.',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        unread: false,
      ),
      AppNotification(
        id: 'n5',
        kind: NotificationKind.inactivity,
        title: 'Three days since your last session',
        body: 'A 10-question set takes four minutes. Pick up where you left '
            'off in Ratio and proportion.',
        createdAt: now.subtract(const Duration(days: 3)),
        unread: false,
      ),
    ];
  }

  static ProgressSummary progress() => const ProgressSummary(
        streakDays: 12,
        readinessScore: 68,
        questionsAnswered: 1284,
        sessionsCompleted: 47,
        overallAccuracy: 0.71,
        recentAccuracy: [58, 64, 61, 73, 70],
        weakAreas: [
          WeakArea(
            subTopicId: 'iq-clocks',
            name: 'Clocks and angles',
            accuracy: 38,
            sampleSize: 26,
          ),
          WeakArea(
            subTopicId: 'iq-coding',
            name: 'Coding and decoding',
            accuracy: 45,
            sampleSize: 31,
          ),
          WeakArea(
            subTopicId: 'gk-economy',
            name: 'Economy',
            accuracy: 46,
            sampleSize: 40,
          ),
        ],
      );
}
