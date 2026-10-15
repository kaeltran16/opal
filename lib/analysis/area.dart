import '../controllers/spending_controller.dart';
import '../models/models.dart';
import '../util/dates.dart';

/// The six areas Opal tracks, in display order. The single source for each
/// area's title, glyph and whether it has a state rule.
enum Area {
  money(
    title: 'Money',
    glyph: 'dollarsign.circle.fill',
    hasStateRule: true,
    tracker: DetailTracker.money,
  ),
  move(
    title: 'Move',
    glyph: 'figure.run',
    hasStateRule: true,
    tracker: DetailTracker.move,
  ),
  routines(
    title: 'Routines',
    glyph: 'sparkles',
    hasStateRule: true,
    tracker: DetailTracker.rituals,
  ),
  nutrition(title: 'Nutrition', glyph: 'fork.knife'),
  sleep(title: 'Sleep', glyph: 'moon.stars.fill'),
  // app_icon maps no smile glyph, so mood falls back to the heart.
  mood(title: 'Mood', glyph: 'heart.fill');

  const Area({
    required this.title,
    required this.glyph,
    this.hasStateRule = false,
    this.tracker,
  });

  final String title;

  /// An [AppIcon] name.
  final String glyph;

  /// Whether the area can be judged on track. The rest show no state word and
  /// are never counted off track (DESIGN.md section 11, decision 4).
  final bool hasStateRule;

  /// The tracker behind the area page's entries; null for areas without one.
  final DetailTracker? tracker;
}

/// Calories eaten on [day]'s calendar date: every meal logged for that date,
/// whatever its time of day, since a logged meal is an eaten one. The one
/// count the Areas card and the Nutrition page both read.
double kcalEatenOn(Iterable<NutritionMeal> meals, DateTime day) => meals
    .where((m) => startOfDay(m.timestamp) == startOfDay(day))
    .fold<double>(0, (s, m) => s + m.cal.mid);
