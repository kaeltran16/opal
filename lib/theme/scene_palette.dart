import 'package:flutter/material.dart';

/// The three moods of Today's time-of-day landscape.
enum DayPhase { morning, afternoon, evening }

/// Colours of one landscape: a vertical sky gradient, a sun glow and three
/// hill layers from the horizon forward.
@immutable
class ScenePalette {
  const ScenePalette({
    required this.sky,
    required this.skyStops,
    required this.sun,
    required this.sunCenter,
    required this.far,
    required this.mid,
    required this.near,
  });

  final List<Color> sky;
  final List<double> skyStops;
  // the glow's peak colour; it fades to transparent at its edge.
  final Color sun;
  final Alignment sunCenter;
  final Color far, mid, near;
}

// the prototype positions a 150px sun by its top-left corner on a 390 by 380
// scene; an alignment keeps the same centre at any scene size.
const double _sceneWidth = 390;
const double _sceneHeight = 380;
const double _sunRadius = 75;

Alignment _sunAt(double left, double top) => Alignment(
      (left + _sunRadius) / _sceneWidth * 2 - 1,
      (top + _sunRadius) / _sceneHeight * 2 - 1,
    );

final Alignment _morningSun = _sunAt(-10, 178);
final Alignment _afternoonSun = _sunAt(262, -40);
final Alignment _eveningSun = _sunAt(236, 186);

const List<double> _morningStops = [0, 0.5, 0.88, 1];
const List<double> _afternoonStops = [0, 0.55, 1];
const List<double> _eveningStops = [0, 0.5, 0.9, 1];

/// The palette for [phase] in [brightness]. Dark comes from the approved
/// prototype. Light keeps the same moods in pale warm tones that fade into the
/// light `bg`; `ink` holds 4.5:1 on every sky stop and hill (contrast_test).
ScenePalette scenePalette(DayPhase phase, Brightness brightness) =>
    brightness == Brightness.dark ? _dark(phase) : _light(phase);

ScenePalette _dark(DayPhase phase) => switch (phase) {
      DayPhase.morning => ScenePalette(
          sky: const [
            Color(0xFF16202E),
            Color(0xFF24303F),
            Color(0xFF4A3F42),
            Color(0xFF5A4640),
          ],
          skyStops: _morningStops,
          sun: const Color.fromRGBO(255, 214, 170, 0.34),
          sunCenter: _morningSun,
          far: const Color(0xFF22303F),
          mid: const Color(0xFF1A252F),
          near: const Color(0xFF141B22),
        ),
      DayPhase.afternoon => ScenePalette(
          sky: const [Color(0xFF1A2F49), Color(0xFF223C56), Color(0xFF263F50)],
          skyStops: _afternoonStops,
          sun: const Color.fromRGBO(190, 215, 240, 0.30),
          sunCenter: _afternoonSun,
          far: const Color(0xFF1F3447),
          mid: const Color(0xFF192936),
          near: const Color(0xFF141C23),
        ),
      DayPhase.evening => ScenePalette(
          sky: const [
            Color(0xFF25203A),
            Color(0xFF3D2C45),
            Color(0xFF6B4340),
            Color(0xFF74493C),
          ],
          skyStops: _eveningStops,
          sun: const Color.fromRGBO(255, 170, 110, 0.32),
          sunCenter: _eveningSun,
          far: const Color(0xFF2A2338),
          mid: const Color(0xFF1F1B2A),
          near: const Color(0xFF16151D),
        ),
    };

ScenePalette _light(DayPhase phase) => switch (phase) {
      DayPhase.morning => ScenePalette(
          sky: const [
            Color(0xFFDCE3EA),
            Color(0xFFEADFD8),
            Color(0xFFF5DDC8),
            Color(0xFFF7D9BF),
          ],
          skyStops: _morningStops,
          sun: const Color.fromRGBO(255, 200, 140, 0.34),
          sunCenter: _morningSun,
          far: const Color(0xFFE3D5C8),
          mid: const Color(0xFFEBDFD2),
          near: const Color(0xFFF2E9DD),
        ),
      DayPhase.afternoon => ScenePalette(
          sky: const [Color(0xFFCFE0EE), Color(0xFFDDE7EC), Color(0xFFECEBE2)],
          skyStops: _afternoonStops,
          sun: const Color.fromRGBO(255, 244, 214, 0.30),
          sunCenter: _afternoonSun,
          far: const Color(0xFFD9DFD6),
          mid: const Color(0xFFE6E4D8),
          near: const Color(0xFFF0EADE),
        ),
      DayPhase.evening => ScenePalette(
          sky: const [
            Color(0xFFDAD3E3),
            Color(0xFFE8D3D6),
            Color(0xFFF3CDB8),
            Color(0xFFF5C7A8),
          ],
          skyStops: _eveningStops,
          sun: const Color.fromRGBO(255, 160, 100, 0.32),
          sunCenter: _eveningSun,
          far: const Color(0xFFDDCFD3),
          mid: const Color(0xFFE9DCD6),
          near: const Color(0xFFF2E7DD),
        ),
    };
