import 'package:flutter/material.dart';

// Brand colors
const kColorBg = Color(0xFF0D0D0D);
const kColorOrange = Color(0xFFE8541A);
const kColorCream = Color(0xFFE8DFC8);
const kColorPanel = Color(0xE00D0D0D); // ~88% opacity
const kColorBorder = Color(0x1FE8DFC8); // ~12% opacity

// Stitch Design System Colors
const kColorCyan = Color(0xFF00F2FF);
const kColorPurple = Color(0xFF9D00FF);
const kColorGlass = Color(0x1AFFFFFF); // ~10% white
const kColorGlassDark = Color(0x4D000000); // ~30% black
const kColorGlowOrange = Color(0x33E8541A); // ~20% orange glow
const kColorGlowCyan = Color(0x3300F2FF); // ~20% cyan glow

// Geometry
const kRadiusPremium = 24.0;
const kRadiusCard = 16.0;
const kPaddingScreen = 24.0;

// Stitch Text Styles
const kStyleHeader = TextStyle(
  fontFamily: 'Inter',
  fontSize: 18,
  fontWeight: FontWeight.bold,
  letterSpacing: 0.5,
  color: kColorCream,
);

const kStyleButton = TextStyle(
  fontFamily: 'Inter',
  fontSize: 13,
  fontWeight: FontWeight.bold,
  letterSpacing: 1.2,
  color: Colors.white,
);

const kStyleBody = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  color: kColorCream,
  height: 1.4,
);

const kStyleCaption = TextStyle(
  fontFamily: 'Inter',
  fontSize: 12,
  color: kColorCream,
);

const kStyleMeta = TextStyle(
  fontFamily: 'Inter',
  fontSize: 10,
  fontWeight: FontWeight.bold,
  letterSpacing: 1.0,
  color: kColorCream,
);

// Map tile styles
//
// All "free" styles (OSM / OpenTopoMap / Esri) work without any key.
//
// MapTiler styles require a key. Inject via:
//   flutter build apk --release --dart-define=MAPTILER_KEY=<your_key>
//
// For production: in the MapTiler console, lock the key to the
// `com.trailtether.app` SHA-1 fingerprint and the production domain.
//
// If MAPTILER_KEY is not provided, the MapTiler tile entries are
// silently dropped from the picker so users never hit a 401 on tiles.
const kMapTilerKey = String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
const _kMapTilerEnabled = kMapTilerKey != '';

String mapTilerUrl(String style) =>
    'https://api.maptiler.com/maps/$style/{z}/{x}/{y}.png?key=$kMapTilerKey';

class MapTileStyle {
  final String label;
  final String url;
  final String iconLabel;
  final String attribution;
  final double maxZoom;

  const MapTileStyle({
    required this.label,
    required this.url,
    required this.iconLabel,
    required this.attribution,
    this.maxZoom = 19.0,
  });
}

// Index 0 is the default.
// OpenTopoMap is first: contour lines + hiking trail markings, completely free.
final kMapTileStyles = <MapTileStyle>[
  const MapTileStyle(
    label: 'Outdoor',
    url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    iconLabel: 'OUT',
    attribution: 'OpenTopoMap (CC-BY-SA) | OpenStreetMap contributors',
    maxZoom: 17.0, // OpenTopoMap caps at 17
  ),
  const MapTileStyle(
    label: 'Standard',
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    iconLabel: 'MAP',
    attribution: 'OpenStreetMap contributors',
    maxZoom: 19.0,
  ),
  const MapTileStyle(
    // Esri World Topo: free, richer topo styling than OSM.
    label: 'Topo',
    url:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    iconLabel: 'TOP',
    attribution: 'Esri, HERE, Garmin, OpenStreetMap contributors',
    maxZoom: 19.0,
  ),
  const MapTileStyle(
    // Esri World Imagery: free satellite, same source as the 3D map base layer.
    label: 'Satellite',
    url:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    iconLabel: 'SAT',
    attribution: 'Esri, DigitalGlobe, GeoEye, Earthstar Geographics',
    maxZoom: 19.0,
  ),
  // MapTiler-backed style: only registered when a key is provided.
  if (_kMapTilerEnabled)
    const MapTileStyle(
      label: 'MT Outdoor',
      url:
          'https://api.maptiler.com/maps/outdoor/{z}/{x}/{y}.png?key=$kMapTilerKey',
      iconLabel: 'MT',
      attribution: 'MapTiler | OpenStreetMap contributors',
      maxZoom: 21.0,
    ),
];

// Night-vision map style
// Stadia Alidade Smooth Dark: free, dark basemap ideal for night hiking.
// Used when the user enables Night Map mode; rendered under a subtle red
// ColorFiltered overlay so hikers can preserve night vision.
const kNightTileUrl =
    'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png';
const kNightTileAttribution =
    'Stadia Maps | OpenMapTiles | OpenStreetMap contributors';

// Legacy constant kept for offline-map service tile store key.
const kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const kTileUserAgent = 'trailtether_app/1.0 (contact: info@hilltrek.co.za)';

// Global map defaults. The camera is intentionally unconstrained so routes can
// be planned and reviewed anywhere in the world.
const kWorldMapCenter = AppLatLng(-29.0, 29.3); // lat, lon (Drakensberg)
const kWorldMapZoomInit = 11.0; // Zoomed in a bit more

// Simple value class so we don't need flutter_map import here.
class AppLatLng {
  final double lat;
  final double lon;

  const AppLatLng(this.lat, this.lon);
}

// Supabase table names
const kColReviews = 'reviews';
const kColGpxUploads = 'gpx_uploads';
const kColIncidents = 'incidents';
const kColTeams = 'teams';
const kColHikePlans = 'hike_plans';
const kColChat = 'chat_messages';
const kColProfiles = 'profiles';

// Admin
/// DEPRECATED — admin status is now read from `profiles.is_admin` via
/// AuthProvider.isAdmin, which is backed by an RLS-enforced server flag.
/// Kept only for backwards compatibility with any UI label that displays
/// "Contact info@hilltrek.co.za". Do NOT use for permission gating.
const kAdminEmail = 'admin@trailtether.co.za';

// Difficulty colors
Color difficultyColor(String d) {
  switch (d.toLowerCase()) {
    case 'easy':
      return const Color(0xFF4CAF50);
    case 'moderate':
      return const Color(0xFFFFC107);
    case 'hard':
      return kColorOrange;
    case 'extreme':
      return const Color(0xFFE53935);
    default:
      return kColorCream;
  }
}

// GPX colors (cycle through these for uploaded tracks)
const kGpxColors = [
  Color(0xFF64B5F6), // blue
  Color(0xFFA5D6A7), // green
  Color(0xFFFFF176), // yellow
  Color(0xFFCE93D8), // purple
  Color(0xFFFFCC80), // orange
];
