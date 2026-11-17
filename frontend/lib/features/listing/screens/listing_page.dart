import 'dart:async';
import 'dart:ui' show ImageFilter;

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
import '../../shell/providers/app_shell_controller.dart';

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
  late final StreamSubscription<void> _listingsChanged;
  final ScrollController _scroll = ScrollController();

  /// 0 while the photos fill the top of the screen, 1 once they have
  /// scrolled away: the top bar goes from floating buttons to a solid bar.
  final ValueNotifier<double> _barSolidity = ValueNotifier<double>(0);

  // The bar turns solid over the last stretch of the photos rather than at a
  // single pixel, so it never flickers while the user scrolls slowly there.
  static const double _fadeDistance = 64;

  void _onScroll() {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final start =
        ListingImageCarousel.height - _ListingTopBar.height - _fadeDistance;
    _barSolidity.value = ((offset - start) / _fadeDistance).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller = ListingPageController(listing: widget.listing);
    _controller.loadMarketReference();
    // The card this opened from may be behind on stock; show what is left now,
    // and again whenever a deal takes stock or gives it back.
    _controller.refresh();
    _listingsChanged = AppShellController.instance.listingsChanged.listen(
      (_) => _controller.refresh(),
    );
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(conversationId: offer.conversationId),
      ),
    );
    // The offer may have been accepted in there, which takes stock.
    _controller.refresh();
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Log in to message the seller.')),
      );
      return;
    }
    if (productId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This listing cannot be messaged.')),
      );
      return;
    }
    final service = MessageService();
    try {
      final thread = await service.openConversation(productId: productId);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(conversationId: thread.id),
        ),
      );
      _controller.refresh();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      service.dispose();
    }
  }

  Future<void> _share(SyntheticListingRecord listing) async {
    final where =
        listing.locationLabel.isEmpty ? '' : ' in ${listing.locationLabel}';
    await Share.share(
      '${listing.title}, ${listing.price}$where.\n\n'
      'See it on Kubo: https://kubo.app/listing/${listing.productId}',
      subject: '${listing.title} on Kubo',
    );
  }

  @override
  void dispose() {
    _listingsChanged.cancel();
    _scroll.dispose();
    _barSolidity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // The carousel heart reads the app-wide saved set, so a toggle here or
      // on any card behind this page repaints it.
      animation: Listenable.merge([
        _controller,
        SavedListingsController.instance,
      ]),
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
              // The top bar sits over the scrolling page and stays put, so
              // Back and Share are always one tap away however far down the
              // details the user has read.
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scroll,
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
                              () => Navigator.of(
                                context,
                              ).pop(_controller.changed),
                          onFavoriteToggle:
                              canSave
                                  ? () =>
                                      KuboSaveButton.toggle(context, listing)
                                  : null,
                          onShare:
                              listing.productId == null
                                  ? null
                                  : () => _share(listing),
                          showControls: false,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          reference:
                                              _controller.marketReference,
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
                                              const ListingTag(
                                                label: 'Sold out',
                                              ),
                                            if (listing.isPreorder)
                                              const ListingTag(
                                                label: 'Pre-order',
                                              ),
                                            if (listing.qualityGrade != null)
                                              ListingTag(
                                                label: ListingOptions.labelOf(
                                                  ListingOptions.qualityGrades,
                                                  listing.qualityGrade,
                                                ),
                                              ),
                                            if (listing.farmingMethod != null &&
                                                listing.farmingMethod !=
                                                    'conventional')
                                              ListingTag(
                                                label: ListingOptions.labelOf(
                                                  ListingOptions.farmingMethods,
                                                  listing.farmingMethod,
                                                ),
                                              ),
                                            ListingTag(
                                              label: listing.regionLabel,
                                            ),
                                            ...listing.groups
                                                .take(2)
                                                .map(
                                                  (groupName) => ListingTag(
                                                    label:
                                                        ListingOptions.labelOf(
                                                          ListingOptions
                                                              .categories,
                                                          groupName,
                                                        ),
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
                                      value:
                                          '${formatQuantity(listing.availableQuantity!)} ${listing.unit ?? ''} available',
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (listing.harvestDate != null) ...[
                                    ListingInfoRow(
                                      icon: Icons.agriculture_outlined,
                                      value:
                                          listing.isPreorder
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
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _barSolidity,
                      builder:
                          (context, solidity, _) => _ListingTopBar(
                            solidity: solidity,
                            title: listing.title,
                            onBack:
                                () => Navigator.of(
                                  context,
                                ).pop(_controller.changed),
                            onShare:
                                listing.productId == null
                                    ? null
                                    : () => _share(listing),
                            isSaved: SavedListingsController.instance.isSaved(
                              listing.productId,
                            ),
                            onSave:
                                canSave
                                    ? () =>
                                        KuboSaveButton.toggle(context, listing)
                                    : null,
                          ),
                    ),
                  ),
                ],
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

/// Back, Share and Save, kept at the top of the listing page while it
/// scrolls. Over the photos they float as round white buttons; once the
/// photos have scrolled away the bar fills in behind them (frosted, with a
/// hairline under it) and the listing's title fades in, so the buttons stay
/// readable over text and cards.
class _ListingTopBar extends StatelessWidget {
  const _ListingTopBar({
    required this.solidity,
    required this.title,
    required this.onBack,
    required this.isSaved,
    this.onShare,
    this.onSave,
  });

  static const double height = 60;

  /// 0 over the photos, 1 once they are gone.
  final double solidity;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final bool isSaved;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (onShare != null)
        _TopBarButton(
          icon: Icons.share_outlined,
          tooltip: 'Share listing',
          solidity: solidity,
          onPressed: onShare!,
        ),
      if (onShare != null && onSave != null) const SizedBox(width: 8),
      if (onSave != null)
        _TopBarButton(
          icon: isSaved ? Icons.favorite : Icons.favorite_border,
          color: isSaved ? AppColors.green : AppColors.black,
          tooltip: isSaved ? 'Remove from saved' : 'Save listing',
          solidity: solidity,
          onPressed: onSave!,
        ),
    ];
    final bar = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92 * solidity),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: solidity),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _TopBarButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            solidity: solidity,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          // Only there once the heading has scrolled away under it, and
          // hidden from screen readers, which read the page's own heading.
          Expanded(
            child:
                solidity == 0
                    ? const SizedBox.shrink()
                    : ExcludeSemantics(
                      child: Opacity(
                        opacity: solidity,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          ...buttons,
        ],
      ),
    );
    if (solidity == 0) return bar;
    // Frosts whatever scrolls under the bar once it has a background.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12 * solidity, sigmaY: 12 * solidity),
        child: bar,
      ),
    );
  }
}

/// A top bar button: a white disc over the photos that melts into the bar
/// as it turns solid, while the icon stays the same size and colour.
class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.solidity,
    required this.onPressed,
    this.color = AppColors.black,
  });

  final IconData icon;
  final String tooltip;
  final double solidity;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.9 * (1 - solidity)),
      shape: const CircleBorder(),
      elevation: 2 * (1 - solidity),
      shadowColor: Colors.black26,
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _DealMethodRow extends StatelessWidget {
  const _DealMethodRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
