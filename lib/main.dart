import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/app_providers.dart';
import 'core/settings/app_settings.dart';
import 'data/auth/session_refresher.dart';
import 'data/auth/session_store.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read before the first frame so the theme and language
  // are already correct when it paints. PRD 6.9 forbids a flash of the
  // wrong theme on cold start, and that is only achievable by resolving
  // this ahead of runApp rather than inside a FutureBuilder.
  final prefs = await SharedPreferences.getInstance();

  // The session is read before the first frame for the same reason the
  // preferences are: the router decides between the landing screen and home
  // on whether there is a token, and resolving that after the first paint
  // would show a signed-in user the landing screen for a frame.
  final sessions = SessionStore();

  if (!SupabaseConfig.useMockBackend) {
    await sessions.restore();

    // Renews the hour-long access token in place, so a returning user goes
    // straight to home instead of being asked for an OTP again (PRD 6.1).
    final refresher = SessionRefresher(sessions: sessions);
    sessions.attachRefresher(refresher.refresh);

    // `accessToken` puts our own token on every request and disables
    // Supabase Auth entirely, which is exactly the arrangement PRD 4.4 asks
    // for: identity is our `users` table, and the token minting happens in
    // the OTP Edge Function.
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      accessToken: sessions.freshAccessToken,
    );

    // Push only (PRD 6.8). A failure here disables push, never the app.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('firebase init failed, push disabled: $error');
    }
  }

  // The app is portrait-only. The design is a single-column phone layout,
  // and landscape would stretch it without adding anything.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Draw behind the system bars so the mint header runs under the status
  // bar the way the design shows it.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStoreProvider.overrideWithValue(sessions),
        backendReadyProvider.overrideWithValue(!SupabaseConfig.useMockBackend),
      ],
      child: const SmartIqApp(),
    ),
  );
}
