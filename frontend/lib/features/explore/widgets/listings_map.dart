import 'package:flutter/material.dart';
import '../../../shared/widgets/kubo_pressable.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_map_controls.dart';
import '../../listing/screens/listing_page.dart';
import '../models/bagsakan_center.dart';
import '../models/location_result.dart';

/// Which set of pins the map plots. Products is the default; bagsakan centers
/// are the alternate mode behind the warehouse toggle.
enum MapPinMode { products, centers }

/// One map pin: every listing at the same point. That is one farm when the
/// seller saved a farm address, and one town otherwise, since a seller
/// without a farm address is placed at their town.
class _FarmPin {
  _FarmPin({required this.point, required this.listings});

  /// Where the listings are: the farm address, or the seller's town.
  final LatLng point;

  /// Every listing at this point, within the active filters.
  final List<SyntheticListingRecord> listings;

  /// How many different sellers those listings belong to.
  int get sellerCount =>
      listings.map<Object>((listing) => listing.sellerId ?? listing.sellerLabel).toSet().length;
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

  /// Identifies what is on screen, ignoring list instance churn. A listing
  /// counts with where it is plotted: the same listings come back from a
  /// refresh with a point once their town has been looked up, and the camera
  /// has to move to the pins that appear.
  String _signature(ListingsMap w) {
    final ids =
        _modeOf(w) == MapPinMode.products
            ? w.listings.map(
              (record) => '${record.id}@${record.latitude},${record.longitude}',
            )
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

  // The recenter button: back to every pin, or to the whole country when
  // there is nothing to frame.
  void _recenter() {
    if (_cameraPoints.isEmpty) {
      _mapController.move(kuboMapCountryCentre, kuboMapCountryZoom);
      return;
    }
    _fitPoints();
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
        final count = pin.listings.length;
        final sellers = pin.sellerCount;
        final listingsLabel = '$count listing${count == 1 ? '' : 's'}';
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
                  // A town's pin can hold several sellers' listings.
                  sellers == 1
                      ? '${first.sellerLabel} - $listingsLabel'
                      : '$listingsLabel from $sellers sellers',
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.title,
                                      style: const TextStyle(
                                        color: AppColors.black,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (sellers > 1)
                                      Text(
                                        listing.sellerLabel,
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
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

    if (_isProducts) {
      // Listings without a point are ones whose town is still being looked
      // up on the server; a refresh a little later picks them up.
      return widget.listings.isEmpty
          ? 'No listings$_regionSuffix to show on the map yet.'
          : 'These listings are not on the map yet. Pull down to refresh in a moment.';
    }
    return 'No bagsakan centers$_regionSuffix yet.';
  }

  @override
  Widget build(BuildContext context) {
    final farmPins = _farmPins;
    final centers = _plottableCenters;
    final isProducts = _isProducts;
    final onPinModeChanged = widget.onPinModeChanged;
    final hasPins = isProducts ? farmPins.isNotEmpty : centers.isNotEmpty;
    final cameraPoints = _cameraPoints;
    final focus = widget.focusLocation;

    // The map is always drawn, pins or no pins. An empty map with a line
    // saying why still shows where the user is looking, and lets them move
    // around or switch to the other pin set; a grey box in its place read as
    // the map being broken.
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
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              // One pin: that pin, close up. Nothing to
                              // frame: the whole country.
                              initialCenter:
                                  cameraPoints.isNotEmpty
                                      ? cameraPoints.first
                                      : focus != null
                                      ? LatLng(focus.latitude, focus.longitude)
                                      : kuboMapCountryCentre,
                              initialZoom:
                                  cameraPoints.isEmpty && focus == null
                                      ? kuboMapCountryZoom
                                      : 11,
                              // Frame every pin at once, widening to the radius
                              // circle when a distance filter is active.
                              initialCameraFit:
                                  cameraPoints.length > 1
                                      ? CameraFit.coordinates(
                                        coordinates: cameraPoints,
                                        padding: const EdgeInsets.all(48),
                                        maxZoom: 13,
                                      )
                                      : null,
                              // Pan and zoom only; the map never rotates.
                              interactionOptions: kuboMapInteraction,
                              minZoom: kuboMapMinZoom,
                              maxZoom: kuboMapMaxZoom,
                              cameraConstraint: kuboMapBounds,
                              // A resize can leave the view past the limit; put it back.
                              onMapEvent: kuboMapKeepInBounds(_mapController),
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
                                        width: _MapPin.markerWidth,
                                        height: _MapPin.markerHeight,
                                        alignment: Alignment.topCenter,
                                        child: KuboPressable(
                                          onTap:
                                              () => _showFarmListings(context, pin),
                                          child: _FarmMarker(
                                            listingCount: pin.listings.length,
                                          ),
                                        ),
                                      )
                                  else
                                    for (final center in centers)
                                      Marker(
                                        point: LatLng(
                                          center.latitude!,
                                          center.longitude!,
                                        ),
                                        width: _MapPin.markerWidth,
                                        height: _MapPin.markerHeight,
                                        alignment: Alignment.topCenter,
                                        child: KuboPressable(
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
                              // Bottom left: the buttons own the right edge.
                              const RichAttributionWidget(
                                alignment: AttributionAlignment.bottomLeft,
                                attributions: [
                                  TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                            ],
                          ),
                ),

                // With nothing plotted, say why rather than leaving the user
                // to guess.
                if (!hasPins)
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
                        KuboMapButton(
                          icon: Icons.inventory_2_outlined,
                          tooltip: 'Show produce listings',
                          selected: isProducts,
                          onTap: () => onPinModeChanged(MapPinMode.products),
                        ),
                        const SizedBox(height: 8),
                        KuboMapButton(
                          icon: Icons.warehouse_outlined,
                          tooltip: 'Show bagsakan centers',
                          selected: !isProducts,
                          onTap: () => onPinModeChanged(MapPinMode.centers),
                        ),
                      ],
                    ),
                  ),

                // Bottom right, top to bottom: back to the pins, zoom in and
                // out, then minimize / expand. The collapsed strip only has
                // room for the last one; pinching still zooms it.
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.minimized) ...[
                        KuboMapButton(
                          icon: Icons.center_focus_strong_outlined,
                          tooltip: hasPins ? 'Show all pins' : 'Show the whole country',
                          onTap: _recenter,
                        ),
                        const SizedBox(height: 8),
                        KuboMapZoomControls(controller: _mapController),
                        const SizedBox(height: 8),
                      ],
                      KuboMapButton(
                        icon:
                            widget.minimized
                                ? Icons.open_in_full
                                : Icons.close_fullscreen,
                        tooltip: widget.minimized ? 'Expand map' : 'Minimize map',
                        onTap: widget.onToggleMinimized,
                      ),
                    ],
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

  /// Summary line that also calls out listings not on the map yet.
  String _listingSummary(List<_FarmPin> pins) {
    final plotted = pins.fold<int>(0, (sum, pin) => sum + pin.listings.length);
    final missing = widget.listings.length - plotted;
    if (missing > 0) {
      return '$plotted of ${widget.listings.length} listings mapped, '
          '$missing not on the map yet';
    }
    return '$plotted listing${plotted == 1 ? '' : 's'} in '
        '${pins.length} location${pins.length == 1 ? '' : 's'}';
  }
}

/// Shared map pin shape so produce and bagsakan markers differ only by what
/// is in the circle and its colour, matching the toggle icons in the map's
/// corner.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color, this.count});

  /// Width and height of a marker drawing this pin: the head (circle plus
  /// room for the badge) and the arrow under it.
  static const double markerWidth = 44;
  static const double markerHeight = 52;

  final IconData icon;
  final Color color;

  /// How many things the pin stands for. Two or more show as a badge on the
  /// circle's top right; the icon always stays.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The circle sits at the bottom centre, leaving room above and to
        // its right for the badge to overlap its corner.
        SizedBox(
          width: markerWidth,
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
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
              if (count != null && count > 1)
                Positioned(top: 0, right: 0, child: _CountBadge(count: count)),
            ],
          ),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 18),
      ],
    );
  }
}

/// The number on a pin's top right: how many listings are at that place.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        // Fixed size: the badge does not grow with the text scale.
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// Brand-green pin marking a place with produce listed: the produce icon,
/// with a badge counting the listings there when there is more than one.
class _FarmMarker extends StatelessWidget {
  const _FarmMarker({required this.listingCount});

  final int listingCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$listingCount listing${listingCount == 1 ? '' : 's'} here',
      child: _MapPin(
        icon: Icons.inventory_2_outlined,
        color: AppColors.green,
        count: listingCount,
      ),
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
