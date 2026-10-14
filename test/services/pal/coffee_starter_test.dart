import 'package:flutter_test/flutter_test.dart';
import 'package:opal/models/models.dart';
import 'package:opal/services/pal/coffee_starter.dart';
import 'package:opal/util/format.dart';

void main() {
  test('usd starter reads \$5 and logs -5', () {
    final starter = coffeeStarter(Currency.usd);
    expect(starter.label, 'Verve coffee, \$5');
    expect(starter.entry?.type, EntryType.money);
    expect(starter.entry?.title, 'Verve coffee');
    expect(starter.entry?.amount, -5);
    expect(starter.entry?.category, 'Food & Drink');
    expect(kSpendCategories, contains(starter.entry?.category));
  });

  test('vnd starter reads 5.000 ₫ and logs -5000', () {
    final starter = coffeeStarter(Currency.vnd);
    expect(starter.label, 'Verve coffee, 5.000\u00a0₫');
    expect(starter.entry?.amount, -5000);
  });
}
