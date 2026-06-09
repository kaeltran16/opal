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
  'character.book.closed.fill': Icons.translate,
  'tray.fill': CupertinoIcons.tray_fill,
  'cup.and.saucer.fill': Icons.local_cafe,
  'fork.knife': Icons.restaurant,
  'basket.fill': Icons.shopping_basket,
  'plus': CupertinoIcons.plus,
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
  'lock.fill': CupertinoIcons.lock_fill,
  'clock.fill': CupertinoIcons.clock_fill,
  'house.fill': CupertinoIcons.house_fill,
  'delete.left.fill': CupertinoIcons.delete_left,
};

IconData iconForSf(String name) => _sfMap[name] ?? CupertinoIcons.circle;

/// Renders an SF Symbol by name using the substitution map.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 17, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(iconForSf(name), size: size, color: color);
}
