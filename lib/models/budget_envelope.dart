/// A per-category monthly budget "envelope": a spending cap for one category,
/// with display knobs (icon + color token) and an ordering [position].
///
/// Categories are matched to entries case-insensitively by name (see
/// `buildBudgetsData`); the model itself only stores the cap and presentation.
class BudgetEnvelope {
  const BudgetEnvelope({
    required this.id,
    required this.category,
    required this.cap,
    required this.icon,
    required this.colorToken,
    required this.position,
  });

  /// Stable id (seed envelopes use `env-*`; user-created ones a UUID).
  final String id;

  /// Display category name, also the case-insensitive match key against
  /// `Entry.category`.
  final String category;

  /// Monthly spending cap, in the user's currency.
  final double cap;

  /// SF symbol for the envelope's icon tile.
  final String icon;

  /// `context.colors.forType(colorToken)` — the envelope's accent color.
  final String colorToken;

  /// Sort order in the budgets list (ascending).
  final int position;

  BudgetEnvelope copyWith({
    String? id,
    String? category,
    double? cap,
    String? icon,
    String? colorToken,
    int? position,
  }) =>
      BudgetEnvelope(
        id: id ?? this.id,
        category: category ?? this.category,
        cap: cap ?? this.cap,
        icon: icon ?? this.icon,
        colorToken: colorToken ?? this.colorToken,
        position: position ?? this.position,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetEnvelope &&
          other.id == id &&
          other.category == category &&
          other.cap == cap &&
          other.icon == icon &&
          other.colorToken == colorToken &&
          other.position == position;

  @override
  int get hashCode =>
      Object.hash(id, category, cap, icon, colorToken, position);

  @override
  String toString() => 'BudgetEnvelope(id: $id, category: $category, '
      'cap: $cap, icon: $icon, colorToken: $colorToken, position: $position)';
}
