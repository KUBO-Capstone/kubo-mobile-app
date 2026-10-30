import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kubo_image.dart';

/// Hero tag for photo [index] of one [gallery] on screen. The gallery object
/// tells apart two galleries of the same photos (a listing opened twice in
/// the stack), so a flight only links the photo that was actually tapped.
@immutable
class KuboPhotoHeroTag {
  const KuboPhotoHeroTag(this.gallery, this.index);

  final Object gallery;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is KuboPhotoHeroTag && identical(other.gallery, gallery) && other.index == index;

  @override
  int get hashCode => Object.hash(identityHashCode(gallery), index);
}

/// Full-screen photo viewer for listing and profile photos: swipe between
/// photos, pinch or double-tap to zoom, drag up or down to close, and tap
/// once to hide or show the controls.
class KuboPhotoViewer extends StatefulWidget {
  const KuboPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.heroTagFor,
    this.onPageChanged,
    this.placeholderFor,
  });

  /// URLs or asset paths, in gallery order.
  final List<String> photos;

  final int initialIndex;

  /// The tag each thumbnail is wrapped in; the photo flies in from (and back
  /// to) the one that was tapped.
  final Object Function(int index)? heroTagFor;

  /// Raised as the user swipes, so the opener can keep its own carousel on
  /// the same photo and the flight back lands on the right slide.
  final ValueChanged<int>? onPageChanged;

  /// An already-decoded copy of each photo (the thumbnail's), shown while the
  /// full-resolution one loads.
  final ImageProvider? Function(int index)? placeholderFor;

  /// Opens the viewer above everything, the bottom bar included. Completes
  /// with the index the user closed it on.
  static Future<int?> open(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
    Object Function(int index)? heroTagFor,
    ValueChanged<int>? onPageChanged,
    ImageProvider? Function(int index)? placeholderFor,
  }) {
    if (photos.isEmpty) return Future<int?>.value();
    return Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder<int>(
        // The page underneath stays visible while the photo is dragged away.
        opaque: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => KuboPhotoViewer(
          photos: photos,
          initialIndex: initialIndex.clamp(0, photos.length - 1),
          heroTagFor: heroTagFor,
          onPageChanged: onPageChanged,
          placeholderFor: placeholderFor,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<KuboPhotoViewer> createState() => _KuboPhotoViewerState();
}

class _KuboPhotoViewerState extends State<KuboPhotoViewer> with SingleTickerProviderStateMixin {
  // How far, as a share of the screen height, a drag must travel to close.
  static const double _dismissFraction = 0.14;
  static const double _dismissVelocity = 900;

  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _chromeVisible = true;
  bool _zoomed = false;

  double _dragOffset = 0;
  late final AnimationController _settle;
  Animation<double>? _settleAnimation;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        final animation = _settleAnimation;
        if (animation != null) setState(() => _dragOffset = animation.value);
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAround(_index);
  }

  @override
  void dispose() {
    _settle.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _precacheAround(int index) {
    for (final neighbour in <int>[index - 1, index + 1]) {
      if (neighbour >= 0 && neighbour < widget.photos.length) {
        precacheKuboImage(context, widget.photos[neighbour]);
      }
    }
  }

  void _handlePageChanged(int index) {
    setState(() => _index = index);
    widget.onPageChanged?.call(index);
    _precacheAround(index);
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _close() => Navigator.of(context).pop(_index);

  void _handleDragUpdate(double delta) {
    _settle.stop();
    setState(() => _dragOffset += delta);
  }

  void _handleDragEnd(double velocity) {
    final height = MediaQuery.sizeOf(context).height;
    final flungAway = velocity.abs() > _dismissVelocity && velocity.sign == _dragOffset.sign;
    if (_dragOffset.abs() > height * _dismissFraction || flungAway) {
      _close();
      return;
    }
    _settleAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final progress = (_dragOffset.abs() / (height * 0.4)).clamp(0.0, 1.0);
    final count = widget.photos.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: 1 - progress)),
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Transform.scale(
                scale: 1 - progress * 0.18,
                child: PageView.builder(
                  controller: _pages,
                  // Panning a zoomed photo must not turn the page.
                  physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                  itemCount: count,
                  onPageChanged: _handlePageChanged,
                  itemBuilder: (context, index) => _PhotoPage(
                    source: widget.photos[index],
                    heroTag: widget.heroTagFor?.call(index),
                    placeholder: widget.placeholderFor?.call(index),
                    semanticLabel: count > 1 ? 'Photo ${index + 1} of $count' : 'Photo',
                    onTap: _toggleChrome,
                    onZoomChanged: (zoomed) {
                      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                    },
                    onDragUpdate: _handleDragUpdate,
                    onDragEnd: _handleDragEnd,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !_chromeVisible,
              child: AnimatedOpacity(
                opacity: _chromeVisible ? (1 - progress * 3).clamp(0.0, 1.0) : 0,
                duration: const Duration(milliseconds: 160),
                child: _ViewerChrome(index: _index, count: count, onClose: _close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Close button and "2 / 5" counter over a scrim at the top, page dots at the
/// bottom.
class _ViewerChrome extends StatelessWidget {
  const _ViewerChrome({required this.index, required this.count, required this.onClose});

  final int index;
  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 96,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x99000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    if (count > 1)
                      Text(
                        '${index + 1} / $count',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == index ? 8 : 6,
                          height: i == index ? 8 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == index ? Colors.white : Colors.white38,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One zoomable photo. At normal size a one-finger vertical drag is handed to
/// the viewer to close it; once zoomed, drags pan the photo instead.
class _PhotoPage extends StatefulWidget {
  const _PhotoPage({
    required this.source,
    required this.onTap,
    required this.onZoomChanged,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.heroTag,
    this.placeholder,
    this.semanticLabel,
  });

  final String source;
  final Object? heroTag;
  final ImageProvider? placeholder;
  final String? semanticLabel;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> with SingleTickerProviderStateMixin {
  static const double _maxScale = 4;
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomAnimation;
  Animation<Matrix4>? _zoomTween;

  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;
  bool _dragging = false;

  // Width / height of the photo, so the hero box matches the photo exactly
  // and the flight morphs the thumbnail's crop into the whole picture.
  double? _aspectRatio;
  final List<ImageStream> _streams = <ImageStream>[];
  late final ImageStreamListener _sizeListener = ImageStreamListener(_handleImageInfo, onError: (_, __) {});

  @override
  void initState() {
    super.initState();
    _zoomAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
      ..addListener(() {
        final tween = _zoomTween;
        if (tween != null) _transform.value = tween.value;
      });
    _transform.addListener(_syncZoomed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streams.isEmpty) {
      final configuration = createLocalImageConfiguration(context);
      for (final provider in <ImageProvider?>[widget.placeholder, kuboImageProvider(widget.source)]) {
        if (provider == null) continue;
        _streams.add(provider.resolve(configuration)..addListener(_sizeListener));
      }
    }
  }

  @override
  void dispose() {
    for (final stream in _streams) {
      stream.removeListener(_sizeListener);
    }
    _transform
      ..removeListener(_syncZoomed)
      ..dispose();
    _zoomAnimation.dispose();
    super.dispose();
  }

  void _handleImageInfo(ImageInfo info, bool synchronousCall) {
    final ratio = info.image.width / info.image.height;
    info.dispose();
    if (!mounted || !ratio.isFinite || ratio <= 0 || ratio == _aspectRatio) return;
    setState(() => _aspectRatio = ratio);
  }

  void _syncZoomed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      // Scale about the tapped point so it stays under the finger.
      final point = _doubleTapPosition;
      const scale = _doubleTapScale;
      target = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, -point.dx * (scale - 1))
        ..setEntry(1, 3, -point.dy * (scale - 1));
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOutCubic),
    );
    _zoomAnimation.forward(from: 0);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _zoomAnimation.stop();
    _dragging = !_zoomed && details.pointerCount == 1;
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if (!_dragging) return;
    if (details.pointerCount > 1 || _zoomed) {
      // A second finger turned the drag into a pinch; put the photo back.
      _dragging = false;
      widget.onDragEnd(0);
      return;
    }
    widget.onDragUpdate(details.focalPointDelta.dy);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    widget.onDragEnd(details.velocity.pixelsPerSecond.dy);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final aspectRatio = _aspectRatio;
    Widget photo = KuboImage(
      widget.source,
      // Until the photo's shape is known the box is the screen's, and cover
      // would crop it.
      fit: aspectRatio == null ? BoxFit.contain : BoxFit.cover,
      fullResolution: true,
      placeholder: widget.placeholder,
      semanticLabel: widget.semanticLabel,
      backgroundColor: Colors.transparent,
    );
    final tag = widget.heroTag;
    if (tag != null) photo = Hero(tag: tag, child: photo);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: _maxScale,
        panEnabled: _zoomed,
        onInteractionStart: _handleInteractionStart,
        onInteractionUpdate: _handleInteractionUpdate,
        onInteractionEnd: _handleInteractionEnd,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio ?? screen.width / screen.height,
            child: photo,
          ),
        ),
      ),
    );
  }
}
