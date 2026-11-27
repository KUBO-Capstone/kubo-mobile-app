import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/amount_input.dart';

void main() {
  String? quantity(String text, {bool required = false}) =>
      amountInputError(text, what: 'a quantity', maxDecimals: 3, required: required, max: 5, unit: 'kg');

  test('good amounts pass', () {
    for (final text in ['1', '4.5', '5', '0.125', '.5', '2.']) {
      expect(quantity(text), isNull, reason: text);
    }
  });

  test('typos are named, not just rejected', () {
    expect(quantity('3 5'), 'Remove the space.');
    expect(quantity('1.2532'), 'Up to 3 decimal places.');
    expect(quantity('2,5'), 'Use a dot for decimals, e.g. 2.5.');
    expect(quantity('abc'), 'Numbers only, e.g. 2 or 2.5.');
    expect(quantity('1.2.3'), 'Numbers only, e.g. 2 or 2.5.');
    expect(quantity('1e3'), 'Numbers only, e.g. 2 or 2.5.');
    expect(quantity('.'), 'Numbers only, e.g. 2 or 2.5.');
    expect(quantity('0'), 'Must be more than 0.');
    expect(quantity('6'), 'Only 5 kg available');
  });

  test('an empty field only counts once required', () {
    expect(quantity(''), isNull);
    expect(quantity('  ', required: true), 'Enter a quantity.');
  });

  test('prices allow two decimals', () {
    expect(amountInputError('12.50', what: 'a price', maxDecimals: 2), isNull);
    expect(amountInputError('12.505', what: 'a price', maxDecimals: 2), 'Up to 2 decimal places.');
    expect(amountInputError('3.5', what: 'pieces', maxDecimals: 0), 'Whole numbers only.');
  });

  test('parseAmountInput reads only what passes', () {
    expect(parseAmountInput(' 2.5 ', maxDecimals: 2), 2.5);
    expect(parseAmountInput('3 5', maxDecimals: 2), isNull);
    expect(parseAmountInput('', maxDecimals: 2), isNull);
  });
}
