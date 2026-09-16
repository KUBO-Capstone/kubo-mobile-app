import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ListingImageCarousel extends StatefulWidget {
  const ListingImageCarousel({
    super.key,
    required this.images,
    required this.onBackPressed,
    required this.onFavoriteToggle,
    required this.isFavorite,
  });

  final List<String> images;
  final VoidCallback onBackPressed;

  /// Null hides the heart (the viewer's own listing, or a mock row).
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;

  @override
  State<ListingImageCarousel> createState() => _ListingImageCarouselState();
}

class _ListingImageCarouselState extends State<ListingImageCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Stack(
      children: [
        CarouselSlider(
          items: images
              .map(
                (item) => ClipRRect(
                  child: Image.network(
                    item,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              )
              .toList(),
          options: CarouselOptions(
            height: 300,
            autoPlay: false,
            enlargeCenterPage: false,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: images.asMap().entries.map((entry) {
              final isActive = entry.key == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.green : AppColors.gray,
                ),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.black),
              onPressed: widget.onBackPressed,
            ),
          ),
        ),
        if (widget.onFavoriteToggle != null)
          Positioned(
            top: 12,
            right: 12,
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              child: IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite ? AppColors.green : AppColors.black,
                ),
                onPressed: widget.onFavoriteToggle,
              ),
            ),
          ),
      ],
    );
  }
}
