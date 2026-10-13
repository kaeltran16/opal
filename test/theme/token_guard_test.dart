import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _annotation = 'kept literal';

final _rawColor = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
final _rawRadius = RegExp(r'BorderRadius\.circular\(\s*[0-9]');
// the tokens retired from lib/theme. DESIGN.md section 10. the [.] and [n]
// classes match as \. and n do, but keep this file clear of a grep for them.
final _legacy = RegExp(r'AppType\.(caption2|footnote|title1|title2|title3|large|amountLg|amount)\b'
    r'|\bc(olors)?\.(money|move|rituals|nutrition|sleep|mood)(Tint|Ink)?\b'
    r'|Elevation\.(sm|card)\b'
    r'|[.]glass(Border|Highlight)?\b'
    r'|[.]accent(Ink|Tint)?\b'
    r'|o[n]Accent'
    r'|\bsfr\('
    r'|AppText\.mono'
    r'|Radii\.(md|lg)\b');

/// Every hand-written `.dart` file in `lib/` outside the theme, sorted.
List<String> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path.replaceAll(r'\', '/'))
    .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
    .where((p) => !p.startsWith('lib/theme/'))
    .toList()
  ..sort();

/// `path:line` for every raw colour or radius in `lib/` outside the theme
/// that is not annotated on the same line or the line above.
List<String> _rawOffenders() {
  final offenders = <String>[];
  for (final path in _libFiles()) {
    final lines = File(path).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_rawColor.hasMatch(line) && !_rawRadius.hasMatch(line)) continue;
      final above = i > 0 ? lines[i - 1] : '';
      if (line.contains(_annotation) || above.contains(_annotation)) continue;
      offenders.add('$path:${i + 1}');
    }
  }
  return offenders;
}

/// `path:line` for every line in `lib/` outside the theme naming a legacy
/// token, comments included. No annotation exempts a line.
List<String> _legacyOffenders() {
  final offenders = <String>[];
  for (final path in _libFiles()) {
    final lines = File(path).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_legacy.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
    }
  }
  return offenders;
}

void main() {
  test('lib has no raw Color(0x...) or numeric BorderRadius.circular outside lib/theme', () {
    final offenders = _rawOffenders();
    expect(
      offenders,
      isEmpty,
      reason: 'use a theme token, or annotate with "$_annotation: <why>" '
          'on the same line or the line above:\n${offenders.join('\n')}',
    );
  });

  test('lib names no retired legacy token outside lib/theme, comments included', () {
    final offenders = _legacyOffenders();
    expect(
      offenders,
      isEmpty,
      reason: 'the legacy tokens are retired; use a current theme token:\n'
          '${offenders.join('\n')}',
    );
  });
}
