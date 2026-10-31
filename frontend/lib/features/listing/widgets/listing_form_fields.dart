import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_options.dart';

const Color listingErrorColor = Color(0xFFD64545);

/// Label above a form field, with an optional "(Optional)" suffix.
class ListingFieldLabel extends StatelessWidget {
  const ListingFieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        optional ? '$text (Optional)' : text,
        style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Red helper line under a field; renders nothing when [message] is null.
class ListingFieldError extends StatelessWidget {
  const ListingFieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(text, style: const TextStyle(color: listingErrorColor, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

/// Shared look for the form's text inputs.
InputDecoration listingInputDecoration({String? hint, String? prefix, bool hasError = false, Widget? suffix}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.gray),
    // prefixIcon rather than prefixText, which hides until the field is focused.
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Text(prefix, style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.softBackground,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: border(hasError ? listingErrorColor : AppColors.border),
    focusedBorder: border(hasError ? listingErrorColor : AppColors.green, 1.4),
    border: border(AppColors.border),
  );
}

/// Read-only field that opens a picker: shows [value] or a gray [placeholder]
/// and a chevron.
class ListingPickerField extends StatelessWidget {
  const ListingPickerField({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.value,
    this.icon,
    this.hasError = false,
  });

  final String placeholder;
  final String? value;
  final IconData? icon;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value;
    return Material(
      color: AppColors.softBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasError ? listingErrorColor : AppColors.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: text == null ? AppColors.gray : AppColors.green),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  text ?? placeholder,
                  style: TextStyle(
                    color: text == null ? AppColors.gray : AppColors.black,
                    fontSize: 15,
                    fontWeight: text == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing [options]; resolves to the chosen value, or null
/// when dismissed.
Future<String?> showListingOptionSheet(
  BuildContext context, {
  required String title,
  required List<ListingOption> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(title, style: const TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final option in options)
                    ListTile(
                      leading: option.icon == null
                          ? null
                          : Icon(option.icon, color: option.value == selected ? AppColors.green : AppColors.gray),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          color: AppColors.black,
                          fontWeight: option.value == selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      subtitle: option.description == null
                          ? null
                          : Text(option.description!, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
                      trailing: option.value == selected ? const Icon(Icons.check_circle, color: AppColors.green) : null,
                      onTap: () => Navigator.of(sheetContext).pop(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pill used for the description templates.
class ListingChoicePill extends StatelessWidget {
  const ListingChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green.withValues(alpha: 0.1) : AppColors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.green : AppColors.border, width: selected ? 1.4 : 1)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.green : AppColors.black,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Switch row used for pre-order and the deal methods.
class ListingSwitchRow extends StatelessWidget {
  const ListingSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: value ? AppColors.green : AppColors.gray),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppColors.gray, fontSize: 12, height: 1.35)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.green,
            ),
          ],
        ),
      ),
    );
  }
}
