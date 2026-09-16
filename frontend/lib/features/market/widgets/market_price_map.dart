import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/market_service.dart';
import 'market_price_table.dart';

/// Map view of a product's area prices (PPA 4–6): a region dropdown, one
/// pin per province/city with data, and the selected area's summary card
/// overlaid at the bottom. Same OSM tiles and camera rules as the explore map.
class MarketPriceMap extends StatefulWidget {
  const MarketPriceMap({
    super.key,
    required this.areas,
    required this.regionNames,
    required this.selectedRegionName,
    required this.selectedArea,
    required this.onRegionChanged,
    required this.onAreaSelected,
    required this.infoCard,
  });

  /// Areas currently plotted (already narrowed to the selected region).
  final List<MarketAreaPrice> areas;
  final List<String> regionNames;
  final String? selectedRegionName;
  final MarketAreaPrice? selectedArea;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<MarketAreaPrice> onAreaSelected;

  /// Card drawn over the bottom of the map for [selectedArea].
  final Widget? infoCard;

  @override
  State<MarketPriceMap> createState() => _MarketPriceMapState();
}

class _MarketPriceMapState extends State<MarketPriceMap> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MarketPriceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same rule as the explore map: initialCameraFit only applies once, so
    // a region change has to move the camera itself. Compare by content.
    if (_signature(oldWidget.areas) != _signature(widget.areas)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  String _signature(List<MarketAreaPrice> areas) =>
      areas.map((a) => '${a.region}|${a.provinceCity}').join(',');

  List<LatLng> get _points => [
        for (final area in widget.areas)
          if (area.hasCoordinates) LatLng(area.latitude!, area.longitude!),
      ];

  void _fit() {
    if (!mounted) return;
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 10);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.fromLTRB(40, 60, 40, 200), maxZoom: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _RegionDropdown(
            regionNames: widget.regionNames,
            selected: widget.selectedRegionName,
            onChanged: widget.onRegionChanged,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: points.isEmpty
                      ? Container(
                          color: AppColors.softBackground,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: const Text(
                            'No mapped prices for this region yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.gray, fontSize: 14),
                          ),
                        )
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: points.first,
                            initialZoom: 10,
                            initialCameraFit: points.length > 1
                                ? CameraFit.coordinates(
                                    coordinates: points,
                                    padding: const EdgeInsets.fromLTRB(40, 60, 40, 200),
                                    maxZoom: 11,
                                  )
                                : null,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.frontend',
                            ),
                            // Soft halo around the selected area, as in PPA 6.
                            if (widget.selectedArea?.hasCoordinates ?? false)
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: LatLng(widget.selectedArea!.latitude!, widget.selectedArea!.longitude!),
                                    radius: widget.selectedArea!.isRegion ? 6000 : 1500,
                                    useRadiusInMeter: true,
                                    color: AppColors.green.withValues(alpha: 0.15),
                                    borderColor: AppColors.green,
                                    borderStrokeWidth: 1,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                for (final area in widget.areas)
                                  if (area.hasCoordinates)
                                    Marker(
                                      point: LatLng(area.latitude!, area.longitude!),
                                      width: 90,
                                      height: 52,
                                      alignment: Alignment.topCenter,
                                      child: GestureDetector(
                                        onTap: () => widget.onAreaSelected(area),
                                        child: _PricePin(
                                          area: area,
                                          selected: area == widget.selectedArea,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                            const RichAttributionWidget(
                              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                            ),
                          ],
                        ),
                ),
                if (widget.infoCard != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: widget.infoCard!,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pin with the area's average price on a label, red when selected to
/// match the wireframe's marker.
class _PricePin extends StatelessWidget {
  const _PricePin({required this.area, required this.selected});

  final MarketAreaPrice area;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.redAccent : AppColors.green;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 30, color: color),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color),
          ),
          child: Text(
            '₱${formatPeso(area.avgPrice)}',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  const _RegionDropdown({required this.regionNames, required this.selected, required this.onChanged});

  final List<String> regionNames;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gray),
          style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All regions')),
            for (final name in regionNames) DropdownMenuItem<String?>(value: name, child: Text(name)),
          ],
          selectedItemBuilder: (context) => [
            for (final label in ['All regions', ...regionNames])
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.black),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
