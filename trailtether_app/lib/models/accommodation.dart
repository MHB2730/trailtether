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
    return Accommodation(
      name: json['name'],
      type: json['type'],
      region: json['region'],
      lat: (json['gps'][0] as num).toDouble(),
      lon: (json['gps'][1] as num).toDouble(),
      phone: json['phone'],
    );
  }
}
