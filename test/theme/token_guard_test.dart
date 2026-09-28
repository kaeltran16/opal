import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _annotation = 'kept literal';

final _rawColor = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');
final _rawRadius = RegExp(r'BorderRadius\.circular\(\s*[0-9]');

/// `path:line` for every raw colour or radius in `lib/` outside the theme
/// that is not annotated on the same line or the line above.
List<String> _offenders() {
  final offenders = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
      .where((p) => !p.startsWith('lib/theme/'))
      .toList()
    ..sort();
  for (final path in files) {
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

void main() {
  test('lib has no raw Color(0x...) or numeric BorderRadius.circular outside lib/theme', () {
    final offenders = _offenders();
    expect(
      offenders,
      isEmpty,
      reason: 'use a theme token, or annotate with "$_annotation: <why>" '
          'on the same line or the line above:\n${offenders.join('\n')}',
    );
  });
}
