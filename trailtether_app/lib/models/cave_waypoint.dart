/// A named cave or rock shelter with an exact GPS fix from the Caves.gpx dataset.
class CaveWaypoint {
  final String name;
  final double lat;
  final double lon;
  final double elevationM;
  final String? description;

  const CaveWaypoint({
    required this.name,
    required this.lat,
    required this.lon,
    required this.elevationM,
    this.description,
  });

  /// True when this entry is a rock shelter rather than a true cave.
  bool get isShelter {
    final n = name.toLowerCase();
    return n.contains('shelter') || n.contains('chalet') || n.contains('hut');
  }
}
