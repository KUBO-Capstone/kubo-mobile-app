import 'package:flutter/foundation.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

/// Gender choices shown in the onboarding form.
enum Gender { female, male, preferNotToSay }

/// Human-readable labels for each gender choice.
extension GenderLabel on Gender {
  String get label {
    switch (this) {
      case Gender.female:
        return 'Female';
      case Gender.male:
        return 'Male';
      case Gender.preferNotToSay:
        return 'Prefer not to say';
    }
  }
}

/// Change-notifier controller that stores the onboarding selections and filters.
class GetStartedFormController extends ChangeNotifier {
  /// Loads the full list of Philippine regions once and exposes it to the form.
  GetStartedFormController()
      : regions = List<Region>.unmodifiable(philippineRegions);

  /// Immutable list of regions used to populate the region dropdown.
  final List<Region> regions;

  /// Text value entered by the user for their username.
  String username = '';
  /// Selected gender option from the pill group.
  Gender? selectedGender;
  /// Selected birthday from the date picker.
  DateTime? selectedBirthday;
  /// Selected region that drives the available-city dropdown.
  Region? selectedRegion;
  /// Selected municipality within the chosen region.
  Municipality? selectedCity;

  // Flattens the selected region into a deduplicated, alphabetized municipality list.
  List<Municipality> get availableCities {
    final region = selectedRegion;
    if (region == null) {
      return const [];
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

  // Stores the selected gender and notifies listeners when it changes.
  void setGender(Gender? value) {
    if (selectedGender == value) {
      return;
    }
    selectedGender = value;
    notifyListeners();
  }

  // Stores the selected birthday and notifies listeners when it changes.
  void setBirthday(DateTime? value) {
    if (selectedBirthday == value) {
      return;
    }
    selectedBirthday = value;
    notifyListeners();
  }

  // Stores a new region and clears the dependent city selection.
  void setRegion(Region? value) {
    if (selectedRegion == value) {
      return;
    }

    selectedRegion = value;
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