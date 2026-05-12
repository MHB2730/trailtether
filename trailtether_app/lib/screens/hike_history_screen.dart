import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/saved_hike.dart';
import '../providers/hike_history_provider.dart';
import '../services/health_connect_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/map/speed_path_layer.dart';

class HikeHistoryScreen extends StatelessWidget {
  final bool embedded;
  const HikeHistoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = Consumer<HikeHistoryProvider>(
      builder: (_, history, __) {
        if (!history.loaded) {
          return const Center(
            child: CircularProgressIndicator(color: kColorOrange),
          );
        }

        if (history.hikes.isEmpty) return const _EmptyHistory();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: history.hikes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _HikeCard(hike: history.hikes[i]),
        );
      },
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        title: Text('Activities', style: GoogleFonts.outfit()),
      ),
      body: body,
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: kColorPanel,
                  shape: BoxShape.circle,
                  border: Border.all(color: kColorBorder),
                ),
                child: const Icon(Icons.directions_walk_rounded,
                    color: kColorOrange, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'No saved hikes yet',
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Completed recordings saved locally will appear here with their full activity stats.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

class _HikeCard extends StatelessWidget {
  final SavedHike hike;
  const _HikeCard({required this.hike});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM yyyy').format(hike.startedAt);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                height: 132, child: _RouteMap(hike: hike, interactive: false)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hike.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: kColorCream,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: kColorCream.withOpacity(0.25)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.38),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _MiniMetric(
                          'DIST', '${hike.distanceKm.toStringAsFixed(2)} km'),
                      _MiniMetric(
                          'TIME', _formatDuration(hike.durationSeconds)),
                      _MiniMetric('ASC', '${hike.ascentM} m'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HikeDetailScreen extends StatelessWidget {
  final SavedHike hike;
  const HikeDetailScreen({super.key, required this.hike});

  @override
  Widget build(BuildContext context) {
    final history = context.read<HikeHistoryProvider>();
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        title: Text('Activity Detail', style: GoogleFonts.outfit()),
        actions: [
          IconButton(
            tooltip: 'Sync to Health Connect',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () async {
              final ok = await HealthConnectService.writeHike(hike);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Activity written to Health Connect'
                        : 'Health Connect sync was not completed',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await history.remove(hike.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            hike.name,
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, d MMMM yyyy  HH:mm').format(hike.startedAt),
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _RouteMap(hike: hike),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Performance',
            children: [
              _MetricTile(
                  'Distance', '${hike.distanceKm.toStringAsFixed(2)} km'),
              _MetricTile(
                  'Elapsed time', _formatDuration(hike.durationSeconds)),
              _MetricTile('Moving time', _formatDuration(hike.movingSeconds)),
              _MetricTile('Stopped time', _formatDuration(hike.stoppedSeconds)),
              _MetricTile('Average speed',
                  '${hike.averageSpeedKmh.toStringAsFixed(1)} km/h'),
              _MetricTile('Moving speed',
                  '${hike.movingSpeedKmh.toStringAsFixed(1)} km/h'),
              _MetricTile(
                  'Max speed', '${hike.maxSpeedKmh.toStringAsFixed(1)} km/h'),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Elevation',
            children: [
              _MetricTile('Ascent', '${hike.ascentM} m'),
              _MetricTile('Descent', '${hike.descentM} m'),
              _MetricTile(
                  'Lowest', '${hike.minElevationM.toStringAsFixed(0)} m'),
              _MetricTile(
                  'Highest', '${hike.maxElevationM.toStringAsFixed(0)} m'),
              _MetricTile(
                  'Range', '${hike.elevationRangeM.toStringAsFixed(0)} m'),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'GPS Quality',
            children: [
              _MetricTile('Captured points', '${hike.pointCount}'),
              _MetricTile('Accepted fixes', '${hike.acceptedFixes}'),
              _MetricTile('Rejected fixes', '${hike.rejectedFixes}'),
              _MetricTile('Poor accuracy', '${hike.poorAccuracyRejects}'),
              _MetricTile('Jump rejects', '${hike.jumpRejects}'),
              _MetricTile('Stale rejects', '${hike.staleRejects}'),
              _MetricTile('Gap warnings', '${hike.gapWarnings}'),
              _MetricTile('Average accuracy',
                  '${hike.averageAccuracyM.toStringAsFixed(1)} m'),
              _MetricTile('Best accuracy',
                  '${hike.bestAccuracyM.toStringAsFixed(1)} m'),
              _MetricTile('Worst accuracy',
                  '${hike.worstAccuracyM.toStringAsFixed(1)} m'),
            ],
          ),
          const SizedBox(height: 12),
          _CapturedPoints(hike: hike),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final SavedHike hike;
  final bool interactive;
  const _RouteMap({required this.hike, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final route =
        hike.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final center = route.isEmpty
        ? LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon)
        : route.first;
    final bounds = route.length < 2 ? null : _boundsFor(route);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        initialCameraFit: bounds == null
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(28),
              ),
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: kMapTileStyles[3].url, // Satellite
          userAgentPackageName: kTileUserAgent,
          tileProvider: OfflineMapService.tileProvider(),
          maxZoom: kMapTileStyles[3].maxZoom,
        ),
        if (hike.points.isNotEmpty) SpeedPathLayer(points: hike.points),
        if (route.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: route.first,
                width: 18,
                height: 18,
                child: const Icon(Icons.trip_origin,
                    color: Color(0xFF81C784), size: 16),
              ),
              Marker(
                point: route.last,
                width: 18,
                height: 18,
                child: const Icon(Icons.flag, color: kColorOrange, size: 18),
              ),
            ],
          ),
      ],
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    final lats = points.map((p) => p.latitude).toList()..sort();
    final lons = points.map((p) => p.longitude).toList()..sort();
    return LatLngBounds(
      LatLng(lats.first, lons.first),
      LatLng(lats.last, lons.last),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.outfit(
                color: kColorOrange,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: children
                      .map((child) => SizedBox(width: itemWidth, child: child))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.42),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _CapturedPoints extends StatelessWidget {
  final SavedHike hike;
  const _CapturedPoints({required this.hike});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kColorBorder),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: kColorOrange,
            collapsedIconColor: kColorCream.withOpacity(0.4),
            title: Text(
              'Captured Points',
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '${hike.pointCount} fixes stored locally',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: hike.points.length,
                separatorBuilder: (_, __) => const Divider(
                  color: kColorBorder,
                  height: 1,
                ),
                itemBuilder: (_, i) {
                  final point = hike.points[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '#${i + 1}',
                            style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${point.latitude.toStringAsFixed(6)}, '
                            '${point.longitude.toStringAsFixed(6)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: kColorCream,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${point.altitude.toStringAsFixed(0)}m  '
                          '${point.accuracy.toStringAsFixed(0)}m',
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.45),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.32),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

String _formatDuration(int seconds) {
  final duration = Duration(seconds: seconds < 0 ? 0 : seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes}m ${secs.toString().padLeft(2, '0')}s';
}
