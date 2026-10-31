import 'package:flutter/material.dart';

/// One choice in a listing picker. [value] is what the backend stores; the
/// lists below mirror the CHECK constraints on `products`.
class ListingOption {
  const ListingOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });

  final String value;
  final String label;
  final String? description;
  final IconData? icon;
}

abstract final class ListingOptions {
  static const categories = <ListingOption>[
    ListingOption(value: 'vegetable', label: 'Vegetables', description: 'Leafy greens, root crops, gourds, tomatoes', icon: Icons.eco_outlined),
    ListingOption(value: 'fruit', label: 'Fruits', description: 'Mangoes, bananas, citrus, berries', icon: Icons.apple_outlined),
    ListingOption(value: 'grain', label: 'Grains', description: 'Rice, corn, and other cereals', icon: Icons.grass_outlined),
    ListingOption(value: 'legume', label: 'Legumes', description: 'Beans, peas, mongo, peanuts', icon: Icons.spa_outlined),
    ListingOption(value: 'herb', label: 'Herbs', description: 'Tanglad, basil, oregano, pandan', icon: Icons.local_florist_outlined),
    ListingOption(value: 'spice', label: 'Spices', description: 'Garlic, ginger, chili, onion', icon: Icons.whatshot_outlined),
  ];

  static const qualityGrades = <ListingOption>[
    ListingOption(value: 'premium', label: 'Premium', description: 'Uniform size and color, no blemishes. Market or gift ready.'),
    ListingOption(value: 'standard', label: 'Standard', description: 'Good everyday produce with minor variation in size or look.'),
    ListingOption(value: 'imperfect', label: 'Imperfect', description: 'Odd shapes or small blemishes, just as fresh. Usually priced lower.'),
  ];

  static const farmingMethods = <ListingOption>[
    ListingOption(value: 'conventional', label: 'Conventional', description: 'Grown with standard farm inputs.'),
    ListingOption(value: 'organic', label: 'Organic', description: 'No synthetic fertilizers or pesticides.'),
    ListingOption(value: 'pesticide-free', label: 'Pesticide-free', description: 'No pesticides used, may use synthetic fertilizer.'),
  ];

  static const units = <ListingOption>[
    ListingOption(value: 'kg', label: 'kg'),
    ListingOption(value: 'g', label: 'g'),
    ListingOption(value: 'lb', label: 'lb'),
    ListingOption(value: 'oz', label: 'oz'),
    ListingOption(value: 'piece', label: 'piece'),
    ListingOption(value: 'liter', label: 'liter'),
    ListingOption(value: 'ml', label: 'ml'),
  ];

  /// Label for [value] in [options], or [value] itself when unknown.
  static String labelOf(List<ListingOption> options, String? value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value ?? '';
  }
}

const _months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 29, 2026".
String formatListingDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// The `YYYY-MM-DD` form the backend stores harvest dates in.
String toApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// "12" rather than "12.0" for whole numbers.
String formatQuantity(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
