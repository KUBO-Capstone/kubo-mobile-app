import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'kubo_listing_card.dart';

const Color _skeletonColor = Color(0xFFEFECE6);

/// A grey block standing in for text or a photo that is still loading.
class KuboSkeletonBox extends StatelessWidget {
  const KuboSkeletonBox({super.key, this.width, this.height, this.radius = 6});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder cards in the listing grid's own layout, pulsing while the
/// first page loads. The feed shows its shape at once instead of a spinner
/// or, worse, a "no listings" message that is not true yet.
class ListingGridSkeleton extends StatefulWidget {
  const ListingGridSkeleton({super.key, this.itemCount = 6}) : sliver = false;

  /// The same grid as a sliver, for feeds built on a CustomScrollView.
  const ListingGridSkeleton.sliver({super.key, this.itemCount = 6}) : sliver = true;

  final int itemCount;
  final bool sliver;

  @override
  State<ListingGridSkeleton> createState() => _ListingGridSkeletonState();
}

class _ListingGridSkeletonState extends State<ListingGridSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.7;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _card(BuildContext context, int index) => const _ListingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    if (widget.sliver) {
      return SliverFadeTransition(
        opacity: _pulse,
        sliver: SliverGrid(
          gridDelegate: kuboListingGridDelegate,
          delegate: SliverChildBuilderDelegate(_card, childCount: widget.itemCount),
        ),
      );
    }
    return Semantics(
      label: 'Loading listings',
      child: FadeTransition(
        opacity: _pulse,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: kuboListingGridDelegate,
          itemCount: widget.itemCount,
          itemBuilder: _card,
        ),
      ),
    );
  }
}

class _ListingCardSkeleton extends StatelessWidget {
  const _ListingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AspectRatio(aspectRatio: 1, child: KuboSkeletonBox(radius: 10)),
              const SizedBox(height: 10),
              KuboSkeletonBox(width: width * 0.85, height: 12),
              const SizedBox(height: 7),
              KuboSkeletonBox(width: width * 0.6, height: 10),
              const SizedBox(height: 7),
              KuboSkeletonBox(width: width * 0.4, height: 10),
            ],
          );
        },
      ),
    );
  }
}

/// Rows of grey blocks shaped like inbox or order rows.
class ListRowsSkeleton extends StatefulWidget {
  const ListRowsSkeleton({super.key, this.rows = 6, this.thumbnailSize = 48});

  final int rows;
  final double thumbnailSize;

  @override
  State<ListRowsSkeleton> createState() => _ListRowsSkeletonState();
}

class _ListRowsSkeletonState extends State<ListRowsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.7;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: _pulse,
        child: ExcludeSemantics(
          child: Column(
            children: [
              for (var i = 0; i < widget.rows; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      KuboSkeletonBox(
                        width: widget.thumbnailSize,
                        height: widget.thumbnailSize,
                        radius: widget.thumbnailSize / 2,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.5 : 0.4,
                              child: const KuboSkeletonBox(height: 12),
                            ),
                            const SizedBox(height: 8),
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.85 : 0.7,
                              child: const KuboSkeletonBox(height: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
