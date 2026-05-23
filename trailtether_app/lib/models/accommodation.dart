class Accommodation {
  final String name;
  final String type;
  final String region;
  final double lat;
  final double lon;
  final String? phone;

  Accommodation({
    required this.name,
    required this.type,
    required this.region,
    required this.lat,
    required this.lon,
    this.phone,
  });

  factory Accommodation.fromJson(Map<String, dynamic> json) {
    // Defensive GPS read: the upstream JSON schema is `[lat, lon]` but a
    // brand-new accommodation row (or a partial CSV import) can arrive with
    // `gps` missing, null, or a single-element list. Falling back to (0, 0)
    // lets the row render in the list with a clear "unknown" pin position
    // instead of taking down the whole accommodation tab.
    double lat = 0;
    double lon = 0;
    final gps = json['gps'];
    if (gps is List && gps.length >= 2) {
      final rawLat = gps[0];
      final rawLon = gps[1];
      if (rawLat is num) lat = rawLat.toDouble();
      if (rawLon is num) lon = rawLon.toDouble();
    }

    return Accommodation(
      name: json['name']?.toString() ?? 'Unknown',
      type: json['type']?.toString() ?? 'other',
      region: json['region']?.toString() ?? '',
      lat: lat,
      lon: lon,
      phone: json['phone']?.toString(),
    );
  }
}
