import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../data/image_bytes_cache.dart';

/// True for sources fetched over HTTP rather than read from the app bundle.
bool isNetworkImageSource(String source) =>
    source.startsWith('http://') || source.startsWith('https://');

/// The provider [KuboImage] draws [source] with. [decodeWidth] is in physical
/// pixels; null decodes the photo at its own size.
ImageProvider kuboImageProvider(String source, {int? decodeWidth}) {
  final ImageProvider base = isNetworkImageSource(source) ? KuboNetworkImage(source) : AssetImage(source);
  return ResizeImage.resizeIfNeeded(decodeWidth, null, base);
}

// Widths a decode is rounded up to, so one photo drawn at slightly different
// sizes (a 168 and a 171 point card) shares a single decoded copy.
const List<int> _decodeSteps = <int>[64, 96, 128, 192, 256, 384, 512, 640, 768, 1024, 1280, 1536, 2048, 2560];

/// Rounds [physicalWidth] up to the next decode step.
int kuboDecodeWidth(double physicalWidth) {
  for (final step in _decodeSteps) {
    if (step >= physicalWidth) return step;
  }
  return _decodeSteps.last;
}

/// Decode width for a photo laid out [width] × [height] points with [fit].
///
/// A landscape photo covering a box is drawn wider than the box, so cover
/// leaves room for the usual 4:3 camera shot. Null when there is no bounded
/// width to go by.
int? kuboDecodeWidthFor(
  BuildContext context, {
  required double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (width == null || !width.isFinite || width <= 0) return null;
  var logical = width;
  if (fit == BoxFit.cover && height != null && height.isFinite) {
    logical = math.max(width, height * 4 / 3);
  }
  final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  return kuboDecodeWidth(logical * ratio);
}

/// Warms the cache for a photo the user is about to see (the next slide).
Future<void> precacheKuboImage(BuildContext context, String source, {int? decodeWidth}) {
  return precacheImage(
    kuboImageProvider(source, decodeWidth: decodeWidth),
    context,
    onError: (_, __) {},
  );
}

// The decode width each photo was last shown at. A new size of the same
// photo draws that copy underneath while it decodes, so a slide or a full
// screen view opens on the thumbnail instead of an empty box.
final LinkedHashMap<String, int> _shownWidths = LinkedHashMap<String, int>();
const int _shownWidthsLimit = 400;

void _rememberShown(String source, int width) {
  if (_shownWidths[source] == width) return;
  _shownWidths.remove(source);
  _shownWidths[source] = width;
  if (_shownWidths.length > _shownWidthsLimit) {
    _shownWidths.remove(_shownWidths.keys.first);
  }
}

ImageProvider? _earlierCopy(String source, int? decodeWidth) {
  final shown = _shownWidths[source];
  if (shown == null || shown == decodeWidth) return null;
  return kuboImageProvider(source, decodeWidth: shown);
}

/// A listing, profile or bundled photo, decoded at the size it is drawn at.
///
/// [source] is a URL (what `resolveMediaUrl` returns) or an asset path. The
/// photo sits on a soft placeholder (or an already-decoded copy of itself)
/// until it arrives, fades in, and falls back to [errorIcon] if it cannot
/// load. Decoding at display size instead of the upload's full 1600 pixels
/// keeps a grid of cards from holding several megabytes per photo.
class KuboImage extends StatelessWidget {
  const KuboImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.decodeWidth,
    this.fullResolution = false,
    this.placeholder,
    this.semanticLabel,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.backgroundColor = AppColors.softBackground,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// Physical decode width. Null works it out from the space the photo is
  /// laid out in; pass it when that space animates (a hero flight) so the
  /// photo is not decoded again on every frame.
  final int? decodeWidth;

  /// Decodes at the photo's own size, for the full-screen viewer.
  final bool fullResolution;

  /// Drawn underneath until the first frame arrives. Defaults to a copy of
  /// the same photo decoded earlier at another size, when there is one.
  final ImageProvider? placeholder;

  final String? semanticLabel;
  final IconData errorIcon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (fullResolution || decodeWidth != null) {
      return _buildImage(fullResolution ? null : decodeWidth);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final h = height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : null);
        return _buildImage(kuboDecodeWidthFor(context, width: w, height: h, fit: fit));
      },
    );
  }

  Widget _buildImage(int? decode) {
    final underlay = placeholder ?? _earlierCopy(source, decode);
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: kuboImageProvider(source, decodeWidth: decode),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && decode != null) _rememberShown(source, decode);
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: underlay == null
                    ? ColoredBox(color: backgroundColor)
                    : Image(
                        image: underlay,
                        fit: fit,
                        alignment: alignment,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => ColoredBox(color: backgroundColor),
                      ),
              ),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => _BrokenImage(
          icon: errorIcon,
          color: backgroundColor,
          width: width,
          height: height,
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage({required this.icon, required this.color, this.width, this.height});

  final IconData icon;
  final Color color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: color,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            return Center(
              child: Icon(
                icon,
                color: AppColors.gray,
                size: side.isFinite ? (side * 0.4).clamp(12.0, 40.0) : 32,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A photo on the Kubo server, fetched once through [ImageBytesCache] no
/// matter how many sizes it is decoded at (wrap it in [ResizeImage] for a
/// size; [kuboImageProvider] does).
@immutable
class KuboNetworkImage extends ImageProvider<KuboNetworkImage> {
  const KuboNetworkImage(this.url);

  final String url;

  @override
  Future<KuboNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<KuboNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(KuboNetworkImage key, ImageDecoderCallback decode) {
    // Closed by _load once the photo is decoded or has failed.
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunkEvents),
      chunkEvents: chunkEvents.stream,
      scale: 1,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
      ],
    );
  }

  Future<ui.Codec> _load(
    KuboNetworkImage key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    try {
      final bytes = await ImageBytesCache.instance.load(
        url,
        onProgress: (received, total) => chunkEvents.add(
          ImageChunkEvent(cumulativeBytesLoaded: received, expectedTotalBytes: total),
        ),
      );
      try {
        return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      } catch (_) {
        // Bytes that do not decode are not worth keeping for the next size.
        ImageBytesCache.instance.evict(url);
        rethrow;
      }
    } catch (_) {
      // Let a later build try the network again instead of reusing the failure.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    } finally {
      unawaited(chunkEvents.close());
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is KuboNetworkImage && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'KuboNetworkImage')}("$url")';
}
