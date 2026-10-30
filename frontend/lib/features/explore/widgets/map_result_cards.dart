import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_image.dart';
import '../../../shared/widgets/kubo_save_button.dart';
import '../../listing/screens/listing_page.dart';
import '../models/bagsakan_center.dart';

/// Produce rows shown under the map, mirroring the plotted product pins.
///
/// Each row opens the same [ListingPage] the list-view grid does, so a
/// listing reached through the map is the same listing, not a summary of it.
class MapListingCards extends StatelessWidget {
  const MapListingCards({super.key, required this.listings, this.loadError});

  final List<SyntheticListingRecord> listings;

  /// Set when the listing fetch failed, which is distinct from an empty region.
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Center(
          child: Text(
            loadError ?? 'No listings to show for this filter yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final listing = listings[index];
        return _MapCardShell(
          imagePath: listing.imageAssetPath,
          title: listing.title,
          subtitle: '${listing.price} | ${listing.locationLabel}',
          footer: listing.sellerLabel,
          footerIcon: Icons.storefront_outlined,
          trailing: KuboSaveButton(listing: listing, size: 32, iconSize: 20),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ListingPage(listing: listing),
                ),
              ),
        );
      },
    );
  }
}

/// Bagsakan center rows shown under the map in center mode.
class BagsakanCards extends StatelessWidget {
  const BagsakanCards({super.key, required this.centers});

  final List<BagsakanCenter> centers;

  @override
  Widget build(BuildContext context) {
    if (centers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 24),
        child: Center(
          child: Text(
            'No bagsakan centers to show for this filter yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: centers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final center = centers[index];
        return _MapCardShell(
          imagePath: AppAssets.placeholderImage,
          title: center.name,
          subtitle: center.addressLine.isEmpty
              ? center.regionLabel
              : center.addressLine,
          footer: center.locationLabel,
          footerIcon: Icons.location_on_outlined,
        );
      },
    );
  }
}

/// Shared row layout for the cards listed under the map.
class _MapCardShell extends StatelessWidget {
  const _MapCardShell({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.footerIcon,
    this.trailing,
    this.onTap,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final String footer;
  final IconData footerIcon;
  final Widget? trailing;

  /// Tap handler for the whole row; null renders a static card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: KuboImage(imagePath, width: 72, height: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(footerIcon, size: 15, color: AppColors.gray),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            footer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gray,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
