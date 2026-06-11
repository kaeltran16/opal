import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controllers/providers.dart';
import 'controllers/widget_sync_controller.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

/// The root app widget: `MaterialApp.router` wired to go_router, with theme
/// driven by the persisted `AppSettingsController` (brightness + accent).
class LoopApp extends ConsumerStatefulWidget {
  const LoopApp({super.key});

  @override
  ConsumerState<LoopApp> createState() => _LoopAppState();
}

class _LoopAppState extends ConsumerState<LoopApp> {
  late final GoRouter _router = createRouter(
    // First-run gate reads the live onboarding flag on every navigation.
    isOnboardingComplete: () =>
        ref.read(settingsRepositoryProvider).onboardingComplete,
  );

  /// U25/U26 — native deep links: Siri/Spotlight AppIntents (`/entry/new`,
  /// `/move/start`) and Live-Activity / Dynamic-Island taps
  /// (`/session/:routineId`), both delivered over the `opal/intents` channel by
  /// the native bridge. No-op stream off iOS.
  StreamSubscription<String>? _deepLinkSub;
  String? _lastDeepLink;
  DateTime? _lastDeepLinkAt;

  @override
  void initState() {
    super.initState();
    final siri = ref.read(siriShortcutsServiceProvider);
    _deepLinkSub = siri.deepLinks.listen(_handleDeepLink);
    // Start the rings-widget sync loop (listens to todayState internally). iOS
    // only: the home-screen widget exists nowhere else, so there's no reason to
    // hold a live todayState subscription on other platforms.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      ref.read(widgetSyncControllerProvider);
    }
    // Donate the app shortcuts and drain any link buffered natively before we
    // were listening (a cold launch from a Siri/Spotlight tap). Best-effort.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await siri.donateShortcuts();
      final initial = await siri.consumeInitialDeepLink();
      if (initial != null) _handleDeepLink(initial);
    });
  }

  void _handleDeepLink(String path) {
    if (path.isEmpty) return;
    // A warm Siri intent both pushes the path over the channel AND re-opens the
    // app with the same `opal://` URL (forwarded by SceneDelegate), so an
    // identical path can arrive twice within a beat — swallow the duplicate.
    final now = DateTime.now();
    if (_lastDeepLink == path &&
        _lastDeepLinkAt != null &&
        now.difference(_lastDeepLinkAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastDeepLink = path;
    _lastDeepLinkAt = now;
    _router.go(path);
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    // Dark background needs light status-bar glyphs, and vice versa, or the
    // system clock/battery render invisibly against the app background.
    final overlay = settings.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: MaterialApp.router(
        title: 'Opal',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(settings.brightness, settings.accent),
        routerConfig: _router,
        // Full-screen routes above the shell (reviews, pal inbox, email, etc.)
        // render outside any Material, so without an ambient default text style
        // Flutter falls back to its yellow double-underline debug style. One
        // app-level DefaultTextStyle covers every route; Material screens still
        // get their own (inner) style.
        builder: (context, child) => DefaultTextStyle(
          style: AppFonts.sf(
              size: 17, color: context.colors.ink, letterSpacing: -0.43),
          child: child!,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness, AppAccent accent) {
    final colors = brightness == Brightness.dark
        ? AppColors.dark(accent)
        : AppColors.light(accent);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.bg,
      fontFamily: null, // resolves to SF on iOS; system fallback elsewhere
      extensions: [colors],
    );
  }
}
