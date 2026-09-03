import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opal/controllers/pal_suggestions_controller.dart';
import 'package:opal/screens/pal/pal_composer_screen.dart';
import 'package:opal/services/pal/pal_service.dart';
import 'package:opal/theme/theme.dart';

/// One of the static fallback labels, used to assert the fallback is (or isn't)
/// on screen. Kept in sync with `_CompactBody._starters`.
const _staticLabel = 'Verve coffee, \$5';

/// The composer sheet with its suggestions seam driven by [suggestions].
Widget _app(FutureOr<List<PalSuggestion>> Function() suggestions) {
  final colors = AppColors.light(AppAccent.blue);
  return ProviderScope(
    overrides: [
      palSuggestionsProvider(SuggestionSurface.composer)
          .overrideWith((ref) async => suggestions()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: const Scaffold(body: PalComposerSheet()),
    ),
  );
}

void main() {
  testWidgets('composer renders Pal-provided starter labels when present', (tester) async {
    await tester.pumpWidget(_app(() => const [
          PalSuggestion(
              label: 'Pal-made coffee, \$4',
              icon: 'cup.and.saucer.fill',
              colorToken: 'money'),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Pal-made coffee, \$4'), findsOneWidget);
  });

  testWidgets('shows a skeleton — not the fallback — while suggestions load', (tester) async {
    final pending = Completer<List<PalSuggestion>>();
    addTearDown(() => pending.complete(const []));

    await tester.pumpWidget(_app(() => pending.future));
    await tester.pump();

    expect(find.byKey(const Key('starter-skeleton')), findsOneWidget,
        reason: 'loading needs its own signal');
    expect(find.text(_staticLabel), findsNothing,
        reason: 'the fallback must not masquerade as a loaded suggestion');
  });

  testWidgets('falls back to the static starters when Pal returns nothing', (tester) async {
    await tester.pumpWidget(_app(() => const <PalSuggestion>[]));
    await tester.pumpAndSettle();

    expect(find.text(_staticLabel), findsOneWidget);
    expect(find.byKey(const Key('starter-skeleton')), findsNothing);
  });
}
