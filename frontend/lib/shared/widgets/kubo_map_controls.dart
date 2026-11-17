import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';

/// How every map in the app answers touch: drag to pan, pinch, double-tap or
/// scroll to zoom, and nothing else. The map never rotates, so north stays
/// up and place names stay level; a map that turns under two fingers is easy
/// to knock askew while zooming and there is no compass here to put it back.
/// That covers the two-finger twist and the desktop Ctrl-drag alike.
final InteractionOptions kuboMapInteraction = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
  cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
);

/// Zoom range shared by the app's maps: from the whole country down to
/// street level. OpenStreetMap's tiles stop at 19.
const double kuboMapMinZoom = 4.5;
const double kuboMapMaxZoom = 18;

/// The Philippines with a margin. The centre of a map cannot be dragged
/// outside it, so nobody ends up lost in open sea.
final CameraConstraint kuboMapBounds = CameraConstraint.containCenter(
  bounds: LatLngBounds(const LatLng(3.5, 115.5), const LatLng(22.0, 128.0)),
);

/// Centre and zoom that show the whole country, for a map with nothing to
/// frame yet.
const LatLng kuboMapCountryCentre = LatLng(12.3, 122.5);
const double kuboMapCountryZoom = 5.2;

/// Square button drawn over a map: the zoom buttons below, and the mode and
/// size toggles on the explore map.
class KuboMapButton extends StatelessWidget {
  const KuboMapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;

  /// Highlights the button green while its mode is the active one.
  final bool selected;

  /// Null draws the button dimmed: there is nothing more to do that way.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? AppColors.green : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            // 40 points: big enough to hit without covering the map.
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.white
                  : enabled
                      ? AppColors.black
                      : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plus and minus for a map, for anyone who would rather tap than pinch
/// (one-handed use, a mouse, an emulator). Each tap glides one zoom level
/// and keeps the centre where it is; a button dims at the end of its range.
class KuboMapZoomControls extends StatefulWidget {
  const KuboMapZoomControls({super.key, required this.controller});

  /// The controller of the map these buttons sit on. The map must be built
  /// before they are tapped.
  final MapController controller;

  @override
  State<KuboMapZoomControls> createState() => _KuboMapZoomControlsState();
}

class _KuboMapZoomControlsState extends State<KuboMapZoomControls> with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _zoom;

  @override
  void initState() {
    super.initState();
    _glide.addListener(_step);
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  /// Where the last tap is heading, so a second tap mid-glide adds to it.
  double? _target;

  // The map's camera, or null in the moment before the map is first laid out.
  MapCamera? get _camera {
    try {
      return widget.controller.camera;
    } on Exception {
      return null;
    }
  }

  void _step() {
    final zoom = _zoom;
    final camera = _camera;
    if (zoom == null || camera == null) return;
    widget.controller.move(camera.center, zoom.value);
  }

  void _zoomBy(double levels) {
    final camera = _camera;
    if (camera == null) return;
    final gliding = _glide.isAnimating;
    final target = ((gliding ? _target ?? camera.zoom : camera.zoom) + levels)
        .clamp(kuboMapMinZoom, kuboMapMaxZoom)
        .toDouble();
    _target = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _glide.stop();
      widget.controller.move(camera.center, target);
      return;
    }
    // The curve rides on the tween rather than on a CurvedAnimation, which
    // would leave one more listener on _glide with every tap.
    _zoom = _glide.drive(
      Tween<double>(begin: camera.zoom, end: target).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _glide.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds as the map moves, so the buttons dim at the ends of the range.
    return StreamBuilder<MapEvent>(
      stream: widget.controller.mapEventStream,
      builder: (context, _) {
        final zoom = _camera?.zoom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KuboMapButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onTap: zoom != null && zoom >= kuboMapMaxZoom - 0.01 ? null : () => _zoomBy(1),
            ),
            const SizedBox(height: 8),
            KuboMapButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onTap: zoom != null && zoom <= kuboMapMinZoom + 0.01 ? null : () => _zoomBy(-1),
            ),
          ],
        );
      },
    );
  }
}
