// Trailtether 2.0 — SOS Active screen.
//
// Recreates project/screens/sos.jsx from the design bundle: a pulsing crimson
// dial broadcasts SOS while the responder is en route. Layered concentric
// ripples + ember disc + glowing rescue badge sit above location, action,
// responder ETA, hazard, and incident-timeline cards. All values are
// placeholder — no providers, services, or platform plugins are imported.

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class TTSOSScreen extends StatefulWidget {
  final bool embedded;
  const TTSOSScreen({super.key, this.embedded = false});

  @override
  State<TTSOSScreen> createState() => _TTSOSScreenState();
}

class _TTSOSScreenState extends State<TTSOSScreen>
    with TickerProviderStateMixin {
  // Slow disc breathe — feeds the inner gradient orb and the rescue badge.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  // Timeline node pulse — only the active step uses this.
  late final AnimationController _nodePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    _nodePulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                  children: [
                    _SOSHero(breathe: _breathe),
                    const SizedBox(height: 18),
                    _RescueBadge(breathe: _breathe),
                    const SizedBox(height: 14),
                    const _LocationCard(),
                    const SizedBox(height: 12),
                    const _ActionRow(),
                    const SizedBox(height: 14),
                    const _ResponderEta(),
                    const SizedBox(height: 14),
                    const _Hazards(),
                    const SizedBox(height: 14),
                    _Timeline(pulse: _nodePulse),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ────────────────────────────── TOP APP BAR ────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 6),
      child: Row(
        children: [
          _BackBtn(onTap: onBack),
          const SizedBox(width: 10),
          Text('SOS ACTIVE',
              style: TT.title(20, letterSpacing: -0.01 * 20)),
          const SizedBox(width: 10),
          const TTPill(label: 'ACTIVE', variant: TTPillVariant.danger),
          const Spacer(),
        ],
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.line, width: 1),
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 16, color: TT.text2),
      ),
    );
  }
}

// ───────────────────────────────── SOS DIAL ─────────────────────────────────

class _SOSHero extends StatelessWidget {
  final AnimationController breathe;
  const _SOSHero({required this.breathe});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft crimson halo behind the orb.
            Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x66E63D2E), Color(0x00E63D2E)],
                  stops: [0.0, 0.75],
                ),
              ),
            ),
            // Concentric pulse rings — explicit red override.
            const TTPulseRings(size: 260, rings: 3, color: TT.red),
            // Inner ember disc with breathing scale.
            AnimatedBuilder(
              animation: breathe,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(breathe.value);
                final scale = 0.97 + 0.04 * t;
                return Transform.scale(
                  scale: scale,
                  child: const _SOSOrb(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SOSOrb extends StatelessWidget {
  const _SOSOrb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [Color(0xFFFF8A6C), Color(0xFFD6291F), Color(0xFF82120C)],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(color: const Color(0x8CFF966C), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xB3E63D2E), blurRadius: 50, spreadRadius: 0),
          BoxShadow(
              color: Color(0x6B000000),
              blurRadius: 28,
              offset: Offset(0, 10),
              spreadRadius: -8),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SOS',
            style: TT
                .title(40, color: Colors.white)
                .copyWith(letterSpacing: 0.1 * 40, height: 1.0),
          ),
          const SizedBox(height: 8),
          Text(
            'TRANSMITTING',
            style: TT
                .mono(size: 10, color: const Color(0xFFFFD5C4))
                .copyWith(letterSpacing: 0.24 * 10),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── RESCUE BADGE ────────────────────────────────

class _RescueBadge extends StatelessWidget {
  final AnimationController breathe;
  const _RescueBadge({required this.breathe});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: breathe,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(breathe.value);
          final glow = 14.0 + 10.0 * t;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TT.ember2, TT.ember],
              ),
              border: Border.all(color: const Color(0x80FFB486), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xA6FF6A2C),
                  blurRadius: glow,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_moon, size: 14, color: TT.emberInk),
                const SizedBox(width: 8),
                Text(
                  'RESCUE DISPATCHED',
                  style: TT
                      .body(size: 11, w: FontWeight.w900, color: TT.emberInk)
                      .copyWith(letterSpacing: 0.16 * 11),
                ),
                const SizedBox(width: 10),
                Container(
                    width: 1, height: 12, color: const Color(0x40000000)),
                const SizedBox(width: 10),
                Text(
                  '14:35',
                  style: TT.mono(
                      size: 11, color: TT.emberInk, w: FontWeight.w800),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────── LOCATION CARD ───────────────────────────────

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.place, size: 18, color: TT.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOCATION',
                    style: TT.label(size: 10, letterSpacing: 0.16 * 10)),
                const SizedBox(height: 4),
                Text(
                  'N 47.6062° · W 122.3321°',
                  style: TT.numStyle(size: 14, letterSpacing: -0.01 * 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'ALT 14.5 m · WGS84',
                  style: TT.mono(size: 10.5, color: TT.text3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1F4CC38A),
              border: Border.all(color: const Color(0x4D4CC38A), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '± 4.2m',
              style:
                  TT.mono(size: 10.5, color: TT.green, w: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── ACTION BUTTONS ──────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: 'CANCEL',
            icon: Icons.close,
            ember: false,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            label: 'CALL',
            icon: Icons.phone,
            ember: true,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool ember;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.ember,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
        scale: _down ? 0.97 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.ember
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  )
                : null,
            color: widget.ember ? null : TT.surf2,
            borderRadius: BorderRadius.circular(13),
            border: widget.ember
                ? null
                : Border.all(color: TT.line3, width: 1),
            boxShadow: widget.ember ? TT.shadowEmber : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: widget.ember ? TT.emberInk : TT.text),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TT
                    .body(
                        size: 12,
                        w: widget.ember
                            ? FontWeight.w900
                            : FontWeight.w800,
                        color: widget.ember ? TT.emberInk : TT.text)
                    .copyWith(letterSpacing: 0.14 * 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── RESPONDER ETA CARD ────────────────────────────

class _ResponderEta extends StatefulWidget {
  const _ResponderEta();

  @override
  State<_ResponderEta> createState() => _ResponderEtaState();
}

class _ResponderEtaState extends State<_ResponderEta>
    with SingleTickerProviderStateMixin {
  // 14:32 starting countdown; ticks once a second for the visual.
  int _seconds = 14 * 60 + 32;
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addStatusListener((s) {
      if (!mounted) return;
      if (s == AnimationStatus.completed) {
        setState(() {
          if (_seconds > 0) _seconds -= 1;
        });
        _tick.forward(from: 0);
      }
    });

  @override
  void initState() {
    super.initState();
    _tick.forward();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x24F2A93B),
              border: Border.all(color: const Color(0x4DF2A93B), width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_outlined,
                size: 22, color: TT.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESPONDER ETA',
                    style: TT.label(size: 10.5, letterSpacing: 0.16 * 10.5)),
                const SizedBox(height: 6),
                Text(
                  '$h:$m:$s',
                  style: TT.numStyle(
                      size: 28, color: TT.text, letterSpacing: -0.02 * 28),
                ),
                const SizedBox(height: 3),
                Text(
                  'RESCUE TEAM #4 · 620 m NW',
                  style: TT.mono(size: 10.5, color: TT.text3),
                ),
              ],
            ),
          ),
          const _SignalBars(),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars();

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 10.0, 14.0, 18.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(heights.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(
            width: 3.5,
            height: heights[i],
            decoration: BoxDecoration(
              color: i < 3 ? TT.green : TT.text3,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────── HAZARDS ───────────────────────────────────

class _Hazards extends StatelessWidget {
  const _Hazards();

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEARBY HAZARDS',
                style: TT.label(
                    size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
              ),
              Text(
                'SEE ALL →',
                style: TT
                    .body(size: 10, w: FontWeight.w800, color: TT.ember)
                    .copyWith(letterSpacing: 0.1 * 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const _HazardRow(
            icon: Icons.landscape_outlined,
            title: 'Loose rock',
            sub: '200 m E · ridge approach',
            time: '14:32',
            color: TT.red,
            riskLabel: 'HIGH',
          ),
          const _HazardDivider(),
          const _HazardRow(
            icon: Icons.warning_amber_rounded,
            title: 'Cliff edge',
            sub: '50 m N · unmarked drop',
            time: '14:30',
            color: TT.amber,
            riskLabel: 'MODERATE',
          ),
          const _HazardDivider(),
          const _HazardRow(
            icon: Icons.water_drop_outlined,
            title: 'Stream crossing',
            sub: '320 m W · waist-deep flow',
            time: '14:28',
            color: TT.blue,
            riskLabel: 'INFO',
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _HazardDivider extends StatelessWidget {
  const _HazardDivider();
  @override
  Widget build(BuildContext context) =>
      Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 1, color: TT.line);
}

class _HazardRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final String time;
  final Color color;
  final String riskLabel;
  const _HazardRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.time,
    required this.color,
    required this.riskLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tintBg = color.withOpacity(0.12);
    final tintBorder = color.withOpacity(0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tintBg,
              border: Border.all(color: tintBorder, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TT.body(size: 13, w: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(time,
                        style: TT.mono(size: 10, color: TT.text3)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(sub,
                    style: TT.mono(size: 10.5, color: TT.text2)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tintBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$riskLabel RISK',
                    style: TT
                        .mono(size: 9, color: color, w: FontWeight.w800)
                        .copyWith(letterSpacing: 0.16 * 9),
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

// ─────────────────────────── INCIDENT TIMELINE ─────────────────────────────

enum _NodeState { done, active, upcoming }

class _TimelineNode {
  final String label;
  final String time;
  final _NodeState state;
  const _TimelineNode(this.label, this.time, this.state);
}

class _Timeline extends StatelessWidget {
  final AnimationController pulse;
  const _Timeline({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const nodes = <_TimelineNode>[
      _TimelineNode('Detected', '14:30', _NodeState.done),
      _TimelineNode('Verified', '14:31', _NodeState.done),
      _TimelineNode('Dispatched', '14:35', _NodeState.done),
      _TimelineNode('En route', '14:39', _NodeState.active),
      _TimelineNode('Arrived', '--:--', _NodeState.upcoming),
    ];

    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'INCIDENT TIMELINE',
            style: TT.label(
                size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              // Spine — runs from first node centre to last node centre.
              Positioned(
                left: 8,
                top: 8,
                bottom: 8,
                child: Container(width: 2, color: TT.line),
              ),
              Column(
                children: List.generate(nodes.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i == nodes.length - 1 ? 0 : 14),
                    child: _TimelineRow(
                      delay: Duration(milliseconds: 200 + i * 80),
                      node: nodes[i],
                      pulse: pulse,
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatefulWidget {
  final Duration delay;
  final _TimelineNode node;
  final AnimationController pulse;
  const _TimelineRow({
    required this.delay,
    required this.node,
    required this.pulse,
  });

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: TT.dSlow);
  late final Animation<double> _t = CurvedAnimation(
    parent: _enter,
    curve: TT.easeOut,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) {
        return Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset((1 - _t.value) * 12, 0),
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NodeDot(state: widget.node.state, pulse: widget.pulse),
          const SizedBox(width: 14),
          SizedBox(
            width: 46,
            child: Text(
              widget.node.time,
              style: TT.mono(
                size: 11,
                color: widget.node.state == _NodeState.upcoming
                    ? TT.text3
                    : TT.text2,
                w: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.node.label,
              style: TT.body(
                size: 12.5,
                color: _labelColor(widget.node.state),
                w: widget.node.state == _NodeState.active
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
          if (widget.node.state == _NodeState.active)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: TT.emberDim,
                border: Border.all(
                    color: const Color(0x59FF6A2C), width: 1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'NOW',
                style: TT
                    .mono(size: 9, color: TT.ember, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.16 * 9),
              ),
            ),
        ],
      ),
    );
  }

  Color _labelColor(_NodeState s) {
    switch (s) {
      case _NodeState.done:
        return TT.text;
      case _NodeState.active:
        return TT.text;
      case _NodeState.upcoming:
        return TT.text3;
    }
  }
}

class _NodeDot extends StatelessWidget {
  final _NodeState state;
  final AnimationController pulse;
  const _NodeDot({required this.state, required this.pulse});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _NodeState.done:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: TT.ember,
            shape: BoxShape.circle,
            border: Border.all(color: TT.ember, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66FF6A2C), blurRadius: 6),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check,
              size: 10, color: TT.emberInk, weight: 900),
        );
      case _NodeState.upcoming:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: TT.bg2,
            shape: BoxShape.circle,
            border: Border.all(color: TT.text4, width: 2),
          ),
        );
      case _NodeState.active:
        return AnimatedBuilder(
          animation: pulse,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(pulse.value);
            final glow = 8.0 + 10.0 * t;
            return Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: TT.bg2,
                shape: BoxShape.circle,
                border: Border.all(color: TT.ember, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xB3FF6A2C), blurRadius: glow),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: TT.ember,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
    }
  }
}
