import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/recorded_trail.dart';
import '../models/recording_point.dart';
import '../models/trail.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/recorded_trails_provider.dart';
import '../services/offline_map_service.dart';
import '../services/recorded_trail_service.dart';
import '../widgets/trail/elevation_chart.dart';

/// "Trails" hub — shows the user's recorded hikes (auto-promoted on save)
/// and community-shared trails. Both lists are offline-aware: the provider
/// caches them to SharedPreferences and a tapped trail's GPX caches to disk
/// for offline viewing.
class RecordedTrailsScreen extends StatefulWidget {
  final bool embedded;
  const RecordedTrailsScreen({super.key, this.embedded = false});

  @override
  State<RecordedTrailsScreen> createState() => _RecordedTrailsScreenState();
}

class _RecordedTrailsScreenState extends State<RecordedTrailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final auth = context.read<ap.AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;
    await context.read<RecordedTrailsProvider>().refresh(uid);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Container(
          color: kColorBg,
          child: TabBar(
            controller: _tabController,
            labelColor: kColorOrange,
            unselectedLabelColor: kColorCream.withOpacity(0.4),
            indicatorColor: kColorOrange,
            labelStyle: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            tabs: const [
              Tab(text: 'MY TRAILS'),
              Tab(text: 'COMMUNITY'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _TrailList(scope: _ListScope.mine),
              _TrailList(scope: _ListScope.community),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        title: Text('Trails', style: GoogleFonts.outfit()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: body,
    );
  }
}

enum _ListScope { mine, community }

class _TrailList extends StatelessWidget {
  final _ListScope scope;
  const _TrailList({required this.scope});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordedTrailsProvider>(
      builder: (_, prov, __) {
        if (!prov.loaded) {
          return const Center(
              child: CircularProgressIndicator(color: kColorOrange));
        }
        final items =
            scope == _ListScope.mine ? prov.mine : prov.community;
        if (items.isEmpty) {
          return _EmptyState(scope: scope, refreshing: prov.refreshing);
        }
        return RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<ap.AuthProvider>();
            final uid = auth.uid;
            if (uid != null) await prov.refresh(uid);
          },
          color: kColorOrange,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TrailCard(trail: items[i]),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _ListScope scope;
  final bool refreshing;
  const _EmptyState({required this.scope, required this.refreshing});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scope == _ListScope.mine ? Icons.timeline : Icons.public,
                color: kColorCream.withOpacity(0.2),
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                scope == _ListScope.mine
                    ? 'No trails yet'
                    : 'No community trails',
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scope == _ListScope.mine
                    ? 'Recorded hikes show up here automatically. Tap one to view its elevation profile or share it with the community.'
                    : 'Trails other hikers share publicly will appear here. Pull down to refresh.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (refreshing) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: kColorOrange),
              ],
            ],
          ),
        ),
      );
}

class _TrailCard extends StatelessWidget {
  final RecordedTrail trail;
  const _TrailCard({required this.trail});

  @override
  Widget build(BuildContext context) {
    final isMine = context.read<ap.AuthProvider>().uid == trail.userId;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordedTrailDetailScreen(trail: trail),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _SharingBadge(trail: trail, dim: !isMine),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEE, d MMM yyyy').format(trail.createdAt),
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniMetric('DIST', '${trail.distanceKm.toStringAsFixed(2)} km'),
                _MiniMetric('ASC', '${trail.ascentM} m'),
                _MiniMetric('TIME', _fmtDuration(trail.durationSeconds)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharingBadge extends StatelessWidget {
  final RecordedTrail trail;
  final bool dim;
  const _SharingBadge({required this.trail, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (trail.sharing) {
      TrailSharing.public => const Color(0xFF22C55E),
      TrailSharing.team => const Color(0xFF38BDF8),
      TrailSharing.private => kColorCream.withOpacity(0.4),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(dim ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(dim ? 0.2 : 0.4)),
      ),
      child: Text(
        trail.sharing.label.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
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

// ── Detail screen ───────────────────────────────────────────────────────────

class RecordedTrailDetailScreen extends StatefulWidget {
  final RecordedTrail trail;
  const RecordedTrailDetailScreen({super.key, required this.trail});

  @override
  State<RecordedTrailDetailScreen> createState() =>
      _RecordedTrailDetailScreenState();
}

class _RecordedTrailDetailScreenState extends State<RecordedTrailDetailScreen> {
  List<RecordingPoint> _points = const [];
  bool _loading = true;
  String? _loadError;

  RecordedTrail get _trail {
    final prov = context.read<RecordedTrailsProvider>();
    return prov.mine.firstWhere((t) => t.id == widget.trail.id,
        orElse: () => prov.community.firstWhere(
              (t) => t.id == widget.trail.id,
              orElse: () => widget.trail,
            ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPoints());
  }

  Future<void> _loadPoints() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final points = await RecordedTrailService.downloadPoints(widget.trail);
      if (!mounted) return;
      setState(() {
        _points = points;
        _loading = false;
        _loadError = points.isEmpty
            ? 'No points found (cached download empty)'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final trail = _trail;
    final isMine = auth.uid == trail.userId;
    final profile = _buildElevationProfile(_points);
    final eleMin = profile.isEmpty
        ? 0
        : profile.map((p) => p.elevationM).reduce((a, b) => a < b ? a : b).round();
    final eleMax = profile.isEmpty
        ? 0
        : profile.map((p) => p.elevationM).reduce((a, b) => a > b ? a : b).round();

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        title: Text(trail.name, style: GoogleFonts.outfit()),
        actions: [
          if (isMine)
            PopupMenuButton<String>(
              onSelected: _onAction,
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'share_public',
                  enabled: trail.sharing != TrailSharing.public,
                  child: const Row(children: [
                    Icon(Icons.public, size: 18),
                    SizedBox(width: 8),
                    Text('Share to community'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'make_private',
                  enabled: trail.sharing != TrailSharing.private,
                  child: const Row(children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Make private'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Delete trail',
                        style: TextStyle(color: Colors.redAccent)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              _SharingBadge(trail: trail),
              const SizedBox(width: 8),
              Text(
                '${trail.pointCount} points',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: kColorOrange))
                : _TrailMap(points: _points, trail: trail),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: GoogleFonts.outfit(
                color: Colors.redAccent.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _StatsGrid(trail: trail),
          const SizedBox(height: 16),
          if (profile.length >= 2) ...[
            Text(
              'ELEVATION',
              style: GoogleFonts.outfit(
                color: kColorOrange,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ElevationChart(
                profile: profile,
                distanceKm: trail.distanceKm,
                minEle: eleMin,
                maxEle: eleMax,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onAction(String value) async {
    final prov = context.read<RecordedTrailsProvider>();
    switch (value) {
      case 'share_public':
        await prov.share(widget.trail.id, TrailSharing.public);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trail is now visible to the community')),
          );
        }
        break;
      case 'make_private':
        await prov.share(widget.trail.id, TrailSharing.private);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trail is now private')),
          );
        }
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kColorPanel,
            title: const Text('Delete trail?'),
            content: const Text(
                'This removes the trail and its GPX file from the cloud and from this device. The original hike in your Activities is not affected.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        );
        if (ok != true) return;
        final removed = await prov.delete(widget.trail);
        if (removed && mounted) Navigator.pop(context);
        break;
    }
  }

  List<ElevationPoint> _buildElevationProfile(List<RecordingPoint> points) {
    if (points.length < 2) return const [];
    final profile = <ElevationPoint>[];
    double cumulative = 0;
    profile.add(ElevationPoint(0, points.first.altitude));
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      cumulative += _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
      profile.add(ElevationPoint(cumulative, b.altitude));
    }
    return profile;
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final aLat = lat1 * math.pi / 180.0;
    final bLat = lat2 * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aLat) *
            math.cos(bLat) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}

class _TrailMap extends StatelessWidget {
  final List<RecordingPoint> points;
  final RecordedTrail trail;
  const _TrailMap({required this.points, required this.trail});

  @override
  Widget build(BuildContext context) {
    final pts = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final center = pts.isEmpty
        ? LatLng((trail.minLat ?? 0 + (trail.maxLat ?? 0)) / 2,
            (trail.minLon ?? 0 + (trail.maxLon ?? 0)) / 2)
        : pts.first;
    final bounds = pts.length < 2 ? null : _boundsFor(pts);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        initialCameraFit: bounds == null
            ? null
            : CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(28),
              ),
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: kMapTileStyles[3].url, // satellite
          userAgentPackageName: kTileUserAgent,
          tileProvider: OfflineMapService.tileProvider(),
          maxZoom: kMapTileStyles[3].maxZoom,
        ),
        if (pts.length >= 2)
          PolylineLayer(polylines: [
            Polyline(points: pts, color: kColorOrange, strokeWidth: 3.5),
          ]),
        if (pts.isNotEmpty)
          MarkerLayer(markers: [
            Marker(
              point: pts.first,
              width: 18,
              height: 18,
              child: const Icon(Icons.trip_origin,
                  color: Color(0xFF81C784), size: 16),
            ),
            Marker(
              point: pts.last,
              width: 18,
              height: 18,
              child: const Icon(Icons.flag, color: kColorOrange, size: 18),
            ),
          ]),
      ],
    );
  }

  LatLngBounds _boundsFor(List<LatLng> p) {
    final lats = p.map((q) => q.latitude).toList()..sort();
    final lons = p.map((q) => q.longitude).toList()..sort();
    return LatLngBounds(
      LatLng(lats.first, lons.first),
      LatLng(lats.last, lons.last),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final RecordedTrail trail;
  const _StatsGrid({required this.trail});

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTile>[
      _StatTile('Distance', '${trail.distanceKm.toStringAsFixed(2)} km'),
      _StatTile('Duration', _fmtDuration(trail.durationSeconds)),
      _StatTile('Ascent', '${trail.ascentM} m'),
      _StatTile('Descent', '${trail.descentM} m'),
      _StatTile('Points', '${trail.pointCount}'),
      _StatTile('Type', trail.activityType),
    ];
    return Container(
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
            'STATS',
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
              final w = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map((t) => SizedBox(width: w, child: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile(this.label, this.value);

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
            Text(label,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.42),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 5),
            Text(value,
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                )),
          ],
        ),
      );
}

String _fmtDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
