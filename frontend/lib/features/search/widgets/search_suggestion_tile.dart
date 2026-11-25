import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// One row of the list that follows the text as it is typed: an icon saying
/// what kind of suggestion it is, the suggestion with the typed part set
/// apart, and an optional note on the right.
class SearchSuggestionTile extends StatelessWidget {
  const SearchSuggestionTile({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.typed = '',
    this.note,
    this.semanticLabel,
  });

  final IconData icon;

  /// The suggestion; tapping the row searches for it.
  final String text;

  /// What the user has typed. Where [text] contains it, that part stays
  /// regular and the rest is bold, so the eye lands on what the suggestion
  /// adds.
  final String typed;

  /// Short note on the right, such as "3 listings" or "Town".
  final String? note;

  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Search for $text',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // A comfortable touch target however short the text is.
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.gray),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _spans()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.black, fontSize: 15),
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(width: 12),
                  Text(note!, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _spans() {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final start = typed.isEmpty ? -1 : text.toLowerCase().indexOf(typed.toLowerCase());
    if (start < 0) return <TextSpan>[TextSpan(text: text, style: bold)];
    final end = start + typed.length;
    return <TextSpan>[
      if (start > 0) TextSpan(text: text.substring(0, start), style: bold),
      TextSpan(text: text.substring(start, end)),
      if (end < text.length) TextSpan(text: text.substring(end), style: bold),
    ];
  }
}
