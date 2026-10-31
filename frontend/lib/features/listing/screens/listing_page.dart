import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/listing_page_controller.dart';
import '../widgets/action_button.dart';
import '../widgets/listing_image_carousel.dart';
import '../widgets/listing_info_row.dart';
import '../widgets/listing_tag.dart';
import '../widgets/seller_card.dart';
import '../widgets/make_offer_dialog.dart';
import '../widgets/manage_listing_sheet.dart';
import '../widgets/market_reference_line.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_options.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/widgets/kubo_save_button.dart';
import '../../chat/screens/chat_page.dart';
import '../../login/services/auth_service.dart';
import '../../saved/providers/saved_listings_controller.dart';

/// Detail screen for a single listing item selected from a card grid.
///
/// Pops with `true` when the signed-in seller changed or removed the
/// listing from here, so list screens know to reload.
class ListingPage extends StatefulWidget {
  const ListingPage({super.key, required this.listing});

  static const routeName = '/listing';

  final SyntheticListingRecord listing;

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  late final ListingPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ListingPageController(listing: widget.listing);
    _controller.loadMarketReference();
  }

  // Seller-only: edit, mark sold out / restore, or remove.
  Future<void> _manage(
    BuildContext context,
    SyntheticListingRecord listing,
  ) async {
    final outcome = await showManageListingSheet(context, listing);
    if (outcome == null || !context.mounted) return;
    if (outcome.removed) {
      _controller.markRemoved();
      Navigator.of(context).pop(true);
      return;
    }
    _controller.replaceListing(outcome.listing!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.listing!.isSoldOut
              ? 'Marked as sold out. Buyers can no longer make offers.'
              : 'Listing updated.',
        ),
      ),
    );
  }

  Future<void> _makeOffer(
    BuildContext context,
    SyntheticListingRecord listing,
  ) async {
    final offer = await showMakeOfferDialog(context, listing);
    if (offer == null || !context.mounted) return;
    // The offer is the first message of the thread; land the buyer in it.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(conversationId: offer.conversationId),
      ),
    );
  }

  // Opens (or creates) the buyer's thread on this listing without an offer.
  Future<void> _message(
    BuildContext context,
    SyntheticListingRecord listing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final buyerId = AuthService.currentUserId;
    final productId = listing.productId;
    if (buyerId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Log in to message the seller.')));
      return;
    }
    if (productId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('This listing cannot be messaged.')));
      return;
    }
    final service = MessageService();
    try {
      final thread = await service.openConversation(productId: productId);
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatPage(conversationId: thread.id)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      service.dispose();
    }
  }

  Future<void> _share(SyntheticListingRecord listing) async {
    final where = listing.locationLabel.isEmpty ? '' : ' in ${listing.locationLabel}';
    await Share.share(
      '${listing.title}, ${listing.price}$where.\n\n'
      'See it on Kubo: https://kubo.app/listing/${listing.productId}',
      subject: '${listing.title} on Kubo',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // The carousel heart reads the app-wide saved set, so a toggle here or
      // on any card behind this page repaints it.
      animation: Listenable.merge([_controller, SavedListingsController.instance]),
      builder: (_, __) {
        final listing = _controller.listing;
        final isOwner = listing.isOwnedBy(AuthService.currentUserId);
        final canSave = KuboSaveButton.canSave(listing);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            Navigator.of(context).pop(_controller.changed);
          },
          child: Scaffold(
            backgroundColor: AppColors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListingImageCarousel(
                      images: _controller.images,
                      isFavorite: SavedListingsController.instance.isSaved(
                        listing.productId,
                      ),
                      onBackPressed:
                          () => Navigator.of(context).pop(_controller.changed),
                      onFavoriteToggle: canSave
                          ? () => KuboSaveButton.toggle(context, listing)
                          : null,
                      onShare: listing.productId == null ? null : () => _share(listing),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.price,
                                      style: const TextStyle(
                                        color: AppColors.green,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    // The buyer's overprice check: how the
                                    // asking price sits against Market Watch.
                                    MarketReferenceLine(
                                      reference: _controller.marketReference,
                                      askingPrice: listing.basePrice,
                                      unit: listing.unit,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      listing.title,
                                      style: const TextStyle(
                                        color: AppColors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        if (listing.isSoldOut)
                                          const ListingTag(label: 'Sold out'),
                                        if (listing.isPreorder)
                                          const ListingTag(label: 'Pre-order'),
                                        if (listing.qualityGrade != null)
                                          ListingTag(
                                            label: ListingOptions.labelOf(ListingOptions.qualityGrades, listing.qualityGrade),
                                          ),
                                        if (listing.farmingMethod != null && listing.farmingMethod != 'conventional')
                                          ListingTag(
                                            label: ListingOptions.labelOf(ListingOptions.farmingMethods, listing.farmingMethod),
                                          ),
                                        ListingTag(label: listing.regionLabel),
                                        ...listing.groups
                                            .take(2)
                                            .map(
                                              (groupName) => ListingTag(
                                                label: ListingOptions.labelOf(ListingOptions.categories, groupName),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Column(
                            children: [
                              ListingInfoRow(
                                icon: Icons.location_on_outlined,
                                value: listing.locationLabel,
                              ),
                              const SizedBox(height: 8),
                              if (listing.availableQuantity != null) ...[
                                ListingInfoRow(
                                  icon: Icons.inventory_2_outlined,
                                  value: '${formatQuantity(listing.availableQuantity!)} ${listing.unit ?? ''} available',
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (listing.harvestDate != null) ...[
                                ListingInfoRow(
                                  icon: Icons.agriculture_outlined,
                                  value: listing.isPreorder
                                      ? 'Expected harvest ${formatListingDate(listing.harvestDate!)}'
                                      : 'Harvested ${formatListingDate(listing.harvestDate!)}',
                                ),
                                const SizedBox(height: 8),
                              ],
                              ListingInfoRow(
                                icon: Icons.favorite_border,
                                value: '${listing.numLikes} likes',
                              ),
                              const SizedBox(height: 8),
                              ListingInfoRow(
                                icon: Icons.calendar_today_outlined,
                                value: listing.date,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'About this listing',
                            style: TextStyle(
                              color: AppColors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            listing.description,
                            style: const TextStyle(
                              color: AppColors.gray,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          if (listing.productId != null) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Deal method',
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (listing.allowsMeetup)
                              const _DealMethodRow(
                                icon: Icons.warehouse_outlined,
                                title: 'Meet-up',
                                subtitle: 'Pick it up at a bagsakan center',
                              ),
                            if (listing.allowsDelivery)
                              const _DealMethodRow(
                                icon: Icons.local_shipping_outlined,
                                title: 'Delivery',
                                subtitle: 'The farmer ships it by courier',
                              ),
                          ],
                          const SizedBox(height: 24),
                          SellerCard(listing: listing),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child:
                    isOwner
                        // The seller has nothing to message or offer on; give
                        // them the manage actions instead.
                        ? ActionButton(
                          label: 'Manage listing',
                          color: AppColors.green,
                          textColor: AppColors.white,
                          onPressed: () => _manage(context, listing),
                        )
                        : Row(
                          children: [
                            Expanded(
                              child: ActionButton(
                                label: 'Message',
                                color: AppColors.softBackground,
                                textColor: AppColors.black,
                                onPressed: () => _message(context, listing),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ActionButton(
                                label: 'Make Offer',
                                color: AppColors.green,
                                textColor: AppColors.white,
                                onPressed: () => _makeOffer(context, listing),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DealMethodRow extends StatelessWidget {
  const _DealMethodRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.softBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
