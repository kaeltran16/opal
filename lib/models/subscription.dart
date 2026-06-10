/// An auto-detected recurring service shown on the Subscriptions screen.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.nextChargeDate,
    required this.icon,
    required this.color,
    this.detectedFromEmail = true,
  });

  /// Caller-supplied id.
  final String id;
  final String name;

  /// Music | Video | Storage | News | Work | Fitness | AI | …
  final String category;

  /// Monthly amount.
  final double amount;
  final DateTime nextChargeDate;

  /// SF Symbol name.
  final String icon;

  /// Brand hex string, e.g. "#1DB954".
  final String color;
  final bool detectedFromEmail;

  Subscription copyWith({
    String? id,
    String? name,
    String? category,
    double? amount,
    DateTime? nextChargeDate,
    String? icon,
    String? color,
    bool? detectedFromEmail,
  }) =>
      Subscription(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        nextChargeDate: nextChargeDate ?? this.nextChargeDate,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        detectedFromEmail: detectedFromEmail ?? this.detectedFromEmail,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          other.id == id &&
          other.name == name &&
          other.category == category &&
          other.amount == amount &&
          other.nextChargeDate == nextChargeDate &&
          other.icon == icon &&
          other.color == color &&
          other.detectedFromEmail == detectedFromEmail;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        amount,
        nextChargeDate,
        icon,
        color,
        detectedFromEmail,
      );

  @override
  String toString() => 'Subscription(id: $id, name: $name, amount: $amount)';
}
