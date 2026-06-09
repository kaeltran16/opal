import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/home_shell.dart';

void main() => runApp(const LoopApp());

class LoopApp extends StatefulWidget {
  const LoopApp({super.key});

  @override
  State<LoopApp> createState() => _LoopAppState();
}

class _LoopAppState extends State<LoopApp> {
  Brightness _brightness = Brightness.light;
  AppAccent _accent = AppAccent.blue;

  ThemeData _buildTheme() {
    final colors = _brightness == Brightness.dark
        ? AppColors.dark(_accent)
        : AppColors.light(_accent);
    return ThemeData(
      useMaterial3: true,
      brightness: _brightness,
      scaffoldBackgroundColor: colors.bg,
      fontFamily: null, // resolves to SF on iOS; system fallback elsewhere
      extensions: [colors],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loop',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: HomeShell(
        brightness: _brightness,
        accent: _accent,
        onBrightness: (b) => setState(() => _brightness = b),
        onAccent: (a) => setState(() => _accent = a),
      ),
    );
  }
}
