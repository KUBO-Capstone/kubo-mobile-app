import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/listing_draft.dart';
import 'listing_form_fields.dart';

const double _thumbSize = 64;

/// Row of open drafts at the top of the create page, plus an Add tile for
/// listing another crop in the same sitting.
class ListingDraftStrip extends StatelessWidget {
  const ListingDraftStrip({
    super.key,
    required this.drafts,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    required this.hasErrors,
    this.maxDrafts = 10,
  });

  final List<ListingDraft> drafts;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  /// Whether the draft at an index has been checked and still has problems.
  final bool Function(int index) hasErrors;
  final int maxDrafts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _thumbSize + 10,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < drafts.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _DraftThumb(
                draft: drafts[i],
                number: i + 1,
                selected: i == selectedIndex,
                hasError: hasErrors(i),
                onTap: () => onSelect(i),
              ),
            ),
          if (drafts.length < maxDrafts) _AddDraftTile(onTap: onAdd),
        ],
      ),
    );
  }
}

class _DraftThumb extends StatelessWidget {
  const _DraftThumb({
    required this.draft,
    required this.number,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  final ListingDraft draft;
  final int number;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = draft.photos.firstOrNull;
    final Widget content;
    if (cover?.file != null) {
      content = Image.file(cover!.file!, fit: BoxFit.cover);
    } else if (cover?.displayUrl != null) {
      content = Image.network(cover!.displayUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } else {
      content = Center(
        child: Text('$number', style: const TextStyle(color: AppColors.gray, fontSize: 18, fontWeight: FontWeight.w800)),
      );
    }

    final borderColor = hasError ? listingErrorColor : (selected ? AppColors.green : AppColors.border);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Listing $number',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.softBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: selected || hasError ? 3 : 1),
                  ),
                  child: content,
                ),
                if (hasError)
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: listingErrorColor,
                      child: Icon(Icons.priority_high, size: 12, color: AppColors.white),
                    ),
                  ),
              ],
            ),
            if (selected)
              CustomPaint(size: const Size(14, 7), painter: _PointerPainter(borderColor))
            else
              const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.color != color;
}

class _AddDraftTile extends StatelessWidget {
  const _AddDraftTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: _thumbSize,
            height: _thumbSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.black, width: 1.4),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: AppColors.black),
                Text('Add', style: TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
