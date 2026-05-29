// Trailtether 3.0 — Hike history & detail screens, reskinned to TT tokens.
//
// HikeHistoryScreen is the legacy list of every locally-recorded hike. It is
// still pushed from a couple of TT screens, so we keep the public API intact
// (constructor, route push behaviour) and only update its visuals.
//
// HikeDetailScreen renders one SavedHike with a real flutter_map polyline
// preview, an animated elevation profile, a stat breakdown, plus share /
// delete actions. Both screens consume HikeHistoryProvider and run on the
// same data model as before — nothing about persistence or Supabase sync is
// touched here.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/saved_hike.dart';
import '../providers/hike_history_provider.dart';
import '../providers/units_provider.dart';
import '../services/health_connect_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_topo.dart';
import '../widgets/map/speed_path_layer.dart';

// ───────────────────────────── HISTORY LIST ────────────────────────────────

class HikeHistoryScreen extends StatelessWidget {
  /// When true the screen renders without its own Scaffold / SafeArea — the
  /// surrounding shell (e.g. AppShell) is expected to provide both.
  final bool embedded;
  const HikeHistoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop()),
        SafeArea(
          top: !embedded,
          bottom: false,
          child: const Column(
            children: [
              TTPageAppBar(title: 'Hike History'),
              Expanded(child: _HistoryBody()),
            ],
          ),
        ),
      ],
    );

    if (embedded) return Material(color: TT.bg, child: stack);
    return Scaffold(backgroundColor: TT.bg, body: stack);
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<HikeHistoryProvider>(
      builder: (_, history, __) {
        if (!history.loaded) {
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
        if (history.hikes.isEmpty) return const _EmptyHistory();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          itemCount: history.hikes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _HistoryRow(hike: history.hikes[i]),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
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
                  border: Border.all(color: const Color(0x52FF6A2C), width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.landscape_outlined,
                    color: TT.ember, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'No recorded hikes yet',
                textAlign: TextAlign.center,
                style: TT.title(17, letterSpacing: -0.01 * 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap Start Hike on the Map to begin a recording — '
                'it will land here when you finish.',
                textAlign: TextAlign.center,
                style: TT.body(size: 12.5, color: TT.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SavedHike hike;
  const _HistoryRow({required this.hike});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final date = DateFormat('EEE, d MMM yyyy').format(hike.startedAt);
    final distance = units.formatDistance(hike.distanceKm, decimals: 2);
    final ascent = units.formatElevation(hike.ascentM.toDouble());
    final duration = _formatDuration(hike.durationSeconds);

    return TTCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: TT.ember,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
                boxShadow: [BoxShadow(color: Color(0x66FF6A2C), blurRadius: 8)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hike.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TT.body(size: 14.5, w: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(date,
                              style: TT.mono(size: 10.5, color: TT.text3)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TT.text3, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RowStat(label: 'DIST', value: distance),
                    _RowStat(label: 'TIME', value: duration),
                    _RowStat(label: 'ASC', value: ascent, ember: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowStat extends StatelessWidget {
  final String label;
  final String value;
  final bool ember;
  const _RowStat(
      {required this.label, required this.value, this.ember = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TT.label(
                  size: 9.5, color: TT.text3, letterSpacing: 0.16 * 9.5)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TT.numStyle(
              size: 14,
              color: ember ? TT.ember : TT.text,
              w: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── DETAIL SCREEN ───────────────────────────────

class HikeDetailScreen extends StatelessWidget {
  final SavedHike hike;
  const HikeDetailScreen({super.key, required this.hike});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Delete this hike?', style: TT.title(16)),
        content: Text(
          'This permanently removes "${hike.name}" from your device. '
          'Cannot be undone.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TT.body(size: 13, color: TT.red, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final history = context.read<HikeHistoryProvider>();
    await history.remove(hike.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _share() async {
    final dist = hike.distanceKm.toStringAsFixed(2);
    final asc = hike.ascentM;
    final dur = _formatDuration(hike.durationSeconds);
    final date = DateFormat('d MMM yyyy').format(hike.startedAt);
    await Share.share(
      '${hike.name} — $date\n'
      '$dist km · ↑ $asc m · $dur\n'
      'Recorded with Trailtether.',
      subject: hike.name,
    );
  }

  Future<void> _syncToHealthConnect(BuildContext context) async {
    final result = await HealthConnectService.writeHike(hike);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(result.userMessage, style: TT.body(size: 13, color: TT.text)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, d MMMM yyyy · HH:mm').format(hike.startedAt);

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
                  title: hike.name,
                  onBack: () => Navigator.of(context).pop(),
                  onShare: _share,
                  onDelete: () => _confirmDelete(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      _HeroCard(hike: hike, date: date),
                      const SizedBox(height: 14),
                      _MapPreview(hike: hike),
                      const SizedBox(height: 14),
                      _ElevationCard(hike: hike),
                      const SizedBox(height: 14),
                      _StatGridCard(hike: hike),
                      const SizedBox(height: 14),
                      _GpsQualityCard(hike: hike),
                      const SizedBox(height: 14),
                      _HealthConnectButton(
                        onTap: () => _syncToHealthConnect(context),
                      ),
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
}

class _DetailAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _DetailAppBar({
    required this.title,
    required this.onBack,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          TTIconBtn(icon: Icons.chevron_left, size: 38, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TT.title(19, letterSpacing: -0.01 * 19),
            ),
          ),
          const SizedBox(width: 8),
          TTIconBtn(icon: Icons.ios_share, size: 38, onTap: onShare),
          const SizedBox(width: 6),
          TTIconBtn(
            icon: Icons.delete_outline,
            size: 38,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final SavedHike hike;
  final String date;
  const _HeroCard({required this.hike, required this.date});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final distance = units.formatDistance(hike.distanceKm, decimals: 2);
    final ascent = units.formatElevation(hike.ascentM.toDouble());
    final maxSpeed = units.formatSpeed(hike.maxSpeedKmh);
    final duration = _formatDuration(hike.durationSeconds);

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hike.name,
            style: TT.title(22, letterSpacing: -0.01 * 22),
          ),
          const SizedBox(height: 6),
          Text(date, style: TT.mono(size: 10.5, color: TT.text3)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroMetric(label: 'DURATION', value: duration),
              _HeroDivider(),
              _HeroMetric(label: 'POINTS', value: '${hike.pointCount}'),
              _HeroDivider(),
              _HeroMetric(
                  label: 'ACTIVITY', value: hike.activityType.toUpperCase()),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: TT.line),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroMetric(label: 'DISTANCE', value: distance, ember: true),
              _HeroDivider(),
              _HeroMetric(label: 'ASCENT', value: ascent, ember: true),
              _HeroDivider(),
              _HeroMetric(label: 'MAX SPD', value: maxSpeed),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool ember;
  const _HeroMetric({
    required this.label,
    required this.value,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TT.label(
                  size: 9.5, color: TT.text3, letterSpacing: 0.16 * 9.5)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TT.numStyle(
              size: 16,
              color: ember ? TT.ember : TT.text,
              w: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: TT.line,
    );
  }
}

class _MapPreview extends StatelessWidget {
  final SavedHike hike;
  const _MapPreview({required this.hike});

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
        child: hike.points.isEmpty
            ? _MapEmpty()
            : _RouteMap(hike: hike, interactive: false),
      ),
    );
  }
}

class _MapEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: TT.bg2,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: TT.text3, size: 30),
          const SizedBox(height: 10),
          Text('No GPS points captured',
              style: TT.body(size: 12, color: TT.text3)),
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
          retinaMode: kHighDensity(context),
        ),
        if (hike.points.isNotEmpty) SpeedPathLayer(points: hike.points),
        if (route.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: route.first,
                width: 18,
                height: 18,
                child: const Icon(Icons.trip_origin, color: TT.green, size: 16),
              ),
              Marker(
                point: route.last,
                width: 18,
                height: 18,
                child: const Icon(Icons.flag, color: TT.ember, size: 18),
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

class _ElevationCard extends StatelessWidget {
  final SavedHike hike;
  const _ElevationCard({required this.hike});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final altitudes = hike.points.length >= 4
        ? hike.points.map((p) => p.altitude).toList()
        : null;
    final ascentLabel =
        '${units.formatElevation(hike.ascentM.toDouble())} ascent';
    final peakLabel = '${units.formatDistance(hike.distanceKm)} · $ascentLabel';

    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ELEVATION PROFILE',
                style: TT.label(
                    size: 11, color: TT.ember, letterSpacing: 0.16 * 11),
              ),
              Text(
                'RANGE ${units.formatElevation(hike.elevationRangeM).toUpperCase()}',
                style: TT.mono(size: 10, color: TT.text3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (altitudes == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Not enough GPS points for an elevation curve',
                  style: TT.body(size: 12, color: TT.text3),
                ),
              ),
            )
          else
            TTBigElevChart(
                samples: altitudes,
                peakLabel: peakLabel,
                elevationUnit: units.elevationUnit),
        ],
      ),
    );
  }
}

class _StatGridCard extends StatelessWidget {
  final SavedHike hike;
  const _StatGridCard({required this.hike});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final paceKm = units.formatPace(hike.durationSeconds, hike.distanceKm);
    final avgSpd = units.formatSpeed(hike.averageSpeedKmh);
    final movSpd = units.formatSpeed(hike.movingSpeedKmh);
    final moving = _formatDuration(hike.movingSeconds);
    final stopped = _formatDuration(hike.stoppedSeconds);
    final descent = units.formatElevation(hike.descentM.toDouble());
    final low = units.formatElevation(hike.minElevationM);
    final high = units.formatElevation(hike.maxElevationM);
    final peaks = '${hike.peaksClimbed}';

    final tiles = <_StatTile>[
      _StatTile(label: 'AVG PACE', value: paceKm, unit: units.paceUnit),
      _StatTile(label: 'AVG SPD', value: avgSpd),
      _StatTile(label: 'MOVING', value: movSpd),
      _StatTile(label: 'MOVING T', value: moving),
      _StatTile(label: 'STOPPED', value: stopped),
      _StatTile(label: 'DESCENT', value: descent, ember: true),
      _StatTile(label: 'LOWEST', value: low),
      _StatTile(label: 'HIGHEST', value: high),
      _StatTile(label: 'PEAKS', value: peaks, ember: true),
    ];

    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PACE & ELEVATION',
            style:
                TT.label(size: 11, color: TT.ember, letterSpacing: 0.16 * 11),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (_, cs) {
            const spacing = 10.0;
            final w = (cs.maxWidth - spacing * 2) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: ember ? TT.emberSoft : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(TT.rSm),
        border: Border.all(
          color: ember ? const Color(0x52FF6A2C) : TT.line,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TT.label(size: 9, color: TT.text3, letterSpacing: 0.16 * 9),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TT.numStyle(
                    size: 13,
                    color: ember ? TT.ember : TT.text,
                    w: FontWeight.w800,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: TT.mono(size: 9.5, color: TT.text3)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GpsQualityCard extends StatelessWidget {
  final SavedHike hike;
  const _GpsQualityCard({required this.hike});

  @override
  Widget build(BuildContext context) {
    final acc = hike.averageAccuracyM.toStringAsFixed(1);
    final best = hike.bestAccuracyM.toStringAsFixed(1);
    final worst = hike.worstAccuracyM.toStringAsFixed(1);

    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GPS QUALITY',
            style:
                TT.label(size: 11, color: TT.ember, letterSpacing: 0.16 * 11),
          ),
          const SizedBox(height: 12),
          _GpsRow(label: 'Accepted fixes', value: '${hike.acceptedFixes}'),
          _GpsRow(label: 'Rejected fixes', value: '${hike.rejectedFixes}'),
          _GpsRow(label: 'Poor accuracy', value: '${hike.poorAccuracyRejects}'),
          _GpsRow(label: 'Jump rejects', value: '${hike.jumpRejects}'),
          _GpsRow(label: 'Stale rejects', value: '${hike.staleRejects}'),
          _GpsRow(label: 'Gap warnings', value: '${hike.gapWarnings}'),
          const SizedBox(height: 10),
          Container(height: 1, color: TT.line),
          const SizedBox(height: 10),
          _GpsRow(label: 'Average accuracy', value: '$acc m'),
          _GpsRow(label: 'Best accuracy', value: '$best m'),
          _GpsRow(label: 'Worst accuracy', value: '$worst m', last: true),
        ],
      ),
    );
  }
}

class _GpsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  const _GpsRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TT.body(size: 12.5, color: TT.text2)),
          Text(value,
              style:
                  TT.numStyle(size: 12.5, color: TT.text, w: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _HealthConnectButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HealthConnectButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(TT.rMd),
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.favorite_outline, size: 18, color: TT.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync to Health Connect',
                    style: TT.body(size: 13.5, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('Writes this hike to your phone\'s health store',
                    style: TT.mono(size: 10.5, color: TT.text3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: TT.text3, size: 22),
        ],
      ),
    );
  }
}

// ───────────────────────────── HELPERS ─────────────────────────────────────

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
