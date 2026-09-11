/// A place the user can centre the radius filter on.
class LocationResult {
  const LocationResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory LocationResult.fromNominatim(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString() ?? '';
    return LocationResult(
      label: _shortLabel(displayName),
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }

  /// Nominatim returns a long comma-separated address; the badge only has room
  /// for the first couple of parts.
  static String _shortLabel(String displayName) {
    final parts =
        displayName
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return 'Selected location';
    if (parts.length == 1) return parts.first;
    return '${parts.first}, ${parts[1]}';
  }

  /// Short display name shown in the badge and recent list.
  final String label;
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LocationResult &&
      other.label == label &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(label, latitude, longitude);
}
