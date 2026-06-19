import '../models/enums.dart';

/// The SF Symbol name for an entry, derived from its [type] and (for money) its
/// [category]. [isWorkout] picks the dumbbell glyph for move entries tied to a
/// logged workout. Single source of truth shared by the Today timeline row and
/// the Pal composer's logged-entry card so an entry reads the same everywhere.
String entryGlyph(EntryType type, {String? category, bool isWorkout = false}) {
  switch (type) {
    case EntryType.money:
      final cat = category?.toLowerCase() ?? '';
      if (cat.contains('coffee')) return 'cup.and.saucer.fill';
      if (cat.contains('dining')) return 'fork.knife';
      if (cat.contains('grocer')) return 'basket.fill';
      return 'creditcard.fill';
    case EntryType.move:
      return isWorkout ? 'dumbbell.fill' : 'figure.run';
    case EntryType.rituals:
      return 'sparkles';
  }
}
