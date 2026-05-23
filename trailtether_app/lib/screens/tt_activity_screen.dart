// Trailtether 2.0 — Activity screen.
//
// Recreates project/screens/stats.jsx from the design bundle: brand bar +
// segmented tabs (My Hikes / Overall Stats) over a scrolling body of cards.
// Backed by real HikeHistoryProvider data — falls back to a friendly empty
// state when the user has no recorded hikes yet.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/saved_hike.dart';
import '../providers/auth_provider.dart';
import '../providers/hike_history_provider.dart';
import '../services/health_connect_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import 'hike_history_screen.dart' show HikeDetailScreen, HikeHistoryScreen;
import 'tt_profile_screen.dart';

class TTActivityScreen extends StatefulWidget {
  final bool embedded;
  /// Optional shell callback for switching the surrounding bottom-nav tab.
  /// When provided, the avatar badge taps `5` to surface the Profile tab
  /// instead of pushing a fresh route — keeping the v3.0 AppShell flow stable.
  final ValueChanged<int>? onNavigate;
  const TTActivityScreen({super.key, this.embedded = false, this.onNavigate});

  @override
  State<TTActivityScreen> createState() => _TTActivityScreenState();
}

class _TTActivityScreenState extends State<TTActivityScreen> {
  int _tab = 1; // 0 My Hikes, 1 Overall Stats — matches the design's default

  void _openProfile() {
    final onNav = widget.onNavigate;
    if (onNav != null) {
      onNav(5); // AppShell profile tab index
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TTProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<HikeHistoryProvider>(builder: (_, history, __) {
      final hikes = history.hikes;
      return Stack(
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
                    _AvatarBadge(onTap: _openProfile),
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
    });

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

class _AvatarBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _AvatarBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(builder: (_, auth, __) {
      final photoUrl = auth.photoUrl;
      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TT.ember, width: 2),
            gradient: hasPhoto
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF6B3A1A), TT.ember2],
                  ),
            image: hasPhoto
                ? DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  )
                : null,
            boxShadow: const [BoxShadow(color: Color(0x66FF6A2C), blurRadius: 12, spreadRadius: 0)],
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? null
              : Text(_initials(auth),
                  style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white)),
        ),
      );
    });
  }

  String _initials(AuthProvider auth) {
    final name = (auth.displayName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return (parts.first[0] + parts.last[0]).toUpperCase();
      }
      if (parts.isNotEmpty && parts.first.length >= 2) {
        return parts.first.substring(0, 2).toUpperCase();
      }
      if (parts.isNotEmpty) {
        return parts.first[0].toUpperCase();
      }
    }
    final email = (auth.email ?? '').trim();
    if (email.isNotEmpty) {
      final local = email.split('@').first;
      if (local.length >= 2) return local.substring(0, 2).toUpperCase();
      if (local.isNotEmpty) return local[0].toUpperCase();
    }
    return '--';
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
        _HealthSync(hikes: hikes),
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
    if (latest == null) {
      return TTCard(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Opacity(
              opacity: 0.35,
              child: Icon(Icons.landscape_outlined, size: 56, color: TT.text2),
            ),
            const SizedBox(height: 14),
            Text(
              'No recorded hikes yet',
              textAlign: TextAlign.center,
              style: TT.title(16, letterSpacing: -0.01 * 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap Start Hike on the Map to record one',
              textAlign: TextAlign.center,
              style: TT.body(size: 12.5, color: TT.text3),
            ),
          ],
        ),
      );
    }

    final h = latest!;
    final name = h.name;
    final date = DateFormat('MMM d, y').format(h.startedAt).toUpperCase();
    final dist = (h.distanceKm * 0.621371).toStringAsFixed(1);
    final ascent = NumberFormat.decimalPattern().format((h.ascentM * 3.28084).round());
    final samples = h.points.length > 4 ? h.points.map((p) => p.altitude).toList() : null;

    void openDetail() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: h)),
        );

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      onTap: openDetail,
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
              TTIconBtn(icon: Icons.chevron_right, size: 32, onTap: openDetail),
            ],
          ),
          const SizedBox(height: 6),
          TTBigElevChart(samples: samples, peakLabel: '$dist mi · $ascent ft'),
        ],
      ),
    );
  }
}

/// Health Connect status pill — hides itself when the platform doesn't
/// support Health Connect or the SDK isn't installed, otherwise lets the user
/// push every recorded hike to Health Connect in one tap. Uses the real
/// [HealthConnectService] — no fake "synced 2m ago" copy.
class _HealthSync extends StatefulWidget {
  final List<SavedHike> hikes;
  const _HealthSync({required this.hikes});

  @override
  State<_HealthSync> createState() => _HealthSyncState();
}

class _HealthSyncState extends State<_HealthSync> {
  // null = still probing, true/false = answer
  bool? _available;
  bool _busy = false;
  DateTime? _lastSyncedAt;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final ok = await HealthConnectService.isAvailable();
    if (!mounted) return;
    setState(() => _available = ok);
  }

  Future<void> _syncAll() async {
    if (_busy || widget.hikes.isEmpty) return;
    setState(() {
      _busy = true;
      _lastError = null;
    });

    var wrote = 0;
    String? firstError;
    for (final h in widget.hikes) {
      final result = await HealthConnectService.writeHike(h);
      if (result.ok) {
        wrote++;
      } else if (firstError == null &&
          result.status != HealthConnectStatus.invalidHike) {
        firstError = result.userMessage;
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastSyncedAt = DateTime.now();
      _lastError = wrote == 0 ? firstError : null;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(wrote == 0
            ? (firstError ?? 'No hikes were written to Health Connect')
            : 'Synced $wrote hike${wrote == 1 ? "" : "s"} to Health Connect'),
      ));
    }
  }

  String _statusLine() {
    if (_busy) return 'SYNCING…';
    if (_lastError != null) return _lastError!.toUpperCase();
    if (_lastSyncedAt != null) return 'JUST SYNCED';
    if (widget.hikes.isEmpty) return 'NO HIKES TO SYNC';
    final n = widget.hikes.length;
    return 'READY · $n HIKE${n == 1 ? "" : "S"}';
  }

  @override
  Widget build(BuildContext context) {
    // Hide entirely on platforms / installs that don't support Health Connect.
    if (_available == false) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _available == true && !_busy && widget.hikes.isNotEmpty
          ? _syncAll
          : null,
      child: ClipRRect(
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
                          Text(
                            _lastSyncedAt != null && _lastError == null
                                ? 'Synced to Health Connect'
                                : 'Sync to Health Connect',
                            style: TT.body(size: 13, w: FontWeight.w900, color: TT.emberInk),
                          ),
                          const SizedBox(height: 3),
                          Text(_statusLine(),
                              style: TT.mono(size: 10, color: TT.emberInk).copyWith(letterSpacing: 0.08 * 10)),
                        ],
                      ),
                    ),
                    Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(color: Color(0xD9000000), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TT.ember2,
                              ),
                            )
                          : Icon(
                              _lastSyncedAt != null && _lastError == null
                                  ? Icons.check
                                  : Icons.sync,
                              size: 15,
                              color: TT.ember2,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    // Stat tiles are summary metrics — intentionally not interactive, so we
    // omit `onTap` to avoid a fake ripple on a no-op tap.
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
    // Caller passes `hikes.sublist(1, ...)`, so an empty list here means there
    // is at most one recorded hike — hide the section entirely rather than
    // showing fake placeholder rows.
    if (hikes.isEmpty) return const SizedBox.shrink();
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HikeHistoryScreen(),
                  ),
                ),
                child: Text('VIEW ALL →',
                    style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember)
                        .copyWith(letterSpacing: 0.1 * 10)),
              ),
            ],
          ),
        ),
        ...List.generate(hikes.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FadeUpDelayed(
              delay: Duration(milliseconds: 800 + i * 80),
              child: _ActivityRow(hike: hikes[i], pathIdx: i % 3),
            ),
          );
        }),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final SavedHike hike;
  final int pathIdx;
  const _ActivityRow({required this.hike, required this.pathIdx});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d').format(hike.startedAt);
    final dist = '${(hike.distanceKm * 0.621371).toStringAsFixed(1)} mi';
    final gain =
        '+${NumberFormat.decimalPattern().format((hike.ascentM * 3.28084).round())}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike)),
      ),
      child: Container(
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
                        Text(hike.name, style: TT.body(size: 13.5, w: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(date, style: TT.mono(size: 10.5, color: TT.text3)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dist, style: TT.numStyle(size: 13, w: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('$gain ft',
                          style: TT.mono(size: 10.5, color: TT.ember, w: FontWeight.w700)),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike)),
      ),
      child: Container(
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
      ),
    );
  }
}
