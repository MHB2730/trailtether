// Trailtether 2.0 — Safety Center screen.
//
// Recreates project/screens/safety.jsx from the design bundle: an active-plan
// card with a check-in countdown, a big hold-3-seconds SOS button with
// concentric ember pulses, an emergency contacts list, an animated gear
// checklist, and a "tether" visualization between the hiker and base camp
// with data dots travelling along the connection.
//
// Placeholder data only — no provider wiring, no callbacks fired.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class TTSafetyScreen extends StatefulWidget {
  final bool embedded;
  const TTSafetyScreen({super.key, this.embedded = false});

  @override
  State<TTSafetyScreen> createState() => _TTSafetyScreenState();
}

class _TTSafetyScreenState extends State<TTSafetyScreen> {
  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop(opacity: 0.5)),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            children: [
              TTPageAppBar(
                title: 'Safety Center',
                trailing: [
                  TTIconBtn(icon: Icons.radio, ember: true, onTap: () {}),
                ],
              ),
              const Expanded(child: _SafetyBody()),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

class _SafetyBody extends StatelessWidget {
  const _SafetyBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: const [
        _FadeUpDelayed(
          delay: Duration(milliseconds: 80),
          child: _ActivePlanCard(),
        ),
        SizedBox(height: 14),
        _FadeUpDelayed(
          delay: Duration(milliseconds: 220),
          child: _BigSosButton(),
        ),
        SizedBox(height: 18),
        _FadeUpDelayed(
          delay: Duration(milliseconds: 380),
          child: _EmergencyContacts(),
        ),
        SizedBox(height: 18),
        _FadeUpDelayed(
          delay: Duration(milliseconds: 500),
          child: _GearChecklist(),
        ),
        SizedBox(height: 18),
        _FadeUpDelayed(
          delay: Duration(milliseconds: 620),
          child: _BaseCampTether(),
        ),
      ],
    );
  }
}

// ──────────────────────────── ACTIVE PLAN CARD ──────────────────────────────

class _ActivePlanCard extends StatefulWidget {
  const _ActivePlanCard();

  @override
  State<_ActivePlanCard> createState() => _ActivePlanCardState();
}

class _ActivePlanCardState extends State<_ActivePlanCard>
    with SingleTickerProviderStateMixin {
  // Total trip duration: 6 hours. Check-in expected at 47 min 23 sec from now.
  static const _totalSeconds = 6 * 3600;
  static const _checkInRemaining = 47 * 60 + 23;
  // Time elapsed = total - remainingForCheckin spread across the journey.
  static const _elapsed = _totalSeconds - _checkInRemaining - 1800;

  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: TT.dDraw);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _countdown {
    const m = _checkInRemaining ~/ 60;
    const s = _checkInRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const progress = _elapsed / _totalSeconds;
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              TTPill(label: 'ACTIVE PLAN', variant: TTPillVariant.live),
              SizedBox(width: 8),
              TTPill(label: 'TETHERED', variant: TTPillVariant.ember),
            ],
          ),
          const SizedBox(height: 12),
          Text('Mt. Marcy Summit Trail',
              style: TT.title(17, letterSpacing: -0.01 * 17)),
          const SizedBox(height: 4),
          Text('EXPECTED RETURN  ·  OCT 28  ·  19:00',
              style: TT.mono(size: 10.5, color: TT.text3, letterSpacing: 0.04 * 10.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: TT.ember,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x80FF6A2C), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('CHECK-IN IN',
                  style: TT.label(size: 10.5, color: TT.text2, letterSpacing: 0.16 * 10.5)),
              const SizedBox(width: 6),
              Text(_countdown,
                  style: TT.numStyle(size: 14, color: TT.ember, letterSpacing: -0.01 * 14)),
            ],
          ),
          const SizedBox(height: 10),
          // Hairline progress bar — animates to the elapsed fraction once.
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, __) {
              final t = TT.easeOut.transform(_ctl.value);
              return ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  children: [
                    Container(height: 3, color: TT.surf2),
                    FractionallySizedBox(
                      widthFactor: (progress * t).clamp(0.0, 1.0),
                      child: Container(
                        height: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [TT.ember, TT.ember2],
                          ),
                          boxShadow: [
                            BoxShadow(color: Color(0x66FF6A2C), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── BIG SOS BUTTON ───────────────────────────────

class _BigSosButton extends StatefulWidget {
  const _BigSosButton();

  @override
  State<_BigSosButton> createState() => _BigSosButtonState();
}

class _BigSosButtonState extends State<_BigSosButton>
    with TickerProviderStateMixin {
  // Hold progress: ticks 0 → 1 over 3 seconds while user holds.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  // Activation snap — runs briefly after a successful 3s hold.
  late final AnimationController _activation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _isHolding = false;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_activated) {
        setState(() => _activated = true);
        _activation.forward(from: 0).whenComplete(() {
          if (!mounted) return;
          setState(() {
            _activated = false;
            _isHolding = false;
          });
          _hold.reset();
        });
      }
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    _activation.dispose();
    super.dispose();
  }

  void _onDown() {
    if (_activated) return;
    setState(() => _isHolding = true);
    _hold.forward(from: 0);
  }

  void _onRelease() {
    if (_activated) return;
    setState(() => _isHolding = false);
    // If not yet complete, snap the arc back to zero.
    if (_hold.status != AnimationStatus.completed) {
      _hold.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 0.6,
          colors: [Color(0x29E63D2E), Color(0x00E63D2E)],
        ),
        borderRadius: BorderRadius.circular(TT.rXl),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ember rings — fade when activated.
                AnimatedOpacity(
                  duration: TT.dMed,
                  opacity: _activated ? 0.0 : 1.0,
                  child: const TTPulseRings(size: 240, color: TT.ember, rings: 3),
                ),
                // Outer ring + 3-second hold arc.
                AnimatedBuilder(
                  animation: Listenable.merge([_hold, _activation]),
                  builder: (_, __) {
                    return CustomPaint(
                      size: const Size(240, 240),
                      painter: _SosHoldArcPainter(
                        progress: _hold.value,
                        active: _activated,
                        activationT: _activation.value,
                      ),
                    );
                  },
                ),
                // Inner ember-gradient disc.
                AnimatedScale(
                  scale: _activated
                      ? 1.06
                      : (_isHolding ? 0.96 : 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _onDown(),
                    onTapUp: (_) => _onRelease(),
                    onTapCancel: _onRelease,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          radius: 0.95,
                          colors: [
                            Color(0xFFFF8A4D),
                            Color(0xFFD6291F),
                            Color(0xFF82120C),
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xA6FF6A2C),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0x66000000),
                            offset: Offset(0, -6),
                            blurRadius: 14,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: TT.dFast,
                        child: _activated
                            ? Column(
                                key: const ValueKey('on'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('ACTIVATED',
                                      style: TT.body(
                                        size: 14,
                                        w: FontWeight.w900,
                                        color: Colors.white,
                                      ).copyWith(letterSpacing: 0.18 * 14)),
                                  const SizedBox(height: 4),
                                  Text('BROADCASTING',
                                      style: TT.mono(
                                        size: 9,
                                        color: const Color(0xFFFFD5C4),
                                        letterSpacing: 0.22 * 9,
                                      )),
                                ],
                              )
                            : Column(
                                key: const ValueKey('off'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('SOS',
                                      style: TT.title(30,
                                              color: Colors.white,
                                              letterSpacing: 0.1 * 30)
                                          .copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Text('HOLD 3s',
                                      style: TT.mono(
                                        size: 9,
                                        color: const Color(0xFFFFD5C4),
                                        letterSpacing: 0.22 * 9,
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Press and hold to broadcast your location and trigger emergency response.',
            textAlign: TextAlign.center,
            style: TT.body(size: 12, color: TT.text2),
          ),
        ],
      ),
    );
  }
}

class _SosHoldArcPainter extends CustomPainter {
  final double progress; // 0..1
  final bool active;
  final double activationT; // 0..1 during activation snap
  _SosHoldArcPainter({
    required this.progress,
    required this.active,
    required this.activationT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 6;
    final center = Offset(size.width / 2, size.height / 2);

    // Static thin track behind the arc — outer ring of the dial.
    final track = Paint()
      ..color = const Color(0x33FF6A2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, track);

    if (progress > 0.001) {
      final arc = Paint()
        ..shader = const SweepGradient(
          colors: [TT.ember, TT.ember2, TT.ember],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      // Start at the top (−π/2) and sweep clockwise.
      const start = -math.pi / 2;
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        sweep,
        false,
        arc,
      );
    }

    // Activation flash — a bright expanding halo immediately after a
    // completed 3-second hold.
    if (active && activationT > 0) {
      final t = activationT;
      final flashR = r + 8 + 30 * t;
      final flash = Paint()
        ..color = TT.ember.withOpacity(((1 - t).clamp(0.0, 1.0)) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - t).clamp(0.2, 1.0);
      canvas.drawCircle(center, flashR, flash);
    }
  }

  @override
  bool shouldRepaint(_SosHoldArcPainter old) =>
      old.progress != progress ||
      old.active != active ||
      old.activationT != activationT;
}

// ──────────────────────────── EMERGENCY CONTACTS ────────────────────────────

class _EmergencyContacts extends StatelessWidget {
  const _EmergencyContacts();

  @override
  Widget build(BuildContext context) {
    final contacts = <_ContactEntry>[
      const _ContactEntry(
        initials: 'SD',
        name: 'Sarah Davies',
        relationship: 'Spouse',
        number: '+27 82 123 4567',
      ),
      const _ContactEntry(
        initials: 'JC',
        name: 'James Carter',
        relationship: 'Hiking partner',
        number: '+27 71 987 6543',
      ),
      const _ContactEntry(
        initials: 'MR',
        name: 'MSAR · Mountain Rescue',
        relationship: '24/7 · Drakensberg',
        number: '074 125 1385',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EMERGENCY CONTACTS',
                  style: TT.label(
                      size: 11, color: TT.text2, letterSpacing: 0.16 * 11)),
              Text('EDIT →',
                  style: TT.body(size: 10, w: FontWeight.w800, color: TT.ember)
                      .copyWith(letterSpacing: 0.1 * 10)),
            ],
          ),
        ),
        TTCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(contacts.length, (i) {
              final c = contacts[i];
              return _ContactRow(
                entry: c,
                isLast: i == contacts.length - 1,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ContactEntry {
  final String initials;
  final String name;
  final String relationship;
  final String number;
  const _ContactEntry({
    required this.initials,
    required this.name,
    required this.relationship,
    required this.number,
  });
}

class _ContactRow extends StatelessWidget {
  final _ContactEntry entry;
  final bool isLast;
  const _ContactRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : TT.line,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          // Gradient avatar disc.
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B3A1A), TT.ember2],
              ),
              boxShadow: [
                BoxShadow(color: Color(0x66FF6A2C), blurRadius: 12),
              ],
            ),
            alignment: Alignment.center,
            child: Text(entry.initials,
                style: TT.body(
                    size: 12, w: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: TT.body(size: 13.5, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(entry.relationship.toUpperCase(),
                    style: TT.mono(size: 10, color: TT.text3,
                        letterSpacing: 0.06 * 10)),
                const SizedBox(height: 4),
                Text(entry.number,
                    style: TT.mono(size: 11, color: TT.text2)),
              ],
            ),
          ),
          // Ember call icon button.
          _CallIconButton(onTap: () {}),
        ],
      ),
    );
  }
}

class _CallIconButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CallIconButton({required this.onTap});

  @override
  State<_CallIconButton> createState() => _CallIconButtonState();
}

class _CallIconButtonState extends State<_CallIconButton> {
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
        scale: _down ? 0.94 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [TT.ember2, TT.ember],
            ),
            boxShadow: [
              BoxShadow(color: Color(0x73FF6A2C), blurRadius: 14),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.phone, color: TT.emberInk, size: 18),
        ),
      ),
    );
  }
}

// ────────────────────────────── GEAR CHECKLIST ──────────────────────────────

class _GearChecklist extends StatefulWidget {
  const _GearChecklist();

  @override
  State<_GearChecklist> createState() => _GearChecklistState();
}

class _GearChecklistState extends State<_GearChecklist> {
  // Eight items per spec — 6 ticked initially.
  static const _items = <String>[
    'Headlamp',
    'Water',
    'Map',
    'First-aid',
    'Whistle',
    'Layers',
    'Compass',
    'Spare batteries',
  ];
  late final List<bool> _done = [
    true, true, true, true, true, true, false, false,
  ];

  int get _completed => _done.where((d) => d).length;

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final ready = _completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GEAR CHECKLIST',
                  style: TT.label(
                      size: 11, color: TT.text2, letterSpacing: 0.16 * 11)),
              Text('$ready of $total ready',
                  style: TT.mono(size: 11, color: TT.ember)),
            ],
          ),
        ),
        TTCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...List.generate(_items.length, (i) {
                return _ChecklistRow(
                  label: _items[i],
                  done: _done[i],
                  isLast: i == _items.length - 1,
                  onToggle: () => setState(() => _done[i] = !_done[i]),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _ProgressBar(value: ready / total),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;
  final VoidCallback onToggle;
  const _ChecklistRow({
    required this.label,
    required this.done,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : TT.line,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: TT.dFast,
              curve: Curves.easeOut,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? TT.ember : Colors.transparent,
                border: Border.all(
                  color: done ? TT.ember : TT.line3,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: done
                    ? const [
                        BoxShadow(color: Color(0x66FF6A2C), blurRadius: 10),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check,
                      size: 14, color: TT.emberInk)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: TT.dFast,
                style: TT.body(
                  size: 13,
                  w: FontWeight.w700,
                  color: done ? TT.text : TT.text2,
                ).copyWith(
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: TT.text3,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value; // 0..1
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 4, color: TT.surf2),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TT.ember, TT.ember2],
                      ),
                      boxShadow: [
                        BoxShadow(color: Color(0x66FF6A2C), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${(value * 100).round()}%',
            style: TT.mono(size: 12, color: TT.ember, w: FontWeight.w800)),
      ],
    );
  }
}

// ──────────────────────────── BASE CAMP · TETHER ────────────────────────────

class _BaseCampTether extends StatefulWidget {
  const _BaseCampTether();

  @override
  State<_BaseCampTether> createState() => _BaseCampTetherState();
}

class _BaseCampTetherState extends State<_BaseCampTether>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Text('BASE CAMP · TETHER',
              style: TT.label(
                  size: 11, color: TT.text2, letterSpacing: 0.16 * 11)),
        ),
        TTCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (_, __) => CustomPaint(
                    painter: _TetherPainter(t: _ctl.value),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Home · Sarah's PC",
                            style: TT.body(size: 13, w: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('PAIRED 14 DAYS  ·  LAST SYNC 2 MIN AGO',
                            style: TT.mono(
                                size: 10,
                                color: TT.text3,
                                letterSpacing: 0.06 * 10)),
                      ],
                    ),
                  ),
                  const TTPill(
                    label: 'CONNECTED',
                    variant: TTPillVariant.live,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TetherPainter extends CustomPainter {
  final double t; // 0..1 looping
  _TetherPainter({required this.t});

  static const _emberDot = Color(0xFFFF8A4D);
  static const _greenDot = Color(0xFF4CC38A);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final cy = h / 2;

    // Two end discs.
    const discR = 18.0;
    final youCenter = Offset(discR + 4, cy);
    final baseCenter = Offset(w - discR - 4, cy);

    // Tether line — ember on the hiker side, faint mid, green at base.
    final lineRect = Rect.fromLTRB(
      youCenter.dx + discR + 6,
      cy - 1,
      baseCenter.dx - discR - 6,
      cy + 1,
    );
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [TT.ember, TT.line3, TT.green],
        stops: [0.0, 0.5, 1.0],
      ).createShader(lineRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect, const Radius.circular(1)),
      linePaint,
    );

    // Travelling data dots — three ember dots offset along time.
    void drawTravelDot(double phase, Color color, {bool reverse = false}) {
      final p = ((t + phase) % 1.0);
      // Fade in/out around the edges of the travel.
      final fade = p < 0.1
          ? p / 0.1
          : (p > 0.9 ? (1 - p) / 0.1 : 1.0);
      double frac = p;
      if (reverse) frac = 1.0 - p;
      final x = lineRect.left + frac * lineRect.width;
      final paint = Paint()
        ..color = color.withOpacity(fade.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(Offset(x, cy), 3.5, paint);
      canvas.drawCircle(
        Offset(x, cy),
        2.4,
        Paint()..color = color.withOpacity(fade.clamp(0.0, 1.0)),
      );
    }

    drawTravelDot(0.00, _emberDot);
    drawTravelDot(0.35, _emberDot);
    drawTravelDot(0.18, _greenDot, reverse: true);
    drawTravelDot(0.72, _greenDot, reverse: true);

    // "You" disc — ember.
    final youGlow = Paint()
      ..color = const Color(0x66FF6A2C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(youCenter, discR + 2, youGlow);
    canvas.drawCircle(
      youCenter,
      discR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B3A1A), TT.ember],
        ).createShader(Rect.fromCircle(center: youCenter, radius: discR)),
    );
    canvas.drawCircle(
      youCenter,
      discR,
      Paint()
        ..color = const Color(0xFFFF8A4D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawCenteredText(canvas, 'YOU', youCenter, Colors.white);

    // "Base" disc — green.
    final baseGlow = Paint()
      ..color = const Color(0x664CC38A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(baseCenter, discR + 2, baseGlow);
    canvas.drawCircle(
      baseCenter,
      discR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A2A), TT.green],
        ).createShader(Rect.fromCircle(center: baseCenter, radius: discR)),
    );
    canvas.drawCircle(
      baseCenter,
      discR,
      Paint()
        ..color = const Color(0xFF6BE0A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawHomeIcon(canvas, baseCenter);
  }

  void _drawCenteredText(
      Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TT.body(size: 10, w: FontWeight.w900, color: color)
            .copyWith(letterSpacing: 0.12 * 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawHomeIcon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xFFE6FFF1);
    final p = Path();
    final x = center.dx, y = center.dy;
    // Roof
    p.moveTo(x - 9, y);
    p.lineTo(x, y - 8);
    p.lineTo(x + 9, y);
    // Sides + base
    p.lineTo(x + 7, y);
    p.lineTo(x + 7, y + 7);
    p.lineTo(x - 7, y + 7);
    p.lineTo(x - 7, y);
    p.close();
    canvas.drawPath(p, fill);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_TetherPainter old) => old.t != t;
}

// ───────────────────────────── FADE-UP ENTRANCE ─────────────────────────────

class _FadeUpDelayed extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUpDelayed({required this.delay, required this.child});

  @override
  State<_FadeUpDelayed> createState() => _FadeUpDelayedState();
}

class _FadeUpDelayedState extends State<_FadeUpDelayed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctl.forward();
    });
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
            offset: Offset(0, (1 - t) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
