// Start-hike ramp.
//
// A deliberate pre-recording ritual so the app never auto-starts a hike
// from a mistap. Two stages:
//   1. SLIDE — user drags a thumb from left to right. Releasing past
//      ~85% commits; releasing before snaps back.
//   2. COUNTDOWN — 3-2-1-GO with a pulsing hex graphic. Tapping the
//      screen during the countdown cancels and pops back to the slide.
//
// The widget itself doesn't start the recording — it returns `true` from
// `StartHikeRamp.show()` on confirmation; the caller does the actual
// `RecordingProvider.start()` so the same ramp can be reused for
// alternate flows (e.g. live-tracking-only without recording) later.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design_tokens.dart';

class StartHikeRamp extends StatefulWidget {
  /// Optional copy override. Defaults to "Start Hike".
  final String title;
  final String subtitle;

  const StartHikeRamp({
    super.key,
    this.title = 'Ready to hike?',
    this.subtitle = 'Slide to start a new recording',
  });

  /// Push the ramp as a full-screen route. Resolves to `true` if the user
  /// completed the countdown, `false` if they cancelled or hit back.
  static Future<bool> show(BuildContext context,
      {String? title, String? subtitle}) async {
    final res = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => StartHikeRamp(
          title: title ?? 'Ready to hike?',
          subtitle: subtitle ?? 'Slide to start a new recording',
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
    return res == true;
  }

  @override
  State<StartHikeRamp> createState() => _StartHikeRampState();
}

class _StartHikeRampState extends State<StartHikeRamp>
    with TickerProviderStateMixin {
  // 0..1 progress of the drag thumb across the track.
  double _slide = 0.0;
  bool _committed = false; // slide passed the threshold and locked in
  bool _counting = false;

  // Heartbeat pulse on the hero hex while waiting for the slide.
  late final AnimationController _heartbeat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  // Countdown controller — drives the 3-2-1-GO sequence + ring animation.
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  Timer? _autoCancel;

  @override
  void dispose() {
    _heartbeat.dispose();
    _countdown.dispose();
    _autoCancel?.cancel();
    super.dispose();
  }

  void _onSlideUpdate(DragUpdateDetails d, double trackWidth) {
    if (_committed) return;
    final dx = d.delta.dx;
    final next = (_slide + dx / trackWidth).clamp(0.0, 1.0);
    setState(() => _slide = next);
  }

  void _onSlideEnd(double trackWidth) {
    if (_committed) return;
    if (_slide >= 0.85) {
      // Lock to 1.0, kick off countdown.
      setState(() {
        _slide = 1.0;
        _committed = true;
      });
      HapticFeedback.mediumImpact();
      _runCountdown();
    } else {
      // Snap back. AnimatedContainer-style smooth release.
      _animateSlideBackTo(0.0);
    }
  }

  void _animateSlideBackTo(double target) {
    final ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final tween = Tween(begin: _slide, end: target).animate(
      CurvedAnimation(parent: ctl, curve: Curves.easeOut),
    );
    tween.addListener(() {
      if (!mounted) return;
      setState(() => _slide = tween.value);
    });
    ctl.forward().whenComplete(ctl.dispose);
  }

  Future<void> _runCountdown() async {
    setState(() => _counting = true);
    _countdown.reset();
    unawaited(HapticFeedback.lightImpact());
    unawaited(_countdown.forward());
    // 3 distinct haptic ticks at second boundaries — confirms each beat.
    Timer(const Duration(seconds: 1), () => HapticFeedback.lightImpact());
    Timer(const Duration(seconds: 2), () => HapticFeedback.lightImpact());
    await _countdown.forward().orCancel.catchError((_) {});
    if (!mounted) return;
    unawaited(HapticFeedback.heavyImpact());
    Navigator.of(context).pop(true);
  }

  void _cancelCountdown() {
    if (!_counting) return;
    _countdown.stop();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final trackWidth = size.width - 64; // 32 px padding each side

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cancelCountdown,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── Top bar (close X) ────────────────────────────────
                Row(
                  children: [
                    if (!_committed)
                      _CloseBtn(onTap: () => Navigator.of(context).pop(false)),
                    const Spacer(),
                  ],
                ),
                const Spacer(),
                // ── Hero hex with pulse rings ────────────────────────
                _HeroGraphic(
                  heartbeat: _heartbeat,
                  countdown: _countdown,
                  counting: _counting,
                ),
                const SizedBox(height: 32),
                // ── Title + subtitle ─────────────────────────────────
                Text(
                  _counting ? 'STARTING…' : widget.title.toUpperCase(),
                  style: TT
                      .body(size: 12, w: FontWeight.w800, color: TT.text3)
                      .copyWith(letterSpacing: 0.2 * 12),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _countdown,
                  builder: (_, __) {
                    final label = _counting
                        ? _countdownLabel(_countdown.value)
                        : widget.subtitle;
                    return Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TT.title(_counting ? 36 : 22,
                          letterSpacing: _counting ? 0.05 : -0.01),
                    );
                  },
                ),
                const Spacer(),
                // ── Slide track ──────────────────────────────────────
                if (!_counting)
                  _SlideTrack(
                    progress: _slide,
                    trackWidth: trackWidth,
                    onDragUpdate: (d) => _onSlideUpdate(d, trackWidth),
                    onDragEnd: (_) => _onSlideEnd(trackWidth),
                    committed: _committed,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'TAP SCREEN TO CANCEL',
                      style: TT.mono(
                          size: 11, color: TT.text3, letterSpacing: 0.16 * 11),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countdownLabel(double t) {
    // t is 0 → 1 over 3 seconds.
    final remaining = 3 - (t * 3);
    if (remaining > 2) return '3';
    if (remaining > 1) return '2';
    if (remaining > 0.05) return '1';
    return 'GO!';
  }
}

// ─────────────────────────────── close button ────────────────────────────────

class _CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TT.surf.withOpacity(0.8),
          border: Border.all(color: TT.line2, width: 1),
        ),
        child: const Icon(Icons.close, size: 18, color: TT.text2),
      ),
    );
  }
}

// ─────────────────────────────── hero graphic ────────────────────────────────
//
// Pulsing hex with hiker icon. During countdown the hex shifts to ember and
// pulse rings expand outward in sync with the timer.

class _HeroGraphic extends StatelessWidget {
  final AnimationController heartbeat;
  final AnimationController countdown;
  final bool counting;
  const _HeroGraphic({
    required this.heartbeat,
    required this.countdown,
    required this.counting,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([heartbeat, countdown]),
        builder: (_, __) {
          return CustomPaint(
            painter: _HeroPainter(
              heartbeat: heartbeat.value,
              countdown: counting ? countdown.value : 0.0,
              counting: counting,
            ),
            child: Center(
              child: Icon(
                Icons.directions_walk_rounded,
                size: 56,
                color: counting ? TT.ember : TT.text,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final double heartbeat; // 0..1..0
  final double countdown; // 0..1
  final bool counting;
  _HeroPainter({
    required this.heartbeat,
    required this.countdown,
    required this.counting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // ── Hex outline ─────────────────────────────────────────────────────
    final hexPath = _hexPath(c, r * 0.78);
    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (counting ? TT.ember : TT.text2).withOpacity(0.55);
    canvas.drawPath(hexPath, hexPaint);

    // Inner glow when counting.
    if (counting) {
      final glow = Paint()
        ..style = PaintingStyle.fill
        ..color = TT.ember.withOpacity(0.10 + 0.18 * (1 - countdown));
      canvas.drawPath(hexPath, glow);
    }

    // ── Heartbeat ring (idle state) ─────────────────────────────────────
    if (!counting) {
      final t = (math.sin(heartbeat * math.pi));
      final hbRadius = r * 0.85 + t * 6;
      final hbPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TT.text2.withOpacity(0.20 + 0.10 * t);
      canvas.drawCircle(c, hbRadius, hbPaint);
    }

    // ── Countdown pulse rings — 3 expanding circles staggered ──────────
    if (counting) {
      for (int i = 0; i < 3; i++) {
        final phase = ((countdown * 3) - i).clamp(0.0, 1.0);
        if (phase <= 0) continue;
        final ringR = r * (0.85 + phase * 0.45);
        final opacity = (1.0 - phase) * 0.7;
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = TT.ember.withOpacity(opacity);
        canvas.drawCircle(c, ringR, ringPaint);
      }
    }

    // ── Tick marks around the hex (6 corners, decorative) ──────────────
    final tickPaint = Paint()
      ..strokeWidth = 1.2
      ..color = (counting ? TT.ember : TT.text3).withOpacity(0.45);
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final p1 = Offset(
          c.dx + math.cos(angle) * r * 0.92, c.dy + math.sin(angle) * r * 0.92);
      final p2 = Offset(
          c.dx + math.cos(angle) * r * 0.98, c.dy + math.sin(angle) * r * 0.98);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  Path _hexPath(Offset center, double r) {
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.heartbeat != heartbeat ||
      old.countdown != countdown ||
      old.counting != counting;
}

// ─────────────────────────────── slide track ─────────────────────────────────

class _SlideTrack extends StatelessWidget {
  final double progress; // 0..1
  final double trackWidth;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final bool committed;

  const _SlideTrack({
    required this.progress,
    required this.trackWidth,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.committed,
  });

  @override
  Widget build(BuildContext context) {
    const thumbSize = 56.0;
    const trackHeight = 64.0;
    final maxX = trackWidth - thumbSize - 8;
    final thumbX = (maxX * progress).clamp(0.0, maxX);

    return SizedBox(
      width: trackWidth,
      height: trackHeight,
      child: Stack(
        children: [
          // Track background.
          Container(
            decoration: BoxDecoration(
              color: TT.surf,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: TT.line2, width: 1),
            ),
          ),
          // Fill that grows behind the thumb as the user drags.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: thumbX + thumbSize + 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    TT.ember.withOpacity(0.0),
                    TT.ember.withOpacity(0.30 + 0.40 * progress),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          // Label centred behind the thumb.
          Center(
            child: Opacity(
              opacity: (1.0 - progress).clamp(0.0, 1.0),
              child: Text(
                'SLIDE TO START',
                style: TT
                    .body(size: 13, w: FontWeight.w900, color: TT.text2)
                    .copyWith(letterSpacing: 0.18 * 13),
              ),
            ),
          ),
          // Thumb.
          Positioned(
            left: 4 + thumbX,
            top: 4,
            child: GestureDetector(
              onHorizontalDragUpdate: committed ? null : onDragUpdate,
              onHorizontalDragEnd: committed ? null : onDragEnd,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TT.ember.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: TT.emberInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
