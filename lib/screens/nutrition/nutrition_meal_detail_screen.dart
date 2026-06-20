import 'package:flutter/widgets.dart';

import '../shell/loop_shell.dart';

/// Meal detail — temporary stub so the router compiles. Replaced by the real
/// screen in a later task.
class NutritionMealDetailScreen extends StatelessWidget {
  const NutritionMealDetailScreen({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(label: 'Meal detail');
}
