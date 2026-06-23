import 'package:flutter/material.dart';

const List<String> moodWords = [
  'Very unpleasant', 'Unpleasant', 'Slightly unpleasant',
  'Neutral', 'Slightly pleasant', 'Pleasant', 'Very pleasant',
];

const List<String> moodTags = [
  'Calm', 'Content', 'Tired', 'Anxious', 'Stressed',
  'Energized', 'Low', 'Grateful', 'Restless', 'Focused',
];

/// The descriptive word for a 0..1 pleasantness [t] (7 evenly-spaced stops).
String moodWord(double t) =>
    moodWords[(t.clamp(0.0, 1.0) * 6).round().clamp(0, 6)];

/// "432" -> "7h 12m", "420" -> "7h", "18" -> "18m".
String hm(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "432" -> "7h12", "420" -> "7h".
String hmShort(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Cool->warm arc through the mood teal: muted blue -> teal -> calm honey. Dark
/// mode lifts each stop. [t] in [0,1].
Color moodColor(double t, bool dark) {
  final stops = dark
      ? const [
          [120, 138, 178],
          [86, 194, 218],
          [226, 190, 122]
        ]
      : const [
          [100, 120, 166],
          [47, 166, 188],
          [206, 166, 96]
        ];
  final c = t.clamp(0.0, 1.0);
  int lerp(int a, int b, double f) => (a + (b - a) * f).round();
  Color mix(List<int> a, List<int> b, double f) =>
      Color.fromARGB(255, lerp(a[0], b[0], f), lerp(a[1], b[1], f), lerp(a[2], b[2], f));
  return c <= 0.5
      ? mix(stops[0], stops[1], c / 0.5)
      : mix(stops[1], stops[2], (c - 0.5) / 0.5);
}
