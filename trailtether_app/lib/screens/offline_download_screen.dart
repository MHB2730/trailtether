import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_state_provider.dart';
import '../providers/gpx_provider.dart';
import '../providers/static_data_provider.dart';
import '../services/offline_map_service.dart';

class OfflineDownloadScreen extends StatefulWidget {
  const OfflineDownloadScreen({super.key});

  @override
  State<OfflineDownloadScreen> createState() => _OfflineDownloadScreenState();
}

class _OfflineDownloadScreenState extends State<OfflineDownloadScreen> {
  bool _downloading = false;
  bool _done = false;
  double _progress = 0.0;
  String _statusMsg = '';
  int _tileCount = 0;

  final MapController _mapController = MapController();
  LatLngBounds? _selectedBounds;
  bool _selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final trailBounds = _downloadBounds(context);
    // Use selected bounds if in selection mode, otherwise use trail bounds
    final effectiveBounds = _selectionMode ? _selectedBounds : trailBounds;

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        title:
            Text('Offline Maps', style: GoogleFonts.outfit(color: kColorCream)),
        backgroundColor: kColorBg,
        iconTheme: IconThemeData(color: kColorCream.withOpacity(0.7)),
        elevation: 0,
        actions: [
          if (!_downloading && !_done)
            TextButton.icon(
              onPressed: () => setState(() => _selectionMode = !_selectionMode),
              icon: Icon(
                  _selectionMode ? Icons.auto_fix_high : Icons.map_outlined,
                  color: kColorOrange,
                  size: 18),
              label: Text(_selectionMode ? 'Auto-Trail' : 'Manual Select',
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Interactive Map Area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        trailBounds?.center ?? const LatLng(-29.0, 29.0),
                    initialZoom: 11,
                    onPositionChanged: (pos, hasGesture) {
                      if (_selectionMode && hasGesture) {
                        setState(() {
                          _selectedBounds = pos.visibleBounds;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kTileUrl,
                      userAgentPackageName: kTileUserAgent,
                      maxZoom: 19, // OSM limit
                      retinaMode: kHighDensity(context),
                    ),
                    if (effectiveBounds != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              effectiveBounds.southWest,
                              LatLng(
                                  effectiveBounds.north, effectiveBounds.west),
                              effectiveBounds.northEast,
                              LatLng(
                                  effectiveBounds.south, effectiveBounds.east),
                              effectiveBounds.southWest,
                            ],
                            color: kColorOrange,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                  ],
                ),
                // Selection UI Overlay
                if (_selectionMode)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: kColorOrange.withOpacity(0.5), width: 20),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kColorOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Pan map to select area',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control Panel
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: kColorBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectionMode
                          ? 'Manual Region Selection'
                          : 'Loaded Trail Area',
                      style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectionMode
                          ? 'Download everything visible in the orange frame above for offline use.'
                          : 'Downloads map tiles specifically around your loaded trails and GPX tracks.',
                      style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.5),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    Row(
                      children: [
                        const _SpecCard(label: 'ZOOM', value: '10 – 15'),
                        const SizedBox(width: 12),
                        _SpecCard(
                          label: 'EST. TILES',
                          value: _estimateTiles(effectiveBounds).toString(),
                        ),
                        const SizedBox(width: 12),
                        _SpecCard(
                          label: 'SOURCE',
                          value: _selectionMode ? 'Viewport' : 'Trails',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Progress / Status
                    if (_downloading || _done) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _done ? 1.0 : _progress,
                          backgroundColor: kColorBorder,
                          color: _done ? Colors.green : kColorOrange,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(_done ? Icons.check_circle : Icons.sync,
                              color: _done ? Colors.green : kColorOrange,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _done
                                  ? 'Success: $_tileCount tiles cached locally.'
                                  : _statusMsg,
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.6),
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_downloading || _done || effectiveBounds == null)
                                ? null
                                : () => _startDownload(effectiveBounds),
                        icon: _done
                            ? const Icon(Icons.done_all)
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _done
                              ? 'READY OFFLINE'
                              : (_downloading
                                  ? 'DOWNLOADING...'
                                  : 'START DOWNLOAD'),
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _done ? Colors.green : kColorOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              kColorOrange.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _estimateTiles(LatLngBounds? bounds) {
    if (bounds == null) return 0;
    double area =
        (bounds.north - bounds.south).abs() * (bounds.east - bounds.west).abs();
    return (area * 15000).round().clamp(10, 5000);
  }

  LatLngBounds? _downloadBounds(BuildContext context) {
    final points = <LatLng>[
      for (final trail in context.watch<StaticDataProvider>().allTrails)
        for (final coord in trail.coords) LatLng(coord.lat, coord.lon),
      for (final track in context.watch<GpxProvider>().tracks) ...track.points,
    ];

    if (points.isEmpty) return null;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    final latPad = math.max((maxLat - minLat).abs() * 0.15, 0.02);
    final lonPad = math.max((maxLon - minLon).abs() * 0.15, 0.02);

    return LatLngBounds(
      LatLng(
        (minLat - latPad).clamp(-85.0, 85.0),
        (minLon - lonPad).clamp(-180.0, 180.0),
      ),
      LatLng(
        (maxLat + latPad).clamp(-85.0, 85.0),
        (maxLon + lonPad).clamp(-180.0, 180.0),
      ),
    );
  }

  Future<void> _startDownload(LatLngBounds bounds) async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _statusMsg = 'Initialising tile store…';
    });

    try {
      await OfflineMapService.downloadRegion(
        bounds: bounds,
        onProgress: (downloaded, total) {
          if (!mounted) return;
          setState(() {
            _tileCount = downloaded;
            _progress = total > 0 ? downloaded / total : 0;
            _statusMsg = 'Downloading tile $downloaded of $total…';
          });
        },
      );
      if (mounted) {
        setState(() {
          _downloading = false;
          _done = true;
        });
        await context.read<AppStateProvider>().setOfflineRegionReady(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}

class _SpecCard extends StatelessWidget {
  final String label;
  final String value;
  const _SpecCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35),
                  fontSize: 10,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
