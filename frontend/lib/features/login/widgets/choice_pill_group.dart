import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Generic option model used by the choice-chip group widget.
class ChoicePillOption<T> {
  const ChoicePillOption({required this.label, required this.value});

  final String label;
  final T value;
}

/// Wraps a list of options in selectable chips and reports the chosen value.
class ChoicePillGroup<T> extends StatelessWidget {
  const ChoicePillGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<ChoicePillOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  @override
  // Builds the responsive chip layout and keeps selection state visual.
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text(
                option.label,
                style: TextStyle(
                  color: option.value == value ? AppColors.white : AppColors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: option.value == value,
              selectedColor: AppColors.green,
              backgroundColor: AppColors.white,
              side: BorderSide(
                color: option.value == value ? AppColors.green : AppColors.border,
                width: 1,
              ),
              shape: const StadiumBorder(),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (selected) {
                onChanged(selected ? option.value : null);
              },
            ),
          )
          .toList(growable: false),
    );
  }
}