import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controllers/providers.dart';
import 'router.dart';
import 'theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      title: 'Opal',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(settings.brightness, settings.accent),
      routerConfig: _router,
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
