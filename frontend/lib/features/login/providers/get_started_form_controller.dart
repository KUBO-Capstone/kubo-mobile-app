import 'package:flutter/foundation.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

enum Gender { female, male, preferNotToSay }

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

class GetStartedFormController extends ChangeNotifier {
  GetStartedFormController()
      : regions = List<Region>.unmodifiable(philippineRegions);

  final List<Region> regions;

  String username = '';
  Gender? selectedGender;
  DateTime? selectedBirthday;
  Region? selectedRegion;
  Municipality? selectedCity;

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

  void setUsername(String value) {
    if (username == value) {
      return;
    }
    username = value;
    notifyListeners();
  }

  void setGender(Gender? value) {
    if (selectedGender == value) {
      return;
    }
    selectedGender = value;
    notifyListeners();
  }

  void setBirthday(DateTime? value) {
    if (selectedBirthday == value) {
      return;
    }
    selectedBirthday = value;
    notifyListeners();
  }

  void setRegion(Region? value) {
    if (selectedRegion == value) {
      return;
    }

    selectedRegion = value;
    selectedCity = null;
    notifyListeners();
  }

  void setCity(Municipality? value) {
    if (selectedRegion == null || selectedCity == value) {
      return;
    }
    selectedCity = value;
    notifyListeners();
  }
}