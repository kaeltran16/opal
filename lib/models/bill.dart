/// A recurring obligation shown on the Bills / Recurring screen.
///
/// [dueDate] is an absolute instant; the screen derives "due in N days" and the
/// "Mon, Apr 28" label from it so the demo never drifts stale.
class Bill {
  const Bill({
    required this.id,
    required this.name,
    required this.payee,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.icon,
    required this.color,
    this.autoPay = false,
  });

  /// Caller-supplied id.
  final String id;
  final String name;

  /// Sub-line, e.g. "Greenwood Property Co." or "Credit card · min $75".
  final String payee;

  /// Housing | Utility | Insurance | Credit | …
  final String category;
  final double amount;
  final DateTime dueDate;
  final bool autoPay;

  /// SF Symbol name.
  final String icon;

  /// Brand hex string, e.g. "#0A84FF".
  final String color;

  Bill copyWith({
    String? id,
    String? name,
    String? payee,
    String? category,
    double? amount,
    DateTime? dueDate,
    bool? autoPay,
    String? icon,
    String? color,
  }) =>
      Bill(
        id: id ?? this.id,
        name: name ?? this.name,
        payee: payee ?? this.payee,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        autoPay: autoPay ?? this.autoPay,
        icon: icon ?? this.icon,
        color: color ?? this.color,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill &&
          other.id == id &&
          other.name == name &&
          other.payee == payee &&
          other.category == category &&
          other.amount == amount &&
          other.dueDate == dueDate &&
          other.autoPay == autoPay &&
          other.icon == icon &&
          other.color == color;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        payee,
        category,
        amount,
        dueDate,
        autoPay,
        icon,
        color,
      );

  @override
  String toString() => 'Bill(id: $id, name: $name, amount: $amount)';
}
