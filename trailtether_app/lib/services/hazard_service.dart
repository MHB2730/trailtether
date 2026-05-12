import 'dart:math' as math;
import '../models/weather.dart';

class HazardZone {
  final String label;
  final String color;
  final List<List<double>> polygon; // [ [lon, lat], ... ]

  HazardZone({required this.label, required this.color, required this.polygon});

  Map<String, dynamic> toGeoJson() => {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [polygon]
        },
        'properties': {
          'label': label,
          'color': color,
        }
      };
}

class HazardService {
  /// Generates visual hazard zones based on current weather conditions.
  static List<HazardZone> calculateWeatherHazards(
      WeatherData? weather, double lat, double lon) {
    if (weather == null) return [];
    final List<HazardZone> zones = [];

    // 1. Lightning Hazard (High cloud cover + specific WMO codes)
    if (weather.current.cloudCover > 80 &&
        (weather.current.weatherCode == 80 ||
            weather.current.weatherCode == 81 ||
            weather.current.weatherCode == 82)) {
      zones.add(HazardZone(
        label: 'LIGHTNING RISK',
        color: '#FFD600',
        polygon: _createCircle(lon, lat, 2000), // 2km zone
      ));
    }

    // 2. High Wind Hazard
    if (weather.current.windSpeed > 40) {
      zones.add(HazardZone(
        label: 'HIGH WIND: ${weather.current.windSpeed.toInt()}km/h',
        color: '#FF6D00',
        polygon: _createCircle(lon, lat, 3500),
      ));
    }

    return zones;
  }

  static List<List<double>> _createCircle(
      double lon, double lat, double radiusM) {
    const int points = 32;
    final List<List<double>> coords = [];
    // Roughly 111,320 meters per degree latitude
    const double degreeLat = 1 / 111320.0;
    // For longitude, it depends on latitude: 111,320 * cos(lat)
    final double degreeLon = 1 / (111320.0 * math.cos(lat * math.pi / 180));

    for (int i = 0; i <= points; i++) {
      final double angle = i * (360 / points) * (math.pi / 180);
      // Add a bit of "wobble" for a more organic/hazard feel if desired,
      // or just keep it a perfect circle. Let's keep it clean for now.
      final double dx = radiusM * degreeLon * math.cos(angle);
      final double dy = radiusM * degreeLat * math.sin(angle);

      coords.add([lon + dx, lat + dy]);
    }

    return coords;
  }
}
