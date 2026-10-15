import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// riverpod_generator stamps each provider's `.g.dart` with the sha1 of its
/// declaration's source. A provider edited without rerunning build_runner keeps
/// the old stamp, and the next run that regenerates finds a diff it did not
/// cause, so this recomputes every stamp the way the generator does.
final _stamp = RegExp(r"String _\$(\w+)Hash\(\) =>\s*r'([0-9a-f]{40})'");
const _annotations = {'riverpod', 'Riverpod'};

bool _isProvider(CompilationUnitMember decl) =>
    decl.metadata.any((a) => _annotations.contains(a.name.name));

String _stampName(CompilationUnitMember decl) {
  final name = switch (decl) {
    FunctionDeclaration(:final name) || ClassDeclaration(:final name) => name.lexeme,
    _ => throw StateError('unexpected provider declaration: ${decl.runtimeType}'),
  };
  return name[0].toLowerCase() + name.substring(1);
}

void main() {
  test('every riverpod provider stamp matches its source', () {
    final stale = <String>[];
    final unmatched = <String>[];
    final generated = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.g.dart'));
    var checked = 0;
    for (final gen in generated) {
      final stamps = {
        for (final m in _stamp.allMatches(gen.readAsStringSync())) m[1]!: m[2]!,
      };
      if (stamps.isEmpty) continue;
      final source = gen.path.replaceFirst(RegExp(r'\.g\.dart$'), '.dart');
      final unit = parseString(content: File(source).readAsStringSync(), path: source).unit;
      for (final decl in unit.declarations.where(_isProvider)) {
        final name = _stampName(decl);
        final stamp = stamps.remove(name);
        checked++;
        if (stamp != sha1.convert(utf8.encode(decl.toSource())).toString()) {
          stale.add('$source: $name');
        }
      }
      unmatched.addAll(stamps.keys.map((name) => '$source: $name'));
    }

    expect(checked, greaterThan(0), reason: 'found no riverpod providers under lib/');
    expect(unmatched, isEmpty, reason: 'stamps with no provider declaration');
    expect(stale, isEmpty,
        reason: 'stale codegen: run `dart run build_runner build --delete-conflicting-outputs`');
  });
}
