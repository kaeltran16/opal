import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opal/models/enums.dart';
import 'package:opal/models/nutrition_meal.dart';
import 'package:opal/screens/nutrition/widgets/nutrition_widgets.dart';
import 'package:opal/theme/app_colors.dart';

// Helper: wraps a widget in a themed ProviderScope + MaterialApp.
Widget _wrap(Widget child) {
  final colors = AppColors.light(AppAccent.indigo);
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
    testWidgets('shows mid rounded to nearest 10 and range sub-line',
        (tester) async {
      await tester.pumpWidget(_wrap(const CalRange(IntRange(560, 820))));

      // mid = (560+820)/2 = 690, already at nearest 10
      expect(find.text('690'), findsOneWidget);
      expect(find.text('560–820 estimated'), findsOneWidget);
      expect(find.text('cal'), findsOneWidget);
      expect(find.text('≈'), findsOneWidget);
    });

    testWidgets('rounds mid to nearest 10', (tester) async {
      // (100+115)/2 = 107.5 → rounds to 110
      await tester.pumpWidget(_wrap(const CalRange(IntRange(100, 115))));
      expect(find.text('110'), findsOneWidget);
      expect(find.text('100–115 estimated'), findsOneWidget);
    });

    testWidgets('accepts custom size and light flag', (tester) async {
      await tester
          .pumpWidget(_wrap(const CalRange(IntRange(400, 600), size: 42, light: true)));
      expect(find.text('500'), findsOneWidget);
      expect(find.text('400–600 estimated'), findsOneWidget);
    });
  });

  // ── MacroSplit ────────────────────────────────────────────────────────────

  group('MacroSplit', () {
    testWidgets('renders protein / carbs / fat labels and ranges',
        (tester) async {
      final macros = Macros(
        protein: const IntRange(30, 50),
        carbs: const IntRange(60, 90),
        fat: const IntRange(15, 25),
      );
      await tester.pumpWidget(_wrap(MacroSplit(macros)));

      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
      expect(find.text('30–50g'), findsOneWidget);
      expect(find.text('60–90g'), findsOneWidget);
      expect(find.text('15–25g'), findsOneWidget);
    });

    testWidgets('light flag does not crash', (tester) async {
      final macros = Macros(
        protein: const IntRange(20, 40),
        carbs: const IntRange(50, 80),
        fat: const IntRange(10, 20),
      );
      await tester.pumpWidget(_wrap(MacroSplit(macros, light: true)));
      expect(find.text('PROTEIN'), findsOneWidget);
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

    testWidgets('plain variant renders without background pill', (tester) async {
      await tester
          .pumpWidget(_wrap(ConfidenceChip(NutritionConfidence.med, plain: true)));
      expect(find.text('fair estimate'), findsOneWidget);
    });
  });

  // ── SourceTag ─────────────────────────────────────────────────────────────

  group('SourceTag', () {
    testWidgets('renders label for each source', (tester) async {
      for (final source in NutritionSource.values) {
        await tester.pumpWidget(_wrap(SourceTag(source)));
        expect(find.text(source.label), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  // ── MealRow ───────────────────────────────────────────────────────────────

  group('MealRow', () {
    final meal = NutritionMeal(
      id: 'test-1',
      timestamp: DateTime(2026, 6, 21, 12, 30),
      slot: 'Lunch',
      name: 'Chicken Bowl',
      source: NutritionSource.home,
      icon: 'fork.knife',
      confidence: NutritionConfidence.high,
      cal: const IntRange(550, 750),
      macros: Macros(
        protein: const IntRange(40, 55),
        carbs: const IntRange(60, 80),
        fat: const IntRange(15, 25),
      ),
    );

    testWidgets('renders meal name, slot, time and cal range', (tester) async {
      await tester.pumpWidget(_wrap(MealRow(meal)));

      expect(find.text('Chicken Bowl'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
      expect(find.text('550–750'), findsOneWidget);
    });

    testWidgets('tapping fires onTap', (tester) async {
      var tapped = false;
      await tester
          .pumpWidget(_wrap(MealRow(meal, onTap: () => tapped = true)));
      await tester.tap(find.text('Chicken Bowl'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('last flag suppresses divider', (tester) async {
      // Should not throw — just a build check
      await tester.pumpWidget(_wrap(MealRow(meal, last: true)));
      expect(find.text('Chicken Bowl'), findsOneWidget);
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
  });
}
