// Trailtether 3.0 — "Trails" hub, reskinned to TT tokens.
//
// Two-tab list (My Trails / Community) backed by RecordedTrailsProvider. The
// detail screen reads its GPX file off Supabase Storage, renders an offline
// flutter_map preview with the route polyline in ember, an animated TT
// elevation chart, and exposes Share / Make private / Delete actions for the
// owner. All data flow (provider.refresh, provider.share, provider.delete,
// RecordedTrailService.downloadPoints) is preserved exactly.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/recorded_trail.dart';
import '../models/recording_point.dart';
import '../models/trail.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/recorded_trails_provider.dart';
import '../services/offline_map_service.dart';
import '../services/recorded_trail_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';

class RecordedTrailsScreen extends StatefulWidget {
  final bool embedded;
  const RecordedTrailsScreen({super.key, this.embedded = false});

  @override
  State<RecordedTrailsScreen> createState() => _RecordedTrailsScreenState();
}

class _RecordedTrailsScreenState extends State<RecordedTrailsScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
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
        if (!widget.embedded)
          TTPageAppBar(
            title: 'Trails',
            trailing: [
              TTIconBtn(icon: Icons.refresh, onTap: _refresh),
            ],
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              18, widget.embedded ? 6 : 6, 18, 12),
          child: TTSegmented(
            tabs: const ['MY TRAILS', 'COMMUNITY'],
            active: _tab,
            onChange: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(child: _TrailList(scope: _tab == 0 ? _Scope.mine : _Scope.community)),
      ],
    );

    final stack = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop()),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: body,
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: stack);
    return Scaffold(backgroundColor: TT.bg, body: stack);
  }
}

enum _Scope { mine, community }

class _TrailList extends StatelessWidget {
  final _Scope scope;
  const _TrailList({required this.scope});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordedTrailsProvider>(
      builder: (_, prov, __) {
        if (!prov.loaded) {
          return const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: TT.ember,
                strokeWidth: 2.4,
              ),
            ),
          );
        }
        final items = scope == _Scope.mine ? prov.mine : prov.community;
        if (items.isEmpty) {
          return _EmptyState(scope: scope, refreshing: prov.refreshing);
        }
        return RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<ap.AuthProvider>();
            final uid = auth.uid;
            if (uid != null) await prov.refresh(uid);
          },
          color: TT.ember,
          backgroundColor: TT.bg2,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TrailRow(trail: items[i]),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _Scope scope;
  final bool refreshing;
  const _EmptyState({required this.scope, required this.refreshing});

  @override
  Widget build(BuildContext context) {
    final isMine = scope == _Scope.mine;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
        child: TTCard(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: TT.emberDim,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0x52FF6A2C), width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isMine ? Icons.timeline : Icons.public,
                  color: TT.ember,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMine ? 'No trails yet' : 'No community trails',
                textAlign: TextAlign.center,
                style: TT.title(17, letterSpacing: -0.01 * 17),
              ),
              const SizedBox(height: 6),
              Text(
                isMine
                    ? 'Recorded hikes show up here automatically. Tap one to view its elevation profile or share it with the community.'
                    : 'Trails other hikers share publicly will appear here. Pull down to refresh.',
                textAlign: TextAlign.center,
                style: TT.body(size: 12.5, color: TT.text3),
              ),
              if (refreshing) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: TT.ember,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailRow extends StatelessWidget {
  final RecordedTrail trail;
  const _TrailRow({required this.trail});

  @override
  Widget build(BuildContext context) {
    final isMine = context.read<ap.AuthProvider>().uid == trail.userId;
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => RecordedTrailDetailScreen(trail: trail),
        ),
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
                  style: TT.title(16, letterSpacing: -0.01 * 16),
                ),
              ),
              _SharingBadge(sharing: trail.sharing, dim: !isMine),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEE, d MMM yyyy').format(trail.createdAt),
            style: TT.mono(size: 11, color: TT.text3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniMetric(
                  label: 'DIST',
                  value: '${trail.distanceKm.toStringAsFixed(2)} km'),
              _Divider(),
              _MiniMetric(label: 'ASC', value: '${trail.ascentM} m'),
              _Divider(),
              _MiniMetric(
                  label: 'TIME',
                  value: _fmtDuration(trail.durationSeconds)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharingBadge extends StatelessWidget {
  final TrailSharing sharing;
  final bool dim;
  const _SharingBadge({required this.sharing, this.dim = false});

  @override
  Widget build(BuildContext context) {
    Color fg;
    String label;
    switch (sharing) {
      case TrailSharing.public:
        fg = TT.green;
        label = 'COMMUNITY';
        break;
      case TrailSharing.team:
        fg = TT.blue;
        label = 'TEAM';
        break;
      case TrailSharing.private:
        fg = TT.text3;
        label = 'PRIVATE';
        break;
    }
    if (dim) fg = fg.withOpacity(0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TT.mono(size: 9.5, color: fg, letterSpacing: 1.14),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TT.numStyle(size: 14, color: TT.text, w: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: TT.line,
      );
}

// ── Detail screen ─────────────────────────────────────────────────────────

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
    return prov.mine.firstWhere(
      (t) => t.id == widget.trail.id,
      orElse: () => prov.community.firstWhere(
        (t) => t.id == widget.trail.id,
        orElse: () => widget.trail,
      ),
    );
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
        _loadError =
            points.isEmpty ? 'No points found (cached download empty)' : null;
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
    final altitudes =
        profile.length >= 2 ? profile.map((p) => p.elevationM).toList() : null;

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _DetailAppBar(
                  title: trail.name,
                  isMine: isMine,
                  sharing: trail.sharing,
                  onBack: () => Navigator.of(context).pop(),
                  onAction: _onAction,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    children: [
                      Row(
                        children: [
                          _SharingBadge(sharing: trail.sharing),
                          const SizedBox(width: 8),
                          Text(
                            '${trail.pointCount} POINTS',
                            style: TT.label(
                                size: 10, color: TT.text3, letterSpacing: 1.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MapPreview(
                        loading: _loading,
                        points: _points,
                        trail: trail,
                      ),
                      if (_loadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _loadError!,
                          style: TT.mono(size: 10.5, color: TT.red),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _StatsCard(trail: trail),
                      if (altitudes != null) ...[
                        const SizedBox(height: 14),
                        _ElevationCard(
                          altitudes: altitudes,
                          distanceKm: trail.distanceKm,
                          ascentM: trail.ascentM,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            SnackBar(
              backgroundColor: TT.surf,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Trail is now visible to the community',
                style: TT.body(size: 13, color: TT.text),
              ),
            ),
          );
        }
        break;
      case 'make_private':
        await prov.share(widget.trail.id, TrailSharing.private);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: TT.surf,
              behavior: SnackBarBehavior.floating,
              content:
                  Text('Trail is now private',
                      style: TT.body(size: 13, color: TT.text)),
            ),
          );
        }
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: TT.bg2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TT.rLg),
              side: const BorderSide(color: TT.line2),
            ),
            title: Text('Delete trail?', style: TT.title(17)),
            content: Text(
              'This removes the trail and its GPX file from the cloud and from this device. The original hike in your Activities is not affected.',
              style: TT.body(size: 13, color: TT.text2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TT.body(
                        size: 13, w: FontWeight.w700, color: TT.text2)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete',
                    style: TT.body(
                        size: 13, w: FontWeight.w800, color: TT.red)),
              ),
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
      cumulative +=
          _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
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

class _DetailAppBar extends StatelessWidget {
  final String title;
  final bool isMine;
  final TrailSharing sharing;
  final VoidCallback onBack;
  final ValueChanged<String> onAction;

  const _DetailAppBar({
    required this.title,
    required this.isMine,
    required this.sharing,
    required this.onBack,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          TTIconBtn(icon: Icons.chevron_left, size: 38, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TT.title(20, letterSpacing: -0.01 * 20),
            ),
          ),
          if (isMine)
            _OverflowMenu(sharing: sharing, onSelected: onAction),
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final TrailSharing sharing;
  final ValueChanged<String> onSelected;
  const _OverflowMenu({required this.sharing, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      icon: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.line),
        ),
        child: const Icon(Icons.more_horiz, color: TT.text2, size: 18),
      ),
      color: TT.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TT.rMd),
        side: const BorderSide(color: TT.line2),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'share_public',
          enabled: sharing != TrailSharing.public,
          child: _menuTile(
              Icons.public, 'Share to community', TT.green),
        ),
        PopupMenuItem<String>(
          value: 'make_private',
          enabled: sharing != TrailSharing.private,
          child: _menuTile(
              Icons.lock_outline, 'Make private', TT.text2),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: _menuTile(
              Icons.delete_outline, 'Delete trail', TT.red),
        ),
      ],
    );
  }

  Widget _menuTile(IconData icon, String label, Color tint) {
    return Row(
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 10),
        Text(label,
            style:
                TT.body(size: 13, w: FontWeight.w700, color: TT.text)),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  final bool loading;
  final List<RecordingPoint> points;
  final RecordedTrail trail;
  const _MapPreview({
    required this.loading,
    required this.points,
    required this.trail,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TT.rLg),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: TT.surf,
          borderRadius: BorderRadius.circular(TT.rLg),
          border: Border.all(color: TT.line, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: TT.ember,
                    strokeWidth: 2,
                  ),
                ),
              )
            : _TrailMap(points: points, trail: trail),
      ),
    );
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
        ? LatLng(
            (trail.minLat ?? 0 + (trail.maxLat ?? 0)) / 2,
            (trail.minLon ?? 0 + (trail.maxLon ?? 0)) / 2,
          )
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
          urlTemplate: kMapTileStyles[3].url,
          userAgentPackageName: kTileUserAgent,
          tileProvider: OfflineMapService.tileProvider(),
          maxZoom: kMapTileStyles[3].maxZoom,
        ),
        if (pts.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: pts,
                color: TT.ember,
                strokeWidth: 3.5,
              ),
            ],
          ),
        if (pts.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: pts.first,
                width: 18,
                height: 18,
                child: const Icon(Icons.trip_origin,
                    color: TT.green, size: 16),
              ),
              Marker(
                point: pts.last,
                width: 18,
                height: 18,
                child: const Icon(Icons.flag, color: TT.ember, size: 18),
              ),
            ],
          ),
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

class _StatsCard extends StatelessWidget {
  final RecordedTrail trail;
  const _StatsCard({required this.trail});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATS',
            style:
                TT.label(size: 11, color: TT.ember, letterSpacing: 1.4),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (_, constraints) {
              final w = (constraints.maxWidth - 10) / 2;
              final tiles = [
                _Stat(
                  width: w,
                  label: 'DISTANCE',
                  value: '${trail.distanceKm.toStringAsFixed(2)} km',
                ),
                _Stat(
                  width: w,
                  label: 'DURATION',
                  value: _fmtDuration(trail.durationSeconds),
                ),
                _Stat(
                  width: w,
                  label: 'ASCENT',
                  value: '${trail.ascentM} m',
                  ember: true,
                ),
                _Stat(
                  width: w,
                  label: 'DESCENT',
                  value: '${trail.descentM} m',
                ),
                _Stat(
                  width: w,
                  label: 'POINTS',
                  value: '${trail.pointCount}',
                ),
                _Stat(
                  width: w,
                  label: 'TYPE',
                  value: trail.activityType.toUpperCase(),
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final bool ember;
  const _Stat({
    required this.width,
    required this.label,
    required this.value,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ember ? TT.emberSoft : const Color(0x05FFFFFF),
          borderRadius: BorderRadius.circular(TT.rSm),
          border: Border.all(
              color: ember ? const Color(0x33FF6A2C) : TT.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TT.label(
                    size: 9.5, color: TT.text3, letterSpacing: 1.4)),
            const SizedBox(height: 5),
            TTCountUp(
              text: value,
              style: TT.numStyle(
                size: 16,
                color: ember ? TT.ember : TT.text,
                w: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElevationCard extends StatelessWidget {
  final List<double> altitudes;
  final double distanceKm;
  final int ascentM;
  const _ElevationCard({
    required this.altitudes,
    required this.distanceKm,
    required this.ascentM,
  });

  @override
  Widget build(BuildContext context) {
    final peakLabel = '${distanceKm.toStringAsFixed(1)} km · $ascentM m';
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ELEVATION',
              style: TT.label(
                  size: 11, color: TT.ember, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          TTBigElevChart(samples: altitudes, peakLabel: peakLabel),
        ],
      ),
    );
  }
}

String _fmtDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
