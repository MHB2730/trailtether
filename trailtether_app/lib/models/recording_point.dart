import 'package:latlong2/latlong.dart';

class RecordingPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  final double speed; // m/s
  final double accuracy; // m

  RecordingPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
    this.speed = 0.0,
    this.accuracy = 0.0,
  });

  LatLng get toLatLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'alt': altitude,
        'ts': timestamp.toIso8601String(),
        'spd': speed,
        'acc': accuracy,
      };

  factory RecordingPoint.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (lat == null ||
        lon == null ||
        lat.isNaN ||
        lon.isNaN ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw FormatException(
          'RecordingPoint has invalid coordinates: lat=$lat, lon=$lon');
    }
    return RecordingPoint(
      latitude: lat,
      longitude: lon,
      altitude: (json['alt'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
      speed: (json['spd'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['acc'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
