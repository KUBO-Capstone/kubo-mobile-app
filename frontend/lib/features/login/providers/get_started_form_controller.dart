import 'package:philippines_rpcmb/philippines_rpcmb.dart';
import 'package:flutter/foundation.dart';

/// Change-notifier controller that stores the registration location selections.
class GetStartedFormController extends ChangeNotifier {
  /// Loads the full list of Philippine regions once and exposes it to the form.
  GetStartedFormController()
      : regions = List<Region>.unmodifiable(philippineRegions);

  /// Immutable list of regions used to populate the region dropdown.
  final List<Region> regions;

  /// Text value entered by the user for their first name.
  String username = '';
  /// Selected region that drives the available-city dropdown.
  Region? selectedRegion;
  /// Selected province, except for NCR where the province field is hidden.
  Province? selectedProvince;
  /// Selected municipality within the chosen region.
  Municipality? selectedCity;

  bool get isNcr => selectedRegion?.id == 'NCR';

  List<Province> get availableProvinces {
    if (selectedRegion == null || isNcr) return const [];
    return selectedRegion!.provinces;
  }

  // Uses the selected province for ordinary regions and all NCR cities directly.
  List<Municipality> get availableCities {
    final region = selectedRegion;
    if (region == null) {
      return const [];
    }

    if (!isNcr && selectedProvince != null) {
      return selectedProvince!.municipalities;
    }

    final municipalitiesById = <String, Municipality>{};
    for (final province in region.provinces) {
      for (final municipality in province.municipalities) {
        municipalitiesById[municipality.id] = municipality;
      }
    }

    final cities = municipalitiesById.values.toList(growable: false);
    cities.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return cities;
  }

  // Updates the username only when the value actually changes.
  void setUsername(String value) {
    if (username == value) {
      return;
    }
    username = value;
    notifyListeners();
  }

  // Stores a new region and clears dependent selections.
  void setRegion(Region? value) {
    if (selectedRegion == value) {
      return;
    }

    selectedRegion = value;
    selectedProvince = null;
    selectedCity = null;
    notifyListeners();
  }

  void setProvince(Province? value) {
    if (selectedProvince == value) return;
    selectedProvince = value;
    selectedCity = null;
    notifyListeners();
  }

  // Stores the selected city only when a region has already been chosen.
  void setCity(Municipality? value) {
    if (selectedRegion == null || selectedCity == value) {
      return;
    }
    selectedCity = value;
    notifyListeners();
  }
}