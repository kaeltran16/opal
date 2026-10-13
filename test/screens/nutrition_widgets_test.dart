import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/models/enums.dart';
import 'package:opal/models/nutrition_meal.dart';
import 'package:opal/screens/nutrition/widgets/nutrition_widgets.dart';
import 'package:opal/theme/app_colors.dart';
import 'package:opal/theme/app_type.dart';
import 'package:opal/widgets/contributor_bar.dart';

// Helper: wraps a widget in a themed ProviderScope + MaterialApp.
Widget _wrap(Widget child) {
  final colors = AppColors.light();
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [colors]),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  // ── CalRange ──────────────────────────────────────────────────────────────

  group('CalRange', () {
    testWidgets('shows the mid in score and the likely range', (tester) async {
      await tester.pumpWidget(_wrap(const CalRange(IntRange(560, 820))));

      final mid = tester.widget<Text>(find.text('690'));
      expect(mid.style?.fontSize, AppType.score.fontSize);
      expect(mid.style?.fontWeight, FontWeight.w300);
      expect(find.text('kcal, likely 560–820'), findsOneWidget);
    });

    testWidgets('uses the same mid as the meal rows', (tester) async {
      // (100+115)/2 = 107.5, which IntRange.mid rounds to 108.
      await tester.pumpWidget(_wrap(const CalRange(IntRange(100, 115))));
      expect(find.text('108'), findsOneWidget);
      expect(find.text('kcal, likely 100–115'), findsOneWidget);
    });

    testWidgets('hero sets the mid in display and groups thousands',
        (tester) async {
      await tester.pumpWidget(_wrap(const CalRange(IntRange(1000, 1200), hero: true)));
      final mid = tester.widget<Text>(find.text('1,100'));
      expect(mid.style?.fontSize, AppType.display.fontSize);
    });

    testWidgets('still accepts the size and light flags', (tester) async {
      await tester
          .pumpWidget(_wrap(const CalRange(IntRange(400, 600), size: 42, light: true)));
      expect(find.text('500'), findsOneWidget);
    });
  });

  // ── MacroSplit ────────────────────────────────────────────────────────────

  group('MacroSplit', () {
    final macros = Macros(
      protein: const IntRange(30, 50),
      carbs: const IntRange(60, 90),
      fat: const IntRange(15, 25),
    );

    testWidgets('renders a row per macro with its grams', (tester) async {
      await tester.pumpWidget(_wrap(MacroSplit(macros)));

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('30–50 g'), findsOneWidget);
      expect(find.text('60–90 g'), findsOneWidget);
      expect(find.text('15–25 g'), findsOneWidget);
    });

    testWidgets("each bar is that macro's share of the split", (tester) async {
      await tester.pumpWidget(_wrap(MacroSplit(macros)));

      final bars = tester.widgetList<ContributorBar>(find.byType(ContributorBar)).toList();
      // mids 40 + 75 + 20 = 135.
      expect(bars.map((b) => b.fraction), [40 / 135, 75 / 135, 20 / 135]);
    });

    testWidgets('a zero split draws empty bars without dividing by zero',
        (tester) async {
      const zero = IntRange(0, 0);
      await tester.pumpWidget(
          _wrap(MacroSplit(Macros(protein: zero, carbs: zero, fat: zero), light: true)));
      final bars = tester.widgetList<ContributorBar>(find.byType(ContributorBar));
      expect(bars.every((b) => b.fraction == 0), isTrue);
    });
  });

  // ── ConfidenceChip ────────────────────────────────────────────────────────

  group('ConfidenceChip', () {
    testWidgets('shows correct label for each level', (tester) async {
      for (final level in NutritionConfidence.values) {
        await tester.pumpWidget(_wrap(ConfidenceChip(level)));
        expect(find.text(level.label), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink()); // reset
      }
    });

    testWidgets('still accepts the plain flag', (tester) async {
      await tester
          .pumpWidget(_wrap(ConfidenceChip(NutritionConfidence.med, plain: true)));
      expect(find.text('fair estimate'), findsOneWidget);
    });
  });

  // ── SheetShell ────────────────────────────────────────────────────────────

  group('SheetShell', () {
    testWidgets('renders title, Cancel and primary action', (tester) async {
      await tester.pumpWidget(_wrap(SheetShell(
        title: 'Add Meal',
        onClose: () {},
        primaryLabel: 'Save',
        onPrimary: () {},
        child: const Text('content'),
      )));
      await tester.pump(); // allow TweenAnimationBuilder to settle

      expect(find.text('Add Meal'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('tapping scrim calls onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(_wrap(SheetShell(
        title: 'Test',
        onClose: () => closed = true,
        child: const SizedBox(height: 100),
      )));
      await tester.pump();

      // Tap the scrim (top-left area, outside the sheet)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(closed, isTrue);
    });
  });

  // ── ChipRow ───────────────────────────────────────────────────────────────

  group('ChipRow', () {
    testWidgets('renders all options and highlights the active one',
        (tester) async {
      final options = ['Breakfast', 'Lunch', 'Dinner'];
      await tester.pumpWidget(_wrap(
        ChipRow(options, 'Lunch', (_) {}),
      ));

      for (final o in options) {
        expect(find.text(o), findsOneWidget);
      }
    });

    testWidgets('tapping an option fires onChange', (tester) async {
      String? selected;
      final options = ['A', 'B', 'C'];
      await tester.pumpWidget(_wrap(
        ChipRow(options, 'A', (v) => selected = v),
      ));
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(selected, 'B');
    });

    testWidgets('only the active option is selected, and each is 44 tall',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ChipRow(const ['Breakfast', 'Lunch'], 'Lunch', (_) {}),
      ));

      expect(find.bySemanticsLabel('Lunch'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Lunch')),
          isSemantics(label: 'Lunch', isSelected: true, isButton: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Breakfast')),
          isSemantics(label: 'Breakfast', isSelected: false));
      expect(tester.getSize(find.bySemanticsLabel('Breakfast')).height,
          greaterThanOrEqualTo(44));
    });
  });
}
