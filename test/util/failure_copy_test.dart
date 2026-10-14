import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _emDash = '—';

// `Couldn\'t` covers the escaped apostrophe in a single-quoted literal.
final _failureWording = RegExp(r"Couldn\\?'t|failed|unreachable|[Tt]ry again");

/// The string literals on one source line, stopping at a trailing `//`
/// comment. Escapes are kept, so `\'` stays inside its literal.
List<String> _literals(String line) {
  final literals = <String>[];
  var i = 0;
  while (i < line.length) {
    final ch = line[i];
    if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') break;
    if (ch != "'" && ch != '"') {
      i++;
      continue;
    }
    final start = ++i;
    while (i < line.length && line[i] != ch) {
      i += line[i] == r'\' ? 2 : 1;
    }
    literals.add(line.substring(start, i.clamp(start, line.length)));
    i++;
  }
  return literals;
}

/// `path:line` for every non-comment line in `lib/` with a string literal
/// that pairs an em-dash with failure wording.
List<String> _offenders() {
  final offenders = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart'))
      .toList()
    ..sort();
  for (final path in files) {
    final lines = File(path).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      final hit = _literals(line)
          .any((s) => s.contains(_emDash) && _failureWording.hasMatch(s));
      if (hit) offenders.add('$path:${i + 1}');
    }
  }
  return offenders;
}

void main() {
  test('failure copy in lib uses full stops, not an em-dash', () {
    final offenders = _offenders();
    expect(
      offenders,
      isEmpty,
      reason: 'write failure copy as short sentences, '
          'e.g. "Couldn\'t save. Try again.":\n${offenders.join('\n')}',
    );
  });
}
