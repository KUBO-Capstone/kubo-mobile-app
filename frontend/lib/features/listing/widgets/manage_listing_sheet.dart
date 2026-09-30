import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../login/services/auth_service.dart';
import '../screens/create_listing_page.dart';

/// What the seller did in the manage sheet, so the caller can update its
/// copy of the listing without refetching.
class ManageListingOutcome {
  const ManageListingOutcome.updated(SyntheticListingRecord this.listing)
      : removed = false;

  const ManageListingOutcome.removed()
      : listing = null,
        removed = true;

  /// The listing after an edit or status change; null when [removed].
  final SyntheticListingRecord? listing;

  /// The listing was delisted and should disappear from the caller's view.
  final bool removed;
}

/// Opens the seller's actions for [listing]: edit, mark sold out / restore,
/// remove. Returns null when the sheet was dismissed without a change.
///
/// Callers should already have checked `listing.isOwnedBy(currentUserId)`;
/// the server enforces it too, this just decides what the sheet shows.
Future<ManageListingOutcome?> showManageListingSheet(
  BuildContext context,
  SyntheticListingRecord listing,
) {
  return showModalBottomSheet<ManageListingOutcome>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ManageListingSheet(listing: listing),
  );
}

class _ManageListingSheet extends StatefulWidget {
  const _ManageListingSheet({required this.listing});

  final SyntheticListingRecord listing;

  @override
  State<_ManageListingSheet> createState() => _ManageListingSheetState();
}

class _ManageListingSheetState extends State<_ManageListingSheet> {
  final _service = ListingService();
  bool _busy = false;

  SyntheticListingRecord get listing => widget.listing;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // Runs one server call, closes the sheet with the outcome, and surfaces
  // the backend message if it refused.
  Future<void> _run(Future<ManageListingOutcome?> Function() action) async {
    if (AuthService.currentUserId == null || listing.productId == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (!mounted) return;
      // Null means the user backed out of a confirm step.
      Navigator.of(context).pop(outcome);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<SyntheticListingRecord>(
      MaterialPageRoute<SyntheticListingRecord>(
        builder: (_) => CreateListingPage(existing: listing),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      saved == null ? null : ManageListingOutcome.updated(saved),
    );
  }

  Future<void> _toggleSoldOut() {
    return _run(() async {
      final updated = await _service.setSoldOut(
        productId: listing.productId!,
        soldOut: !listing.isSoldOut,
      );
      return ManageListingOutcome.updated(updated);
    });
  }

  Future<void> _remove() {
    return _run(() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Remove this listing?'),
              content: Text(
                '"${listing.title}" will disappear from Kubo for buyers and '
                'from your profile. Offers already made on it are kept.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Keep it'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );
      if (confirmed != true) {
        return null;
      }
      await _service.removeListing(productId: listing.productId!);
      return const ManageListingOutcome.removed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = listing.isSoldOut;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                listing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.edit_outlined, color: AppColors.black),
              title: const Text('Edit listing'),
              onTap: _edit,
            ),
            ListTile(
              enabled: !_busy,
              leading: Icon(
                soldOut ? Icons.restore_outlined : Icons.inventory_2_outlined,
                color: AppColors.black,
              ),
              title: Text(soldOut ? 'Mark as available' : 'Mark as sold out'),
              subtitle: Text(
                soldOut
                    ? 'Buyers can find it and make offers again.'
                    : 'Stays on your profile; buyers can no longer offer on it.',
              ),
              onTap: _toggleSoldOut,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Remove listing',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _remove,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
          ],
        ),
      ),
    );
  }
}
