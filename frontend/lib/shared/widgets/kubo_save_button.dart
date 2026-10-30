import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../features/login/services/auth_service.dart';
import '../../features/saved/providers/saved_listings_controller.dart';
import '../data/synthetic_records.dart';

/// The heart on a listing: filled green when saved, outlined grey when not.
///
/// Reads and writes [SavedListingsController.instance] so every heart for the
/// same listing stays in step. Renders an empty box (keeping the row layout)
/// for mock rows, which have no backend id, and for the viewer's own listings.
class KuboSaveButton extends StatelessWidget {
  const KuboSaveButton({
    super.key,
    required this.listing,
    this.size = 26,
    this.iconSize = 18,
  });

  final SyntheticListingRecord listing;

  /// Tap-target box; the icon is centred inside it.
  final double size;

  final double iconSize;

  /// Whether a heart makes sense for [listing] at all.
  static bool canSave(SyntheticListingRecord listing) =>
      listing.productId != null && !listing.isOwnedBy(AuthService.currentUserId);

  /// Flips the saved state and confirms with a snackbar. Shared with the
  /// listing page's carousel heart, which has its own look.
  static Future<void> toggle(BuildContext context, SyntheticListingRecord listing) async {
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.lightImpact();
    final result = await SavedListingsController.instance.toggle(listing);
    messenger.hideCurrentSnackBar();
    if (result == null) {
      final error = SavedListingsController.instance.errorMessage;
      messenger.showSnackBar(SnackBar(content: Text(error ?? 'Could not update saved listings')));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(result ? '${listing.title} saved' : '${listing.title} removed from saved'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canSave(listing)) {
      return SizedBox(width: size, height: size);
    }
    return AnimatedBuilder(
      animation: SavedListingsController.instance,
      builder: (context, _) {
        final saved = SavedListingsController.instance.isSaved(listing.productId);
        return Semantics(
          button: true,
          toggled: saved,
          label: saved ? 'Remove ${listing.title} from saved' : 'Save ${listing.title}',
          onTap: () => toggle(context, listing),
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => toggle(context, listing),
            radius: size - 4,
            child: SizedBox(
              width: size,
              height: size,
              // The heart pops when it fills, like a like on social apps.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey<bool>(saved),
                  size: iconSize,
                  color: saved ? AppColors.green : AppColors.gray,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
