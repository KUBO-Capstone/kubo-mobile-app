import 'dart:math' as math;

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
/// street level. OpenStreetMap's tiles stop at 19. How far out a map really
/// goes is set by [kuboMapBounds], which depends on the map's size; this is
/// only the floor below that.
const double kuboMapMinZoom = 4.5;
const double kuboMapMaxZoom = 18;

/// How far any map can show: the Philippine Area of Responsibility (PAR,
/// 5–25°N, 115–135°E), widened a little to the south and west so the whole
/// country stays reachable (Tawi-Tawi's southern islands sit near 4.6°N,
/// Pag-asa in the Kalayaan group near 114.3°E). Bits of the neighbours
/// inside this box (Taiwan, northern Borneo) are unavoidable.
final LatLngBounds kuboPhilippineArea = LatLngBounds(const LatLng(4.0, 114.0), const LatLng(25.0, 135.0));

/// Keeps every map's whole view inside [kuboPhilippineArea]: it cannot be
/// zoomed out past the point where that area fills the map, or panned past
/// its edges.
final KuboContainCamera kuboMapBounds = KuboContainCamera(kuboPhilippineArea);

/// A camera constraint that keeps the map's visible edges inside [bounds].
///
/// flutter_map's own `CameraConstraint.contain` drops a whole move that would
/// show anything outside, so a pinch or the zoom-out button stops short and
/// a resized map can be left stuck outside. This one moves the camera to the
/// nearest view that fits instead: zoomed in just enough, then slid back in.
class KuboContainCamera extends CameraConstraint {
  const KuboContainCamera(this.bounds);

  final LatLngBounds bounds;

  /// The furthest-out zoom at which [bounds] still cover the whole view of
  /// [camera], which depends on the map's size on screen.
  double minZoomFor(MapCamera camera) {
    final size = camera.size;
    if (!_isLaidOut(size)) return camera.zoom;
    final northEast = camera.projectAtZoom(bounds.northEast, camera.zoom);
    final southWest = camera.projectAtZoom(bounds.southWest, camera.zoom);
    final spanWidth = (northEast.dx - southWest.dx).abs();
    final spanHeight = (northEast.dy - southWest.dy).abs();
    if (spanWidth == 0 || spanHeight == 0) return camera.zoom;
    // Each zoom level doubles the area's size on screen.
    final scale = math.max(size.width / spanWidth, size.height / spanHeight);
    return camera.zoom + math.log(scale) / math.ln2;
  }

  static bool _isLaidOut(Size size) => size.isFinite && size.width > 0 && size.height > 0;

  @override
  MapCamera constrain(MapCamera camera) {
    // Before the first layout the map has no real size to fit yet.
    if (!_isLaidOut(camera.size)) return camera;
    // A hair over the limit, so rounding can never make the area fall short.
    final minZoom = minZoomFor(camera) + 1e-6;
    final zoomed = camera.zoom < minZoom ? camera.withPosition(zoom: minZoom) : camera;
    return CameraConstraint.contain(bounds: bounds).constrain(zoomed) ?? zoomed;
  }

  @override
  bool operator ==(Object other) => other is KuboContainCamera && other.bounds == bounds;

  @override
  int get hashCode => bounds.hashCode;
}

/// For `MapOptions.onMapEvent` on every map using [kuboMapBounds]. The
/// constraint applies when the map moves, not when it is resized, so a map
/// that grows (the explore map expanded, a phone turned) could be left
/// showing past the edges, and flutter_map's debug check would then fail.
/// On each size change, including the first layout, the camera is put back
/// inside.
ValueChanged<MapEvent> kuboMapKeepInBounds(MapController controller) {
  return (event) {
    if (event is! MapEventNonRotatedSizeChange) return;
    final camera = controller.camera;
    // move() runs the constraint, which does the putting back.
    if (kuboMapBounds.constrain(camera) != camera) controller.move(camera.center, camera.zoom);
  };
}

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

  // How far out this map can go at its current size: the Philippine area
  // filling it, never below the shared floor.
  static double _minZoom(MapCamera camera) => math.max(kuboMapMinZoom, kuboMapBounds.minZoomFor(camera));

  void _zoomBy(double levels) {
    final camera = _camera;
    if (camera == null) return;
    final gliding = _glide.isAnimating;
    final target = ((gliding ? _target ?? camera.zoom : camera.zoom) + levels)
        .clamp(_minZoom(camera), kuboMapMaxZoom)
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
        final camera = _camera;
        final zoom = camera?.zoom;
        final minZoom = camera == null ? kuboMapMinZoom : _minZoom(camera);
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
              onTap: zoom != null && zoom <= minZoom + 0.01 ? null : () => _zoomBy(-1),
            ),
          ],
        );
      },
    );
  }
}
