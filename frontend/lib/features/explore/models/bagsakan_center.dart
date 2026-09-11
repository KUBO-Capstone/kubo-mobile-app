/// Drop-off point where buyers collect produce, plotted in the map's
/// bagsakan mode.
class BagsakanCenter {
  const BagsakanCenter({
    required this.id,
    required this.name,
    required this.locationLabel,
    required this.regionLabel,
    this.addressLine = '',
    this.latitude,
    this.longitude,
  });

  factory BagsakanCenter.fromJson(Map<String, dynamic> json) {
    return BagsakanCenter(
      id: '${json['center_id']}',
      name: json['location_name']?.toString() ?? 'Bagsakan Center Name',
      locationLabel: json['location_label']?.toString() ?? 'Philippines',
      regionLabel: json['region_label']?.toString() ?? 'NCR',
      addressLine: json['address_line']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Stable identifier for the center.
  final String id;

  /// Display name such as "Malolos Kubo Bagsakan Center".
  final String name;

  /// City or municipality the center sits in.
  final String locationLabel;

  /// Region label used by the shared region filter chips.
  final String regionLabel;

  /// Street and barangay line shown under the name.
  final String addressLine;

  /// Center latitude, null when the address has not been geocoded.
  final double? latitude;

  /// Center longitude, null when the address has not been geocoded.
  final double? longitude;

  /// Whether this center can be plotted on the map.
  bool get hasCoordinates => latitude != null && longitude != null;
}
