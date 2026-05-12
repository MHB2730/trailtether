import 'package:flutter/services.dart' show rootBundle;
import '../models/cave_waypoint.dart';

class CaveWaypointService {
  static List<CaveWaypoint>? _cache;

  /// Parses assets/data/caves.gpx and returns all cave waypoints.
  /// Result is cached — subsequent calls are instant.
  static Future<List<CaveWaypoint>> loadCaves() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/data/caves.gpx');
    _cache = _parseGpx(raw);
    return _cache!;
  }

  static List<CaveWaypoint> _parseGpx(String xml) {
    final caves = <CaveWaypoint>[];

    // Simple regex-based parser — avoids xml package dependency.
    final wptPattern = RegExp(
      r'<wpt\s+lat="([^"]+)"\s+lon="([^"]+)">(.*?)</wpt>',
      dotAll: true,
    );
    final namePattern = RegExp(r'<name>(.*?)</name>');
    final elePattern = RegExp(r'<ele>(.*?)</ele>');
    final descPattern = RegExp(r'<desc>(.*?)</desc>');

    for (final m in wptPattern.allMatches(xml)) {
      final lat = double.tryParse(m.group(1)?.trim() ?? '') ?? 0;
      final lon = double.tryParse(m.group(2)?.trim() ?? '') ?? 0;
      final body = m.group(3) ?? '';

      final name = namePattern.firstMatch(body)?.group(1)?.trim() ?? '';
      final ele = double.tryParse(
              elePattern.firstMatch(body)?.group(1)?.trim() ?? '') ??
          0;
      final desc = descPattern.firstMatch(body)?.group(1)?.trim();

      if (name.isNotEmpty && lat != 0 && lon != 0) {
        caves.add(CaveWaypoint(
          name: name,
          lat: lat,
          lon: lon,
          elevationM: ele,
          description: (desc != null && desc.isNotEmpty) ? desc : null,
        ));
      }
    }

    return caves..sort((a, b) => a.name.compareTo(b.name));
  }
}
