import 'package:flutter/material.dart';

import '../providers/listing_page_controller.dart';
import '../widgets/action_button.dart';
import '../widgets/listing_image_carousel.dart';
import '../widgets/listing_info_row.dart';
import '../widgets/listing_tag.dart';
import '../widgets/seller_card.dart';
import '../widgets/make_offer_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';

/// Detail screen for a single listing item selected from a card grid.
class ListingPage extends StatefulWidget {
  const ListingPage({super.key, required this.listing});

  static const routeName = '/listing';

  final SyntheticListingRecord listing;

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  static const List<String> _listingImages = <String>[
    'https://picsum.photos/id/1018/600/400',
    'https://picsum.photos/id/1015/600/400',
    'https://picsum.photos/id/1016/600/400',
  ];

  late final ListingPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ListingPageController(
      listing: widget.listing,
      images: _listingImages,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final listing = _controller.listing;

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListingImageCarousel(
                    images: _controller.images,
                    isFavorite: _controller.isFavorite,
                    onBackPressed: () => Navigator.of(context).pop(),
                    onFavoriteToggle: _controller.toggleFavorite,
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
                                      ListingTag(label: listing.regionLabel),
                                      ...listing.groups
                                          .take(2)
                                          .map((groupName) => ListingTag(label: groupName)),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Message',
                      color: AppColors.softBackground,
                      textColor: AppColors.black,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'Make Offer',
                      color: AppColors.green,
                      textColor: AppColors.white,
                      onPressed: () => showMakeOfferDialog(context, 'display name', listing.price),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

