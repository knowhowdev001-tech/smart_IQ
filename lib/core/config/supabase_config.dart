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
  /// Off for now: the question bank holds placeholder content, and the free
  /// tier it is served under caps a set at two questions, which makes the app
  /// awkward to demonstrate. With this off, questions, progress and quota all
  /// come from the in-memory sample content instead, while accounts, profiles
  /// and notifications stay on the real backend.
  ///
  /// The server side is built and tested either way (migration 0021 and the
  /// three Supabase repositories), so turning it on is this flag alone:
  /// `--dart-define=PRACTICE_FROM_BACKEND=true`.
  static const bool practiceFromBackend = bool.fromEnvironment(
    'PRACTICE_FROM_BACKEND',
  );

  /// True when the app should talk to Supabase at all. Set
  /// `--dart-define=USE_MOCK_BACKEND=true` to run the in-memory repositories
  /// instead, which is how the UI can still be worked on offline.
  static const bool useMockBackend = bool.fromEnvironment(
    'USE_MOCK_BACKEND',
  );
}
