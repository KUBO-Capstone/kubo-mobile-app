import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../listing/screens/listing_page.dart';
import '../models/bagsakan_center.dart';
import '../models/location_result.dart';

/// Which set of pins the map plots. Products is the default; bagsakan centers
/// are the alternate mode behind the warehouse toggle.
enum MapPinMode { products, centers }

/// One map pin representing a single farm address that may host several listings.
class _FarmPin {
  _FarmPin({required this.point, required this.listings});

  /// Coordinate taken from the farm address on the seller's farmer profile.
  final LatLng point;

  /// Every listing sold from this farm, within the active region filter.
  final List<SyntheticListingRecord> listings;
}

/// Map view that plots either farm listings or bagsakan centers onto
/// OpenStreetMap tiles, depending on the active pin mode.
///
/// Shared by the explore tab and the search results page. Pass
/// [onPinModeChanged] to expose the produce/warehouse toggle; leave it null
/// (as search does) to plot products only and hide the toggle.
class ListingsMap extends StatefulWidget {
  const ListingsMap({
    super.key,
    required this.listings,
    required this.minimized,
    required this.onToggleMinimized,
    this.centers = const <BagsakanCenter>[],
    this.pinMode = MapPinMode.products,
    this.regionLabel = 'All',
    this.onPinModeChanged,
    this.focusLocation,
    this.radiusKm = 25,
    this.loadError,
  });

  /// Centre of the active radius filter, drawn as a circle when set.
  final LocationResult? focusLocation;

  /// Radius in kilometres around [focusLocation].
  final double radiusKm;

  /// Listings already narrowed by the shared region filter chips.
  final List<SyntheticListingRecord> listings;

  /// Bagsakan centers narrowed by the same chips.
  final List<BagsakanCenter> centers;

  /// Which pin set to plot. Ignored (always products) when
  /// [onPinModeChanged] is null.
  final MapPinMode pinMode;

  /// Whether the map is collapsed to a strip so the cards get the screen.
  final bool minimized;

  /// Active region chip, or 'All' when the feed is unfiltered.
  final String regionLabel;

  /// Raised when the user taps the produce or warehouse toggle. Null hides
  /// the toggle entirely.
  final ValueChanged<MapPinMode>? onPinModeChanged;

  /// Raised when the user taps the minimize/expand control.
  final VoidCallback onToggleMinimized;

  /// Set when the listing fetch failed, which is distinct from having no pins.
  final String? loadError;

  @override
  State<ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<ListingsMap> {
  /// Drives the camera when filters or pin mode change the visible points.
  final MapController _mapController = MapController();

  /// Expanded and collapsed map heights, per the minimize control.
  static const _expandedHeight = 420.0;
  static const _minimizedHeight = 150.0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ListingsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initialCenter and initialCameraFit only apply to the map's first build,
    // so a region or mode change has to move the camera explicitly or the new
    // pins land off-screen. Compare by content: the parent rebuilds a fresh
    // filtered list every time, and refitting on identity would fight panning.
    if (_signature(oldWidget) != _signature(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPoints());
    }
  }

  /// Effective pin mode: the toggle can only pick centers when it is shown.
  MapPinMode _modeOf(ListingsMap w) =>
      w.onPinModeChanged == null ? MapPinMode.products : w.pinMode;

  bool get _isProducts => _modeOf(widget) == MapPinMode.products;

  /// Identifies what is on screen, ignoring list instance churn.
  String _signature(ListingsMap w) {
    final ids =
        _modeOf(w) == MapPinMode.products
            ? w.listings.map((record) => record.id)
            : w.centers.map((center) => center.id);
    final focus = w.focusLocation;
    final focusKey =
        focus == null ? 'none' : '${focus.latitude},${focus.longitude},${w.radiusKm}';
    return '${_modeOf(w)}:$focusKey:${ids.join(',')}';
  }

  /// Groups listings by coordinate so one farm address renders one pin.
  List<_FarmPin> get _farmPins {
    final grouped = <String, _FarmPin>{};
    for (final listing in widget.listings) {
      if (!listing.hasCoordinates) {
        continue;
      }
      final key = '${listing.latitude},${listing.longitude}';
      grouped
          .putIfAbsent(
            key,
            () => _FarmPin(
              point: LatLng(listing.latitude!, listing.longitude!),
              listings: <SyntheticListingRecord>[],
            ),
          )
          .listings
          .add(listing);
    }
    return grouped.values.toList(growable: false);
  }

  /// Centers that carry coordinates and can therefore be plotted.
  List<BagsakanCenter> get _plottableCenters =>
      widget.centers.where((center) => center.hasCoordinates).toList(growable: false);

  /// Every point currently on the map, whichever mode is active.
  List<LatLng> get _points =>
      _isProducts
          ? _farmPins.map((pin) => pin.point).toList(growable: false)
          : _plottableCenters
              .map((center) => LatLng(center.latitude!, center.longitude!))
              .toList(growable: false);

  /// Points the camera should frame. With a radius active this is the circle's
  /// compass extremes rather than the centre: fitting the centre alone zooms
  /// past the circle, leaving the user no sense of how far the filter reaches.
  List<LatLng> get _cameraPoints {
    final focus = widget.focusLocation;
    if (focus == null) {
      return _points;
    }

    const distance = Distance();
    final centre = LatLng(focus.latitude, focus.longitude);
    final metres = widget.radiusKm * 1000;
    return <LatLng>[
      ..._points,
      for (final bearing in <double>[0, 90, 180, 270])
        distance.offset(centre, metres, bearing),
    ];
  }

  // Frames the current points, zooming in when only one remains.
  void _fitPoints() {
    if (!mounted) {
      return;
    }
    final points = _cameraPoints;
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
        maxZoom: 13,
      ),
    );
  }

  // Opens the same detail page the list-view cards use, closing the pin
  // sheet first so the back button returns to the map rather than the sheet.
  void _openListing(BuildContext sheetContext, SyntheticListingRecord listing) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ListingPage(listing: listing)),
    );
  }

  // Opens a sheet listing every product sold from the tapped farm location.
  void _showFarmListings(BuildContext context, _FarmPin pin) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final first = pin.listings.first;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.locationLabel,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${first.sellerLabel} - ${pin.listings.length} listing'
                  '${pin.listings.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.gray, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pin.listings.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (_, index) {
                      final listing = pin.listings[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _openListing(sheetContext, listing),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  listing.title,
                                  style: const TextStyle(
                                    color: AppColors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                listing.price,
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.gray,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Opens a sheet describing the tapped bagsakan drop-off center.
  void _showCenterDetail(BuildContext context, BagsakanCenter center) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center.name,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        center.addressLine.isEmpty
                            ? '${center.locationLabel}, ${center.regionLabel}'
                            : '${center.addressLine}, ${center.locationLabel}',
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// " in Region III", or empty while the unfiltered 'All' chip is selected.
  String get _regionSuffix =>
      widget.regionLabel == 'All' ? '' : ' in ${widget.regionLabel}';

  /// Empty-state copy that distinguishes a failed fetch from an empty region.
  String get _emptyMessage {
    if (widget.loadError != null && _isProducts) {
      return widget.loadError!;
    }
    // With a radius active the distance is almost always the reason nothing
    // matched, so name it instead of blaming the region.
    if (widget.focusLocation != null) {
      final what = _isProducts ? 'produce' : 'bagsakan centers';
      return 'No $what within ${widget.radiusKm.toStringAsFixed(0)} km of '
          '${widget.focusLocation!.label}. Try a wider radius.';
    }

    return _isProducts
        ? 'No mapped listings$_regionSuffix yet. Sellers need a saved farm '
            'address before they appear on the map.'
        : 'No bagsakan centers$_regionSuffix yet.';
  }

  @override
  Widget build(BuildContext context) {
    final farmPins = _farmPins;
    final centers = _plottableCenters;
    final isProducts = _isProducts;
    final onPinModeChanged = widget.onPinModeChanged;
    final hasPins = isProducts ? farmPins.isNotEmpty : centers.isNotEmpty;

    // Keep the map up whenever a radius is active even with nothing matching:
    // seeing the empty circle is what explains why the results are empty.
    final showMap = hasPins || widget.focusLocation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.minimized ? _minimizedHeight : _expandedHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      showMap
                          ? FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter:
                                  _points.isNotEmpty
                                      ? _points.first
                                      : widget.focusLocation != null
                                      ? LatLng(
                                        widget.focusLocation!.latitude,
                                        widget.focusLocation!.longitude,
                                      )
                                      : const LatLng(12.8797, 121.7740),
                              initialZoom: 11,
                              // Frame every pin at once, widening to the radius
                              // circle when a distance filter is active.
                              initialCameraFit:
                                  _cameraPoints.length > 1
                                      ? CameraFit.coordinates(
                                        coordinates: _cameraPoints,
                                        padding: const EdgeInsets.all(48),
                                        maxZoom: 13,
                                      )
                                      : null,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                // Required by the OpenStreetMap tile usage policy.
                                userAgentPackageName: 'com.example.frontend',
                              ),
                              // Shows how far the distance filter reaches.
                              if (widget.focusLocation != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: LatLng(
                                        widget.focusLocation!.latitude,
                                        widget.focusLocation!.longitude,
                                      ),
                                      radius: widget.radiusKm * 1000,
                                      useRadiusInMeter: true,
                                      color: AppColors.green.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderColor: AppColors.green,
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (isProducts)
                                    for (final pin in farmPins)
                                      Marker(
                                        point: pin.point,
                                        width: 44,
                                        height: 46,
                                        alignment: Alignment.topCenter,
                                        child: GestureDetector(
                                          onTap:
                                              () => _showFarmListings(context, pin),
                                          child: const _FarmMarker(),
                                        ),
                                      )
                                  else
                                    for (final center in centers)
                                      Marker(
                                        point: LatLng(
                                          center.latitude!,
                                          center.longitude!,
                                        ),
                                        width: 44,
                                        height: 46,
                                        alignment: Alignment.topCenter,
                                        child: GestureDetector(
                                          onTap:
                                              () => _showCenterDetail(
                                                context,
                                                center,
                                              ),
                                          child: const _CenterMarker(),
                                        ),
                                      ),
                                ],
                              ),
                              const RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                            ],
                          )
                          : Container(
                            color: AppColors.softBackground,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.gray,
                                fontSize: 14,
                              ),
                            ),
                          ),
                ),

                // With the map still showing an empty circle, say why it is
                // empty rather than leaving the user to guess.
                if (showMap && !hasPins)
                  Positioned(
                    left: 12,
                    right: onPinModeChanged == null ? 12 : 62,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          _emptyMessage,
                          style: const TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Pin-mode toggle: produce listings or bagsakan drop-off points.
                if (onPinModeChanged != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _MapModeButton(
                          icon: Icons.inventory_2_outlined,
                          tooltip: 'Show produce listings',
                          selected: isProducts,
                          onTap: () => onPinModeChanged(MapPinMode.products),
                        ),
                        const SizedBox(height: 8),
                        _MapModeButton(
                          icon: Icons.warehouse_outlined,
                          tooltip: 'Show bagsakan centers',
                          selected: !isProducts,
                          onTap: () => onPinModeChanged(MapPinMode.centers),
                        ),
                      ],
                    ),
                  ),

                // Minimize / expand control.
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: _MapModeButton(
                    icon:
                        widget.minimized
                            ? Icons.open_in_full
                            : Icons.close_fullscreen,
                    tooltip: widget.minimized ? 'Expand map' : 'Minimize map',
                    selected: false,
                    onTap: widget.onToggleMinimized,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasPins) ...[
          const SizedBox(height: 10),
          Text(
            isProducts
                ? _listingSummary(farmPins)
                : '${centers.length} bagsakan center'
                    '${centers.length == 1 ? '' : 's'}$_regionSuffix',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// Summary line that also calls out listings missing a farm address.
  String _listingSummary(List<_FarmPin> pins) {
    final plotted = pins.fold<int>(0, (sum, pin) => sum + pin.listings.length);
    final missing = widget.listings.length - plotted;
    if (missing > 0) {
      return '$plotted of ${widget.listings.length} listings mapped, '
          '$missing without a farm address';
    }
    return '$plotted listing${plotted == 1 ? '' : 's'} across '
        '${pins.length} farm${pins.length == 1 ? '' : 's'}';
  }
}

/// Small translucent square button used for the map overlay controls.
class _MapModeButton extends StatelessWidget {
  const _MapModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Highlights the button green while its mode is the active one.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: selected ? AppColors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared map pin shape so produce and bagsakan markers differ only by icon
/// and colour, matching the toggle icons in the map's corner.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.white),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
}

/// Brand-green pin marking a farm that has produce listed.
class _FarmMarker extends StatelessWidget {
  const _FarmMarker();

  @override
  Widget build(BuildContext context) {
    return const _MapPin(
      icon: Icons.inventory_2_outlined,
      color: AppColors.green,
    );
  }
}

/// Lighter-green pin marking a bagsakan drop-off center.
class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return const _MapPin(
      icon: Icons.warehouse_outlined,
      color: AppColors.greenLight,
    );
  }
}
