import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/landing_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/practice/presentation/practice_hub_screen.dart';
import '../../features/practice/presentation/practice_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/quiz/presentation/quiz_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/tutor/presentation/tutor_screen.dart';
import '../providers/app_providers.dart';

abstract final class Routes {
  static const landing = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';

  static const home = '/home';
  static const practiceHub = '/practice';
  static const tutor = '/tutor';
  static const profile = '/profile';

  static const practiceCategory = '/practice/category';
  static const quiz = '/quiz';
  static const results = '/results';
  static const notifications = '/notifications';
  static const settings = '/settings';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.landing,
    // The signed-in check gates the whole authenticated tree. A user who has
    // verified but not yet created a profile cannot reach the app at all
    // (PRD 6.1), so that case redirects to profile setup rather than home.
    redirect: (context, state) {
      final profile = ref.read(profileProvider);
      final signedIn = profile.valueOrNull != null;
      final path = state.matchedLocation;

      const authRoutes = {
        Routes.landing,
        Routes.login,
        Routes.signup,
        Routes.otp,
        Routes.profileSetup,
      };
      final inAuthFlow = authRoutes.contains(path);

      if (!signedIn && !inAuthFlow) return Routes.landing;
      if (signedIn && inAuthFlow && path != Routes.profileSetup) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (context, state) => OtpScreen(
          msisdn: state.uri.queryParameters['msisdn'] ?? '',
          isSignup: state.uri.queryParameters['signup'] == '1',
        ),
      ),
      GoRoute(
        path: Routes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // The four bottom-nav destinations share one shell so the bar stays
      // put and each tab keeps its own navigation stack.
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.practiceHub,
                builder: (context, state) => const PracticeHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tutor,
                builder: (context, state) => const TutorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen routes above the shell: they cover the bottom bar, which
      // is what the design shows for a running quiz.
      GoRoute(
        path: Routes.practiceCategory,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => PracticeScreen(
          categoryKey: state.uri.queryParameters['category'] ?? 'iq',
        ),
      ),
      GoRoute(
        path: Routes.quiz,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: Routes.results,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
