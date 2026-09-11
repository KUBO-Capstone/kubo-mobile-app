import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../models/location_result.dart';
import '../services/location_search_service.dart';

/// Outcome of the location sheet: where to centre the radius and how wide it is.
class LocationFilterSelection {
  const LocationFilterSelection({required this.location, required this.radiusKm});

  final LocationResult location;
  final double radiusKm;
}

/// Bottom sheet that changes the explore location and its search radius,
/// opened by tapping the location badge in the header.
class LocationFilterSheet extends StatefulWidget {
  const LocationFilterSheet({
    super.key,
    required this.initialRadiusKm,
    required this.recentLocations,
    this.currentLabel,
  });

  /// Radius the sheet opens with, in kilometres.
  final double initialRadiusKm;

  /// Previously chosen locations, most recent first.
  final List<LocationResult> recentLocations;

  /// Label of the location currently in effect, shown as context.
  final String? currentLabel;

  @override
  State<LocationFilterSheet> createState() => _LocationFilterSheetState();
}

class _LocationFilterSheetState extends State<LocationFilterSheet> {
  final LocationSearchService _searchService = LocationSearchService();
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  /// Nominatim asks callers to stay near one request per second, so typing is
  /// debounced rather than searched on every keystroke.
  Timer? _debounce;

  List<LocationResult> _results = const <LocationResult>[];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _radiusController.text = widget.initialRadiusKm.toStringAsFixed(0);
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _radiusController.dispose();
    _searchService.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.length < 3) {
      setState(() {
        _results = const <LocationResult>[];
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await _searchService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = results.isEmpty ? 'No places found for "$query".' : null;
      });
    } catch (error) {
      debugPrint('Location search failed: $error');
      if (!mounted) return;
      setState(() {
        _results = const <LocationResult>[];
        _searching = false;
        _error = 'Could not search locations. Check your connection.';
      });
    }
  }

  /// Radius typed by the user, clamped to the 1-400 km range in the wireframe.
  double get _radiusKm {
    final parsed = double.tryParse(_radiusController.text.trim());
    if (parsed == null || parsed <= 0) return widget.initialRadiusKm;
    return parsed.clamp(1, 400).toDouble();
  }

  void _apply(LocationResult location) {
    Navigator.of(context).pop(
      LocationFilterSelection(location: location, radiusKm: _radiusKm),
    );
  }

  // Resolves the device position so the badge can follow the real user.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _apply(
        LocationResult(
          label: 'My location',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (error) {
      debugPrint('Current location failed: $error');
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Could not get your location. Allow location access or search instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Search location',
                        style: TextStyle(
                          color: AppColors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: TextField(
                  controller: _queryController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'City, municipality, or barangay',
                    suffixIcon:
                        _searching
                            ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                            : const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _radiusController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Radius',
                    hintText: 'Kilometres (1 - 400)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.my_location,
                        color: AppColors.green,
                      ),
                      title: const Text('Use my current location'),
                      onTap: _searching ? null : _useCurrentLocation,
                    ),
                    if (_results.isNotEmpty) ...[
                      const _SheetSectionLabel('Results'),
                      for (final result in _results)
                        ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.gray,
                          ),
                          title: Text(result.label),
                          onTap: () => _apply(result),
                        ),
                    ],
                    if (widget.recentLocations.isNotEmpty) ...[
                      const _SheetSectionLabel('Recent locations'),
                      for (final recent in widget.recentLocations)
                        ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: AppColors.gray,
                          ),
                          title: Text(recent.label),
                          onTap: () => _apply(recent),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
