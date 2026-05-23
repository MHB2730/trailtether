// Trailtether 2.0 - Welcome / Onboarding screen.
//
// Auto-rotating first-run hero with five animated feature scenes:
// Tether, Plan, Navigate, Stay Aware, SOS. Recreates project/screens/
// welcome.jsx - animated dots indicator, rotating eyebrow + title + body,
// shimmering CTA, and a brand mark in the top-left.
//
// This screen is always full-screen and has no provider/service dependencies.
// Pass [onDone] to navigate away when the user taps "GET STARTED".

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_topo.dart';

// =============================== FEATURES =================================

enum _SceneId { tether, plan, navigate, aware, sos }

class _Feature {
  final _SceneId id;
  final String eyebrow;
  final String title;
  final String body;
  final Color color;
  const _Feature({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.color,
  });
}

const List<_Feature> _kFeatures = [
  _Feature(
    id: _SceneId.tether,
    eyebrow: 'STAY TETHERED',
    title: 'Someone at home, always watching.',
    body:
        'Your phone broadcasts live position to a base-camp PC at home. No surveillance - just a tether.',
    color: TT.ember,
  ),
  _Feature(
    id: _SceneId.plan,
    eyebrow: 'PLAN',
    title: 'Know what you walk into.',
    body:
        'Curated routes with distance, elevation, and live weather scored for hiking - not just temperature.',
    color: TT.ember2,
  ),
  _Feature(
    id: _SceneId.navigate,
    eyebrow: 'NAVIGATE OFFLINE',
    title: '2D, 3D, and signal-dead.',
    body:
        'Topographic, satellite, and terrain layers. Downloaded for offline. Speed-coloured trail recording.',
    color: TT.ember,
  ),
  _Feature(
    id: _SceneId.aware,
    eyebrow: 'STAY AWARE',
    title: 'Weather, hazards, and shelter.',
    body:
        'Multi-source forecasts, community hazard reports, 125 surveyed Drakensberg caves and shelters built in.',
    color: TT.amber,
  ),
  _Feature(
    id: _SceneId.sos,
    eyebrow: 'ACT FAST',
    title: 'One tap. Help on the way.',
    body:
        'SOS shares your live location. Compass, flashlight, native emergency contacts - all one tap deep.',
    color: TT.red,
  ),
];

// =============================== SCREEN ===================================

class TTWelcomeScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const TTWelcomeScreen({super.key, this.onDone});

  @override
  State<TTWelcomeScreen> createState() => _TTWelcomeScreenState();
}

class _TTWelcomeScreenState extends State<TTWelcomeScreen>
    with TickerProviderStateMixin {
  int _idx = 0;
  bool _paused = false;
  late final AnimationController _enterCtl;

  static const Duration _rotateEvery = Duration(milliseconds: 5200);
  static const Duration _xfade = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _enterCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _scheduleNext();
  }

  void _scheduleNext() {
    Future.delayed(_rotateEvery, () {
      if (!mounted) return;
      if (_paused) {
        _scheduleNext();
        return;
      }
      setState(() => _idx = (_idx + 1) % _kFeatures.length);
      _scheduleNext();
    });
  }

  void _select(int i) {
    if (i == _idx) return;
    setState(() => _idx = i);
  }

  @override
  void dispose() {
    _enterCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feat = _kFeatures[_idx];

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          SafeArea(
            child: Column(
              children: [
                _BrandBar(onSkip: widget.onDone, enterCtl: _enterCtl),
                // Hero illustration zone - fixed height, color-tinted radial glow.
                SizedBox(
                  height: 340,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // v3.0 feature graphic — keeps original logo in app_icon,
                      // adds photographic depth behind the animated scenes.
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.32,
                          child: ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.transparent],
                              stops: [0.5, 1.0],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/icon/feature_graphic.png',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.2),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: Opacity(opacity: 0.25, child: TTTopoBackdrop()),
                      ),
                      // Color-following radial glow.
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: _xfade,
                          curve: TT.easeOut,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, 0.1),
                              radius: 0.9,
                              colors: [
                                feat.color.withOpacity(0.135),
                                feat.color.withOpacity(0),
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                      // Scene crossfade - only the active scene is built.
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: _xfade,
                          switchInCurve: TT.easeOut,
                          switchOutCurve: TT.easeOut,
                          transitionBuilder: (child, anim) {
                            final scale = Tween(begin: 0.98, end: 1.0)
                                .chain(CurveTween(curve: TT.easeOut))
                                .animate(anim);
                            return FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: scale, child: child),
                            );
                          },
                          child: _Scene(
                            key: ValueKey(feat.id),
                            id: feat.id,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                    child: Column(
                      children: [
                        // Tagline - never changes. Slides in once on first build.
                        _AnimUp(
                          ctl: _enterCtl,
                          delay: 180,
                          child: Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TT.title(26, letterSpacing: -0.02 * 26)
                                    .copyWith(height: 1.15),
                                children: const [
                                  TextSpan(text: 'Plan smarter.\n'),
                                  TextSpan(text: 'Hike safer.\n'),
                                  TextSpan(
                                    text: 'Stay connected on the trail.',
                                    style: TextStyle(color: TT.ember),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Rotating eyebrow + title + body.
                        SizedBox(
                          height: 110,
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _paused = true),
                            onExit: (_) => setState(() => _paused = false),
                            child: GestureDetector(
                              onTapDown: (_) => setState(() => _paused = true),
                              onTapUp: (_) => setState(() => _paused = false),
                              onTapCancel: () => setState(() => _paused = false),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                switchInCurve: TT.easeOut,
                                switchOutCurve: TT.easeOut,
                                transitionBuilder: (child, anim) {
                                  final slide = Tween<Offset>(
                                          begin: const Offset(0, 0.06),
                                          end: Offset.zero)
                                      .chain(CurveTween(curve: TT.easeOut))
                                      .animate(anim);
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                        position: slide, child: child),
                                  );
                                },
                                child: _CopyBlock(
                                  key: ValueKey(feat.id),
                                  feat: feat,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Dots(
                          count: _kFeatures.length,
                          active: _idx,
                          onTap: _select,
                        ),
                        const Spacer(),
                        // CTAs
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            children: [
                              _GetStartedButton(onTap: widget.onDone),
                              const SizedBox(height: 14),
                              _SignInRow(onTap: widget.onDone),
                              const SizedBox(height: 16),
                              Text(
                                'FREE   NO ADS   BUILT IN CAPE TOWN',
                                textAlign: TextAlign.center,
                                style: TT.mono(
                                  size: 9.5,
                                  color: TT.text4,
                                  letterSpacing: 0.16 * 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

// =============================== BRAND BAR ================================

class _BrandBar extends StatelessWidget {
  final VoidCallback? onSkip;
  final AnimationController enterCtl;
  const _BrandBar({required this.onSkip, required this.enterCtl});

  @override
  Widget build(BuildContext context) {
    return _AnimUp(
      ctl: enterCtl,
      delay: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 6),
        child: Row(
          children: [
            const Expanded(child: TTBrandMark(size: 13)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'SKIP',
                  style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                      .copyWith(letterSpacing: 0.1 * 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================== COPY BLOCK ===============================

class _CopyBlock extends StatelessWidget {
  final _Feature feat;
  const _CopyBlock({super.key, required this.feat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: feat.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: feat.color.withOpacity(0.33), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: feat.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: feat.color, blurRadius: 5, spreadRadius: 0),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                feat.eyebrow,
                style: TT.mono(
                  size: 9.5,
                  color: feat.color,
                  w: FontWeight.w800,
                  letterSpacing: 0.18 * 9.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          feat.title,
          textAlign: TextAlign.center,
          style: TT.body(size: 15, w: FontWeight.w700)
              .copyWith(height: 1.35, letterSpacing: -0.005 * 15),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            feat.body,
            textAlign: TextAlign.center,
            style: TT.body(size: 12, w: FontWeight.w500, color: TT.text2)
                .copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

// =============================== DOTS =====================================

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  final ValueChanged<int> onTap;
  const _Dots({required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: TT.easeOut,
              width: isActive ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? TT.ember : TT.line3,
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive
                    ? const [
                        BoxShadow(
                          color: Color(0x8CFF6A2C),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =============================== CTA / FOOTER =============================

class _GetStartedButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _GetStartedButton({required this.onTap});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: SizedBox(
          height: 54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [TT.ember2, TT.ember],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: TT.shadowEmber,
                  ),
                ),
                const Positioned.fill(child: TTShimmerBand()),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GET STARTED',
                        style: TT.body(
                          size: 13,
                          w: FontWeight.w900,
                          color: TT.emberInk,
                        ).copyWith(letterSpacing: 0.14 * 13),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right,
                          size: 18, color: TT.emberInk),
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

class _SignInRow extends StatelessWidget {
  final VoidCallback? onTap;
  const _SignInRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TT.body(size: 12, w: FontWeight.w600, color: TT.text3),
          children: const [
            TextSpan(text: 'Already have an account?  '),
            TextSpan(
              text: 'Sign in',
              style: TextStyle(color: TT.ember, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================== ANIM PRIMITIVES ==========================

/// Mirrors the `anim-up` CSS keyframe - fades + rises into place once, driven
/// by an external controller so all entrance animations stay in sync with the
/// screen lifetime.
class _AnimUp extends StatelessWidget {
  final AnimationController ctl;
  final int delay; // ms
  final Widget child;
  const _AnimUp({required this.ctl, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctl,
      builder: (_, c) {
        // Drive a sub-curve that begins at `delay / totalDuration`.
        final total = ctl.duration?.inMilliseconds ?? 900;
        final start = (delay / total).clamp(0.0, 1.0);
        final raw = ((ctl.value - start) / (1 - start)).clamp(0.0, 1.0);
        final t = TT.easeOut.transform(raw);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// =============================== SCENE DISPATCH ===========================

class _Scene extends StatelessWidget {
  final _SceneId id;
  const _Scene({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case _SceneId.tether:
        return const _SceneTether();
      case _SceneId.plan:
        return const _ScenePlan();
      case _SceneId.navigate:
        return const _SceneNavigate();
      case _SceneId.aware:
        return const _SceneAware();
      case _SceneId.sos:
        return const _SceneSOS();
    }
  }
}

// Logical canvas the SVGs were authored in. All scenes are 412 x 340 and
// scale to fit the available box via `FittedBox`.
const Size _kSceneSize = Size(412, 340);

Widget _sceneFit(CustomPainter painter, {Widget? overlay}) {
  return FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: _kSceneSize.width,
      height: _kSceneSize.height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: painter)),
          if (overlay != null) Positioned.fill(child: overlay),
        ],
      ),
    ),
  );
}

// =========================== SCENE 1 - TETHER =============================
// Phone on mountain <-> basecamp PC connected via a glowing dashed tether arc.

class _SceneTether extends StatefulWidget {
  const _SceneTether();
  @override
  State<_SceneTether> createState() => _SceneTetherState();
}

class _SceneTetherState extends State<_SceneTether>
    with TickerProviderStateMixin {
  late final AnimationController _arcCtl =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  late final AnimationController _windowCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);
  late final AnimationController _pulseCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();

  @override
  void dispose() {
    _arcCtl.dispose();
    _windowCtl.dispose();
    _pulseCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_arcCtl, _windowCtl, _pulseCtl]),
      builder: (_, __) {
        return _sceneFit(_TetherPainter(
          arcT: _arcCtl.value,
          windowT: _windowCtl.value,
          pulseT: _pulseCtl.value,
        ));
      },
    );
  }
}

class _TetherPainter extends CustomPainter {
  final double arcT, windowT, pulseT;
  _TetherPainter({required this.arcT, required this.windowT, required this.pulseT});

  // The shared cubic arc the dashed line + packet pulses ride along.
  Path _arcPath() {
    return Path()
      ..moveTo(145, 130)
      ..cubicTo(200, 60, 270, 60, 310, 200);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Mountain silhouette.
    final mountain = Path()
      ..moveTo(-10, 280)
      ..lineTo(60, 180)
      ..lineTo(100, 220)
      ..lineTo(140, 140)
      ..lineTo(180, 200)
      ..lineTo(220, 250)
      ..lineTo(220, 340)
      ..lineTo(-10, 340)
      ..close();
    canvas.drawPath(
        mountain,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2F38), Color(0xFF0D1116)],
          ).createShader(const Rect.fromLTWH(0, 0, 412, 340)));
    final ridge = Path()
      ..moveTo(-10, 280)
      ..lineTo(60, 180)
      ..lineTo(100, 220)
      ..lineTo(140, 140)
      ..lineTo(180, 200)
      ..lineTo(220, 250);
    canvas.drawPath(
        ridge,
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round);
    // Snow caps.
    final snow = Paint()..color = const Color(0xD9EEF1F4);
    canvas.drawPath(
        Path()
          ..moveTo(55, 188)
          ..lineTo(60, 180)
          ..lineTo(65, 190)
          ..close(),
        snow);
    canvas.drawPath(
        Path()
          ..moveTo(135, 148)
          ..lineTo(140, 140)
          ..lineTo(146, 152)
          ..lineTo(142, 150)
          ..close(),
        snow);

    // Base camp house ----------------------------------------------------
    canvas.save();
    canvas.translate(310, 210);
    const wall = Rect.fromLTWH(-30, 0, 60, 46);
    canvas.drawRect(wall, Paint()..color = const Color(0xFF1A2029));
    canvas.drawRect(
        wall,
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    final roof = Path()
      ..moveTo(-36, 0)
      ..lineTo(0, -28)
      ..lineTo(36, 0)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF22293A));
    canvas.drawPath(
        roof,
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round);
    // Door
    canvas.drawRect(const Rect.fromLTWH(-10, 14, 20, 32),
        Paint()..color = const Color(0xFF0A0C0F));
    canvas.drawRect(
        const Rect.fromLTWH(-10, 14, 20, 32),
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    // Two windows that alternate brightness.
    final w1op = 0.6 + 0.4 * windowT;
    final w2op = 0.85 - 0.35 * windowT;
    canvas.drawRect(const Rect.fromLTWH(-22, 10, 10, 10),
        Paint()..color = TT.ember2.withOpacity(w1op));
    canvas.drawRect(const Rect.fromLTWH(12, 10, 10, 10),
        Paint()..color = TT.ember2.withOpacity(w2op));
    _drawText(canvas,
        text: 'BASE  CAMP',
        center: const Offset(0, 62),
        color: const Color(0xFF98A1AC),
        fontFamily: 'JetBrainsMono',
        size: 9,
        weight: FontWeight.w700,
        letterSpacing: 0.2 * 9);
    canvas.restore();

    // Tether arc (animated dash offset) ---------------------------------
    final dashOffset = -100 * arcT;
    _drawDashed(
      canvas,
      _arcPath(),
      paint: Paint()
        ..color = TT.ember2.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      dashOn: 4,
      dashOff: 6,
      offset: dashOffset,
    );
    _drawDashed(
      canvas,
      _arcPath(),
      paint: Paint()
        ..color = TT.ember2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
      dashOn: 3,
      dashOff: 5,
      offset: dashOffset * 0.8,
    );

    // Data packet pulses traveling along the arc - two staggered.
    for (final phase in const [0.0, 0.5]) {
      final p = (arcT + phase) % 1.0;
      final metrics = _arcPath().computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final m = metrics.first;
        final tan = m.getTangentForOffset(p * m.length);
        if (tan != null) {
          final op = math.sin(p * math.pi).clamp(0.0, 1.0);
          canvas.drawCircle(
              tan.position,
              3.5,
              Paint()
                ..color = TT.ember2.withOpacity(op)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4));
        }
      }
    }

    // Phone on mountain peak --------------------------------------------
    canvas.save();
    canvas.translate(140, 130);
    final phoneOuter = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -22, 24, 44), const Radius.circular(4));
    canvas.drawRRect(phoneOuter, Paint()..color = const Color(0xFF0A0C0F));
    canvas.drawRRect(
        phoneOuter,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-9, -18, 18, 36), const Radius.circular(2)),
        Paint()..color = TT.emberInk);
    // Tiny screen content.
    final scOp = 0.5 + 0.5 * (math.sin(_twoPi * windowT * 0.7) * 0.5 + 0.5);
    canvas.drawCircle(
        const Offset(0, -10), 1.5, Paint()..color = TT.ember2.withOpacity(scOp));
    canvas.drawRect(const Rect.fromLTWH(-6, -5, 12, 1.5),
        Paint()..color = TT.ember.withOpacity(0.7));
    canvas.drawRect(const Rect.fromLTWH(-6, -1, 9, 1.5),
        Paint()..color = TT.ember.withOpacity(0.5));
    canvas.drawRect(const Rect.fromLTWH(-6, 3, 11, 1.5),
        Paint()..color = TT.ember.withOpacity(0.6));
    // Pulse ring around the phone.
    final r = 18 + 16 * pulseT;
    final op = (0.7 - 0.7 * pulseT).clamp(0.0, 1.0);
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = TT.ember.withOpacity(op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.restore();

    // Floating data labels (alternating opacity) ------------------------
    final lbl1Op = (math.sin(arcT * _twoPi - 0.4) * 0.5 + 0.5).clamp(0.0, 1.0);
    final lbl2Op = (math.sin(arcT * _twoPi + 2.0) * 0.5 + 0.5).clamp(0.0, 1.0);
    _floatingLabel(canvas, const Offset(218, 80), 'GPS  3m', lbl1Op);
    _floatingLabel(canvas, const Offset(252, 55), '+2 SE', lbl2Op);
  }

  void _floatingLabel(Canvas canvas, Offset center, String text, double opacity) {
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 60, height: 18),
        const Radius.circular(4));
    canvas.drawRRect(
        rect, Paint()..color = const Color(0xFF0A0C0F).withOpacity(opacity));
    canvas.drawRRect(
        rect,
        Paint()
          ..color = TT.ember.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7);
    _drawText(canvas,
        text: text,
        center: center,
        color: TT.ember2.withOpacity(opacity),
        fontFamily: 'JetBrainsMono',
        size: 9,
        weight: FontWeight.w700);
  }

  @override
  bool shouldRepaint(_TetherPainter old) =>
      old.arcT != arcT || old.windowT != windowT || old.pulseT != pulseT;
}

// =========================== SCENE 2 - PLAN ===============================
// Curated route with elevation card. Route draws in, peak pops, weather chip
// floats up.

class _ScenePlan extends StatefulWidget {
  const _ScenePlan();
  @override
  State<_ScenePlan> createState() => _ScenePlanState();
}

class _ScenePlanState extends State<_ScenePlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) => _sceneFit(_PlanPainter(t: _ctl.value)),
    );
  }
}

class _PlanPainter extends CustomPainter {
  final double t;
  _PlanPainter({required this.t});

  double _sub(double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    // Map base.
    final mapRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 32, 340, 180), const Radius.circular(14));
    canvas.drawRRect(mapRect, Paint()..color = const Color(0xFF0B1015));
    canvas.drawRRect(
        mapRect,
        Paint()
          ..color = const Color(0xFF1C2127)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Contour lines (clipped to map area).
    canvas.save();
    canvas.clipRRect(mapRect);
    final contourPaint = Paint()
      ..color = const Color(0xFF222A33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final contours = [
      [const Offset(40, 180), const Offset(380, 165), 160.0],
      [const Offset(40, 150), const Offset(380, 125), 120.0],
      [const Offset(40, 120), const Offset(380, 90), 85.0],
      [const Offset(40, 90), const Offset(380, 60), 55.0],
      [const Offset(40, 60), const Offset(380, 40), 40.0],
    ];
    for (final c in contours) {
      final a = c[0] as Offset;
      final b = c[1] as Offset;
      final dipY = c[2] as double;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(120, dipY, 200, (a.dy + b.dy) / 2)
        ..quadraticBezierTo(280, b.dy + 10, b.dx, b.dy);
      canvas.drawPath(path, contourPaint);
    }
    canvas.restore();

    // Route - animated draw-in.
    final route = Path()
      ..moveTo(70, 180)
      ..quadraticBezierTo(130, 150, 170, 130)
      ..quadraticBezierTo(220, 100, 280, 85)
      ..lineTo(340, 50);
    final routeT = _sub(0.00, 0.55);
    _drawPathTrim(
        canvas,
        route,
        Paint()
          ..color = TT.ember.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        routeT);
    _drawPathTrim(
        canvas,
        route,
        Paint()
          ..color = TT.ember2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
        _sub(0.04, 0.55));

    // Start diamond + summit marker.
    canvas.save();
    canvas.translate(70, 180);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(const Rect.fromLTWH(-5, -5, 10, 10), Paint()..color = TT.ember);
    canvas.drawRect(
        const Rect.fromLTWH(-5, -5, 10, 10),
        Paint()
          ..color = TT.emberInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.restore();
    canvas.save();
    canvas.translate(340, 50);
    canvas.drawCircle(Offset.zero, 7, Paint()..color = TT.emberInk);
    canvas.drawCircle(
        Offset.zero,
        7,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    final summit = Path()
      ..moveTo(0, -3)
      ..lineTo(-3, 2)
      ..lineTo(3, 2)
      ..close();
    canvas.drawPath(summit, Paint()..color = TT.ember);
    canvas.restore();

    // Map title chip.
    final titleRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(206, 52), width: 132, height: 22),
        const Radius.circular(5));
    canvas.drawRRect(
        titleRect, Paint()..color = const Color(0xEB0A0C0F));
    canvas.drawRRect(
        titleRect,
        Paint()
          ..color = const Color(0x26FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    _drawText(canvas,
        text: 'WONDERLAND LOOP',
        center: const Offset(206, 52),
        color: TT.text,
        fontFamily: 'Manrope',
        size: 10.5,
        weight: FontWeight.w800,
        letterSpacing: 0.14 * 10.5);

    // Elevation card ----------------------------------------------------
    canvas.save();
    canvas.translate(36, 232);
    final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 340, 86), const Radius.circular(12));
    canvas.drawRRect(card, Paint()..color = TT.surf);
    canvas.drawRRect(
        card,
        Paint()
          ..color = const Color(0xFF1C2127)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    _drawText(canvas,
        text: 'ELEVATION',
        topLeft: const Offset(14, 11),
        color: TT.text3,
        fontFamily: 'Manrope',
        size: 9.5,
        weight: FontWeight.w800,
        letterSpacing: 0.16 * 9.5);

    // Elevation fill (anim-in from below).
    final elevFillT = _sub(0.22, 0.65);
    final fillPath = Path()
      ..moveTo(14, 70)
      ..quadraticBezierTo(50, 60, 80, 55)
      ..quadraticBezierTo(120, 40, 160, 28)
      ..quadraticBezierTo(200, 22, 240, 30)
      ..quadraticBezierTo(280, 40, 320, 32)
      ..lineTo(326, 32)
      ..lineTo(326, 78)
      ..lineTo(14, 78)
      ..close();
    canvas.save();
    canvas.translate(0, (1 - elevFillT) * 8);
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TT.ember.withOpacity(0.5 * elevFillT),
              TT.ember.withOpacity(0),
            ],
          ).createShader(const Rect.fromLTWH(14, 22, 312, 56)));
    canvas.restore();

    final elevLine = Path()
      ..moveTo(14, 70)
      ..quadraticBezierTo(50, 60, 80, 55)
      ..quadraticBezierTo(120, 40, 160, 28)
      ..quadraticBezierTo(200, 22, 240, 30)
      ..quadraticBezierTo(280, 40, 320, 32);
    _drawPathTrim(
        canvas,
        elevLine,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
        _sub(0.18, 0.6));

    // Peak marker pop.
    final peakT = _sub(0.55, 0.85);
    if (peakT > 0) {
      // Dotted vertical line.
      _drawDashed(
        canvas,
        Path()
          ..moveTo(220, 22)
          ..lineTo(220, 78),
        paint: Paint()
          ..color = const Color(0x47FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
        dashOn: 2,
        dashOff: 2,
      );
      canvas.save();
      canvas.translate(220, 22);
      canvas.scale(peakT);
      canvas.drawCircle(Offset.zero, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset.zero,
          3.5,
          Paint()
            ..color = TT.ember
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.restore();
    }

    // Weather chip (anim-up).
    final chipT = _sub(0.35, 0.7);
    if (chipT > 0) {
      canvas.save();
      canvas.translate(326, 18 + (1 - chipT) * 6);
      final chipRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-46, -10, 46, 20), const Radius.circular(5));
      canvas.drawRRect(
          chipRect, Paint()..color = TT.emberInk.withOpacity(chipT));
      canvas.drawRRect(
          chipRect,
          Paint()
            ..color = TT.ember.withOpacity(chipT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7);
      _drawText(canvas,
          text: '8/10',
          center: const Offset(-23, 0),
          color: TT.ember2.withOpacity(chipT),
          fontFamily: 'JetBrainsMono',
          size: 9,
          weight: FontWeight.w800);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) => old.t != t;
}

// =========================== SCENE 3 - NAVIGATE ===========================
// Isometric 3D terrain block + compass with rotating needle + 2D/3D/SAT chip.

class _SceneNavigate extends StatefulWidget {
  const _SceneNavigate();
  @override
  State<_SceneNavigate> createState() => _SceneNavigateState();
}

class _SceneNavigateState extends State<_SceneNavigate>
    with TickerProviderStateMixin {
  late final AnimationController _drawCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();
  late final AnimationController _compassCtl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _drawCtl.dispose();
    _compassCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_drawCtl, _compassCtl]),
      builder: (_, __) {
        // Compass needle eases between -12 and +18 degrees.
        final ease = Curves.easeInOut.transform(_compassCtl.value);
        final needleDeg = -12 + 30 * ease;
        return _sceneFit(_NavigatePainter(
          t: _drawCtl.value,
          needleDeg: needleDeg,
        ));
      },
    );
  }
}

class _NavigatePainter extends CustomPainter {
  final double t;
  final double needleDeg;
  _NavigatePainter({required this.t, required this.needleDeg});

  double _sub(double s, double e) => ((t - s) / (e - s)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    // 3D terrain block --------------------------------------------------
    canvas.save();
    canvas.translate(206, 180);
    // Base shadow.
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 100), width: 320, height: 44),
        Paint()..color = const Color(0x99000000));

    // Right side face.
    final rightFace = Path()
      ..moveTo(140, -20)
      ..lineTo(140, 50)
      ..lineTo(0, 100)
      ..lineTo(0, 30)
      ..close();
    canvas.drawPath(
        rightFace,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF22293A), Color(0xFF0A0C0F)],
          ).createShader(const Rect.fromLTWH(0, -20, 140, 120)));
    // Left side face.
    final leftFace = Path()
      ..moveTo(-140, -20)
      ..lineTo(-140, 50)
      ..lineTo(0, 100)
      ..lineTo(0, 30)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFF171C25));
    // Top (mountain ridge).
    final top = Path()
      ..moveTo(-140, -20)
      ..lineTo(-90, -65)
      ..lineTo(-55, -30)
      ..lineTo(-20, -85)
      ..lineTo(20, -45)
      ..lineTo(60, -90)
      ..lineTo(100, -55)
      ..lineTo(140, -20)
      ..lineTo(0, 30)
      ..close();
    canvas.drawPath(
        top,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A4150), Color(0xFF1A1F28)],
          ).createShader(const Rect.fromLTWH(-140, -90, 280, 120)));
    canvas.drawPath(
        top,
        Paint()
          ..color = const Color(0xFF3A4150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeJoin = StrokeJoin.round);

    // Ridge highlights.
    final ridge = Paint()
      ..color = const Color(0x995A6470)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(-90, -65), const Offset(-20, -85), ridge);
    canvas.drawLine(const Offset(20, -45), const Offset(60, -90), ridge);
    canvas.drawLine(
        const Offset(-55, -30),
        const Offset(20, -45),
        Paint()
          ..color = const Color(0x665A6470)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Snow caps.
    final snow = Paint()..color = const Color(0xD9EEF1F4);
    canvas.drawPath(
        Path()
          ..moveTo(56, -82)
          ..lineTo(60, -90)
          ..lineTo(64, -82)
          ..close(),
        snow);
    canvas.drawPath(
        Path()
          ..moveTo(-23, -78)
          ..lineTo(-20, -85)
          ..lineTo(-16, -78)
          ..close(),
        snow);

    // Trail traced over terrain (animated draw).
    final trail = Path()
      ..moveTo(-110, 20)
      ..quadraticBezierTo(-60, -10, -20, -10)
      ..quadraticBezierTo(30, -20, 60, -50)
      ..lineTo(60, -85);
    _drawPathTrim(
        canvas,
        trail,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
        _sub(0.0, 0.55));

    // Speed-coloured dots (anim-pop).
    final dots = [
      (-90.0, 14.0, TT.blue),
      (-50.0, -3.0, TT.blue),
      (-15.0, -9.0, TT.ember2),
      (25.0, -25.0, TT.ember),
      (55.0, -65.0, TT.ember),
    ];
    for (var i = 0; i < dots.length; i++) {
      final (x, y, c) = dots[i];
      final start = 0.35 + i * 0.04;
      final popT = _sub(start, start + 0.18);
      if (popT > 0) {
        // Overshoot scale: 0 -> 1.15 -> 1.
        final s = popT < 0.7
            ? (popT / 0.7) * 1.15
            : 1.15 - ((popT - 0.7) / 0.3) * 0.15;
        canvas.drawCircle(Offset(x, y), 2.4 * s, Paint()..color = c);
      }
    }
    canvas.restore();

    // Compass -----------------------------------------------------------
    canvas.save();
    canvas.translate(330, 80);
    canvas.drawCircle(Offset.zero, 44,
        Paint()..color = const Color(0xF20A0C0F));
    canvas.drawCircle(
        Offset.zero,
        44,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.drawCircle(
        Offset.zero,
        38,
        Paint()
          ..color = const Color(0xFF1C2127)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    // Ticks.
    for (var i = 0; i < 24; i++) {
      final a = i * 15 * math.pi / 180;
      const r1 = 32.0;
      final r2 = i % 6 == 0 ? 26.0 : 30.0;
      final isMajor = i % 6 == 0;
      canvas.drawLine(
          Offset(math.sin(a) * r1, -math.cos(a) * r1),
          Offset(math.sin(a) * r2, -math.cos(a) * r2),
          Paint()
            ..color = isMajor ? TT.ember2 : const Color(0xFF5A6470)
            ..strokeWidth = isMajor ? 1.5 : 0.8);
    }
    // Cardinal labels.
    _drawText(canvas,
        text: 'N',
        center: const Offset(0, -18),
        color: TT.ember2,
        fontFamily: 'Manrope',
        size: 9,
        weight: FontWeight.w800,
        letterSpacing: 0.12 * 9);
    _drawText(canvas,
        text: 'E',
        center: const Offset(18, 3),
        color: const Color(0xFF5A6470),
        fontFamily: 'Manrope',
        size: 8,
        weight: FontWeight.w700);
    _drawText(canvas,
        text: 'S',
        center: const Offset(0, 22),
        color: const Color(0xFF5A6470),
        fontFamily: 'Manrope',
        size: 8,
        weight: FontWeight.w700);
    _drawText(canvas,
        text: 'W',
        center: const Offset(-18, 3),
        color: const Color(0xFF5A6470),
        fontFamily: 'Manrope',
        size: 8,
        weight: FontWeight.w700);
    // Needle.
    canvas.save();
    canvas.rotate(needleDeg * math.pi / 180);
    canvas.drawPath(
        Path()
          ..moveTo(0, -22)
          ..lineTo(4, 0)
          ..lineTo(0, 4)
          ..lineTo(-4, 0)
          ..close(),
        Paint()..color = TT.ember);
    canvas.drawPath(
        Path()
          ..moveTo(0, 22)
          ..lineTo(4, 0)
          ..lineTo(0, -4)
          ..lineTo(-4, 0)
          ..close(),
        Paint()..color = const Color(0xFF3A4150));
    canvas.restore();
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = TT.emberInk);
    canvas.drawCircle(
        Offset.zero,
        2.5,
        Paint()
          ..color = TT.ember2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.restore();

    // Layer toggle chip -------------------------------------------------
    final chipT = _sub(0.3, 0.6);
    if (chipT > 0) {
      canvas.save();
      canvas.translate(62, 272 + (1 - chipT) * 6);
      final chip = RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 170, 36), const Radius.circular(10));
      canvas.drawRRect(
          chip, Paint()..color = TT.surf.withOpacity(chipT));
      canvas.drawRRect(
          chip,
          Paint()
            ..color = const Color(0xFF1C2127).withOpacity(chipT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      const labels = ['2D', '3D', 'SAT'];
      for (var i = 0; i < labels.length; i++) {
        final active = i == 1;
        final tab = RRect.fromRectAndRadius(
            Rect.fromLTWH(10.0 + i * 53, 6, 48, 24), const Radius.circular(7));
        if (active) {
          canvas.drawRRect(tab,
              Paint()..color = TT.emberDim.withOpacity(chipT));
          canvas.drawRRect(
              tab,
              Paint()
                ..color = TT.ember.withOpacity(0.4 * chipT)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
        }
        _drawText(canvas,
            text: labels[i],
            center: Offset(10.0 + i * 53 + 24, 18),
            color: (active ? TT.ember2 : TT.text2)
                .withOpacity(chipT),
            fontFamily: 'Manrope',
            size: 10,
            weight: FontWeight.w800,
            letterSpacing: 0.12 * 10);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_NavigatePainter old) =>
      old.t != t || old.needleDeg != needleDeg;
}

// =========================== SCENE 4 - STAY AWARE =========================
// Weather card with sun + drifting cloud + wind lines, hazard pin, shelter
// pin, and a floating "Storm in 90 min" alert.

class _SceneAware extends StatefulWidget {
  const _SceneAware();
  @override
  State<_SceneAware> createState() => _SceneAwareState();
}

class _SceneAwareState extends State<_SceneAware>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  late final AnimationController _cloud =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat(reverse: true);
  late final AnimationController _sunPulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);
  late final AnimationController _hazard = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);
  late final AnimationController _alert = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _entry.dispose();
    _cloud.dispose();
    _sunPulse.dispose();
    _hazard.dispose();
    _alert.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_entry, _cloud, _sunPulse, _hazard, _alert]),
      builder: (_, __) => _sceneFit(_AwarePainter(
        entryT: _entry.value,
        cloudT: _cloud.value,
        sunT: _sunPulse.value,
        hazardT: _hazard.value,
        alertT: _alert.value,
      )),
    );
  }
}

class _AwarePainter extends CustomPainter {
  final double entryT, cloudT, sunT, hazardT, alertT;
  _AwarePainter({
    required this.entryT,
    required this.cloudT,
    required this.sunT,
    required this.hazardT,
    required this.alertT,
  });

  double _sub(double s, double e) => ((entryT - s) / (e - s)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    // Weather card -----------------------------------------------------
    canvas.save();
    canvas.translate(50, 40);
    final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 312, 120), const Radius.circular(14));
    canvas.drawRRect(card, Paint()..color = TT.surf);
    canvas.drawRRect(
        card,
        Paint()
          ..color = const Color(0xFF1C2127)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Sun + rays.
    canvas.save();
    canvas.translate(60, 60);
    canvas.drawCircle(
        Offset.zero,
        22,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFB486), TT.ember],
          ).createShader(const Rect.fromLTWH(-22, -22, 44, 44)));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final wave = math.sin(sunT * _twoPi + i * 0.4);
      final op = (0.4 + 0.6 * (wave * 0.5 + 0.5)).clamp(0.0, 1.0);
      canvas.drawLine(
          Offset(math.cos(a) * 28, math.sin(a) * 28),
          Offset(math.cos(a) * 38, math.sin(a) * 38),
          Paint()
            ..color = TT.ember2.withOpacity(op)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();

    // Drifting cloud.
    canvas.save();
    final cloudDx = (Curves.easeInOut.transform(cloudT) - 0.5) * 24;
    canvas.translate(cloudDx, 0);
    final cloudPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A4150), Color(0xFF1C2127)],
      ).createShader(const Rect.fromLTWH(110, 40, 70, 30));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(135, 58), width: 44, height: 28),
        cloudPaint);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(155, 62), width: 36, height: 24),
        cloudPaint);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(145, 50), width: 28, height: 20),
        cloudPaint);
    canvas.restore();

    // Wind lines.
    for (var i = 0; i < 3; i++) {
      final pulse = (math.sin(sunT * _twoPi + i * 0.5) * 0.5 + 0.5).clamp(0.0, 1.0);
      final op = 0.3 + 0.5 * pulse;
      canvas.drawLine(
          Offset(110, 82 + i * 8.0),
          Offset(110 + (24 - i * 4).toDouble(), 82 + i * 8.0),
          Paint()
            ..color = const Color(0xFF5A6470).withOpacity(op)
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round);
    }

    // Right-side stats.
    _drawText(canvas,
        text: 'CONDITIONS',
        topLeft: const Offset(200, 28),
        color: TT.text3,
        fontFamily: 'Manrope',
        size: 9,
        weight: FontWeight.w800,
        letterSpacing: 0.16 * 9);
    _drawText(canvas,
        text: '14',
        topLeft: const Offset(200, 44),
        color: TT.text,
        fontFamily: 'JetBrainsMono',
        size: 22,
        weight: FontWeight.w800);
    _drawText(canvas,
        text: 'WIND 18 KM/H',
        topLeft: const Offset(200, 72),
        color: TT.text2,
        fontFamily: 'JetBrainsMono',
        size: 10,
        weight: FontWeight.w700);
    _drawText(canvas,
        text: 'HIKE SCORE  8/10',
        topLeft: const Offset(200, 88),
        color: TT.amber,
        fontFamily: 'JetBrainsMono',
        size: 10,
        weight: FontWeight.w800,
        letterSpacing: 0.06 * 10);
    canvas.restore();

    // Hazard pin -------------------------------------------------------
    canvas.save();
    canvas.translate(50, 180);
    final hazardCard = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 150, 64), const Radius.circular(12));
    canvas.drawRRect(hazardCard, Paint()..color = TT.surf);
    canvas.drawRRect(
        hazardCard,
        Paint()
          ..color = TT.amber.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 3, 64),
        Paint()..color = TT.amber);
    // Pulsing icon halo.
    final hr = 11 + 4 * hazardT;
    canvas.save();
    canvas.translate(20, 18);
    canvas.drawCircle(
        Offset.zero, hr, Paint()..color = TT.amber.withOpacity(0.15));
    canvas.drawCircle(
        Offset.zero,
        hr,
        Paint()
          ..color = TT.amber.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawPath(
        Path()
          ..moveTo(0, -6)
          ..lineTo(6, 6)
          ..lineTo(-6, 6)
          ..close(),
        Paint()
          ..color = TT.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round);
    canvas.drawLine(
        const Offset(0, -2),
        const Offset(0, 2),
        Paint()
          ..color = TT.amber
          ..strokeWidth = 1.5);
    canvas.drawCircle(const Offset(0, 4), 0.8, Paint()..color = TT.amber);
    canvas.restore();
    _drawText(canvas,
        text: 'Loose rock',
        topLeft: const Offset(44, 14),
        color: TT.text,
        fontFamily: 'Manrope',
        size: 11,
        weight: FontWeight.w800);
    _drawText(canvas,
        text: '320m ahead',
        topLeft: const Offset(44, 30),
        color: TT.text2,
        fontFamily: 'JetBrainsMono',
        size: 9,
        weight: FontWeight.w700);
    _drawText(canvas,
        text: 'REPORTED 18m',
        topLeft: const Offset(44, 44),
        color: TT.amber,
        fontFamily: 'JetBrainsMono',
        size: 8,
        weight: FontWeight.w800,
        letterSpacing: 0.12 * 8);
    canvas.restore();

    // Shelter pin ------------------------------------------------------
    canvas.save();
    canvas.translate(212, 180);
    final shelterCard = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 150, 64), const Radius.circular(12));
    canvas.drawRRect(shelterCard, Paint()..color = TT.surf);
    canvas.drawRRect(
        shelterCard,
        Paint()
          ..color = TT.green.withOpacity(0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 3, 64),
        Paint()..color = TT.green);
    canvas.save();
    canvas.translate(20, 18);
    canvas.drawCircle(
        Offset.zero, 13, Paint()..color = TT.green.withOpacity(0.13));
    canvas.drawCircle(
        Offset.zero,
        13,
        Paint()
          ..color = TT.green.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawPath(
        Path()
          ..moveTo(-7, 5)
          ..lineTo(0, -6)
          ..lineTo(7, 5)
          ..lineTo(5, 5)
          ..lineTo(5, 8)
          ..lineTo(-5, 8)
          ..lineTo(-5, 5)
          ..close(),
        Paint()
          ..color = TT.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
    _drawText(canvas,
        text: 'Shelter',
        topLeft: const Offset(44, 14),
        color: TT.text,
        fontFamily: 'Manrope',
        size: 11,
        weight: FontWeight.w800);
    _drawText(canvas,
        text: 'Cave  1.2 km',
        topLeft: const Offset(44, 30),
        color: TT.text2,
        fontFamily: 'JetBrainsMono',
        size: 9,
        weight: FontWeight.w700);
    _drawText(canvas,
        text: 'DRAKENSBERG #47',
        topLeft: const Offset(44, 44),
        color: TT.green,
        fontFamily: 'JetBrainsMono',
        size: 8,
        weight: FontWeight.w800,
        letterSpacing: 0.12 * 8);
    canvas.restore();

    // Floating storm alert (anim-up) -----------------------------------
    final alertEntry = _sub(0.2, 0.6);
    if (alertEntry > 0) {
      canvas.save();
      canvas.translate(50, 272 + (1 - alertEntry) * 8);
      final alertCard = RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 312, 34), const Radius.circular(10));
      canvas.drawRRect(
          alertCard, Paint()..color = TT.surf.withOpacity(alertEntry));
      canvas.drawRRect(
          alertCard,
          Paint()
            ..color = TT.ember.withOpacity(0.32 * alertEntry)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // Pulsing red dot.
      final dr = 4 + 3 * alertT;
      canvas.drawCircle(
          const Offset(18, 17),
          dr,
          Paint()
            ..color = TT.ember
                .withOpacity((1 - 0.6 * alertT) * alertEntry));
      _drawText(canvas,
          text: 'Storm in 90 min',
          topLeft: const Offset(34, 6),
          color: TT.text.withOpacity(alertEntry),
          fontFamily: 'Manrope',
          size: 10,
          weight: FontWeight.w800,
          letterSpacing: 0.02 * 10);
      _drawText(canvas,
          text: 'Consider shelter at km 5.8',
          topLeft: const Offset(34, 20),
          color: TT.text2.withOpacity(alertEntry),
          fontFamily: 'JetBrainsMono',
          size: 8.5,
          weight: FontWeight.w700);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AwarePainter old) =>
      old.entryT != entryT ||
      old.cloudT != cloudT ||
      old.sunT != sunT ||
      old.hazardT != hazardT ||
      old.alertT != alertT;
}

// =========================== SCENE 5 - SOS ================================
// Pulsing red beacon orb with three concentric ripples, transmitting label,
// and dispatched-rescue chip.

class _SceneSOS extends StatefulWidget {
  const _SceneSOS();
  @override
  State<_SceneSOS> createState() => _SceneSOSState();
}

class _SceneSOSState extends State<_SceneSOS>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final List<AnimationController> _ripples = List.generate(
    3,
    (_) => AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    ),
  );

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _ripples.length; i++) {
      final c = _ripples[i];
      Future.delayed(Duration(milliseconds: i * 1000), () {
        if (mounted) c.repeat();
      });
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    for (final c in _ripples) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entry, ..._ripples]),
      builder: (_, __) => _sceneFit(_SOSPainter(
        entryT: _entry.value,
        ripple1: _ripples[0].value,
        ripple2: _ripples[1].value,
        ripple3: _ripples[2].value,
      )),
    );
  }
}

class _SOSPainter extends CustomPainter {
  final double entryT, ripple1, ripple2, ripple3;
  _SOSPainter({
    required this.entryT,
    required this.ripple1,
    required this.ripple2,
    required this.ripple3,
  });

  double _sub(double s, double e) => ((entryT - s) / (e - s)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    // Three concentric ripples - radius 60 -> 160, opacity 0.9 -> 0.
    for (final t in [ripple1, ripple2, ripple3]) {
      final r = 60 + 100 * t;
      final op = (0.9 - 0.9 * t).clamp(0.0, 1.0);
      canvas.drawCircle(
          const Offset(206, 160),
          r,
          Paint()..color = TT.red.withOpacity(0.06 * op));
      canvas.drawCircle(
          const Offset(206, 160),
          r,
          Paint()
            ..color = TT.ember.withOpacity(0.4 * op)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Soft glow under orb.
    canvas.drawCircle(
        const Offset(206, 160),
        80,
        Paint()
          ..color = TT.ember.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Orb pop animation.
    final popT = _sub(0.10, 0.55);
    final s = popT < 0.7 ? (popT / 0.7) * 1.15 : 1.15 - ((popT - 0.7) / 0.3) * 0.15;
    canvas.save();
    canvas.translate(206, 160);
    canvas.scale(s);
    canvas.drawCircle(
        Offset.zero,
        58,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            radius: 0.7,
            colors: [Color(0xFFFF6A4D), Color(0xFFD6291F), Color(0xFF82120C)],
            stops: [0.0, 0.6, 1.0],
          ).createShader(const Rect.fromLTWH(-58, -58, 116, 116)));
    canvas.drawCircle(
        Offset.zero,
        58,
        Paint()
          ..color = const Color(0xFFFF966C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.restore();

    if (popT > 0.4) {
      _drawText(canvas,
          text: 'SOS',
          center: const Offset(206, 158),
          color: Colors.white,
          fontFamily: 'Manrope',
          size: 32,
          weight: FontWeight.w900,
          letterSpacing: 0.1 * 32);
      _drawText(canvas,
          text: 'ACTIVE',
          center: const Offset(206, 184),
          color: const Color(0xFFFFD5C4),
          fontFamily: 'Manrope',
          size: 8.5,
          weight: FontWeight.w800,
          letterSpacing: 0.24 * 8.5);
    }

    // Top transmitting label (anim-in).
    final topT = _sub(0.30, 0.65);
    if (topT > 0) {
      canvas.save();
      canvas.translate(0, (1 - topT) * 6);
      _drawText(canvas,
          text: 'TRANSMITTING  00:14',
          center: const Offset(206, 40),
          color: TT.text3.withOpacity(topT),
          fontFamily: 'JetBrainsMono',
          size: 9,
          weight: FontWeight.w800,
          letterSpacing: 0.18 * 9);
      _drawText(canvas,
          text: 'N 47.6062  W 122.3321',
          center: const Offset(206, 56),
          color: TT.text.withOpacity(topT),
          fontFamily: 'JetBrainsMono',
          size: 13,
          weight: FontWeight.w800);
      canvas.restore();
    }

    // Dispatch chip (anim-up).
    final chipT = _sub(0.45, 0.95);
    if (chipT > 0) {
      canvas.save();
      canvas.translate(206, 278 + (1 - chipT) * 8);
      final chipRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-92, -16, 184, 32), const Radius.circular(9));
      canvas.drawRRect(
          chipRect, Paint()..color = TT.surf.withOpacity(chipT));
      canvas.drawRRect(
          chipRect,
          Paint()
            ..color = TT.amber.withOpacity(0.4 * chipT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // Shield glyph.
      canvas.save();
      canvas.translate(-72, 0);
      canvas.drawCircle(
          Offset.zero, 9, Paint()..color = TT.amber.withOpacity(0.16 * chipT));
      canvas.drawCircle(
          Offset.zero,
          9,
          Paint()
            ..color = TT.amber.withOpacity(0.45 * chipT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawPath(
          Path()
            ..moveTo(0, -4)
            ..lineTo(5, -1)
            ..lineTo(5, 4)
            ..cubicTo(5, 6, 3, 7, 0, 8)
            ..cubicTo(-3, 7, -5, 6, -5, 4)
            ..lineTo(-5, -1)
            ..close(),
          Paint()
            ..color = TT.amber.withOpacity(chipT)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
      _drawText(canvas,
          text: 'Rescue Team #4 dispatched',
          topLeft: const Offset(-58, -10),
          color: TT.text.withOpacity(chipT),
          fontFamily: 'Manrope',
          size: 10.5,
          weight: FontWeight.w800);
      _drawText(canvas,
          text: 'ETA 4 MIN  620 m NW',
          topLeft: const Offset(-58, 4),
          color: TT.amber.withOpacity(chipT),
          fontFamily: 'JetBrainsMono',
          size: 9,
          weight: FontWeight.w800,
          letterSpacing: 0.12 * 9);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SOSPainter old) =>
      old.entryT != entryT ||
      old.ripple1 != ripple1 ||
      old.ripple2 != ripple2 ||
      old.ripple3 != ripple3;
}

// =============================== PAINT HELPERS ============================

const double _twoPi = math.pi * 2;

void _drawDashed(
  Canvas canvas,
  Path src, {
  required Paint paint,
  required double dashOn,
  required double dashOff,
  double offset = 0,
}) {
  for (final m in src.computeMetrics()) {
    double dist = offset % (dashOn + dashOff);
    if (dist < 0) dist += dashOn + dashOff;
    // Skip the leading partial gap.
    if (dist < dashOn) {
      canvas.drawPath(m.extractPath(0, dashOn - dist), paint);
      dist = dashOn - dist + dashOff;
    } else {
      dist = (dashOn + dashOff) - dist;
    }
    while (dist < m.length) {
      final next = math.min(dist + dashOn, m.length);
      canvas.drawPath(m.extractPath(dist, next), paint);
      dist = next + dashOff;
    }
  }
}

void _drawPathTrim(Canvas canvas, Path src, Paint paint, double t) {
  if (t <= 0) return;
  for (final m in src.computeMetrics()) {
    canvas.drawPath(m.extractPath(0, m.length * t), paint);
  }
}

void _drawText(
  Canvas canvas, {
  required String text,
  Offset? center,
  Offset? topLeft,
  required Color color,
  required String fontFamily,
  required double size,
  required FontWeight weight,
  double letterSpacing = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  if (center != null) {
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  } else if (topLeft != null) {
    tp.paint(canvas, topLeft);
  }
}
