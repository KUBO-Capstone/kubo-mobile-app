/// What is wrong with an amount typed into a price or quantity field, or
/// null when it is fine. Shown under the field as it is typed, so a typo
/// ("3 5", "1.2532", "2,5") turns the field red instead of only blocking
/// the button.
///
/// [what] names the amount for the empty message ("a quantity"); an empty
/// field only counts as an error when [required] (after a submit attempt).
/// [maxDecimals] is what the database keeps: 2 for prices, 3 for quantities.
/// [max] and [unit] add "Only 5 kg available".
String? amountInputError(
  String text, {
  required String what,
  required int maxDecimals,
  bool required = false,
  double? max,
  String? unit,
}) {
  final value = text.trim();
  if (value.isEmpty) return required ? 'Enter $what.' : null;
  if (RegExp(r'\s').hasMatch(value)) return 'Remove the space.';
  if (value.contains(',')) return 'Use a dot for decimals, e.g. 2.5.';
  if (!RegExp(r'^\d*\.?\d*$').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Numbers only, e.g. 2 or 2.5.';
  }
  final dot = value.indexOf('.');
  final decimals = dot < 0 ? 0 : value.length - dot - 1;
  if (decimals > maxDecimals) {
    return maxDecimals == 0
        ? 'Whole numbers only.'
        : 'Up to $maxDecimals decimal place${maxDecimals == 1 ? '' : 's'}.';
  }
  final amount = double.parse(value);
  if (amount <= 0) return 'Must be more than 0.';
  if (max != null && amount > max) {
    return 'Only ${formatAmountInput(max)}${unit == null ? '' : ' $unit'} available';
  }
  return null;
}

/// The amount in [text], or null when [amountInputError] would complain.
double? parseAmountInput(String text, {required int maxDecimals}) {
  if (amountInputError(text, what: '', maxDecimals: maxDecimals, required: true) != null) return null;
  return double.parse(text.trim());
}

/// Drops a trailing `.0`, so amounts read as `30 kg`, not `30.0 kg`.
String formatAmountInput(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
