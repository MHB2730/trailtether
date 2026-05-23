// Trailtether 2.0 — Map / Peak Tracker screen.
//
// Real flutter_map backed implementation that keeps the v3.0 visual treatment
// (floating glass stat cards, ember route polyline, bottom RecordingPanel)
// but drives all data through the live providers: RecordingProvider (active
// trail / stats / points), StaticDataProvider (route overlays), and the
// OfflineMapService tile provider for cached tiles.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../providers/recording_provider.dart';
import '../providers/static_data_provider.dart';
import '../services/location_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';

class TTMapScreen extends StatefulWidget {
  final bool embedded;
  const TTMapScreen({super.key, this.embedded = false});

  @override
  State<TTMapScreen> createState() => _TTMapScreenState();
}

class _TTMapScreenState extends State<TTMapScreen>
    with TickerProviderStateMixin {
  // Live flutter_map controller.
  final MapController _mapCtrl = MapController();

  // Tile style index into kMapTileStyles.
  int _tileStyleIndex = 0; // 0 = Outdoor / OpenTopoMap

  // Live GPS position (drives the user marker + recenter).
  LatLng? _currentLatLng;
  double? _currentHeading;
  StreamSubscription<Position>? _positionSub;

  // Drives the route draw + panel entry anim.
  late final AnimationController _entryCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _entryCtl.forward();
    });
    _startLocationStream();
  }

  Future<void> _startLocationStream() async {
    final ok = await LocationService.requestPermission();
    if (!ok) return;
    _positionSub = LocationService.smoothedPositionStream.listen(
      (pos) {
        if (!mounted) return;
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
          _currentHeading = pos.heading;
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _entryCtl.dispose();
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Map control handlers ───────────────────────────────────────────────────
  void _zoomIn() {
    final z = _mapCtrl.camera.zoom;
    _mapCtrl.move(_mapCtrl.camera.center, (z + 1).clamp(2.0, 20.0));
  }

  void _zoomOut() {
    final z = _mapCtrl.camera.zoom;
    _mapCtrl.move(_mapCtrl.camera.center, (z - 1).clamp(2.0, 20.0));
  }

  void _recenter() {
    final p = _currentLatLng;
    if (p != null) {
      _mapCtrl.move(p, math.max(_mapCtrl.camera.zoom, 14.0));
    } else {
      _mapCtrl.move(LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
          kWorldMapZoomInit);
    }
  }

  void _openLayerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: TT.line3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('MAP STYLE',
                  style: TT.label(size: 11, color: TT.text2, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              for (var i = 0; i < kMapTileStyles.length; i++)
                _LayerOption(
                  label: kMapTileStyles[i].label,
                  iconLabel: kMapTileStyles[i].iconLabel,
                  selected: i == _tileStyleIndex,
                  onTap: () {
                    setState(() => _tileStyleIndex = i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recording actions ──────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final rec = context.read<RecordingProvider>();
    final ok = await rec.start();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permission required to start recording.')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      top: !widget.embedded,
      bottom: false,
      child: Column(
        children: [
          TTPageAppBar(
            title: 'Peak Tracker',
            trailing: [
              TTIconBtn(icon: Icons.search, onTap: () {}),
              TTIconBtn(icon: Icons.menu, onTap: () {}),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MapView(
                    mapCtrl: _mapCtrl,
                    tileStyleIndex: _tileStyleIndex,
                    currentLatLng: _currentLatLng,
                    currentHeading: _currentHeading,
                    entryCtl: _entryCtl,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onRecenter: _recenter,
                    onOpenLayers: _openLayerSheet,
                  ),
                ),
                _RecordingPanel(
                  entryCtl: _entryCtl,
                  onStart: _startRecording,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ───────────────────────────── MAP VIEW ──────────────────────────────────────

class _MapView extends StatelessWidget {
  final MapController mapCtrl;
  final int tileStyleIndex;
  final LatLng? currentLatLng;
  final double? currentHeading;
  final AnimationController entryCtl;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback onOpenLayers;

  const _MapView({
    required this.mapCtrl,
    required this.tileStyleIndex,
    required this.currentLatLng,
    required this.currentHeading,
    required this.entryCtl,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onOpenLayers,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final recording = context.watch<RecordingProvider>();

    final style = kMapTileStyles[tileStyleIndex.clamp(0, kMapTileStyles.length - 1)];

    // ── Polylines ──
    final polylines = <Polyline>[];

    // All known trails as faint background routes (so the map isn't empty).
    for (final t in data.allTrails) {
      if (t.coords.isEmpty) continue;
      final pts = t.coords.map((c) => LatLng(c.lat, c.lon)).toList();
      polylines.add(Polyline(
        points: pts,
        color: const Color(0x4DFF6A2C),
        strokeWidth: 1.6,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    // Active recording route — ember glow + sharp stroke.
    if (recording.points.length >= 2) {
      final recPts = recording.points.map((p) => p.toLatLng).toList();
      polylines.add(Polyline(
        points: recPts,
        color: const Color(0x66FF6A2C),
        strokeWidth: 8.0,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
      polylines.add(Polyline(
        points: recPts,
        color: TT.ember,
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    // ── Markers ──
    final markers = <Marker>[];

    // Recording start dot.
    if (recording.points.isNotEmpty) {
      final start = recording.points.first.toLatLng;
      markers.add(Marker(
        point: start,
        width: 18,
        height: 18,
        child: const _StartDot(),
      ));
    }

    // User position pulse.
    if (currentLatLng != null) {
      markers.add(Marker(
        point: currentLatLng!,
        width: 56,
        height: 56,
        child: const _YouMarker(),
      ));
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Real map underlay.
          AnimatedBuilder(
            animation: entryCtl,
            builder: (_, child) {
              final t = TT.easeOut.transform(entryCtl.value);
              return Opacity(opacity: 0.4 + 0.6 * t, child: child);
            },
            child: FlutterMap(
              mapController: mapCtrl,
              options: MapOptions(
                initialCenter: currentLatLng ??
                    LatLng(kWorldMapCenter.lat, kWorldMapCenter.lon),
                initialZoom: kWorldMapZoomInit,
                minZoom: 2,
                maxZoom: 20,
                backgroundColor: const Color(0xFF06080B),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  enableMultiFingerGestureRace: true,
                ),
              ),
              children: [
                TileLayer(
                  key: ValueKey('tile_$tileStyleIndex'),
                  urlTemplate: style.url,
                  tileProvider: OfflineMapService.tileProvider(),
                  userAgentPackageName: 'com.trailtether.app',
                  maxZoom: style.maxZoom,
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Floating top stat cards.
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: _AnimUp(
                    delay: const Duration(milliseconds: 120),
                    child: _FloatingStat(
                      icon: Icons.navigation,
                      label: 'Distance',
                      value: _formatMiles(recording.distanceKm),
                      unit: 'mi',
                      sublabel: recording.isRecording
                          ? 'Recording'
                          : (recording.points.isEmpty ? 'No data' : 'Last hike'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnimUp(
                    delay: const Duration(milliseconds: 220),
                    child: _FloatingStat(
                      icon: Icons.schedule,
                      label: 'Time',
                      value: _formatDurationShort(recording.duration),
                      sublabel: 'Duration',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right-side controls.
          Positioned(
            top: 152,
            right: 14,
            child: _MapControls(
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onRecenter: onRecenter,
              onOpenLayers: onOpenLayers,
            ),
          ),

          // Tile attribution / style label.
          Positioned(
            bottom: 14,
            left: 14,
            child: _AnimUp(
              delay: const Duration(milliseconds: 900),
              child: _ScaleBar(label: style.iconLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── MARKERS ──────────────────────────────────────

class _YouMarker extends StatefulWidget {
  const _YouMarker();
  @override
  State<_YouMarker> createState() => _YouMarkerState();
}

class _YouMarkerState extends State<_YouMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse.
            Opacity(
              opacity: (1 - t).clamp(0.0, 0.6),
              child: Transform.scale(
                scale: 0.7 + t * 1.4,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33FF6A2C),
                  ),
                ),
              ),
            ),
            // Inner halo.
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x52FF6A2C),
              ),
            ),
            // Core dot.
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: TT.ember, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StartDot extends StatelessWidget {
  const _StartDot();
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        decoration: BoxDecoration(
          color: TT.ember,
          border: Border.all(color: const Color(0xFF1A0D04), width: 2),
        ),
      ),
    );
  }
}

// ───────────────────────── FLOATING STAT CARDS ───────────────────────────────

class _FloatingStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sublabel;

  const _FloatingStat({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1AFF6A2C),
              border: Border.all(color: const Color(0x40FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(TT.rSm),
            ),
            child: Icon(icon, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TT.body(size: 10, w: FontWeight.w600, color: TT.text3)
                      .copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TT.numStyle(size: 17, letterSpacing: -0.02 * 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 3),
                      Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
                    ],
                  ],
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sublabel!,
                    style: TT.mono(size: 9.5, color: TT.text3, w: FontWeight.w500)
                        .copyWith(letterSpacing: 0.2),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── MAP CONTROLS ───────────────────────────────────

class _MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;
  final VoidCallback onOpenLayers;
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onOpenLayers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnimPop(
          delay: const Duration(milliseconds: 420),
          child: _ZoomGroup(onZoomIn: onZoomIn, onZoomOut: onZoomOut),
        ),
        const SizedBox(height: 8),
        _AnimPop(
          delay: const Duration(milliseconds: 520),
          child: _CircleBtn(
            icon: Icons.gps_fixed,
            ember: true,
            onTap: onRecenter,
          ),
        ),
        const SizedBox(height: 8),
        _AnimPop(
          delay: const Duration(milliseconds: 580),
          child: _CircleBtn(
            icon: Icons.layers_outlined,
            onTap: onOpenLayers,
          ),
        ),
      ],
    );
  }
}

class _ZoomGroup extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _ZoomGroup({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, onTap: onZoomIn),
          Container(width: 38, height: 1, color: TT.line2),
          _ZoomBtn(icon: Icons.remove, onTap: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: TT.text),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final bool ember;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return TTGlass(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 16, color: ember ? TT.ember : TT.text2),
      ),
    );
  }
}

// ─────────────────────────────── SCALE BAR ──────────────────────────────────

class _ScaleBar extends StatelessWidget {
  final String label;
  const _ScaleBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xC70A0C0F),
        border: Border.all(color: TT.line2, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 22, height: 4, color: TT.text),
          Container(
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C0F),
              border: Border.all(color: TT.text, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TT.mono(size: 9.5, color: TT.text, w: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── LAYER SHEET ROW ───────────────────────────────────

class _LayerOption extends StatelessWidget {
  final String label;
  final String iconLabel;
  final bool selected;
  final VoidCallback onTap;
  const _LayerOption({
    required this.label,
    required this.iconLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x14FF6A2C) : TT.surf,
          border: Border.all(
            color: selected ? const Color(0x66FF6A2C) : TT.line,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TT.bg2,
                borderRadius: BorderRadius.circular(TT.rSm),
                border: Border.all(color: TT.line2),
              ),
              child: Text(
                iconLabel,
                style: TT.mono(size: 10, color: TT.ember, w: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TT.body(size: 14, w: FontWeight.w700)),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: TT.ember),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── RECORDING PANEL ───────────────────────────────────

class _RecordingPanel extends StatelessWidget {
  final AnimationController entryCtl;
  final Future<void> Function() onStart;
  const _RecordingPanel({required this.entryCtl, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (_, recording, __) => _AnimUp(
        delay: const Duration(milliseconds: 700),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x000F1318), Color(0xF20B0E12), TT.bg2],
              stops: [0.0, 0.3, 1.0],
            ),
            border: Border(top: BorderSide(color: TT.line, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle.
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: TT.line3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleFor(recording),
                          style: TT.title(16, letterSpacing: -0.01 * 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (recording.isRecording ||
                            recording.isPaused) ...[
                          const SizedBox(height: 6),
                          TTPill(
                            label: recording.isPaused
                                ? 'PAUSED'
                                : 'IN PROGRESS',
                            variant: recording.isPaused
                                ? TTPillVariant.neutral
                                : TTPillVariant.live,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (recording.isRecording)
                    _PauseButton(onTap: recording.pause)
                  else if (recording.isPaused)
                    _ResumeButton(onTap: () => recording.start())
                  else
                    _StartButton(onTap: onStart),
                  if (recording.isRecording || recording.isPaused) ...[
                    const SizedBox(width: 8),
                    _StopButton(onTap: recording.stop),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              // 3-stat row.
              _StatRow(recording: recording),
              const SizedBox(height: 12),
              // Mini elevation chart card (only when we have data).
              if (recording.points.length >= 2)
                _MiniElevCard(points: recording.points)
              else
                _EmptyChartCard(isRecording: recording.isRecording),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(RecordingProvider rec) {
    if (rec.isRecording || rec.isPaused) {
      return rec.targetTrail?.name ??
          rec.customName ??
          'Free-form recording';
    }
    return 'Tap PLAY to start recording';
  }
}

class _PauseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PauseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause, size: 12, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'PAUSE',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResumeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, size: 14, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'RESUME',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final Future<void> Function() onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(11),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, size: 14, color: TT.emberInk),
            const SizedBox(width: 6),
            Text(
              'START RECORDING',
              style: TT.body(size: 12, w: FontWeight.w800, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.12 * 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: TT.line3, width: 1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          'STOP',
          style: TT.body(size: 12, w: FontWeight.w800, color: TT.text2)
              .copyWith(letterSpacing: 0.12 * 12),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final RecordingProvider recording;
  const _StatRow({required this.recording});

  @override
  Widget build(BuildContext context) {
    // Pace in km/h — derived from RecordingProvider.averageSpeedKmh.
    final pace = recording.averageSpeedKmh;
    final elev = recording.totalGainM;
    final time = recording.duration;

    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rMd),
        child: Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Elev',
                value: elev.toString(),
                unit: 'm',
                ember: true,
              ),
            ),
            _StatDivider(),
            Expanded(
              child: _MiniStat(
                label: 'Pace',
                value: pace.toStringAsFixed(1),
                unit: 'km/h',
              ),
            ),
            _StatDivider(),
            Expanded(
              child: _MiniStat(
                label: 'Time',
                value: _formatDurationLong(time),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: TT.line);
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _MiniStat({
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TT.surf,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.14 * 9.5),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TT.numStyle(
                    size: 19,
                    color: ember ? TT.ember : TT.text,
                    letterSpacing: -0.02 * 19,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: TT.mono(size: 10, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniElevCard extends StatelessWidget {
  final List<dynamic> points;
  const _MiniElevCard({required this.points});

  @override
  Widget build(BuildContext context) {
    // Sample the elevations from the recording points. Cap the number of
    // samples used for the chart so dense recordings don't bog down paint.
    const maxSamples = 96;
    final n = points.length;
    final stride = math.max(1, (n / maxSamples).ceil());
    final samples = <double>[];
    var totalDistKm = 0.0;
    final distSamples = <double>[]; // cumulative km
    for (var i = 0; i < n; i += stride) {
      final p = points[i];
      samples.add((p.altitude as double));
      if (i > 0) {
        final prev = points[i - stride < 0 ? 0 : i - stride];
        totalDistKm += Geolocator.distanceBetween(
              prev.latitude as double,
              prev.longitude as double,
              p.latitude as double,
              p.longitude as double,
            ) /
            1000.0;
      }
      distSamples.add(totalDistKm);
    }
    final lastKm = distSamples.isEmpty ? 0.0 : distSamples.last;

    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ELEVATION PROFILE',
                style: TT.label(size: 10.5, color: TT.text2, letterSpacing: 0.14 * 10.5),
              ),
              Text(
                '0 → ${lastKm.toStringAsFixed(1)} km',
                style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: CustomPaint(
              painter: _MiniElevPainter(samples: samples),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartCard extends StatelessWidget {
  final bool isRecording;
  const _EmptyChartCard({required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.timeline : Icons.show_chart,
            size: 18,
            color: TT.text3,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRecording
                  ? 'Waiting for GPS fixes — elevation profile will appear shortly.'
                  : 'Start a recording to see live elevation and pace.',
              style: TT.body(size: 12, w: FontWeight.w500, color: TT.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniElevPainter extends CustomPainter {
  final List<double> samples;
  _MiniElevPainter({required this.samples});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    const pad = 4.0;
    final n = samples.length;
    final stepX = (size.width - pad * 2) / (n - 1);

    var minV = samples.first;
    var maxV = samples.first;
    for (final v in samples) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV - minV < 1) maxV = minV + 1;

    Offset xy(double v, int i) {
      final x = pad + i * stepX;
      final y = size.height -
          pad -
          ((v - minV) / (maxV - minV)) * (size.height - pad * 2);
      return Offset(x, y);
    }

    final stroke = Path();
    for (var i = 0; i < n; i++) {
      final p = xy(samples[i], i);
      if (i == 0) {
        stroke.moveTo(p.dx, p.dy);
      } else {
        stroke.lineTo(p.dx, p.dy);
      }
    }

    // Fill under the curve.
    final fillPath = Path.from(stroke)
      ..lineTo(size.width - pad, size.height - pad)
      ..lineTo(pad, size.height - pad)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8CFF6A2C), Color(0x00FF6A2C)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      stroke,
      Paint()
        ..color = TT.ember
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Peak marker.
    var peakIdx = 0;
    for (var i = 1; i < n; i++) {
      if (samples[i] > samples[peakIdx]) peakIdx = i;
    }
    final peak = xy(samples[peakIdx], peakIdx);
    canvas.drawLine(
      peak,
      Offset(peak.dx, size.height - pad),
      Paint()
        ..color = const Color(0x4DFFFFFF)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(peak, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      peak,
      3.5,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MiniElevPainter old) => old.samples != samples;
}

// ──────────────────────── FORMATTING HELPERS ─────────────────────────────────

String _formatMiles(double km) {
  final mi = km * 0.621371;
  if (mi < 10) return mi.toStringAsFixed(2);
  return mi.toStringAsFixed(1);
}

String _formatDurationShort(Duration d) {
  if (d == Duration.zero) return '0m';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

String _formatDurationLong(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ──────────────────────── ANIMATION PRIMITIVES ───────────────────────────────

/// `anim-up` — fade + rise from 14px.
class _AnimUp extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimUp({required this.delay, required this.child});
  @override
  State<_AnimUp> createState() => _AnimUpState();
}

class _AnimUpState extends State<_AnimUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, (1 - t) * 14), child: widget.child),
        );
      },
    );
  }
}

/// `anim-pop` — fade + scale from 0.7.
class _AnimPop extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _AnimPop({required this.delay, required this.child});
  @override
  State<_AnimPop> createState() => _AnimPopState();
}

class _AnimPopState extends State<_AnimPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: widget.child),
        );
      },
    );
  }
}
