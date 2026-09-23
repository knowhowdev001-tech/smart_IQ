/// Connection details for the Supabase project `Smart_IQ`.
///
/// The URL and publishable key are not secrets — they ship in every client
/// and are safe to default here so a plain `flutter run` reaches the real
/// backend. Both are still overridable at build time so a staging project
/// needs no code change:
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
/// ```
///
/// Nothing that must stay secret belongs here. The JWT signing secret, the
/// OTP pepper and the service role key exist only as Edge Function secrets,
/// which is what keeps a decompiled APK from being able to mint a session.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://glmryghkrpnmlqymsxuz.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_8XxYk1O8EWjPgjxJXa8pcg_zKQT87j8',
  );

  /// Whether practice content comes from the server.
  ///
  /// On. The question bank is seeded with placeholder content under the same
  /// taxonomy the app shows (migration 0024 and
  /// `supabase/seed/placeholder_questions.csv`), and the free tier's demo
  /// limits (migration 0025) make a real set servable. This is what puts
  /// progress, the streak, mastery, quota, bookmarks and the wrong-answer
  /// bank on the backend, where they survive a reinstall.
  ///
  /// Set `--dart-define=PRACTICE_FROM_BACKEND=false` to go back to the
  /// in-memory sample content, which is how the UI can be worked on with no
  /// server.
  static const bool practiceFromBackend = bool.fromEnvironment(
    'PRACTICE_FROM_BACKEND',
    defaultValue: true,
  );

  /// True when the app should talk to Supabase at all. Set
  /// `--dart-define=USE_MOCK_BACKEND=true` to run the in-memory repositories
  /// instead, which is how the UI can still be worked on offline.
  static const bool useMockBackend = bool.fromEnvironment(
    'USE_MOCK_BACKEND',
  );
}
