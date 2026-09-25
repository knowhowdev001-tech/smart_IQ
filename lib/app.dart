import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_scale.dart';
import 'core/theme/app_theme.dart';
import 'data/push/push_service.dart';
import 'domain/enums.dart';
import 'l10n/generated/app_localizations.dart';

class SmartIqApp extends ConsumerStatefulWidget {
  const SmartIqApp({super.key});

  @override
  ConsumerState<SmartIqApp> createState() => _SmartIqAppState();
}

class _SmartIqAppState extends ConsumerState<SmartIqApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // PRD 7.3 asks the charging rail on every open, and coming back from the
    // background is an open too: someone who unsubscribed by SMS, or whose
    // daily charge failed, must not keep their tier until a cold start. The
    // repository's one-hour debounce keeps a quick app switch from costing a
    // round trip; a signed-out controller ignores the call.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(entitlementProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(routerProvider);
    ref.watch(pushBootstrapProvider);

    return MaterialApp.router(
      title: 'Smart IQ',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Read synchronously from disk before runApp, so the very first frame
      // is already in the right theme (PRD 6.9).
      themeMode: settings.theme.mode,
      locale: settings.language.locale,
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      localizationsDelegates: AppL10n.localizationsDelegates,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayFor(brightness),
          // ResponsiveScope publishes the device metrics and clamps the
          // platform text scale, so it must wrap every route rather than
          // each screen doing it for itself.
          child: ResponsiveScope(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Convenience accessor so screens read strings as `context.l10n.navHome`.
extension L10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);

  AppLanguage get language =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);
}
