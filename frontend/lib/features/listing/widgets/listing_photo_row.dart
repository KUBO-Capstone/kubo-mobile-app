import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/listing_draft.dart';
import 'listing_form_fields.dart';

const double _tileWidth = 100;
const double _tileHeight = 128;

/// Horizontal photo strip for one draft. The first photo is the cover;
/// long-press and drag to reorder, tap a photo for its actions. Empty add
/// slots pad the row out to three tiles.
class ListingPhotoRow extends StatelessWidget {
  const ListingPhotoRow({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onPhotoTap,
    required this.onReorder,
    this.hasError = false,
  });

  final List<ListingPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onPhotoTap;

  /// Called with the photo's old index and its index after the move.
  final void Function(int from, int to) onReorder;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < maxListingPhotos;
    final addSlots = canAdd ? (3 - photos.length).clamp(1, 3) : 0;

    return SizedBox(
      height: _tileHeight,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        onReorderItem: onReorder,
        proxyDecorator: (child, _, __) => Material(
          color: Colors.transparent,
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
        footer: Row(
          children: [
            for (var i = 0; i < addSlots; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _AddPhotoTile(onTap: onAdd, hasError: hasError, showLabel: photos.isEmpty && i == 0),
              ),
          ],
        ),
        itemBuilder: (context, index) => Padding(
          key: ValueKey(photos[index].id),
          padding: const EdgeInsets.only(right: 10),
          child: _PhotoTile(
            photo: photos[index],
            isCover: index == 0,
            onTap: () => onPhotoTap(index),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.isCover, required this.onTap});

  final ListingPhoto photo;
  final bool isCover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = photo.file;
    final image = file != null
        ? Image.file(file, fit: BoxFit.cover, width: _tileWidth, height: _tileHeight)
        : Image.network(
            photo.displayUrl!,
            fit: BoxFit.cover,
            width: _tileWidth,
            height: _tileHeight,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.softBackground,
              child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.gray)),
            ),
          );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: _tileWidth,
          height: _tileHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.drag_indicator, size: 14, color: AppColors.black),
                ),
              ),
              if (isCover)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.green.withValues(alpha: 0.9),
                    child: const Text(
                      'Cover',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap, required this.hasError, required this.showLabel});

  final VoidCallback onTap;
  final bool hasError;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: _tileWidth,
          height: _tileHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasError ? listingErrorColor : AppColors.border, width: hasError ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showLabel ? Icons.add_a_photo_outlined : Icons.add_circle_outline,
                size: showLabel ? 30 : 36,
                color: hasError ? listingErrorColor : AppColors.gray,
              ),
              if (showLabel) ...[
                const SizedBox(height: 6),
                Text(
                  'Add photos',
                  style: TextStyle(color: hasError ? listingErrorColor : AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
