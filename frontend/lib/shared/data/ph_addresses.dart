import 'package:flutter/foundation.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';

/// Lookups over the `philippines_rpcmb` region -> province -> municipality ->
/// barangay lists, which sign-up and Edit Profile both choose addresses from,
/// so every address is spelled one way ("REGION III", "BULACAN",
/// "MALOLOS CITY").
class PhAddresses {
  PhAddresses._();

  static List<Region> get regions => philippineRegions;

  static bool isNcr(Region region) => region.regionName == 'NCR';

  /// The towns to pick from: a province's, or for NCR (whose "provinces" are
  /// its districts, and which addresses leave out) all of the region's.
  static List<Municipality> townsOf(Region region, Province? province) {
    if (isNcr(region)) {
      return [for (final district in region.provinces) ...district.municipalities];
    }
    return province?.municipalities ?? const <Municipality>[];
  }

  /// The region a saved address names: "REGION III", "Region III", "NCR" or
  /// "National Capital Region".
  static Region? findRegion(String? value) {
    final wanted = comparable(value);
    if (wanted.isEmpty) return null;
    if (wanted == 'national capital region' || wanted == 'metro manila') {
      return regions.firstWhere(isNcr);
    }
    if (wanted == 'mimaropa') return findRegion('REGION IV-B');
    for (final region in regions) {
      if (comparable(region.regionName) == wanted) return region;
    }
    return null;
  }

  /// The entry of [options] a saved name stands for, even when an older
  /// address spells it another way: "Malolos" and "City of Malolos" both find
  /// "MALOLOS CITY".
  static T? findByName<T>(Iterable<T> options, String? value, String Function(T) nameOf) {
    final wanted = comparable(value);
    if (wanted.isEmpty) return null;
    for (final option in options) {
      if (comparable(nameOf(option)) == wanted) return option;
    }
    return null;
  }

  /// [name] lowercased, without "City of", a trailing "City", bracketed old
  /// names, accents or extra spaces.
  @visibleForTesting
  static String comparable(String? name) {
    var text = (name ?? '').trim().toLowerCase();
    const accents = {'ñ': 'n', 'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    accents.forEach((from, to) => text = text.replaceAll(from, to));
    return text
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceFirst(RegExp(r'^city of\s+'), '')
        .replaceFirst(RegExp(r'\s+city$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
