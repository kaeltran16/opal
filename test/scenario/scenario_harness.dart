import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/flush_provider_timers.dart';
import '../support/golden_harness.dart';

/// Every family name the app's sans text resolves to under test: Material's
/// default, the Cupertino system faces, and the engine's default family,
/// which a style with no family at all lands on.
const _sansFamilies = [
  'Roboto',
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.SF UI Text',
  '.SF UI Display',
  '.SF Pro Text',
  '.SF Pro Display',
  'Ahem',
  'FlutterTest',
];

const _scenarioSize = Size(390, 844);
const _scenarioPixelRatio = 2.0;
const _outEnv = 'ARC_FINAL_OUT';
const _defaultOut = 'build/scenario';

Future<void>? _fontsLoaded;

/// Loads real fonts so scenario captures show glyphs rather than Ahem blocks:
/// every family in the app's `FontManifest.json`, plus the SDK's Roboto as the
/// sans. Fonts stay registered for the whole test process, so this loads once.
Future<void> loadScenarioFonts() => _fontsLoaded ??= _loadFonts();

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadManifestFonts();
  await _loadSans();
}

Future<void> _loadManifestFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _loadSans() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is unset; run scenarios with `flutter test`');
  }
  final dir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  final faces = [
    for (final file in dir.listSync().whereType<File>())
      // the sdk ships Roboto-Regular.ttf; RobotoCondensed has no hyphen here.
      if (RegExp(r'[\\/]roboto-[a-z]+\.ttf$', caseSensitive: false).hasMatch(file.path))
        ByteData.sublistView(file.readAsBytesSync()),
  ];
  if (faces.isEmpty) {
    throw StateError('no Roboto faces in ${dir.path}');
  }
  for (final family in _sansFamilies) {
    final loader = FontLoader(family);
    for (final face in faces) {
      loader.addFont(Future.value(face));
    }
    await loader.load();
  }
}

/// Where [shot] writes: `ARC_FINAL_OUT`, or `build/scenario` when unset.
Directory get scenarioOut =>
    Directory(Platform.environment[_outEnv] ?? _defaultOut);

/// Registers a light and a dark scenario for [name], tagged `scenario`. Each
/// runs [body] under [at] on a 390 by 844 surface at device pixel ratio 2.
void scenarioTest(
  String name,
  Future<void> Function(WidgetTester tester, bool dark) body, {
  Clock? at,
}) {
  setUpAll(loadScenarioFonts);
  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('scenario: $name ($theme)', tags: 'scenario', (tester) async {
      await withClock(at ?? goldenClock, () async {
        tester.view.physicalSize = _scenarioSize * _scenarioPixelRatio;
        tester.view.devicePixelRatio = _scenarioPixelRatio;
        addTearDown(tester.view.reset);
        await body(tester, dark);
        await flushProviderTimers(tester);
      });
    });
  }
}

/// Captures the app's root repaint boundary to `<scenarioOut>/<name>.png`.
Future<void> shot(WidgetTester tester, String name) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  // encoding and file io are real async work, which the test's fake-async
  // zone never completes.
  await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('could not encode $name.png');
    }
    scenarioOut.createSync(recursive: true);
    File('${scenarioOut.path}/$name.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
  });
}
