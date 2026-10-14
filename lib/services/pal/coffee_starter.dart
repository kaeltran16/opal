import '../../models/models.dart';
import '../../util/format.dart';
import 'pal_service.dart';

/// The coffee starter's price in usd; [Currency.budgetScale] scales it.
const double coffeeStarterAmount = 5;

const _coffeeTitle = 'Verve coffee';

// the kSpendCategories member coffee lands in, so it counts against a budget
// and the nutrition food gate, like the mock parser's coffee keyword.
const _coffeeCategory = 'Food & Drink';

/// The composer's coffee quick-log in [currency]: one builder for the static
/// starter and the mock Pal, so label and logged amount agree in any currency.
PalSuggestion coffeeStarter(Currency currency) {
  final amount = coffeeStarterAmount * currency.budgetScale;
  return PalSuggestion(
    label: '$_coffeeTitle, ${formatCurrency(amount, currency)}',
    icon: 'cup.and.saucer.fill',
    colorToken: 'money',
    entry: StarterEntry(
      type: EntryType.money,
      title: _coffeeTitle,
      amount: -amount, // negative = expense
      category: _coffeeCategory,
    ),
  );
}
