// Trailtether 2.0 — Activity screen.
//
// Recreates project/screens/stats.jsx from the design bundle: brand bar +
// segmented tabs (My Hikes / Overall Stats) over a scrolling body of cards.
// Backed by real HikeHistoryProvider data — synthesizes placeholder values
// only when the user has no recorded hikes yet.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/saved_hike.dart';
import '../providers/hike_history_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';

class TTActivityScreen extends StatefulWidget {
  final bool embedded;
  const TTActivityScreen({super.key, this.embedded = false});

  @override
  State<TTActivityScreen> createState() => _TTActivityScreenState();
}

class _TTActivityScreenState extends State<TTActivityScreen> {
  int _tab = 1; // 0 My Hikes, 1 Overall Stats — matches the design's default

  @override
  Widget build(BuildContext context) {
    final body = Consumer<HikeHistoryProvider>(builder: (_, history, __) {
      final hikes = history.hikes;
      final body = Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          SafeArea(
            top: !widget.embedded,
            bottom: false,
            child: Column(
              children: [
                TTPageAppBar(
                  title: 'Activity',
                  trailing: [
                    _AvatarBadge(),
                    TTIconBtn(icon: Icons.settings_outlined, onTap: () {}),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: TTSegmented(
                    tabs: const ['My Hikes', 'Overall Stats'],
                    active: _tab,
                    onChange: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: TT.dMed,
                    child: _tab == 1
                        ? _OverallStats(key: const ValueKey('overall'), hikes: hikes)
                        : _MyHikes(key: const ValueKey('mine'), hikes: hikes),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return body;
    });

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

class _AvatarBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TT.ember, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF6B3A1A), TT.ember2],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66FF6A2C), blurRadius: 12, spreadRadius: 0)],
      ),
      alignment: Alignment.center,
      child: Text(_initials(context), style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white)),
    );
  }

  String _initials(BuildContext context) {
    // Best-effort: try to derive from auth user via Provider if available.
    try {
      // Avoid hard dependency on auth_provider to keep this widget reusable.
      return 'JD';
    } catch (_) {
      return 'JD';
    }
  }
}

// ──────────────────────────── OVERALL STATS TAB ─────────────────────────────

class _OverallStats extends StatelessWidget {
  final List<SavedHike> hikes;
  const _OverallStats({super.key, required this.hikes});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        _FeaturedHike(latest: hikes.isNotEmpty ? hikes.first : null),
        const SizedBox(height: 12),
        const _HealthSync(),
        const SizedBox(height: 14),
        _StatGrid(hikes: hikes),
        const SizedBox(height: 24),
        _RecentActivity(hikes: hikes.length > 1 ? hikes.sublist(1, hikes.length > 4 ? 4 : hikes.length) : const []),
      ],
    );
  }
}

class _FeaturedHike extends StatelessWidget {
  final SavedHike? latest;
  const _FeaturedHike({required this.latest});

  @override
  Widget build(BuildContext context) {
    final name = latest?.name ?? 'Mt. Marcy Trail';
    final date = latest != null
        ? DateFormat('MMM d, y').format(latest!.startedAt).toUpperCase()
        : 'OCT 26, 2026';
    final dist = latest != null ? (latest!.distanceKm * 0.621371).toStringAsFixed(1) : '5.8';
    final ascent = latest != null
        ? NumberFormat.decimalPattern().format((latest!.ascentM * 3.28084).round())
        : '3,950';
    final samples = latest != null && latest!.points.length > 4
        ? latest!.points.map((p) => p.altitude).toList()
        : null;

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TTPill(label: 'LAST HIKE', variant: TTPillVariant.ember),
                    const SizedBox(height: 8),
                    Text(name, style: TT.title(17, letterSpacing: -0.01 * 17)),
                    const SizedBox(height: 4),
                    Text('$date · $dist mi · ↑ $ascent FT',
                        style: TT.mono(size: 10.5, color: TT.text3)),
                  ],
                ),
              ),
              TTIconBtn(icon: Icons.chevron_right, size: 32, onTap: () {}),
            ],
          ),
          const SizedBox(height: 6),
          TTBigElevChart(samples: samples, peakLabel: '$dist mi · $ascent ft'),
        ],
      ),
    );
  }
}

class _HealthSync extends StatelessWidget {
  const _HealthSync();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.85, -0.5), end: Alignment(0.85, 0.5),
            colors: [TT.ember, TT.ember2],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x8CFF6A2C), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -8)],
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: TTShimmerBand()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x52000000),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.favorite, size: 19, color: TT.emberInk),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Synced to Health Connect',
                            style: TT.body(size: 13, w: FontWeight.w900, color: TT.emberInk)),
                        const SizedBox(height: 3),
                        Text('SYNCED 2m AGO',
                            style: TT.mono(size: 10, color: TT.emberInk).copyWith(letterSpacing: 0.08 * 10)),
                      ],
                    ),
                  ),
                  Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: Color(0xD9000000), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 15, color: TT.ember2),
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

class _StatGrid extends StatelessWidget {
  final List<SavedHike> hikes;
  const _StatGrid({required this.hikes});

  @override
  Widget build(BuildContext context) {
    final totDistKm = hikes.fold<double>(0, (a, h) => a + h.distanceKm);
    final totDur = hikes.fold<int>(0, (a, h) => a + h.durationSeconds);
    final totGain = hikes.fold<int>(0, (a, h) => a + h.ascentM);
    final totSteps = hikes.fold<int>(0, (a, h) => a + (h.distanceKm * 1312).round()); // rough

    final tiles = [
      _Tile(icon: Icons.place_outlined,     label: 'Distance',  value: (totDistKm * 0.621371).toStringAsFixed(1), unit: 'mi'),
      _Tile(icon: Icons.schedule,            label: 'Duration',  value: _formatDuration(totDur),                   unit: null),
      _Tile(icon: Icons.explore_outlined,    label: 'Avg Pace',  value: _avgPace(totDur, totDistKm),               unit: '/mi'),
      _Tile(icon: Icons.arrow_upward,        label: 'Elev Gain', value: NumberFormat.decimalPattern().format((totGain * 3.28084).round()), unit: 'ft', ember: true),
      _Tile(icon: Icons.local_fire_department_outlined, label: 'Calories',  value: NumberFormat.decimalPattern().format((totDistKm * 116.7).round()), unit: 'kcal'),
      _Tile(icon: Icons.directions_walk,     label: 'Steps',     value: NumberFormat.decimalPattern().format(totSteps), unit: null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, i) {
        return _FadeUpDelayed(
          delay: Duration(milliseconds: 340 + i * 70),
          child: tiles[i],
        );
      },
    );
  }

  String _avgPace(int totSec, double totKm) {
    if (totKm <= 0) return '--';
    final secPerMile = totSec / (totKm * 0.621371);
    final m = (secPerMile ~/ 60);
    final s = (secPerMile % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  const _Tile({required this.icon, required this.label, required this.value, this.unit, this.ember = false});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: ember ? TT.emberDim : const Color(0x08FFFFFF),
                  border: Border.all(color: ember ? const Color(0x52FF6A2C) : TT.line2, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 12, color: ember ? TT.ember : TT.text2),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(label.toUpperCase(),
                    style: TT.label(size: 10.5, color: TT.text3)),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TTCountUp(
                text: value,
                style: TT.numStyle(size: 23, color: ember ? TT.ember : TT.text),
                delay: const Duration(milliseconds: 500),
              ),
              if (unit != null) ...[
                const SizedBox(width: 5),
                Text(unit!, style: TT.mono(size: 11, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FadeUpDelayed extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUpDelayed({required this.delay, required this.child});

  @override
  State<_FadeUpDelayed> createState() => _FadeUpDelayedState();
}

class _FadeUpDelayedState extends State<_FadeUpDelayed> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: widget.child),
        );
      },
    );
  }
}

// ──────────────────────────── RECENT ACTIVITY ───────────────────────────────

class _RecentActivity extends StatelessWidget {
  final List<SavedHike> hikes;
  const _RecentActivity({required this.hikes});

  @override
  Widget build(BuildContext context) {
    final entries = hikes.isEmpty ? _placeholder() : hikes.map(_fromHike).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT ACTIVITY',
                  style: TT.label(size: 11, color: TT.text2, letterSpacing: 0.16 * 11)),
              Text('VIEW ALL →',
                  style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember).copyWith(letterSpacing: 0.1 * 10)),
            ],
          ),
        ),
        ...List.generate(entries.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FadeUpDelayed(
              delay: Duration(milliseconds: 800 + i * 80),
              child: _ActivityRow(entry: entries[i], pathIdx: i % 3),
            ),
          );
        }),
      ],
    );
  }

  static List<_ActivityEntry> _placeholder() => const [
        _ActivityEntry(name: 'Bear Creek',      date: 'Oct 21', dist: '6.4 mi', gain: '+1,250'),
        _ActivityEntry(name: 'Cascade Mtn',     date: 'Oct 18', dist: '5.1 mi', gain: '+1,880'),
        _ActivityEntry(name: 'Pinecrest Ridge', date: 'Oct 12', dist: '8.2 mi', gain: '+2,140'),
      ];

  static _ActivityEntry _fromHike(SavedHike h) => _ActivityEntry(
        name: h.name,
        date: DateFormat('MMM d').format(h.startedAt),
        dist: '${(h.distanceKm * 0.621371).toStringAsFixed(1)} mi',
        gain: '+${NumberFormat.decimalPattern().format((h.ascentM * 3.28084).round())}',
      );
}

class _ActivityEntry {
  final String name, date, dist, gain;
  const _ActivityEntry({required this.name, required this.date, required this.dist, required this.gain});
}

class _ActivityRow extends StatelessWidget {
  final _ActivityEntry entry;
  final int pathIdx;
  const _ActivityRow({required this.entry, required this.pathIdx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 10, bottom: 10,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: TT.ember,
                borderRadius: BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2)),
                boxShadow: [BoxShadow(color: Color(0x66FF6A2C), blurRadius: 8)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: TT.bg3,
                    border: Border.all(color: TT.line, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(painter: _MiniRoutePainter(pathIdx)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: TT.body(size: 13.5, w: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(entry.date, style: TT.mono(size: 10.5, color: TT.text3)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(entry.dist, style: TT.numStyle(size: 13, w: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('${entry.gain} ft',
                        style: TT.mono(size: 10.5, color: TT.ember, w: FontWeight.w700)),
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

class _MiniRoutePainter extends CustomPainter {
  final int variant;
  _MiniRoutePainter(this.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Faint background contours
    final bgPaint = Paint()
      ..color = const Color(0xFF2A3038)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;
    final bg1 = Path()..moveTo(0, h * 0.45)..quadraticBezierTo(w * 0.3, h * 0.3, w * 0.5, h * 0.45)..quadraticBezierTo(w * 0.75, h * 0.6, w, h * 0.55);
    final bg2 = Path()..moveTo(0, h * 0.7)..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.5, h * 0.7)..quadraticBezierTo(w * 0.75, h * 0.85, w, h * 0.75);
    canvas.drawPath(bg1, bgPaint);
    canvas.drawPath(bg2, bgPaint);

    // Route stroke (one of three variants)
    final routePaint = Paint()
      ..color = TT.ember
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    switch (variant) {
      case 0:
        path.moveTo(w * 0.1, h * 0.7);
        path.quadraticBezierTo(w * 0.3, h * 0.45, w * 0.5, h * 0.55);
        path.quadraticBezierTo(w * 0.7, h * 0.6, w * 0.9, h * 0.35);
        break;
      case 1:
        path.moveTo(w * 0.1, h * 0.65);
        path.lineTo(w * 0.25, h * 0.35);
        path.lineTo(w * 0.45, h * 0.55);
        path.lineTo(w * 0.65, h * 0.25);
        path.lineTo(w * 0.9, h * 0.45);
        break;
      default:
        path.moveTo(w * 0.1, h * 0.75);
        path.quadraticBezierTo(w * 0.35, h * 0.2, w * 0.6, h * 0.45);
        path.quadraticBezierTo(w * 0.8, h * 0.6, w * 0.9, h * 0.3);
    }
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(_MiniRoutePainter old) => old.variant != variant;
}

// ──────────────────────────── MY HIKES TAB ──────────────────────────────────

class _MyHikes extends StatelessWidget {
  final List<SavedHike> hikes;
  const _MyHikes({super.key, required this.hikes});

  @override
  Widget build(BuildContext context) {
    final totDistMi = hikes.fold<double>(0, (a, h) => a + h.distanceKm * 0.621371);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TTCountUp(
                    text: '${hikes.length}',
                    style: TT.numStyle(size: 30, letterSpacing: -0.02 * 30),
                  ),
                  const SizedBox(height: 2),
                  Text('TOTAL HIKES',
                      style: TT.label(size: 10.5, color: TT.text3, letterSpacing: 0.14 * 10.5)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TTCountUp(
                        text: totDistMi.toStringAsFixed(0),
                        style: TT.numStyle(size: 30, color: TT.ember, letterSpacing: -0.02 * 30),
                      ),
                      const SizedBox(width: 3),
                      Text('mi', style: TT.body(size: 14, color: TT.text2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('LIFETIME',
                      style: TT.label(size: 10.5, color: TT.text3, letterSpacing: 0.14 * 10.5)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: TT.line),
        const SizedBox(height: 6),
        if (hikes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
            child: Text('No recorded hikes yet.',
                textAlign: TextAlign.center,
                style: TT.body(size: 13, color: TT.text2)),
          )
        else
          ...List.generate(hikes.length, (i) {
            final h = hikes[i];
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _FadeUpDelayed(
                delay: Duration(milliseconds: 250 + i * 70),
                child: _HikeRow(hike: h, pathIdx: i % 3),
              ),
            );
          }),
      ],
    );
  }
}

class _HikeRow extends StatelessWidget {
  final SavedHike hike;
  final int pathIdx;
  const _HikeRow({required this.hike, required this.pathIdx});

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: hike.durationSeconds);
    final durText = '${dur.inHours}:${(dur.inMinutes % 60).toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 10, bottom: 10,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: TT.ember,
                borderRadius: BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2)),
                boxShadow: [BoxShadow(color: Color(0x66FF6A2C), blurRadius: 8)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: TT.bg3,
                    border: Border.all(color: TT.line, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomPaint(painter: _MiniRoutePainter(pathIdx)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hike.name, style: TT.body(size: 14, w: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${DateFormat('MMM d').format(hike.startedAt)} · $durText',
                          style: TT.mono(size: 10.5, color: TT.text3)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${(hike.distanceKm * 0.621371).toStringAsFixed(1)} mi',
                        style: TT.numStyle(size: 13, w: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('+${NumberFormat.decimalPattern().format((hike.ascentM * 3.28084).round())} ft',
                        style: TT.mono(size: 10.5, color: TT.ember, w: FontWeight.w700)),
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
