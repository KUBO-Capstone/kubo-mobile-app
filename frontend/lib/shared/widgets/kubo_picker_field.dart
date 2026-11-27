import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A form field that looks like a dropdown and opens a searchable list. Used
/// where a plain dropdown would be too long to scroll (a town can have
/// hundreds of barangays). Disabled, it is greyed out and [disabledHint]
/// says what to pick first.
class KuboPickerField extends StatelessWidget {
  const KuboPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
    this.errorText,
    this.disabledHint,
    this.loading = false,
  });

  final String label;

  /// The chosen option as stored. A value missing from [options] (an older
  /// address spelled another way) is still shown.
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  /// How an option is shown; defaults to the option itself.
  final String Function(String option)? labelOf;
  final String? errorText;

  /// Shown in place of a value while [options] is empty.
  final String? disabledHint;
  final bool loading;

  bool get _enabled => !loading && options.isNotEmpty;

  String _labelFor(String option) => labelOf?.call(option) ?? option;

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(title: label, options: options, labelOf: _labelFor, selected: value),
    );
    if (picked != null && picked != value) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    final hasValue = current != null && current.isNotEmpty;
    return Semantics(
      button: true,
      enabled: _enabled,
      child: InkWell(
        onTap: _enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isEmpty: !hasValue,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            enabled: _enabled,
            hintText: _enabled ? null : (loading ? 'Loading...' : disabledHint),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Icon(Icons.arrow_drop_down, color: _enabled ? AppColors.black : AppColors.gray),
          ),
          child: hasValue
              ? Text(
                  _labelFor(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _enabled ? AppColors.black : AppColors.gray, fontSize: 16),
                )
              : null,
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.title, required this.options, required this.labelOf, required this.selected});

  final String title;
  final List<String> options;
  final String Function(String) labelOf;
  final String? selected;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();

  // Short lists (regions, most provinces) need no search box.
  bool get _searchable => widget.options.length > 12;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? widget.options
        : widget.options.where((option) => widget.labelOf(option).toLowerCase().contains(query)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _searchable ? 0.85 : 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          if (_searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No matches', style: TextStyle(color: AppColors.gray)))
                : ListView.builder(
                    controller: scroll,
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final option = shown[index];
                      final selected = option == widget.selected;
                      return ListTile(
                        title: Text(
                          widget.labelOf(option),
                          style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
                        ),
                        trailing: selected ? const Icon(Icons.check, color: AppColors.green) : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
