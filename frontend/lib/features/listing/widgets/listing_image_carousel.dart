import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_image.dart';
import '../../../shared/widgets/kubo_photo_viewer.dart';

/// The listing's photos across the top of the listing page. Tapping one opens
/// it full screen, where the user can swipe, zoom and drag it closed.
class ListingImageCarousel extends StatefulWidget {
  const ListingImageCarousel({
    super.key,
    required this.images,
    required this.onBackPressed,
    required this.onFavoriteToggle,
    required this.isFavorite,
    this.onShare,
  });

  final List<String> images;
  final VoidCallback onBackPressed;

  /// Null hides the heart (the viewer's own listing, or a mock row).
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;

  /// Null hides the share button (mock rows have nothing to link to).
  final VoidCallback? onShare;

  @override
  State<ListingImageCarousel> createState() => _ListingImageCarouselState();
}

class _ListingImageCarouselState extends State<ListingImageCarousel> {
  static const double _height = 300;

  final CarouselSliderController _carousel = CarouselSliderController();

  // Tells this carousel's photos apart from the same listing opened again
  // further up the stack.
  final Object _gallery = Object();
  int _currentIndex = 0;

  Object _heroTag(int index) => KuboPhotoHeroTag(_gallery, index);

  // Fixed from the screen width rather than laid out, so a hero flight that
  // resizes the photo does not decode it again on every frame.
  int? _decodeWidth(BuildContext context) =>
      kuboDecodeWidthFor(context, width: MediaQuery.sizeOf(context).width, height: _height);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheNext(_currentIndex);
  }

  void _precacheNext(int index) {
    final next = index + 1;
    if (next < widget.images.length) {
      precacheKuboImage(context, widget.images[next], decodeWidth: _decodeWidth(context));
    }
  }

  void _openViewer(int index) {
    final decodeWidth = _decodeWidth(context);
    KuboPhotoViewer.open(
      context,
      photos: widget.images,
      initialIndex: index,
      heroTagFor: _heroTag,
      // The slide already decoded is the instant stand-in for the full photo.
      placeholderFor: (i) => kuboImageProvider(widget.images[i], decodeWidth: decodeWidth),
      // Follow along underneath so closing flies back to the photo on screen.
      onPageChanged: (i) {
        if (mounted && i != _currentIndex) _carousel.jumpToPage(i);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final decodeWidth = _decodeWidth(context);

    return Stack(
      children: [
        CarouselSlider(
          carouselController: _carousel,
          items: [
            for (var i = 0; i < images.length; i++)
              Semantics(
                button: true,
                label: images.length > 1 ? 'Photo ${i + 1} of ${images.length}' : 'Listing photo',
                onTapHint: 'view full screen',
                onTap: () => _openViewer(i),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _openViewer(i),
                  child: Hero(
                    tag: _heroTag(i),
                    // Keep the slide on screen while its copy flies.
                    placeholderBuilder: (context, size, child) => child,
                    child: KuboImage(
                      images[i],
                      width: double.infinity,
                      height: _height,
                      decodeWidth: decodeWidth,
                      errorIcon: Icons.broken_image_outlined,
                    ),
                  ),
                ),
              ),
          ],
          options: CarouselOptions(
            height: _height,
            autoPlay: false,
            enlargeCenterPage: false,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
              _precacheNext(index);
            },
          ),
        ),
        if (images.length > 1)
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: IgnorePointer(
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
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _OverlayButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: widget.onBackPressed,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              if (widget.onShare != null)
                _OverlayButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Share listing',
                  onPressed: widget.onShare!,
                ),
              if (widget.onShare != null && widget.onFavoriteToggle != null)
                const SizedBox(width: 8),
              if (widget.onFavoriteToggle != null)
                _OverlayButton(
                  icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite ? AppColors.green : AppColors.black,
                  tooltip: widget.isFavorite ? 'Remove from saved' : 'Save listing',
                  onPressed: widget.onFavoriteToggle!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Round white button floating over the photos.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.black,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
