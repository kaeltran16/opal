import 'package:flutter_test/flutter_test.dart';
import 'package:opal/services/pal/pal_service.dart';

void main() {
  test('PalMemoryDigest is empty when both lists are empty', () {
    expect(const PalMemoryDigest().isEmpty, isTrue);
    expect(
      const PalMemoryDigest(facts: [PalFact(id: 'f-1', text: 'x')]).isEmpty,
      isFalse,
    );
  });

  test('PalFact equality is by id and text', () {
    expect(const PalFact(id: 'f-1', text: 'x'), const PalFact(id: 'f-1', text: 'x'));
    expect(const PalFact(id: 'f-1', text: 'x') == const PalFact(id: 'f-2', text: 'x'), isFalse);
  });
}
