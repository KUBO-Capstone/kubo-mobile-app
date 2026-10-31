import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_image.dart';

/// Asks which of [listings] the buyer wants to message [sellerName] about.
/// Chats on Kubo belong to a listing, the way they do on Carousell.
Future<SyntheticListingRecord?> showMessageListingPicker(
  BuildContext context, {
  required String sellerName,
  required List<SyntheticListingRecord> listings,
}) {
  return showModalBottomSheet<SyntheticListingRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Message $sellerName about',
                style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Pick a listing to start the chat on.',
                style: TextStyle(color: AppColors.gray, fontSize: 13),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: listings.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 88, color: AppColors.border),
                itemBuilder: (_, index) {
                  final listing = listings[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: KuboImage(listing.imageAssetPath, width: 52, height: 52),
                    ),
                    title: Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      listing.price,
                      style: const TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.gray),
                    onTap: () => Navigator.of(sheetContext).pop(listing),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
