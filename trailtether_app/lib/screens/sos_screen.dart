// Trailtether 3.0 — Emergency SOS screen.
//
// Reskin notes:
//   * UI rewritten on top of TT design tokens (TT.bg / TTAmbient /
//     TTTopoBackdrop / TTPulseRings / TTCard) — no `kColor*` legacy.
//   * SAFETY-CRITICAL behaviour preserved EXACTLY:
//       - 5 s press-and-hold required to trigger `_triggerSos`.
//       - IncidentType picker (Medical / Lost / Stuck).
//       - Live GPS position via `LocationService.currentPosition`.
//       - Heavy haptic on hold start + tick haptic every 1 s during hold +
//         long vibrate on fire.
//       - `IncidentService.addIncident` insert with selected type +
//         current coords, with 15 s upload timeout and loud failure.
//       - Local emergency notification on success.
//       - No way to "cancel" after the SOS has fired.
//
// Owns only this file.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design_tokens.dart';
import '../core/utils.dart';
import '../models/incident.dart';
import '../services/incident_service.dart';
import '../services/location_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_topo.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  // Five-second hold gate — drives the progress arc AND the auto-fire
  // status listener. Do not shorten the duration without security review.
  late final AnimationController _holdController;

  Position? _currentPos;
  bool _triggered = false;
  DateTime? _firedAt;

  IncidentType _sosType = IncidentType.medicalEmergency;

  /// Tracks which whole-second tick we last fired a haptic for during the
  /// hold so we get a `selectionClick` once per second, not on every frame.
  int _lastHapticSecond = 0;

  @override
  void initState() {
    super.initState();

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_triggered) {
          _triggerSos();
        }
      })
      ..addListener(_onHoldTick);

    _updateLocation();
  }

  @override
  void dispose() {
    _holdController
      ..removeListener(_onHoldTick)
      ..dispose();
    super.dispose();
  }

  void _onHoldTick() {
    if (_triggered) return;
    // 0..5 seconds → tick once each whole second crossed.
    final secs = (_holdController.value * 5).floor();
    if (secs > _lastHapticSecond && secs <= 5) {
      _lastHapticSecond = secs;
      HapticFeedback.selectionClick();
    }
    setState(() {}); // animate countdown label
  }

  Future<void> _updateLocation() async {
    try {
      final pos = await LocationService.currentPosition();
      if (mounted) setState(() => _currentPos = pos);
    } catch (e, stack) {
      LoggerService.error('SOS', 'Failed to fetch current location: $e', stack);
    }
  }

  Future<void> _triggerSos() async {
    if (_triggered) return;

    if (_currentPos == null) {
      await _updateLocation();
    }

    if (_currentPos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot send SOS without GPS location. Please ensure GPS is enabled.',
            ),
            backgroundColor: TT.amber,
          ),
        );
      }
      // Reset the hold so the user can try again after enabling GPS.
      _holdController.value = 0;
      _lastHapticSecond = 0;
      return;
    }

    setState(() {
      _triggered = true;
      _firedAt = DateTime.now();
    });
    await HapticFeedback.vibrate();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        throw Exception('You must be signed in to send SOS.');
      }

      final deviceId = await TrailUtils.getDeviceId();
      final now = DateTime.now();

      String specificDesc =
          'SOS emergency broadcast. Immediate assistance required.';
      if (_sosType == IncidentType.lostOrDisoriented) {
        specificDesc =
            'SOS: User is LOST or DISORIENTED. Assistance required for navigation/rescue.';
      } else if (_sosType == IncidentType.stuckOrTrapped) {
        specificDesc =
            'SOS: User is STUCK or TRAPPED (Cliff/Valley). Technical rescue may be required.';
      }

      final incident = Incident(
        id: '',
        lat: _currentPos!.latitude,
        lon: _currentPos!.longitude,
        type: _sosType,
        severity: IncidentSeverity.critical,
        description: specificDesc,
        incidentDate: now,
        reportedAt: now,
        deviceId: deviceId,
        createdBy: uid,
        isEmergency: true,
      );

      // Bound the upload — if it can't reach the server in 15 s, fail loudly
      // so the user knows to use another channel (phone, satellite, etc.).
      await IncidentService.addIncident(incident).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
            'Could not reach Trailtether servers within 15 seconds.'),
      );

      LoggerService.log(
          'SOS',
          'Broadcast accepted by server. uid=$uid lat=${incident.lat} '
              'lon=${incident.lon}');

      // Local notification is best-effort — don't fail the SOS if it errors.
      try {
        await NotificationService.instance.showNotification(
          id: 999,
          title: 'SOS BROADCAST ACTIVE',
          body:
              'Emergency incident shared with nearby Trailtether users. Contact emergency services directly if needed.',
          isEmergency: true,
        );
      } catch (e, stack) {
        LoggerService.error(
            'SOS', 'Local SOS notification failed (non-fatal): $e', stack);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS broadcast sent. Now contact emergency services directly.',
            ),
            backgroundColor: TT.red,
            duration: Duration(seconds: 10),
          ),
        );
      }
    } catch (e, stack) {
      LoggerService.error('SOS', 'Failed to broadcast SOS: $e', stack);
      if (mounted) {
        setState(() {
          _triggered = false;
          _firedAt = null;
        });
        _holdController.value = 0;
        _lastHapticSecond = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOS NOT SENT — $e\nUse phone/satellite to contact emergency services.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF7A1A12),
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _triggerSos,
            ),
          ),
        );
      }
    }
  }

  Future<void> _onHoldStart() async {
    if (_triggered) return;
    _lastHapticSecond = 0;
    await HapticFeedback.heavyImpact();
    await _holdController.forward();
  }

  void _onHoldEnd() {
    if (_triggered) return;
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
      _lastHapticSecond = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Big central press surface — capped so it never spills off small phones.
    final buttonSize = (width - 96).clamp(220.0, 280.0).toDouble();
    final ringSize = buttonSize + 64;

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.55)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                              onBack: () => Navigator.of(context).maybePop()),
                          const SizedBox(height: TT.s4),
                          _LocationCard(pos: _currentPos),
                          const SizedBox(height: TT.s4),
                          if (!_triggered)
                            _TypePicker(
                              selected: _sosType,
                              onSelect: (t) => setState(() => _sosType = t),
                            )
                          else
                            _ActivatedBanner(
                              type: _sosType,
                              firedAt: _firedAt ?? DateTime.now(),
                            ),
                          const SizedBox(height: TT.s5),
                          Center(
                            child: _HoldButton(
                              ringSize: ringSize,
                              buttonSize: buttonSize,
                              progress: _holdController.value,
                              holding: _holdController.isAnimating &&
                                  _holdController.value < 1.0,
                              triggered: _triggered,
                              onHoldStart: _onHoldStart,
                              onHoldEnd: _onHoldEnd,
                            ),
                          ),
                          const SizedBox(height: TT.s5),
                          _ExplainerCopy(triggered: _triggered),
                          const SizedBox(height: TT.s5),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(TT.rMd),
                border: Border.all(color: TT.line, width: 1),
              ),
              child: const Icon(Icons.chevron_left, size: 22, color: TT.text2),
            ),
          ),
          const SizedBox(width: TT.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITICAL ALERT',
                  style: TT.label(color: TT.red, letterSpacing: 1.8),
                ),
                const SizedBox(height: 2),
                Text(
                  'EMERGENCY SOS',
                  style:
                      TT.title(22, color: TT.text, letterSpacing: -0.02 * 22),
                ),
              ],
            ),
          ),
          // Live red dot — matches the danger pill rhythm without crowding.
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: TT.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: TT.red, blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Location card ──────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final Position? pos;
  const _LocationCard({required this.pos});

  @override
  Widget build(BuildContext context) {
    final p = pos;
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TT.emberDim,
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(color: const Color(0x59FF6A2C), width: 1),
            ),
            child: const Icon(Icons.location_on, color: TT.ember, size: 20),
          ),
          const SizedBox(width: TT.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR CURRENT LOCATION',
                    style: TT.label(letterSpacing: 1.6)),
                const SizedBox(height: 6),
                if (p != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                      style:
                          TT.mono(size: 13, color: TT.text, letterSpacing: 0.5),
                    ),
                  )
                else
                  Text('Acquiring GPS…',
                      style: TT.mono(size: 12, color: TT.text2)),
                const SizedBox(height: 4),
                Text(
                  p != null
                      ? '±${p.accuracy.toStringAsFixed(0)} m accuracy'
                      : 'Waiting for satellites',
                  style: TT.body(size: 11, color: TT.text3, w: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (p == null)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: TT.ember,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Type picker ────────────────────────────────────────────────────────────

class _TypePicker extends StatelessWidget {
  final IncidentType selected;
  final ValueChanged<IncidentType> onSelect;
  const _TypePicker({required this.selected, required this.onSelect});

  static const _items = <_PickerItem>[
    _PickerItem(IncidentType.medicalEmergency, Icons.medical_services_outlined,
        'MEDICAL'),
    _PickerItem(IncidentType.lostOrDisoriented, Icons.explore_outlined, 'LOST'),
    _PickerItem(IncidentType.stuckOrTrapped, Icons.terrain_outlined, 'STUCK'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT EMERGENCY TYPE', style: TT.label(letterSpacing: 1.8)),
        const SizedBox(height: TT.s2),
        Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i != 0) const SizedBox(width: TT.s2),
              Expanded(
                child: _TypeTile(
                  item: _items[i],
                  selected: selected == _items[i].type,
                  onTap: () => onSelect(_items[i].type),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PickerItem {
  final IncidentType type;
  final IconData icon;
  final String label;
  const _PickerItem(this.type, this.icon, this.label);
}

class _TypeTile extends StatelessWidget {
  final _PickerItem item;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: TT.dFast,
        curve: TT.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1AE63D2E) : TT.surf,
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(
            color: selected ? TT.red : TT.line,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Color(0x59E63D2E),
                      blurRadius: 18,
                      spreadRadius: -4),
                ]
              : TT.shadowCard,
        ),
        child: Column(
          children: [
            Icon(
              item.icon,
              color: selected ? TT.red : TT.text2,
              size: 22,
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: TT
                  .body(
                    size: 11,
                    w: FontWeight.w800,
                    color: selected ? TT.red : TT.text2,
                  )
                  .copyWith(letterSpacing: 0.14 * 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activated banner ──────────────────────────────────────────────────────

class _ActivatedBanner extends StatelessWidget {
  final IncidentType type;
  final DateTime firedAt;
  const _ActivatedBanner({required this.type, required this.firedAt});

  String get _label {
    switch (type) {
      case IncidentType.lostOrDisoriented:
        return 'LOST / DISORIENTED';
      case IncidentType.stuckOrTrapped:
        return 'STUCK / TRAPPED';
      default:
        return 'MEDICAL EMERGENCY';
    }
  }

  String _hms(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1A4CC38A),
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(color: const Color(0x594CC38A), width: 1),
            ),
            child: const Icon(Icons.check_rounded, color: TT.green, size: 22),
          ),
          const SizedBox(width: TT.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SOS ACTIVATED · $_label',
                    style: TT.label(color: TT.red, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                Text(
                  'Broadcast at ${_hms(firedAt)} — nearby Trailtether users notified.',
                  style: TT.body(size: 12, color: TT.text, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hold-5s button ────────────────────────────────────────────────────────

class _HoldButton extends StatelessWidget {
  final double ringSize;
  final double buttonSize;
  final double progress; // 0..1
  final bool holding;
  final bool triggered;
  final Future<void> Function() onHoldStart;
  final VoidCallback onHoldEnd;

  const _HoldButton({
    required this.ringSize,
    required this.buttonSize,
    required this.progress,
    required this.holding,
    required this.triggered,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    final secondsRemaining = (5 - (progress * 5)).clamp(0.0, 5.0).ceil();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: triggered ? null : (_) => onHoldStart(),
      onTapUp: triggered ? null : (_) => onHoldEnd(),
      onTapCancel: triggered ? null : onHoldEnd,
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse rings — silenced once activated so the screen
            // visibly settles into "SENT" state.
            if (!triggered)
              IgnorePointer(
                child: TTPulseRings(
                  size: ringSize,
                  color: TT.red,
                  rings: 3,
                ),
              ),
            // Inner ember→red filled disc.
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: triggered
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A6B43), Color(0xFF12442C)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TT.ember, TT.red],
                      ),
                boxShadow: triggered
                    ? const [
                        BoxShadow(
                            color: Color(0x664CC38A),
                            blurRadius: 32,
                            spreadRadius: -6),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0x80FF6A2C),
                            blurRadius: 34,
                            spreadRadius: -6),
                        BoxShadow(
                            color: Color(0x66E63D2E),
                            blurRadius: 18,
                            spreadRadius: -4),
                      ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: triggered
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 56),
                            const SizedBox(height: 4),
                            Text(
                              'SOS\nACTIVATED',
                              textAlign: TextAlign.center,
                              style: TT
                                  .title(20, color: Colors.white)
                                  .copyWith(letterSpacing: 0.18 * 20),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              holding ? Icons.touch_app : Icons.emergency_share,
                              color: Colors.white,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              holding ? 'KEEP HOLDING' : 'HOLD 5s FOR SOS',
                              textAlign: TextAlign.center,
                              style: TT
                                  .title(holding ? 18 : 20, color: Colors.white)
                                  .copyWith(letterSpacing: 0.16 * 18),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              holding ? '$secondsRemaining s' : 'Press & hold',
                              style: TT.mono(
                                size: 13,
                                color: const Color(0xCCFFFFFF),
                                letterSpacing: 0.06 * 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            // Progress arc — drawn on top of the disc so the unfilled
            // portion stays subtle ember and the filled portion glows red.
            if (!triggered)
              IgnorePointer(
                child: SizedBox(
                  width: buttonSize + 18,
                  height: buttonSize + 18,
                  child: CustomPaint(
                    painter: _HoldArcPainter(progress: progress),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HoldArcPainter extends CustomPainter {
  final double progress;
  _HoldArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x33FFFFFF);
    canvas.drawCircle(centre, radius, track);

    if (progress <= 0) return;

    final filled = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [TT.ember, TT.red, TT.red],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, progress * math.pi * 2, false, filled);
  }

  @override
  bool shouldRepaint(_HoldArcPainter old) => old.progress != progress;
}

// ─── Explainer copy ─────────────────────────────────────────────────────────

class _ExplainerCopy extends StatelessWidget {
  final bool triggered;
  const _ExplainerCopy({required this.triggered});

  @override
  Widget build(BuildContext context) {
    if (triggered) {
      return Column(
        children: [
          Text(
            'Your team and nearby Trailtether users have been alerted.',
            textAlign: TextAlign.center,
            style: TT.body(size: 13, color: TT.text, w: FontWeight.w700),
          ),
          const SizedBox(height: TT.s2),
          Text(
            'For life-threatening emergencies, contact the local emergency service directly. Trailtether is not a substitute for satellite messengers or 911.',
            textAlign: TextAlign.center,
            style: TT.body(size: 11.5, color: TT.text2, w: FontWeight.w600),
          ),
        ],
      );
    }
    return Column(
      children: [
        Text(
          'Press and hold for 5 seconds to broadcast a critical incident.',
          textAlign: TextAlign.center,
          style: TT.body(size: 13, color: TT.text, w: FontWeight.w700),
        ),
        const SizedBox(height: TT.s2),
        Text(
          'Your coordinates and selected emergency type are shared with nearby Trailtether users. Contact emergency services directly if needed.',
          textAlign: TextAlign.center,
          style: TT.body(size: 11.5, color: TT.text2, w: FontWeight.w600),
        ),
      ],
    );
  }
}
