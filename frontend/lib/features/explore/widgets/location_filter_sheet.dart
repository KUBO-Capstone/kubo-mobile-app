import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../models/location_result.dart';
import '../services/location_search_service.dart';

/// Outcome of the location sheet: where to centre the radius and how wide it is.
class LocationFilterSelection {
  const LocationFilterSelection({
    required this.location,
    required this.radiusKm,
  });

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
    this.initialLocation,
  });

  /// Radius the sheet opens with, in kilometres.
  final double initialRadiusKm;

  /// Previously chosen locations, most recent first.
  final List<LocationResult> recentLocations;

  /// Location already in effect, preselected so the radius can be changed on
  /// its own without picking a place again.
  final LocationResult? initialLocation;

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

  /// Place the Apply button will commit. Seeded from the active filter so
  /// adjusting only the radius needs no reselection.
  LocationResult? _selected;

  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    _radiusController.text = widget.initialRadiusKm.toStringAsFixed(0);
    _queryController.addListener(_onQueryChanged);
    // Keep the Apply label in step with a typed radius.
    _radiusController.addListener(() => setState(() {}));
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

  void _apply() {
    final selected = _selected;
    if (selected == null) return;
    Navigator.of(
      context,
    ).pop(LocationFilterSelection(location: selected, radiusKm: _radiusKm));
  }

  // Resolves the device position so the badge can follow the real user.
  //
  // Each failure mode gets its own message: "could not get location" on its own
  // leaves the user with nothing to act on, and on an emulator the usual cause
  // is simply that no position has ever been set.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(
          'Location services are turned off. Enable them in system settings, '
          'then try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationFailure(
          'Location permission was denied. Allow it to use your position, or '
          'search for a place instead.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(
          'Location permission is permanently denied. Enable it for Kubo in '
          'system settings, or search for a place instead.',
        );
      }

      // A fresh fix can take a while indoors, and an emulator without a set
      // position never returns one, so fall back to the last known fix.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      } catch (error) {
        debugPrint('getCurrentPosition failed: $error');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw const _LocationFailure(
          'No GPS fix yet. Move somewhere with a clearer signal, or search for '
          'a place instead. (On an emulator, set a location first.)',
        );
      }

      if (!mounted) return;
      setState(() {
        _locating = false;
        _selected = LocationResult(
          label: 'My location',
          latitude: position!.latitude,
          longitude: position.longitude,
        );
        _results = const <LocationResult>[];
        _error = null;
      });
    } on _LocationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = failure.message;
      });
    } catch (error) {
      debugPrint('Current location failed: $error');
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = 'Could not get your location. Search for a place instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
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
                    suffixText: 'km',
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
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  children: [
                    ListTile(
                      leading:
                          _locating
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.my_location,
                                color: AppColors.green,
                              ),
                      title: const Text('Use my current location'),
                      onTap: _locating ? null : _useCurrentLocation,
                    ),
                    if (_results.isNotEmpty) ...[
                      const _SheetSectionLabel('Results'),
                      for (final result in _results)
                        _LocationTile(
                          icon: Icons.location_on_outlined,
                          label: result.label,
                          selected: result == selected,
                          onTap: () => setState(() => _selected = result),
                        ),
                    ],
                    if (widget.recentLocations.isNotEmpty) ...[
                      const _SheetSectionLabel('Recent locations'),
                      for (final recent in widget.recentLocations)
                        _LocationTile(
                          icon: Icons.history,
                          label: recent.label,
                          selected: recent == selected,
                          onTap: () => setState(() => _selected = recent),
                        ),
                    ],
                  ],
                ),
              ),
              // Apply commits the place and radius together, so the radius can
              // be changed on its own without reselecting a location.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selected == null ? null : _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selected == null
                            ? 'Pick a location to apply'
                            : 'Apply - ${_radiusKm.toStringAsFixed(0)} km of '
                                '${selected.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Selectable row for a search result or recent location.
class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.green : AppColors.gray),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.black,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing:
          selected
              ? const Icon(Icons.check_circle, color: AppColors.green)
              : null,
      selected: selected,
      selectedTileColor: AppColors.softBackground,
      onTap: onTap,
    );
  }
}

/// Internal error carrying a message already written for the user.
class _LocationFailure implements Exception {
  const _LocationFailure(this.message);

  final String message;
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
