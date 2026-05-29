// Trailtether 3.0 — Trail detail bottom sheet, reskinned to TT tokens.
//
// Pushed as a DraggableScrollableSheet from the map screen and Mission
// Control. Renders one Trail's hero, stat tiles, elevation profile, reviews,
// nearby caves and a sticky ember "START HIKE" CTA that wires the trail into
// RecordingProvider and pops back to the live map.
//
// Logic preserved: favourite / completed toggles, pace selector, peak
// check-in via Supabase, share, safety centre, follow target trail.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// latlong2 exports a generic `Path<T>` that shadows the `dart:ui` `Path`
// used by CustomPainter elsewhere in this file, so we hide it on import.
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../models/cave_waypoint.dart';
import '../models/trail.dart';
import '../services/offline_map_service.dart';
import '../services/logger_service.dart';
import '../providers/app_state_provider.dart';
import '../providers/community_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/review_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/units_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';
import '../widgets/review/review_card.dart';
import '../widgets/review/review_summary_bar.dart';
import '../widgets/cave_detail_sheet.dart';
import 'reviews_screen.dart';
import 'safety_center_screen.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final VoidCallback onNavigateToMap;
  const TrailDetailScreen({
    super.key,
    required this.trail,
    required this.onNavigateToMap,
  });

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  double _paceFactor = 1.0;
  late StaticDataProvider _staticDataProvider;

  @override
  void initState() {
    super.initState();
    context.read<ReviewProvider>().listenTo(widget.trail.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _staticDataProvider = context.read<StaticDataProvider>();
  }

  @override
  void dispose() {
    _staticDataProvider.clearProfileCursor();
    super.dispose();
  }

  void _startHike() {
    final rec = context.read<RecordingProvider>();
    rec.setTargetTrail(widget.trail);
    Navigator.pop(context);
    widget.onNavigateToMap();
  }

  void _openOnMap() {
    context.read<StaticDataProvider>().selectTrail(widget.trail);
    Navigator.pop(context);
    widget.onNavigateToMap();
  }

  Future<void> _share() {
    final units = context.read<UnitsProvider>();
    return Share.share(
      'Check out ${widget.trail.name} on Trailtether: '
      '${units.formatDistance(widget.trail.distanceKm)}, '
      '${units.formatElevation(widget.trail.elevationGainM.toDouble())} gain.',
    );
  }

  void _openSafety() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SafetyCenterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trail = widget.trail;
    final appState = context.watch<AppStateProvider>();
    final isFavorite = appState.isFavorite(trail.id);
    final isCompleted = appState.isCompleted(trail.id);
    final caves = _cavesOnRoute(
      context.watch<StaticDataProvider>().caves,
      trail,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(TT.rXl)),
        // Material ancestor is required for Text to render without Flutter's
        // yellow "missing-Material" debug underline. A bare Container in the
        // DraggableScrollableSheet builder doesn't provide one, so every
        // label inside the sheet was rendering with a yellow squiggle.
        child: Material(
          color: TT.bg,
          child: Stack(
            children: [
              const Positioned.fill(child: TTAmbient()),
              const Positioned.fill(child: TTTopoBackdrop()),
              Column(
                children: [
                  // Grab handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TT.line3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                      children: [
                        _HeroArea(trail: trail),
                        const SizedBox(height: 14),
                        _TitleCard(
                          trail: trail,
                          isCompleted: isCompleted,
                        ),
                        const SizedBox(height: 14),
                        _StatsRow(trail: trail, paceFactor: _paceFactor),
                        const SizedBox(height: 14),
                        _PaceCard(
                          paceFactor: _paceFactor,
                          onChanged: (v) => setState(() => _paceFactor = v),
                        ),
                        const SizedBox(height: 14),
                        _ActionRow(
                          isFavorite: isFavorite,
                          isCompleted: isCompleted,
                          isFollowing: context
                                  .watch<RecordingProvider>()
                                  .targetTrail
                                  ?.id ==
                              trail.id,
                          onFavorite: () => context
                              .read<AppStateProvider>()
                              .toggleFavorite(trail.id),
                          onCompleted: () => context
                              .read<AppStateProvider>()
                              .toggleCompleted(trail.id),
                          onFollow: _startHike,
                          onMap: _openOnMap,
                          onShare: () => unawaited(_share()),
                          onSafety: _openSafety,
                        ),
                        const SizedBox(height: 18),
                        _ElevationCard(trail: trail),
                        const SizedBox(height: 14),
                        _PlanningNotes(trail: trail),
                        if (trail.description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _DescriptionCard(text: trail.description),
                        ],
                        if (caves.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _CavesCard(caves: caves),
                        ],
                        const SizedBox(height: 14),
                        _ReviewsSection(trail: trail),
                        if (_isPeak(trail)) ...[
                          const SizedBox(height: 14),
                          _PeakCheckInCard(trail: trail),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Sticky bottom START HIKE button.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyStartButton(
                  isFollowing:
                      context.watch<RecordingProvider>().targetTrail?.id ==
                          trail.id,
                  onTap: _startHike,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isPeak(Trail t) {
    final n = t.name.toLowerCase();
    return n.contains('peak') || n.contains('summit') || n.contains('pass');
  }

  static List<CaveWaypoint> _cavesOnRoute(List<CaveWaypoint> all, Trail t) {
    if (all.isEmpty || t.coords.isEmpty) return const [];
    const thresholdM = 300.0;
    final result = <CaveWaypoint>[];
    for (final c in all) {
      var nearest = double.infinity;
      for (final coord in t.coords) {
        final d =
            Geolocator.distanceBetween(c.lat, c.lon, coord.lat, coord.lon);
        if (d < nearest) nearest = d;
        if (nearest < thresholdM) break;
      }
      if (nearest < thresholdM) result.add(c);
    }
    return result;
  }
}

// ── Hero area ─────────────────────────────────────────────────────────────

class _HeroArea extends StatelessWidget {
  final Trail trail;
  const _HeroArea({required this.trail});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TT.rLg),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MountainPainter(
                primary: TT.ember,
                secondary: TT.ember.withOpacity(0.55),
                tertiary: TT.text3,
                background: TT.bg2,
              ),
            ),
            // Top fade for legibility
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TT.bg.withOpacity(0.0),
                    TT.bg.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 12,
              child: Hero(
                tag: 'trail_name_${trail.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    trail.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TT
                        .body(
                          size: 12,
                          w: FontWeight.w900,
                          color: TT.text,
                        )
                        .copyWith(
                          letterSpacing: 0.18 * 12,
                          decoration: TextDecoration.none,
                        ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trail.isCave) ...[
                    const TTPill(
                      label: 'CAVE ROUTE',
                      variant: TTPillVariant.neutral,
                      leadingIcon: Icons.dark_mode_outlined,
                    ),
                    const SizedBox(width: 6),
                  ],
                  TTPill(
                    label: trail.difficulty.toUpperCase(),
                    variant: TTPillVariant.ember,
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

class _MountainPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  _MountainPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = background);

    // Far mountains
    final far = Path()
      ..moveTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.15, size.height * 0.55)
      ..lineTo(size.width * 0.30, size.height * 0.70)
      ..lineTo(size.width * 0.48, size.height * 0.40)
      ..lineTo(size.width * 0.65, size.height * 0.65)
      ..lineTo(size.width * 0.82, size.height * 0.50)
      ..lineTo(size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        far,
        Paint()
          ..color = tertiary.withOpacity(0.25)
          ..style = PaintingStyle.fill);

    // Mid range
    final mid = Path()
      ..moveTo(0, size.height * 0.88)
      ..lineTo(size.width * 0.12, size.height * 0.72)
      ..lineTo(size.width * 0.32, size.height * 0.85)
      ..lineTo(size.width * 0.50, size.height * 0.58)
      ..lineTo(size.width * 0.66, size.height * 0.82)
      ..lineTo(size.width * 0.85, size.height * 0.66)
      ..lineTo(size.width, size.height * 0.80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        mid,
        Paint()
          ..color = secondary.withOpacity(0.30)
          ..style = PaintingStyle.fill);

    // Foreground summit
    final fg = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.20, size.height * 0.84)
      ..lineTo(size.width * 0.42, size.height * 0.55)
      ..lineTo(size.width * 0.56, size.height * 0.72)
      ..lineTo(size.width * 0.80, size.height * 0.60)
      ..lineTo(size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
        fg,
        Paint()
          ..color = primary.withOpacity(0.85)
          ..style = PaintingStyle.fill);

    // Summit highlight
    final ridge = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.20, size.height * 0.84)
      ..lineTo(size.width * 0.42, size.height * 0.55)
      ..lineTo(size.width * 0.56, size.height * 0.72)
      ..lineTo(size.width * 0.80, size.height * 0.60)
      ..lineTo(size.width, size.height * 0.78);
    canvas.drawPath(
        ridge,
        Paint()
          ..color = primary
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_MountainPainter old) =>
      old.primary != primary || old.secondary != secondary;
}

// ── Title card ────────────────────────────────────────────────────────────

class _TitleCard extends StatelessWidget {
  final Trail trail;
  final bool isCompleted;
  const _TitleCard({required this.trail, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trail.name,
                  style: TT.title(20, letterSpacing: -0.01 * 20),
                ),
              ),
              const SizedBox(width: 10),
              TTPill(
                label: trail.difficulty.toUpperCase(),
                variant: TTPillVariant.ember,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.terrain, size: 12, color: TT.text3),
              const SizedBox(width: 4),
              Text(
                '${trail.minEle}–${trail.maxEle} m elevation',
                style: TT.mono(size: 11, color: TT.text3),
              ),
              const SizedBox(width: 12),
              if (isCompleted) ...[
                const Icon(Icons.check_circle, size: 12, color: TT.green),
                const SizedBox(width: 4),
                Text('COMPLETED',
                    style: TT.mono(
                        size: 9.5, color: TT.green, letterSpacing: 1.14)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Trail trail;
  final double paceFactor;
  const _StatsRow({required this.trail, required this.paceFactor});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final descentDisplay =
        units.elevationFromM(trail.elevationDescentM.toDouble()).round();
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'DISTANCE',
            from: 0,
            to: units.distanceFromKm(trail.distanceKm),
            formatter: (v) => '${v.toStringAsFixed(1)} ${units.distanceUnit}',
            ember: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'ELEV +/−',
            from: 0,
            to: units.elevationFromM(trail.elevationGainM.toDouble()),
            formatter: (v) =>
                '${v.toInt()}/$descentDisplay ${units.elevationUnit}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'EST. TIME',
            text: trail.formattedTime(paceFactor),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String? text;
  final double? from;
  final double? to;
  final String Function(double)? formatter;
  final bool ember;
  const _StatTile({
    required this.label,
    this.text,
    this.from,
    this.to,
    this.formatter,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TT.numStyle(
      size: 16,
      color: ember ? TT.ember : TT.text,
      w: FontWeight.w800,
    );
    return TTCard(
      tight: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          if (text != null)
            TTCountUp(text: text!, style: style)
          else
            TTCountUp.number(
              from: from!,
              to: to!,
              formatter: formatter!,
              style: style,
            ),
        ],
      ),
    );
  }
}

// ── Pace selector card ────────────────────────────────────────────────────

class _PaceCard extends StatelessWidget {
  final double paceFactor;
  final ValueChanged<double> onChanged;
  const _PaceCard({required this.paceFactor, required this.onChanged});

  static const _values = [0.7, 1.0, 1.3];

  @override
  Widget build(BuildContext context) {
    final active = _values.indexOf(paceFactor).clamp(0, 2);
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 12, color: TT.ember),
              const SizedBox(width: 6),
              Text('PACE',
                  style: TT.label(
                      size: 10.5, color: TT.ember, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
          TTSegmented(
            tabs: const ['FAST', 'MODERATE', 'SLOW'],
            active: active,
            onChange: (i) => onChanged(_values[i]),
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool isFavorite;
  final bool isCompleted;
  final bool isFollowing;
  final VoidCallback onFavorite;
  final VoidCallback onCompleted;
  final VoidCallback onFollow;
  final VoidCallback onMap;
  final VoidCallback onShare;
  final VoidCallback onSafety;

  const _ActionRow({
    required this.isFavorite,
    required this.isCompleted,
    required this.isFollowing,
    required this.onFavorite,
    required this.onCompleted,
    required this.onFollow,
    required this.onMap,
    required this.onShare,
    required this.onSafety,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon: isFollowing ? Icons.gps_fixed : Icons.directions_walk,
          label: isFollowing ? 'Following' : 'Follow',
          ember: isFollowing,
          onTap: onFollow,
        ),
        _ActionChip(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          label: isFavorite ? 'Saved' : 'Save',
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            onFavorite();
          },
        ),
        _ActionChip(
          icon: isCompleted ? Icons.check_circle : Icons.check_circle_outline,
          label: isCompleted ? 'Done' : 'Complete',
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            onCompleted();
          },
        ),
        _ActionChip(
          icon: Icons.map_outlined,
          label: 'Map',
          onTap: onMap,
        ),
        _ActionChip(
          icon: Icons.ios_share,
          label: 'Share',
          onTap: onShare,
        ),
        _ActionChip(
          icon: Icons.shield_outlined,
          label: 'Safety',
          onTap: onSafety,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool ember;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: ember ? TT.emberDim : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: ember ? const Color(0x52FF6A2C) : TT.line2, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ember ? TT.ember : TT.text2),
            const SizedBox(width: 6),
            Text(
              label,
              style: TT.body(
                size: 12,
                w: FontWeight.w700,
                color: ember ? TT.ember : TT.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Elevation card ────────────────────────────────────────────────────────

class _ElevationCard extends StatefulWidget {
  final Trail trail;
  const _ElevationCard({required this.trail});

  @override
  State<_ElevationCard> createState() => _ElevationCardState();
}

class _ElevationCardState extends State<_ElevationCard> {
  StaticDataProvider? _staticData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture the provider while we still have a live context — using
    // context.read in dispose() is unsafe because the element may already
    // be deactivated by the time the dispose runs.
    _staticData = context.read<StaticDataProvider>();
  }

  @override
  void dispose() {
    // Drop the cursor when the card is torn down so a re-open of any other
    // trail doesn't briefly show a stale cursor before the user touches it.
    _staticData?.clearProfileCursor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final trail = widget.trail;
    final coords = trail.coords;
    final hasProfile = trail.profile.isNotEmpty;
    final samples =
        hasProfile ? trail.profile.map((p) => p.elevationM).toList() : null;
    final peakLabel =
        '${units.formatDistance(trail.distanceKm)} · ${units.formatElevation(trail.elevationGainM.toDouble())}';
    final range = (trail.maxEle - trail.minEle).abs().toDouble();

    // Translate a chart sample index back to a TrailCoord. The chart works on
    // the elevation-profile samples but the cursor needs to land on a real
    // coordinate, so we interpolate proportionally into the coord list.
    void onChartCursor(int? idx) {
      final prov = context.read<StaticDataProvider>();
      if (idx == null || coords.isEmpty || samples == null) {
        prov.clearProfileCursor();
        return;
      }
      final t = idx / (samples.length - 1).clamp(1, double.infinity);
      final mapped =
          (t * (coords.length - 1)).round().clamp(0, coords.length - 1);
      prov.setProfileCursor(coords[mapped]);
    }

    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ELEVATION PROFILE',
                  style:
                      TT.label(size: 11, color: TT.ember, letterSpacing: 1.4)),
              Text(
                'RANGE ${units.formatElevation(range).toUpperCase()}',
                style: TT.mono(size: 10, color: TT.text3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Inline mini-map preview. Shows the route silhouette plus a moving
          // cursor as the user drags across the elevation chart below — so the
          // user can see *where on the route* the steep section actually sits.
          if (coords.length >= 2)
            _RouteCursorMiniMap(trail: trail)
          else
            const SizedBox(height: 4),
          if (coords.length >= 2) const SizedBox(height: 8),
          Selector<StaticDataProvider, int?>(
            selector: (_, p) {
              final cursor = p.profileCursor;
              if (cursor == null || samples == null) return null;
              // Reverse-map the cursor coord back to a sample index. The
              // cursor and the chart speak in different lists (coords vs
              // profile samples) but should stay perfectly synced.
              final idx = coords.indexOf(cursor);
              if (idx < 0) return null;
              final t = idx / (coords.length - 1).clamp(1, double.infinity);
              return (t * (samples.length - 1)).round();
            },
            builder: (_, cursorIdx, __) => TTBigElevChart(
              samples: samples,
              peakLabel: peakLabel,
              elevationUnit: units.elevationUnit,
              onCursor: hasProfile ? onChartCursor : null,
              cursorIndex: cursorIdx,
            ),
          ),
          if (hasProfile) ...[
            const SizedBox(height: 6),
            Text(
              'Drag across the chart to see where the route gets tough.',
              style: TT.mono(
                  size: 9.5, color: TT.text3, letterSpacing: 0.06 * 9.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact map preview showing the full trail outline on real satellite
/// tiles, plus a moving pin at the current `StaticDataProvider.profileCursor`.
/// As the user drags across the elevation chart, the pin tracks across the
/// satellite imagery so they can see *what kind of terrain* the steep
/// section actually crosses — not just an abstract polyline.
///
/// User interaction is locked off (no pan/zoom) so the mini-map stays
/// framed on the route while drag gestures pass through to the chart.
class _RouteCursorMiniMap extends StatefulWidget {
  final Trail trail;
  const _RouteCursorMiniMap({required this.trail});

  @override
  State<_RouteCursorMiniMap> createState() => _RouteCursorMiniMapState();
}

class _RouteCursorMiniMapState extends State<_RouteCursorMiniMap> {
  final MapController _mapCtrl = MapController();
  bool _didFit = false;

  void _fitToTrail() {
    final coords = widget.trail.coords;
    if (coords.length < 2 || !mounted) return;
    try {
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(widget.trail.minLat, widget.trail.minLon),
            LatLng(widget.trail.maxLat, widget.trail.maxLon),
          ),
          padding: const EdgeInsets.all(20),
        ),
      );
      _didFit = true;
    } catch (_) {
      // Map not yet laid out — try again on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToTrail();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trail = widget.trail;
    if (trail.coords.length < 2) {
      return const SizedBox(height: 140);
    }

    // Use the Satellite tile style (Esri World Imagery) so the user can see
    // the actual terrain the route crosses. Falls back to the first available
    // style if the satellite entry isn't present in this build.
    final satStyleIdx =
        kMapTileStyles.indexWhere((s) => s.label.toLowerCase().contains('sat'));
    final style = kMapTileStyles[satStyleIdx >= 0 ? satStyleIdx : 0];

    final routePts = trail.coords.map((c) => LatLng(c.lat, c.lon)).toList();
    final startLL = routePts.first;
    final endLL = routePts.last;

    return SizedBox(
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rSm),
        child: Stack(
          children: [
            // Real flutter_map underlay. We listen to onMapReady to do the
            // initial fit because fitCamera before the map has a size will
            // silently no-op.
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: LatLng(
                  (trail.minLat + trail.maxLat) / 2,
                  (trail.minLon + trail.maxLon) / 2,
                ),
                initialZoom: 12,
                minZoom: 4,
                maxZoom: 18,
                backgroundColor: const Color(0xFF06080B),
                // Disable user interaction — pan/zoom would compete with
                // the elevation-chart drag gesture sitting directly below.
                interactionOptions: const InteractionOptions(flags: 0),
                onMapReady: () {
                  if (!_didFit) _fitToTrail();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: style.url,
                  tileProvider: OfflineMapService.tileProvider(),
                  userAgentPackageName: 'com.trailtether.app',
                  maxZoom: style.maxZoom,
                  retinaMode: kHighDensity(context),
                ),
                // Trail polyline — ember glow underneath, sharp ember on top.
                PolylineLayer(polylines: [
                  Polyline(
                    points: routePts,
                    color: const Color(0x66FF6A2C),
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  Polyline(
                    points: routePts,
                    color: TT.ember,
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ]),
                // Start / end dots so the user knows which way the route runs.
                MarkerLayer(
                  rotate: true,
                  markers: [
                    Marker(
                      point: startLL,
                      width: 14,
                      height: 14,
                      child: const _RouteEndDot(color: TT.green),
                    ),
                    Marker(
                      point: endLL,
                      width: 14,
                      height: 14,
                      child: const _RouteEndDot(color: TT.amber),
                    ),
                  ],
                ),
                // Cursor pin — driven by StaticDataProvider.profileCursor so
                // it moves in real time as the user drags the chart.
                Consumer<StaticDataProvider>(
                  builder: (_, prov, __) {
                    final cursor = (prov.selectedTrail?.id == trail.id ||
                            prov.selectedTrail == null)
                        ? prov.profileCursor
                        : null;
                    if (cursor == null) return const SizedBox.shrink();
                    return MarkerLayer(
                      rotate: true,
                      markers: [
                        Marker(
                          point: LatLng(cursor.lat, cursor.lon),
                          width: 28,
                          height: 28,
                          child: const _RouteCursorPin(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            // Subtle inner border so the panel reads as a card rather than a
            // raw map cut-out.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TT.rSm),
                    border: Border.all(color: TT.line, width: 1),
                  ),
                ),
              ),
            ),
            // Attribution stays mandatory for the tile provider.
            Positioned(
              right: 4,
              bottom: 2,
              child: IgnorePointer(
                child: Text(
                  style.attribution,
                  style: TT.mono(size: 7.5, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteEndDot extends StatelessWidget {
  final Color color;
  const _RouteEndDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

class _RouteCursorPin extends StatelessWidget {
  const _RouteCursorPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TT.ember,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0xCCFF6A2C), blurRadius: 16, spreadRadius: 2),
          BoxShadow(
              color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

// ── Planning notes ────────────────────────────────────────────────────────

class _PlanningNotes extends StatelessWidget {
  final Trail trail;
  const _PlanningNotes({required this.trail});

  @override
  Widget build(BuildContext context) {
    final note = switch (trail.distanceKm) {
      < 5 => 'Short outing. Good for low-commitment mornings and skill drills.',
      < 12 => 'Solid day hike. Start early and carry full weather layers.',
      _ =>
        'Long day or overnight effort. Plan nutrition, water, and exit time carefully.',
    };
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLANNING NOTES',
              style: TT.label(size: 11, color: TT.ember, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Text(
            note,
            style: TT
                .body(size: 12.5, color: TT.text2, w: FontWeight.w600)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Description card ──────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final String text;
  const _DescriptionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT',
              style: TT.label(size: 11, color: TT.ember, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TT
                .body(size: 13, color: TT.text2, w: FontWeight.w600)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Caves on route ────────────────────────────────────────────────────────

class _CavesCard extends StatelessWidget {
  final List<CaveWaypoint> caves;
  const _CavesCard({required this.caves});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dark_mode_outlined, size: 13, color: TT.ember),
              const SizedBox(width: 6),
              Text('CAVES & SHELTERS ON ROUTE',
                  style:
                      TT.label(size: 11, color: TT.ember, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
          ...caves.take(5).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(TT.rSm),
                  onTap: () => CaveDetailSheet.show(context, c),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TT.emberSoft,
                            borderRadius: BorderRadius.circular(TT.rSm),
                          ),
                          child: Icon(
                            c.isShelter ? Icons.cabin : Icons.terrain,
                            size: 14,
                            color: TT.ember,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TT.body(
                                    size: 13,
                                    w: FontWeight.w700,
                                    color: TT.text),
                              ),
                              Builder(builder: (ctx) {
                                final units = ctx.watch<UnitsProvider>();
                                return Text(
                                  '${units.formatElevation(c.elevationM)} · ${c.isShelter ? 'shelter' : 'cave'}',
                                  style: TT.mono(size: 10.5, color: TT.text3),
                                );
                              }),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: TT.text3),
                      ],
                    ),
                  ),
                ),
              )),
          if (caves.length > 5)
            Text('+${caves.length - 5} more',
                style: TT.mono(size: 10.5, color: TT.text3)),
        ],
      ),
    );
  }
}

// ── Reviews ───────────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  final Trail trail;
  const _ReviewsSection({required this.trail});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Consumer<ReviewProvider>(
        builder: (_, prov, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('COMMUNITY REVIEWS',
                      style: TT.label(
                          size: 11, color: TT.ember, letterSpacing: 1.4)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewsScreen(trail: trail),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all',
                          style: TT.body(
                              size: 12, w: FontWeight.w700, color: TT.ember)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 16, color: TT.ember),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ReviewSummaryBar(summary: prov.summary),
            const SizedBox(height: 10),
            ...prov.reviews.take(3).map(
                  (review) => ReviewCard(review: review),
                ),
          ],
        ),
      ),
    );
  }
}

// ── Peak check-in ─────────────────────────────────────────────────────────

class _PeakCheckInCard extends StatefulWidget {
  final Trail trail;
  const _PeakCheckInCard({required this.trail});

  @override
  State<_PeakCheckInCard> createState() => _PeakCheckInCardState();
}

class _PeakCheckInCardState extends State<_PeakCheckInCard> {
  bool _verifying = false;
  String? _status;

  Future<void> _checkIn() async {
    setState(() {
      _verifying = true;
      _status = 'Verifying…';
    });

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final lastCoord = widget.trail.coords.last;
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, lastCoord.lat, lastCoord.lon);

      if (dist < 250) {
        setState(() => _status = 'Verified');
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        final userEmail =
            Supabase.instance.client.auth.currentUser?.email ?? 'A hiker';

        await Supabase.instance.client.from('community_activities').insert({
          'user_id': uid,
          'user_name': userEmail.split('@')[0],
          'type': 'check_in',
          'title': 'Summited Peak',
          'subtitle': 'Verified at ${widget.trail.name}',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        unawaited(context.read<CommunityProvider>().refresh());
        setState(() => _status = 'Done');
        unawaited(HapticFeedback.heavyImpact());
      } else {
        setState(() => _status = 'Too far');
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e, stack) {
      LoggerService.error('PEAK_CHECKIN', 'verify/check-in failed: $e', stack);
      if (!mounted) return;
      setState(() => _status = 'Error');
    } finally {
      if (mounted) {
        unawaited(Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _verifying = false;
              _status = null;
            });
          }
        }));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _status == 'Done';
    final label = _status ?? 'Check-in at peak';
    return GestureDetector(
      onTap: _verifying ? null : _checkIn,
      behavior: HitTestBehavior.opaque,
      child: TTCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? const Color(0x1A4CC38A) : TT.emberDim,
                borderRadius: BorderRadius.circular(TT.rSm),
                border: Border.all(
                  color:
                      done ? const Color(0x594CC38A) : const Color(0x52FF6A2C),
                ),
              ),
              child: Icon(
                done ? Icons.check : Icons.flag_outlined,
                size: 16,
                color: done ? TT.green : TT.ember,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PEAK CHECK-IN',
                      style: TT.label(
                          size: 10, color: TT.ember, letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TT.body(
                          size: 13, w: FontWeight.w700, color: TT.text)),
                ],
              ),
            ),
            if (_verifying)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TT.ember,
                ),
              )
            else
              const Icon(Icons.chevron_right, size: 18, color: TT.text2),
          ],
        ),
      ),
    );
  }
}

// ── Sticky START HIKE button ──────────────────────────────────────────────

class _StickyStartButton extends StatefulWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _StickyStartButton({
    required this.isFollowing,
    required this.onTap,
  });

  @override
  State<_StickyStartButton> createState() => _StickyStartButtonState();
}

class _StickyStartButtonState extends State<_StickyStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: TT.ember,
            borderRadius: BorderRadius.circular(TT.rLg),
            boxShadow: TT.shadowEmber,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TT.rLg),
            child: Stack(
              children: [
                // Shimmer band
                AnimatedBuilder(
                  animation: _ctl,
                  builder: (_, __) {
                    final dx = -1.2 + _ctl.value * 2.4;
                    return FractionalTranslation(
                      translation: Offset(dx, 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-0.5, -0.2),
                            end: Alignment(0.5, 0.2),
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0x4DFFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: [0.3, 0.5, 0.7],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isFollowing
                            ? Icons.gps_fixed
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: TT.emberInk,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.isFollowing
                            ? 'TRACKING THIS TRAIL'
                            : 'START HIKE',
                        style: TT
                            .body(
                              size: 13,
                              w: FontWeight.w900,
                              color: TT.emberInk,
                            )
                            .copyWith(letterSpacing: 0.16 * 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
