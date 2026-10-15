import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// SF Symbols are Apple-licensed and can't be bundled off-Apple, so the design's
/// symbol names are mapped to the closest Cupertino/Material glyphs for the
/// Windows/web preview. On a real iOS build these map back to native SF Symbols.
const Map<String, IconData> _sfMap = {
  'flame.fill': CupertinoIcons.flame_fill,
  'dollarsign.circle.fill': CupertinoIcons.money_dollar_circle_fill,
  'sparkles': CupertinoIcons.sparkles,
  'figure.run': Icons.directions_run,
  'figure.walk': Icons.directions_walk,
  'dumbbell.fill': Icons.fitness_center,
  'book.closed.fill': CupertinoIcons.book_fill,
  'books.vertical.fill': Icons.menu_book,
  // a journal is writing; Icons.translate drew a 文A glyph.
  'character.book.closed.fill': Icons.edit_note,
  'tray.fill': CupertinoIcons.tray_fill,
  'cup.and.saucer.fill': Icons.local_cafe,
  'fork.knife': Icons.restaurant,
  'basket.fill': Icons.shopping_basket,
  'plus': CupertinoIcons.plus,
  'play.fill': CupertinoIcons.play_fill,
  'star.fill': CupertinoIcons.star_fill,
  'magnifyingglass': CupertinoIcons.search,
  'chevron.left': CupertinoIcons.chevron_back,
  'chevron.right': CupertinoIcons.chevron_forward,
  'chevron.up': CupertinoIcons.chevron_up,
  'chevron.down': CupertinoIcons.chevron_down,
  'ellipsis': CupertinoIcons.ellipsis,
  'bell.fill': CupertinoIcons.bell_fill,
  'heart.fill': CupertinoIcons.heart_fill,
  'target': CupertinoIcons.scope,
  'gearshape.fill': CupertinoIcons.gear_solid,
  'person.crop.circle.fill': CupertinoIcons.person_crop_circle_fill,
  'calendar': CupertinoIcons.calendar,
  'chart.bar.fill': Icons.bar_chart,
  'envelope.fill': CupertinoIcons.mail_solid,
  'paperplane.fill': CupertinoIcons.paperplane_fill,
  'checkmark': CupertinoIcons.checkmark_alt,
  'xmark': CupertinoIcons.xmark,
  'arrow.up.right': CupertinoIcons.arrow_up_right,
  'arrow.down.right': CupertinoIcons.arrow_down_right,
  'lock.fill': CupertinoIcons.lock_fill,
  'clock.fill': CupertinoIcons.clock_fill,
  'house.fill': CupertinoIcons.house_fill,
  'delete.left.fill': CupertinoIcons.delete_left,
  'trash.fill': CupertinoIcons.delete_solid,
  'slider.horizontal.3': CupertinoIcons.slider_horizontal_3,
  'square.and.arrow.up': CupertinoIcons.share,
  // Exercise-catalog glyphs (U11). Closest Material substitutes for preview;
  // map back to true SF Symbols on a real iOS build.
  'figure.strengthtraining.traditional': Icons.fitness_center,
  'figure.strengthtraining.functional': Icons.sports_gymnastics,
  'figure.pullup': Icons.sports_gymnastics,
  'figure.core.training': Icons.self_improvement,
  'figure.rower': Icons.rowing,
  'figure.indoor.cycle': Icons.directions_bike,
  'figure.stair.stepper': Icons.stairs,
  'figure.mixed.cardio': Icons.sports_gymnastics,
  // Handoff #2 additions (Pal composer, ritual routines, money utilities,
  // weekly plan, routine generator). Closest preview substitutes.
  'arrow.up': CupertinoIcons.arrow_up,
  'arrow.down': CupertinoIcons.arrow_down,
  'arrow.clockwise': CupertinoIcons.arrow_clockwise,
  'arrow.triangle.2.circlepath': CupertinoIcons.arrow_2_circlepath,
  'sunrise.fill': CupertinoIcons.sunrise_fill,
  'sun.max.fill': CupertinoIcons.sun_max_fill,
  'moon.stars.fill': CupertinoIcons.moon_stars_fill,
  'drop.fill': CupertinoIcons.drop_fill,
  'bolt.fill': CupertinoIcons.bolt_fill,
  'leaf.fill': Icons.eco,
  'music.note': CupertinoIcons.music_note,
  'square.grid.2x2.fill': CupertinoIcons.square_grid_2x2_fill,
  'creditcard.fill': CupertinoIcons.creditcard_fill,
  'arrow.right': CupertinoIcons.arrow_right,
  'timer': CupertinoIcons.timer,
  'list.number': CupertinoIcons.list_number,
  'arrow.uturn.backward': CupertinoIcons.arrow_counterclockwise,
  // Pal memory — head-with-gears connotes mind/memory; distinct from sparkles.
  'brain.head.profile': Icons.psychology,
  // Budgets (Phase 1) envelope + action glyphs.
  'bag.fill': CupertinoIcons.bag_fill,
  'car.fill': CupertinoIcons.car_fill,
  'tv.fill': CupertinoIcons.tv_fill,
  'plus.circle.fill': CupertinoIcons.add_circled_solid,
  'pencil': CupertinoIcons.pencil,
  'mic': CupertinoIcons.mic,
  // workout line glyphs (oura): outline icons, drawn in ink2, never in tiles.
  'list.bullet': CupertinoIcons.list_bullet,
  'wand.and.stars': Icons.auto_fix_high_outlined,
  'book': CupertinoIcons.book,
  'chart.line.uptrend.xyaxis': Icons.show_chart,
  'minus': CupertinoIcons.minus,
  'dumbbell': Icons.fitness_center_outlined,
  'star': CupertinoIcons.star,
  'trash': CupertinoIcons.delete,
  'line.3.horizontal': CupertinoIcons.line_horizontal_3,
  // routine line glyphs (oura): outline stems of the routine icon picker's
  // .fill names, so stored names draw as lines without a data migration.
  'sunrise': CupertinoIcons.sunrise,
  'sun.max': CupertinoIcons.sun_max,
  'moon.stars': CupertinoIcons.moon_stars,
  'drop': CupertinoIcons.drop,
  'bolt': CupertinoIcons.bolt,
  'leaf': Icons.eco_outlined,
  'book.closed': CupertinoIcons.book,
  'books.vertical': Icons.menu_book_outlined,
  'character.book.closed': Icons.edit_note_outlined,
  'tray': CupertinoIcons.tray,
  'cup.and.saucer': Icons.local_cafe_outlined,
  'heart': CupertinoIcons.heart,
  // envelope line glyphs (oura): the editor's picker names and the stems of
  // the seeded envelopes' .fill names.
  'bag': CupertinoIcons.bag,
  // cupertino's car and car_fill are the same glyph, so use a true outline.
  'car': Icons.directions_car_outlined,
  'tv': CupertinoIcons.tv,
  'basket': Icons.shopping_basket_outlined,
  'house': CupertinoIcons.house,
  'creditcard': CupertinoIcons.creditcard,
  'gift': CupertinoIcons.gift,
  'airplane': CupertinoIcons.airplane,
};

const _fillSuffix = '.fill';

IconData iconForSf(String name) => _sfMap[name] ?? CupertinoIcons.circle;

/// The outline form of [name]: a `.fill` name draws its stem's glyph when the
/// stem is mapped, and any other name draws as [iconForSf] does.
IconData lineIconForSf(String name) {
  if (!name.endsWith(_fillSuffix)) return iconForSf(name);
  final stem = name.substring(0, name.length - _fillSuffix.length);
  return _sfMap[stem] ?? iconForSf(name);
}

/// Renders an SF Symbol by name using the substitution map.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 17, this.color})
      : _line = false;

  /// Draws [name] in its outline form, via [lineIconForSf].
  const AppIcon.line(this.name, {super.key, this.size = 17, this.color})
      : _line = true;

  final String name;
  final double size;
  final Color? color;
  final bool _line;

  @override
  Widget build(BuildContext context) => Icon(
        _line ? lineIconForSf(name) : iconForSf(name),
        size: size,
        color: color,
      );
}
