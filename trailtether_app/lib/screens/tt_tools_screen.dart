// Trailtether 2.0 — Tools screen.
//
// Compass-focused tool picker recreating project/screens/tools.jsx from the
// design bundle: brand bar + a horizontally scrolling tool tab strip
// (Compass / Level / Torch / Altimeter / Sun / Info) over a body that
// AnimatedSwitch-fades between each tool's distinct visual.
//
// Each tool is wired to real device sensors (flutter_compass, sensors_plus,
// torch_light, geolocator). All interactive controls — settings gear, metric
// tiles, cardinal letters, info cards — are live; no placeholder data leaks
// through to the UI.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

import '../core/design_tokens.dart';
import '../core/sun_utils.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

enum _Tool { compass, level, torch, altimeter, sun, info }

class _ToolSpec {
  final _Tool id;
  final String label;
  final IconData icon;
  const _ToolSpec(this.id, this.label, this.icon);
}

const List<_ToolSpec> _kTools = [
  _ToolSpec(_Tool.compass,   'Compass',   Icons.explore_outlined),
  _ToolSpec(_Tool.level,     'Level',     Icons.center_focus_strong_outlined),
  _ToolSpec(_Tool.torch,     'Torch',     Icons.local_fire_department_outlined),
  _ToolSpec(_Tool.altimeter, 'Altimeter', Icons.terrain_outlined),
  _ToolSpec(_Tool.sun,       'Sun',       Icons.wb_sunny_outlined),
  _ToolSpec(_Tool.info,      'Info',      Icons.tips_and_updates_outlined),
];

// ─────────────────────── Persistent tool preferences ───────────────────────
//
// A tiny ChangeNotifier wrapping SharedPreferences so every tool can read &
// react to the same settings without piping props through every widget.
class _ToolPrefs extends ChangeNotifier {
  static const _kDeclination = 'tt_tool_declination_deg';
  static const _kUseImperial = 'tt_tool_use_imperial';
  static const _kSunTime24 = 'tt_tool_sun_24h';

  double _declination = 0.0; // user-entered declination in degrees (east +)
  bool _useImperial = false; // metres / feet
  bool _sunTime24 = true;    // 24h vs 12h sunrise/sunset readout

  double get declination => _declination;
  bool get useImperial => _useImperial;
  bool get sunTime24 => _sunTime24;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _declination = p.getDouble(_kDeclination) ?? 0.0;
    _useImperial = p.getBool(_kUseImperial) ?? false;
    _sunTime24 = p.getBool(_kSunTime24) ?? true;
    notifyListeners();
  }

  Future<void> setDeclination(double v) async {
    _declination = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kDeclination, v);
  }

  Future<void> setUseImperial(bool v) async {
    _useImperial = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUseImperial, v);
  }

  Future<void> setSunTime24(bool v) async {
    _sunTime24 = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSunTime24, v);
  }
}

class TTToolsScreen extends StatefulWidget {
  final bool embedded;
  const TTToolsScreen({super.key, this.embedded = false});

  @override
  State<TTToolsScreen> createState() => _TTToolsScreenState();
}

class _TTToolsScreenState extends State<TTToolsScreen>
    with AutomaticKeepAliveClientMixin {
  _Tool _tool = _Tool.compass;
  final _ToolPrefs _prefs = _ToolPrefs();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prefs.load();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TT.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => _ToolSettingsSheet(prefs: _prefs),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = AnimatedBuilder(
      animation: _prefs,
      builder: (_, __) => Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.55)),
          SafeArea(
            top: !widget.embedded,
            bottom: false,
            child: Column(
              children: [
                TTPageAppBar(
                  title: 'Hiking Tools',
                  trailing: [
                    TTIconBtn(
                      icon: Icons.settings_outlined,
                      onTap: _openSettings,
                    ),
                  ],
                ),
                _ToolPicker(
                  active: _tool,
                  onChange: (t) => setState(() => _tool = t),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: TT.dMed,
                    switchInCurve: TT.easeOut,
                    switchOutCurve: TT.easeOut,
                    transitionBuilder: (child, anim) {
                      final scale =
                          Tween<double>(begin: 0.96, end: 1.0).animate(anim);
                      return FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: scale, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_tool),
                      child: _toolBody(_tool, _prefs),
                    ),
                  ),
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

  Widget _toolBody(_Tool t, _ToolPrefs prefs) {
    switch (t) {
      case _Tool.compass:   return _CompassTool(prefs: prefs);
      case _Tool.level:     return const _LevelTool();
      case _Tool.torch:     return const _TorchTool();
      case _Tool.altimeter: return _AltimeterTool(prefs: prefs);
      case _Tool.sun:       return _SunTool(prefs: prefs);
      case _Tool.info:      return const _InfoTool();
    }
  }
}

// ──────────────────────────── TOOL PICKER ───────────────────────────────────

class _ToolPicker extends StatelessWidget {
  final _Tool active;
  final ValueChanged<_Tool> onChange;
  const _ToolPicker({required this.active, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        itemCount: _kTools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _kTools[i];
          final a = t.id == active;
          return _ToolTab(spec: t, active: a, onTap: () => onChange(t.id));
        },
      ),
    );
  }
}

class _ToolTab extends StatefulWidget {
  final _ToolSpec spec;
  final bool active;
  final VoidCallback onTap;
  const _ToolTab({required this.spec, required this.active, required this.onTap});

  @override
  State<_ToolTab> createState() => _ToolTabState();
}

class _ToolTabState extends State<_ToolTab> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
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
        child: AnimatedContainer(
          duration: TT.dMed,
          curve: TT.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: a ? TT.emberDim : TT.surf,
            border: Border.all(
              color: a ? const Color(0x5CFF6A2C) : TT.line,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: a
                ? const [BoxShadow(color: Color(0x40FF6A2C), blurRadius: 14, spreadRadius: -6)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.spec.icon, size: 14, color: a ? TT.ember : TT.text2),
              const SizedBox(width: 7),
              Text(
                widget.spec.label.toUpperCase(),
                style: TT.body(size: 11, w: FontWeight.w800, color: a ? TT.ember : TT.text2)
                    .copyWith(letterSpacing: 0.1 * 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── SETTINGS SHEET ────────────────────────────────

class _ToolSettingsSheet extends StatefulWidget {
  final _ToolPrefs prefs;
  const _ToolSettingsSheet({required this.prefs});

  @override
  State<_ToolSettingsSheet> createState() => _ToolSettingsSheetState();
}

class _ToolSettingsSheetState extends State<_ToolSettingsSheet> {
  late final TextEditingController _decCtrl =
      TextEditingController(text: widget.prefs.declination.toStringAsFixed(1));

  @override
  void dispose() {
    _decCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyDeclination() async {
    final parsed = double.tryParse(_decCtrl.text.trim());
    if (parsed == null) {
      _decCtrl.text = widget.prefs.declination.toStringAsFixed(1);
      return;
    }
    final clamped = parsed.clamp(-30.0, 30.0).toDouble();
    await widget.prefs.setDeclination(clamped);
    if (mounted) _decCtrl.text = clamped.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.prefs,
      builder: (_, __) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 12,
          bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TT.line2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Tool preferences', style: TT.title(18)),
            const SizedBox(height: 4),
            Text(
              'Applies to every tool on this screen.',
              style: TT.body(size: 11.5, color: TT.text3),
            ),
            const SizedBox(height: 18),

            // Declination override
            _SettingsRow(
              icon: Icons.explore_outlined,
              title: 'Magnetic declination',
              subtitle: 'Added to compass heading. East positive.',
              trailing: SizedBox(
                width: 96,
                child: TextField(
                  controller: _decCtrl,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  style: TT.numStyle(size: 13, color: TT.ember),
                  decoration: InputDecoration(
                    suffixText: '°',
                    suffixStyle: TT.mono(size: 11, color: TT.text3),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TT.rSm),
                      borderSide: const BorderSide(color: TT.line2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TT.rSm),
                      borderSide: const BorderSide(color: TT.ember),
                    ),
                  ),
                  onSubmitted: (_) => _applyDeclination(),
                  onEditingComplete: _applyDeclination,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Units toggle
            _SettingsRow(
              icon: Icons.straighten,
              title: 'Altitude unit',
              subtitle: widget.prefs.useImperial
                  ? 'Showing feet'
                  : 'Showing metres',
              trailing: Switch.adaptive(
                value: widget.prefs.useImperial,
                activeColor: TT.ember,
                onChanged: widget.prefs.setUseImperial,
              ),
            ),
            const SizedBox(height: 10),

            // 24-hour toggle
            _SettingsRow(
              icon: Icons.schedule,
              title: 'Sun times in 24-hour',
              subtitle: widget.prefs.sunTime24
                  ? '06:42 / 19:18'
                  : '6:42 AM / 7:18 PM',
              trailing: Switch.adaptive(
                value: widget.prefs.sunTime24,
                activeColor: TT.ember,
                onChanged: widget.prefs.setSunTime24,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: TT.text2,
                  textStyle:
                      TT.body(size: 12, w: FontWeight.w700, color: TT.text2),
                ),
                onPressed: () {
                  _applyDeclination();
                  Navigator.of(context).maybePop();
                },
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TT.body(size: 13, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TT.body(size: 11, color: TT.text3)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ──────────────────────────── COMPASS ───────────────────────────────────────

class _CompassTool extends StatefulWidget {
  final _ToolPrefs prefs;
  const _CompassTool({required this.prefs});

  @override
  State<_CompassTool> createState() => _CompassToolState();
}

class _CompassToolState extends State<_CompassTool> {
  double? _heading;
  bool _available = true;
  StreamSubscription<CompassEvent>? _sub;

  // Live altitude + GPS accuracy for the metric grid below the dial.
  Position? _pos;
  StreamSubscription<Position>? _posSub;

  // Heading lock — when set, dial freezes at this bearing so the user can
  // sight a landmark without the rose spinning under their hand.
  double? _lock;

  @override
  void initState() {
    super.initState();
    _initCompass();
    _initLocation();
  }

  void _initCompass() {
    // flutter_compass has no Windows/macOS/Linux plugin implementation.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() => _available = false);
      return;
    }
    try {
      final events = FlutterCompass.events;
      if (events == null) {
        setState(() => _available = false);
        return;
      }
      _sub = events.listen(
        (e) {
          if (mounted && e.heading != null) {
            setState(() => _heading = e.heading!);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _available = false);
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  void _initLocation() {
    try {
      _posSub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen(
        (p) {
          if (mounted) setState(() => _pos = p);
        },
        onError: (_) {/* leave _pos null — tile shows em-dash */},
      );
    } catch (_) {/* same */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  String _toCardinal(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }

  String _toCardinalLong(double deg) {
    const names = [
      'NORTH',
      'NORTHEAST',
      'EAST',
      'SOUTHEAST',
      'SOUTH',
      'SOUTHWEST',
      'WEST',
      'NORTHWEST',
    ];
    return names[((deg + 22.5) / 45).floor() % 8];
  }

  void _toggleLock(double bearing) {
    setState(() {
      _lock = (_lock == null) ? bearing : null;
    });
    _flash(_lock == null
        ? 'Heading lock cleared'
        : 'Locked at ${bearing.toStringAsFixed(0)}°');
  }

  /// Tap on a cardinal letter snaps the lock to that direction.
  void _lockToCardinal(double deg) {
    setState(() => _lock = deg);
    _flash('Locked to ${_toCardinal(deg)}');
  }

  void _flash(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: TT.body(size: 12)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _flash('$label copied: $value');
  }

  @override
  Widget build(BuildContext context) {
    final rawHeading = _heading ?? 0.0;
    // Apply user declination override, then optional lock.
    final compensated = (rawHeading + widget.prefs.declination) % 360;
    final display = _lock ?? compensated;
    final cardinal = _toCardinal(display);
    final cardinalLong = _toCardinalLong(display);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            TTCard(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
              onTap: () => _toggleLock(compensated),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TT.rLg),
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [Color(0x1FFF6A2C), Color(0x00FF6A2C)],
                            stops: [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _CompassDial(
                        bearing: display,
                        locked: _lock != null,
                        onCardinalTap: _lockToCardinal,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${display.toStringAsFixed(0)}°',
                        style: TT.numStyle(size: 38, letterSpacing: -0.025 * 38),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$cardinalLong · $cardinal',
                        style: TT.body(size: 12, w: FontWeight.w800, color: TT.ember)
                            .copyWith(letterSpacing: 0.2 * 12),
                      ),
                      if (_lock != null) ...[
                        const SizedBox(height: 8),
                        const TTPill(
                          label: 'LOCKED',
                          variant: TTPillVariant.ember,
                          leadingIcon: Icons.lock_outline,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.navigation_outlined,
                label: 'Heading',
                value: '${display.toStringAsFixed(0)}°',
                unit: cardinal,
                ember: true,
                onTap: () =>
                    _copy('${display.toStringAsFixed(0)}° $cardinal', 'Heading'),
              ),
              _MetricSpec(
                icon: Icons.layers_outlined,
                label: 'Declination',
                value: widget.prefs.declination == 0
                    ? '0.0'
                    : '${widget.prefs.declination > 0 ? '+' : ''}'
                        '${widget.prefs.declination.toStringAsFixed(1)}',
                unit: '° DEC',
                onTap: () => _copy(
                  '${widget.prefs.declination.toStringAsFixed(1)}°',
                  'Declination',
                ),
              ),
              _MetricSpec(
                icon: Icons.terrain_outlined,
                label: 'Altitude',
                value: _pos == null
                    ? '—'
                    : _formatAltShared(_pos!.altitude, widget.prefs.useImperial),
                unit: widget.prefs.useImperial ? 'ft' : 'm',
                onTap: _pos == null
                    ? null
                    : () => _copy(
                          '${_formatAltShared(_pos!.altitude, widget.prefs.useImperial)} '
                              '${widget.prefs.useImperial ? 'ft' : 'm'}',
                          'Altitude',
                        ),
              ),
              _MetricSpec(
                icon: Icons.center_focus_strong_outlined,
                label: 'GPS Acc',
                value: _pos == null ? '—' : '+/- ${_pos!.accuracy.toStringAsFixed(0)}',
                unit: 'm',
                onTap: _pos == null
                    ? null
                    : () => _copy(
                          '+/- ${_pos!.accuracy.toStringAsFixed(0)} m',
                          'GPS accuracy',
                        ),
              ),
            ]),
            const SizedBox(height: 14),
            _Callout(
              icon: Icons.info_outline,
              color: TT.blue,
              text: _lock != null
                  ? 'Heading locked. Tap the dial again to release.'
                  : 'Hold flat. Tap a cardinal letter to lock that bearing.',
            ),
          ],
        ),
        if (!_available)
          const Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.explore_off,
              title: 'Compass unavailable',
              subtitle: 'This device has no magnetometer.',
            ),
          ),
      ],
    );
  }
}

class _CompassDial extends StatefulWidget {
  final double bearing;
  final bool locked;
  final ValueChanged<double> onCardinalTap;
  const _CompassDial({
    required this.bearing,
    required this.locked,
    required this.onCardinalTap,
  });

  @override
  State<_CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<_CompassDial> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();

  static const double _size = 220;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Convert a tap-local position to "did the user hit one of the four
  /// cardinal labels?" — returns 0/90/180/270 if yes, otherwise null.
  double? _cardinalForTap(Offset local) {
    const r = _size / 2;
    final dx = local.dx - r;
    final dy = local.dy - r;
    final dist = math.sqrt(dx * dx + dy * dy);
    // Cardinal labels live at radius (r - 25..r - 36); accept hits in a wider
    // band so the touch target is comfortable.
    if (dist < r - 50 || dist > r - 4) return null;
    // Direction in the (rotated) rose frame: undo the canvas rotation.
    final screenAng = math.atan2(dy, dx); // 0 = east, +y is south on screen
    // The rose is rotated by -bearing, so its 'N' lives at screen up.
    // We want the cardinal nearest to the tap angle, but in *world* terms
    // we just need to map the angle to one of four directions.
    final ang = (screenAng * 180 / math.pi + 360 + 90) % 360; // 0 = up
    if (ang < 22.5 || ang > 337.5) return 0;   // N
    if (ang > 67.5 && ang < 112.5) return 90;  // E
    if (ang > 157.5 && ang < 202.5) return 180; // S
    if (ang > 247.5 && ang < 292.5) return 270; // W
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final c = _cardinalForTap(d.localPosition);
          if (c != null) widget.onCardinalTap(c);
        },
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, __) {
            // Sin-based wiggle: +/- 1.5 degrees around the current bearing.
            // Wiggle freezes when the dial is locked so the user gets a stable
            // sighting reference.
            final wiggle = widget.locked
                ? 0.0
                : math.sin(_ctl.value * 2 * math.pi) * 1.5;
            return CustomPaint(
              painter: _CompassPainter(bearing: widget.bearing + wiggle),
            );
          },
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearing;
  _CompassPainter({required this.bearing});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Outer disc gradient + rim.
    final discPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF0D1116), Color(0xFF06080B)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 10, discPaint);
    final rim = Paint()
      ..color = TT.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(c, r - 10, rim);
    canvas.drawCircle(
      c, r - 24,
      Paint()
        ..color = TT.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Rotate the whole rose by -heading so the cardinal letters and ticks
    // physically align with magnetic compass directions. The needle below is
    // drawn AFTER the restore() so it stays fixed pointing up.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-bearing * math.pi / 180);

    // Tick marks every 7.5 degrees: 48 total, every 12th = major, every 4th = mid.
    for (var i = 0; i < 48; i++) {
      final ang = (i * 7.5 - 90) * math.pi / 180;
      final major = i % 12 == 0;
      final mid = i % 4 == 0;
      final r1 = r - 14;
      final r2 = major ? r - 30 : (mid ? r - 24 : r - 20);
      final p = Paint()
        ..color = major ? TT.ember2 : (mid ? TT.text2 : TT.text4)
        ..strokeWidth = major ? 2 : (mid ? 1.2 : 0.8)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(math.cos(ang) * r1, math.sin(ang) * r1),
        Offset(math.cos(ang) * r2, math.sin(ang) * r2),
        p,
      );
    }

    // Cardinal labels: N (ember), E S W (muted). Drawn relative to origin
    // because the canvas has been translated above.
    _drawText(canvas, 'N', Offset(0, -r + 28), TT.ember, 14, FontWeight.w900);
    _drawText(canvas, 'E', Offset(r - 36, 0), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'S', Offset(0, r - 25), TT.text2, 11, FontWeight.w800);
    _drawText(canvas, 'W', Offset(-r + 36, 0), TT.text2, 11, FontWeight.w800);

    canvas.restore();

    // Heading indicator wedge — a short 12-degree ember beam that always points
    // straight up at the direction the user is facing.
    final sectorPath = Path()..moveTo(c.dx, c.dy);
    final wedgeRect = Rect.fromCircle(center: c, radius: r - 22);
    sectorPath.arcTo(wedgeRect, -math.pi / 2 - 6 * math.pi / 180,
        12 * math.pi / 180, false);
    sectorPath.close();
    canvas.drawPath(
      sectorPath,
      Paint()..color = const Color(0x29FF6A2C),
    );

    // Fixed needle — ember tip up (= the heading the user is facing).
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final needleN = Path()
      ..moveTo(0, -(r - 36))
      ..lineTo(6, 0)
      ..lineTo(0, 6)
      ..lineTo(-6, 0)
      ..close();
    final needleS = Path()
      ..moveTo(0, r - 36)
      ..lineTo(6, 0)
      ..lineTo(0, -6)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(needleN, Paint()..color = TT.ember);
    canvas.drawPath(needleS, Paint()..color = TT.text4);
    canvas.restore();

    // Pivot.
    canvas.drawCircle(
      c, 6,
      Paint()..color = TT.emberInk,
    );
    canvas.drawCircle(
      c, 6,
      Paint()
        ..color = TT.ember2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 2, Paint()..color = TT.ember2);
  }

  void _drawText(Canvas canvas, String text, Offset center, Color color, double size, FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TT.body(size: size, w: w, color: color)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.bearing != bearing;
}

// ──────────────────────────── LEVEL ─────────────────────────────────────────

class _LevelTool extends StatefulWidget {
  const _LevelTool();

  @override
  State<_LevelTool> createState() => _LevelToolState();
}

class _LevelToolState extends State<_LevelTool>
    with SingleTickerProviderStateMixin {
  // Accelerometer raw axis values (m/s^2).
  double _ax = 0, _ay = 0, _az = 9.8;
  bool _available = true;
  StreamSubscription<AccelerometerEvent>? _sub;

  // Calibration offsets — subtracted from raw pitch/roll before display.
  // Lets the user zero out a non-flat surface (e.g. their hand) and read the
  // delta from that reference.
  double _pitchOffset = 0;
  double _rollOffset = 0;

  // Idle wobble — runs even when no sensor data so the visuals never freeze.
  late final AnimationController _wobble =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat();

  @override
  void initState() {
    super.initState();
    _initSensor();
  }

  void _initSensor() {
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((e) {
        if (mounted) {
          setState(() {
            _ax = e.x;
            _ay = e.y;
            _az = e.z;
          });
        }
      }, onError: (_) {
        if (mounted) setState(() => _available = false);
      });
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _wobble.dispose();
    super.dispose();
  }

  // Pitch + roll in degrees from raw accelerometer axes.
  double get _pitchRaw =>
      math.atan2(_ay, math.sqrt(_ax * _ax + _az * _az)) * 180 / math.pi;
  double get _rollRaw =>
      math.atan2(-_ax, _az) * 180 / math.pi;
  double get _pitch => _pitchRaw - _pitchOffset;
  double get _roll => _rollRaw - _rollOffset;
  double get _tilt {
    final p = _pitch;
    final r = _roll;
    return math.sqrt(p * p + r * r);
  }

  Future<void> _calibrate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line2),
        ),
        title: Text('Calibrate level', style: TT.title(17)),
        content: Text(
          'Set the current orientation as the new "level" reference. '
          'Place the phone on the surface you want to use as zero, then '
          'confirm.',
          style: TT.body(size: 12.5, color: TT.text2).copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: TT.text2),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: TT.ember),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SET ZERO'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _pitchOffset = _pitchRaw;
        _rollOffset = _rollRaw;
      });
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Level calibrated', style: TT.body(size: 12)),
            backgroundColor: TT.surf2,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  void _resetCalibration() {
    setState(() {
      _pitchOffset = 0;
      _rollOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tilt = _tilt;
    final pitchAbs = _pitch.abs();
    final rollAbs = _roll.abs();
    final level = tilt < 2.0;
    final statusText = level ? 'NEARLY LEVEL' : 'TILTED';
    final statusColor = level ? TT.green : TT.amber;
    final calibrated = _pitchOffset != 0 || _rollOffset != 0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            TTCard(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TT.rLg),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.95,
                            colors: [
                              statusColor.withOpacity(0.08),
                              const Color(0x004CC38A),
                            ],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 240, height: 240,
                        child: _BubbleLevel(
                          ax: _ax - _rollOffset * 0.17,
                          ay: _ay + _pitchOffset * 0.17,
                          wobble: _wobble,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${tilt.toStringAsFixed(1)}°',
                            style: TT.numStyle(size: 32, letterSpacing: -0.02 * 32),
                          ),
                          const SizedBox(width: 8),
                          Text('tilt', style: TT.body(size: 14, color: TT.text2)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusText,
                        style: TT.body(size: 11, w: FontWeight.w800, color: statusColor)
                            .copyWith(letterSpacing: 0.16 * 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.swap_horiz,
                label: 'Pitch',
                value: '${pitchAbs.toStringAsFixed(1)}°',
                ember: true,
              ),
              _MetricSpec(
                icon: Icons.swap_vert,
                label: 'Roll',
                value: '${rollAbs.toStringAsFixed(1)}°',
              ),
            ]),
            const SizedBox(height: 14),
            // Calibration row — replaces the dead "calibrate by drawing a
            // figure-8" instructional text with a real action.
            TTCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              onTap: _calibrate,
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: TT.emberDim,
                      border: Border.all(color: const Color(0x52FF6A2C), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.tune, size: 14, color: TT.ember),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calibrated
                              ? 'Custom zero set'
                              : 'Calibrate level',
                          style: TT.body(size: 13, w: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          calibrated
                              ? 'Tap to recalibrate. Long-press to reset.'
                              : 'Tap to set the current orientation as zero.',
                          style: TT.body(size: 11, color: TT.text3),
                        ),
                      ],
                    ),
                  ),
                  if (calibrated)
                    GestureDetector(
                      onTap: _resetCalibration,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: TT.surf2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: TT.line2),
                        ),
                        child: Text(
                          'RESET',
                          style: TT.mono(size: 9.5, color: TT.text2, letterSpacing: 1.1),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: TT.text3),
                ],
              ),
            ),
          ],
        ),
        if (!_available)
          const Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.bubble_chart_outlined,
              title: 'Accelerometer unavailable',
              subtitle: 'This device has no accelerometer.',
            ),
          ),
      ],
    );
  }
}

class _BubbleLevel extends StatelessWidget {
  final double ax;
  final double ay;
  final AnimationController wobble;
  const _BubbleLevel({required this.ax, required this.ay, required this.wobble});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wobble,
      builder: (_, __) {
        // Subtle wobble — keeps the bubble alive even with zero tilt.
        final t = wobble.value * 2 * math.pi;
        final wobbleDx = math.sin(t) * 1.2;
        final wobbleDy = math.cos(t * 1.3) * 1.0;
        return CustomPaint(
          painter: _BubbleLevelPainter(ax: ax, ay: ay,
              wobble: Offset(wobbleDx, wobbleDy)),
        );
      },
    );
  }
}

class _BubbleLevelPainter extends CustomPainter {
  final double ax; // x accel (left/right tilt)
  final double ay; // y accel (forward/back tilt)
  final Offset wobble;
  _BubbleLevelPainter({required this.ax, required this.ay, required this.wobble});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;

    canvas.drawCircle(
      c, r,
      Paint()..color = const Color(0xFF06080B),
    );
    canvas.drawCircle(
      c, r,
      Paint()
        ..color = TT.line2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Concentric rings.
    for (final rr in [90.0, 70.0, 50.0, 30.0]) {
      canvas.drawCircle(
        c, rr,
        Paint()
          ..color = const Color(0x0FFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Crosshair.
    final ch = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ch);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ch);

    // Ember target ring (dashed).
    _drawDashedCircle(canvas, c, 22,
        Paint()
          ..color = TT.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Bubble position from raw accel. Standard phone orientation:
    //   ax > 0 → tilted right     → bubble should move LEFT (negative)
    //   ay > 0 → tilted forward   → bubble should move UP   (negative)
    // Normalize to [-1, 1] using gravity, clamp at ~0.85 of radius.
    final nx = (-ax / 9.8).clamp(-0.85, 0.85);
    final ny = (ay / 9.8).clamp(-0.85, 0.85);
    final mag = math.sqrt(nx * nx + ny * ny);
    final scale = mag > 0.85 ? 0.85 / mag : 1.0;
    const bubbleR = 22.0;
    final bx = c.dx + nx * scale * (r - bubbleR - 4) + wobble.dx;
    final by = c.dy + ny * scale * (r - bubbleR - 4) + wobble.dy;
    final bubble = Offset(bx, by);

    // Bubble — green glass with soft glow.
    canvas.drawCircle(
      bubble, 22,
      Paint()
        ..color = const Color(0x224CC38A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      bubble, 18,
      Paint()..color = const Color(0x404CC38A),
    );
    canvas.drawCircle(
      bubble, 18,
      Paint()
        ..color = TT.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Highlight pip on the bubble.
    canvas.drawCircle(
      bubble + const Offset(-5, -5), 4,
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const segments = 24;
    for (var i = 0; i < segments; i++) {
      if (i.isOdd) continue;
      final a1 = (i / segments) * 2 * math.pi;
      final a2 = ((i + 1) / segments) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final path = Path()..addArc(rect, a1, a2 - a1);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BubbleLevelPainter old) =>
      old.ax != ax || old.ay != ay || old.wobble != wobble;
}

// ──────────────────────────── TORCH ─────────────────────────────────────────

class _TorchTool extends StatefulWidget {
  const _TorchTool();

  @override
  State<_TorchTool> createState() => _TorchToolState();
}

class _TorchToolState extends State<_TorchTool> with SingleTickerProviderStateMixin {
  bool _on = false;
  bool _available = true;

  // Strobe (SOS) mode — runs a Morse-coded loop while active.
  bool _strobeActive = false;
  Future<void>? _strobeTask;

  late final AnimationController _flicker =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    try {
      final ok = await TorchLight.isTorchAvailable();
      if (mounted) setState(() => _available = ok);
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _setTorch(bool on) async {
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (_) {
      if (mounted) setState(() => _available = false);
    }
  }

  Future<void> _toggle() async {
    if (!_available) return;
    // If strobe is running, killing the toggle should stop it cleanly first.
    if (_strobeActive) {
      await _stopStrobe();
      return;
    }
    final next = !_on;
    await _setTorch(next);
    if (mounted) setState(() => _on = next);
  }

  Future<void> _startStrobe() async {
    if (!_available || _strobeActive) return;
    setState(() {
      _strobeActive = true;
      _on = false;
    });
    _strobeTask = _runStrobe();
  }

  Future<void> _stopStrobe() async {
    setState(() => _strobeActive = false);
    await _strobeTask;
    await _setTorch(false);
    if (mounted) setState(() => _on = false);
  }

  Future<void> _runStrobe() async {
    // SOS in Morse: ... --- ...   Dot = 200ms, dash = 600ms, intra-letter gap
    // 200ms, letter gap 600ms, word gap 1400ms.
    const sequence = <int>[
      // S
      200, 200, 200, 200, 200,
      // letter gap
      600,
      // O
      600, 200, 600, 200, 600,
      // letter gap
      600,
      // S
      200, 200, 200, 200, 200,
      // word gap (loop wait)
      1400,
    ];
    var on = true;
    while (_strobeActive && mounted) {
      for (var i = 0; i < sequence.length; i++) {
        if (!_strobeActive || !mounted) break;
        if (i == sequence.length - 1 ||
            i == 5 ||
            i == 11) {
          // long off gap segments — never turn the torch on
          await _setTorch(false);
          if (mounted) setState(() => _on = false);
        } else {
          await _setTorch(on);
          if (mounted) setState(() => _on = on);
        }
        await Future.delayed(Duration(milliseconds: sequence[i]));
        on = !on;
      }
    }
  }

  @override
  void dispose() {
    // Best-effort: turn the torch off when leaving so it doesn't get stuck on.
    _strobeActive = false;
    if (_on) {
      TorchLight.disableTorch().catchError((_) {});
    }
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeLabel = _strobeActive ? 'SOS' : (_on ? 'Steady' : 'Off');
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            TTCard(
              padding: const EdgeInsets.fromLTRB(18, 32, 18, 28),
              child: SizedBox(
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_on)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _flicker,
                            builder: (_, __) {
                              final t = Curves.easeInOut.transform(_flicker.value);
                              return Opacity(
                                opacity: 0.9 + 0.1 * t,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(TT.rLg),
                                    gradient: const RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.9,
                                      colors: [Color(0x73FFEFAA), Color(0x26FF8A4D), Color(0x00FF8A4D)],
                                      stops: [0.0, 0.4, 0.75],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TorchButton(
                          on: _on,
                          onTap: _available ? _toggle : () {},
                        ),
                        const SizedBox(height: 18),
                        Text(
                          !_available
                              ? 'NO FLASHLIGHT AVAILABLE'
                              : _strobeActive
                                  ? 'TORCH · SOS'
                                  : 'TORCH · ${_on ? 'ON' : 'OFF'}',
                          style: TT.body(
                                  size: 13,
                                  w: FontWeight.w800,
                                  color: !_available
                                      ? TT.text3
                                      : (_on || _strobeActive
                                          ? TT.ember
                                          : TT.text3))
                              .copyWith(letterSpacing: 0.2 * 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _available
                              ? (_strobeActive
                                  ? 'Tap the lamp to stop SOS'
                                  : 'Tap the lamp to toggle')
                              : 'This device has no torch.',
                          style: TT.mono(size: 11, color: TT.text3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.local_fire_department_outlined,
                label: 'Mode',
                value: modeLabel,
                ember: _on || _strobeActive,
              ),
              _MetricSpec(
                icon: Icons.warning_amber_outlined,
                label: 'Strobe',
                value: _strobeActive ? 'ON' : 'OFF',
                ember: _strobeActive,
                onTap: !_available
                    ? null
                    : (_strobeActive ? _stopStrobe : _startStrobe),
              ),
            ]),
            const SizedBox(height: 14),
            _Callout(
              icon: _strobeActive ? Icons.sos : Icons.tips_and_updates_outlined,
              color: _strobeActive ? TT.red : TT.blue,
              text: _strobeActive
                  ? 'Sending SOS in Morse — three short, three long, three short.'
                  : 'Tap the strobe tile to start an SOS pattern.',
            ),
          ],
        ),
      ],
    );
  }
}

class _TorchButton extends StatefulWidget {
  final bool on;
  final VoidCallback onTap;
  const _TorchButton({required this.on, required this.onTap});

  @override
  State<_TorchButton> createState() => _TorchButtonState();
}

class _TorchButtonState extends State<_TorchButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: TT.dMed,
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on
                ? const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: [Color(0xFFFFEFAA), Color(0xFFFF8A4D), Color(0xFFD6291F)],
                    stops: [0.0, 0.6, 1.0],
                  )
                : const RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    radius: 0.95,
                    colors: [Color(0xFF2A313C), Color(0xFF0A0C0F)],
                  ),
            border: Border.all(
              color: on ? const Color(0xFFFFD5A0) : const Color(0xFF2A313C),
              width: 3,
            ),
            boxShadow: on
                ? const [BoxShadow(color: Color(0xB3FF8A4D), blurRadius: 50, spreadRadius: 0)]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.local_fire_department,
            size: 56,
            color: on ? TT.emberInk : TT.text3,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── ALTIMETER ─────────────────────────────────────

class _AltimeterTool extends StatefulWidget {
  final _ToolPrefs prefs;
  const _AltimeterTool({required this.prefs});

  @override
  State<_AltimeterTool> createState() => _AltimeterToolState();
}

class _AltimeterToolState extends State<_AltimeterTool> {
  Position? _pos;
  double? _firstAltitude;
  double _minAlt = double.infinity;
  double _maxAlt = double.negativeInfinity;
  bool _available = true;
  String? _error;
  StreamSubscription<Position>? _sub;

  // Rolling altitude history fed into the spark chart so the line responds to
  // real data instead of a hard-coded curve.
  final List<_AltSample> _history = [];
  static const int _maxSamples = 240; // ~2h at 30s tick / unlimited otherwise

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  void _initLocation() {
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      ).listen(
        (p) {
          if (!mounted) return;
          setState(() {
            _pos = p;
            _firstAltitude ??= p.altitude;
            if (p.altitude < _minAlt) _minAlt = p.altitude;
            if (p.altitude > _maxAlt) _maxAlt = p.altitude;
            _history.add(_AltSample(
              when: p.timestamp,
              altitude: p.altitude,
            ));
            if (_history.length > _maxSamples) {
              _history.removeRange(0, _history.length - _maxSamples);
            }
          });
        },
        onError: (e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _available = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _fmtAlt(double m) {
    final v = widget.prefs.useImperial ? m * 3.28084 : m;
    final rounded = v.round();
    if (rounded.abs() < 1000) return '$rounded';
    // Add a thousands separator.
    final s = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${rounded < 0 ? '-' : ''}$buf';
  }

  void _resetMinMax() {
    setState(() {
      _firstAltitude = _pos?.altitude;
      _minAlt = _pos?.altitude ?? double.infinity;
      _maxAlt = _pos?.altitude ?? double.negativeInfinity;
      _history.clear();
      if (_pos != null) {
        _history.add(_AltSample(when: _pos!.timestamp, altitude: _pos!.altitude));
      }
    });
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Min / max reset', style: TT.body(size: 12)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _openHistorySheet() {
    if (_history.length < 2) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => _AltitudeHistorySheet(
        history: _history,
        useImperial: widget.prefs.useImperial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = _pos != null;
    final unit = widget.prefs.useImperial ? 'ft' : 'm';
    final altM = _pos?.altitude ?? 0;
    final delta = (hasFix && _firstAltitude != null)
        ? (altM - _firstAltitude!)
        : 0.0;
    final deltaDisp = widget.prefs.useImperial ? delta * 3.28084 : delta;
    final deltaPositive = delta >= 0;
    // Show metres and the alternate unit so the user always has a quick cross-
    // reference even when prefs is set to imperial.
    final altPrimary = hasFix ? _fmtAlt(altM) : '—';
    final altSecondary = hasFix
        ? widget.prefs.useImperial
            ? '${altM.toStringAsFixed(0)} m'
            : '${(altM * 3.28084).toStringAsFixed(0)} ft'
        : (widget.prefs.useImperial ? '— m' : '— ft');

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            // Swipe horizontally to reset session min/max. Wrapped around the
            // whole hero card so the gesture target is generous.
            Dismissible(
              key: const ValueKey('altimeter-reset'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (_) async {
                _resetMinMax();
                return false; // keep the widget mounted
              },
              background: const _SwipeHint(
                alignment: Alignment.centerLeft,
                icon: Icons.restart_alt,
                label: 'RESET',
              ),
              secondaryBackground: const _SwipeHint(
                alignment: Alignment.centerRight,
                icon: Icons.restart_alt,
                label: 'RESET',
              ),
              child: TTCard(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                onTap: _history.length >= 2 ? _openHistorySheet : null,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(TT.rLg),
                            gradient: const RadialGradient(
                              center: Alignment(0, 1.0),
                              radius: 0.9,
                              colors: [Color(0x1FFF6A2C), Color(0x00FF6A2C)],
                              stops: [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CURRENT ELEVATION',
                          textAlign: TextAlign.center,
                          style: TT.label(size: 11, color: TT.text3, letterSpacing: 0.18 * 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              altPrimary,
                              style: TT.numStyle(
                                size: 56,
                                color: TT.ember,
                                w: FontWeight.w900,
                                letterSpacing: -0.03 * 56,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(unit, style: TT.body(size: 20, color: TT.text2, w: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              deltaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12,
                              color: deltaPositive ? TT.green : TT.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasFix
                                  ? '${deltaPositive ? '+' : ''}'
                                      '${deltaDisp.toStringAsFixed(0)} $unit this session'
                                  : 'Waiting for GPS fix',
                              style: TT.mono(
                                size: 11,
                                color: hasFix
                                    ? (deltaPositive ? TT.green : TT.amber)
                                    : TT.text3,
                                w: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 3, height: 3,
                              decoration: const BoxDecoration(color: TT.text3, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(altSecondary, style: TT.mono(size: 11, color: TT.text3)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 80,
                          child: CustomPaint(
                            painter: _SparkPainter(
                              samples: _history,
                              useImperial: widget.prefs.useImperial,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SparkAxisLabels(history: _history),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.arrow_upward,
                label: 'Delta',
                value: hasFix
                    ? '${deltaPositive ? '+' : ''}'
                        '${deltaDisp.toStringAsFixed(0)}'
                    : '—',
                unit: unit,
                ember: true,
              ),
              _MetricSpec(
                icon: Icons.center_focus_strong_outlined,
                label: 'GPS Acc',
                value: hasFix ? '+/- ${_pos!.accuracy.toStringAsFixed(0)}' : '—',
                unit: 'm',
              ),
              _MetricSpec(
                icon: Icons.terrain_outlined,
                label: 'Max',
                value: _maxAlt.isFinite ? _fmtAlt(_maxAlt) : '—',
                unit: unit,
              ),
              _MetricSpec(
                icon: Icons.layers_outlined,
                label: 'Min',
                value: _minAlt.isFinite ? _fmtAlt(_minAlt) : '—',
                unit: unit,
              ),
            ]),
            const SizedBox(height: 14),
            const _Callout(
              icon: Icons.swipe_outlined,
              color: TT.blue,
              text: 'Swipe the card to reset min/max. Tap to expand the trace.',
            ),
          ],
        ),
        if (!_available || _error != null)
          Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.gps_off_outlined,
              title: 'Location unavailable',
              subtitle: _error ?? 'Permission needed to read altitude.',
            ),
          ),
      ],
    );
  }
}

class _AltSample {
  final DateTime when;
  final double altitude;
  const _AltSample({required this.when, required this.altitude});
}

class _SwipeHint extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final String label;
  const _SwipeHint({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0x33FF6A2C),
        borderRadius: BorderRadius.circular(TT.rLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: TT.ember),
          const SizedBox(width: 8),
          Text(label,
              style: TT.mono(size: 11, color: TT.ember, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<_AltSample> samples;
  final bool useImperial;
  _SparkPainter({required this.samples, required this.useImperial});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final empty = Paint()
      ..color = TT.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Baseline so the chart never feels visually broken when empty.
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), empty);

    if (samples.length < 2) return;

    final values = samples
        .map((s) => useImperial ? s.altitude * 3.28084 : s.altitude)
        .toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1.0 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final t = i / (values.length - 1);
      final x = t * w;
      // Pad top/bottom a touch so peaks/troughs don't graze the edges.
      final y = h - 8 - ((values[i] - minV) / span) * (h - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill underneath.
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x80FF6A2C), Color(0x00FF6A2C)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Endpoint dot at the current sample.
    final lastValue = values.last;
    final endpoint = Offset(
      w,
      h - 8 - ((lastValue - minV) / span) * (h - 16),
    );
    canvas.drawCircle(
      endpoint, 5,
      Paint()..color = const Color(0x40FF6A2C),
    );
    canvas.drawCircle(
      endpoint, 3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      endpoint, 3,
      Paint()
        ..color = TT.ember
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.samples.length != samples.length ||
      old.useImperial != useImperial;
}

class _SparkAxisLabels extends StatelessWidget {
  final List<_AltSample> history;
  const _SparkAxisLabels({required this.history});

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('—', style: TT.mono(size: 9, color: TT.text3)),
          Text('Waiting for GPS', style: TT.mono(size: 9, color: TT.text3)),
          Text('NOW', style: TT.mono(size: 9, color: TT.ember)),
        ],
      );
    }
    final first = history.first.when.toLocal();
    final mid = history[history.length ~/ 2].when.toLocal();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_fmt(first), style: TT.mono(size: 9, color: TT.text3)),
        Text(_fmt(mid), style: TT.mono(size: 9, color: TT.text3)),
        Text('NOW', style: TT.mono(size: 9, color: TT.ember)),
      ],
    );
  }
}

class _AltitudeHistorySheet extends StatelessWidget {
  final List<_AltSample> history;
  final bool useImperial;
  const _AltitudeHistorySheet({
    required this.history,
    required this.useImperial,
  });

  @override
  Widget build(BuildContext context) {
    final unit = useImperial ? 'ft' : 'm';
    final values = history
        .map((s) => useImperial ? s.altitude * 3.28084 : s.altitude)
        .toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final last = history.last;
    final first = history.first;
    final span = last.when.difference(first.when);
    String fmtTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String fmtSpan(Duration d) {
      if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
      if (d.inMinutes > 0) return '${d.inMinutes}m';
      return '${d.inSeconds}s';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: TT.line2,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Altitude trace', style: TT.title(18)),
          const SizedBox(height: 4),
          Text(
            'Live samples since this tool was opened.',
            style: TT.body(size: 11.5, color: TT.text3),
          ),
          const SizedBox(height: 16),
          TTCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: _SparkPainter(
                      samples: history,
                      useImperial: useImperial,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmtTime(first.when.toLocal()),
                        style: TT.mono(size: 10, color: TT.text3)),
                    Text(fmtTime(last.when.toLocal()),
                        style: TT.mono(size: 10, color: TT.ember)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MetricGrid(tiles: [
            _MetricSpec(
              icon: Icons.terrain_outlined,
              label: 'Max',
              value: maxV.toStringAsFixed(0),
              unit: unit,
              ember: true,
            ),
            _MetricSpec(
              icon: Icons.layers_outlined,
              label: 'Min',
              value: minV.toStringAsFixed(0),
              unit: unit,
            ),
            _MetricSpec(
              icon: Icons.timer_outlined,
              label: 'Span',
              value: fmtSpan(span),
            ),
            _MetricSpec(
              icon: Icons.show_chart,
              label: 'Samples',
              value: '${history.length}',
            ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: TT.text2),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── SUN ───────────────────────────────────────────

class _SunTool extends StatefulWidget {
  final _ToolPrefs prefs;
  const _SunTool({required this.prefs});

  @override
  State<_SunTool> createState() => _SunToolState();
}

class _SunToolState extends State<_SunTool> {
  Position? _pos;
  bool _waiting = true;
  String? _error;
  StreamSubscription<Position>? _sub;
  bool _refreshing = false;

  // Tick the UI every 30 seconds so "time to peak" / current time stay live.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _initLocation() {
    try {
      _sub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).listen(
        (p) {
          if (mounted) {
            setState(() {
              _pos = p;
              _waiting = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
              _waiting = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _waiting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        final next = await Geolocator.requestPermission();
        if (next == LocationPermission.denied ||
            next == LocationPermission.deniedForever) {
          throw Exception('Location permission required');
        }
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _pos = p;
          _error = null;
          _waiting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    if (widget.prefs.sunTime24) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h12:${local.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _copyTime(String label, DateTime? dt) {
    if (dt == null) return;
    final str = _formatTime(dt);
    Clipboard.setData(ClipboardData(text: '$label $str'));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copied: $str', style: TT.body(size: 12)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasFix = _pos != null;
    DateTime? sunrise;
    DateTime? sunset;
    double progress = 0;
    final now = DateTime.now();

    if (hasFix) {
      final sun = SunUtils.calculate(now, _pos!.latitude, _pos!.longitude);
      sunrise = sun['sunrise'];
      sunset = sun['sunset'];
      if (sunrise != null && sunset != null) {
        if (now.isBefore(sunrise)) {
          progress = 0;
        } else if (now.isAfter(sunset)) {
          progress = 1;
        } else {
          progress = now.difference(sunrise).inMinutes /
              sunset.difference(sunrise).inMinutes;
        }
      }
    }

    final dayLen = (sunrise != null && sunset != null)
        ? SunUtils.formatDuration(sunset.difference(sunrise))
        : '—';

    // Golden hour: ±30min around sunrise/sunset for a quick photographer cue.
    final goldenStart = sunset?.subtract(const Duration(minutes: 60));
    final goldenEnd = sunset?.add(const Duration(minutes: 0));

    // Status copy: time-to-peak when sun is up; otherwise countdown to next event.
    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      if (h <= 0) return '${m}M';
      return '${h}H ${m}M';
    }

    String status = 'TAP TO ENABLE LOCATION';
    if (hasFix && sunrise != null && sunset != null) {
      final peak = sunrise.add(sunset.difference(sunrise) ~/ 2);
      if (now.isBefore(sunrise)) {
        status = 'SUN IS DOWN · ${fmt(sunrise.difference(now))} TO SUNRISE';
      } else if (now.isAfter(sunset)) {
        status = 'AFTER SUNSET · PLAN FOR DARKNESS';
      } else if (now.isBefore(peak)) {
        status = 'SUN IS UP · ${fmt(peak.difference(now))} TO PEAK';
      } else {
        status = 'SUN IS UP · ${fmt(sunset.difference(now))} TO SUNSET';
      }
    }

    final clockNow = widget.prefs.sunTime24
        ? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
        : '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')}';
    final ampm = widget.prefs.sunTime24 ? '' : (now.hour >= 12 ? 'PM' : 'AM');

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            TTCard(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TT.rLg),
                          gradient: const RadialGradient(
                            center: Alignment(0, 1.0),
                            radius: 0.95,
                            colors: [Color(0x2EFF8A4D), Color(0x00FF8A4D)],
                            stops: [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: CustomPaint(
                          painter: _SunArcPainter(progress: progress),
                          size: Size.infinite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            clockNow,
                            style: TT.numStyle(size: 38, w: FontWeight.w900, letterSpacing: -0.025 * 38),
                          ),
                          if (ampm.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(ampm, style: TT.body(size: 16, color: TT.text2)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TT.body(size: 11, w: FontWeight.w800, color: TT.ember)
                            .copyWith(letterSpacing: 0.18 * 11),
                      ),
                      const SizedBox(height: 12),
                      _SunPillStrip(
                        sunrise: sunrise,
                        sunset: sunset,
                        goldenStart: goldenStart,
                        goldenEnd: goldenEnd,
                        format: _formatTime,
                        onCopy: _copyTime,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MetricGrid(tiles: [
              _MetricSpec(
                icon: Icons.wb_twilight,
                label: 'Sunrise',
                value: sunrise != null ? _formatTime(sunrise) : '—',
                ember: true,
                onTap: sunrise == null ? null : () => _copyTime('Sunrise', sunrise),
              ),
              _MetricSpec(
                icon: Icons.nights_stay_outlined,
                label: 'Sunset',
                value: sunset != null ? _formatTime(sunset) : '—',
                onTap: sunset == null ? null : () => _copyTime('Sunset', sunset),
              ),
              _MetricSpec(
                icon: Icons.schedule,
                label: 'Daylight',
                value: dayLen,
              ),
              _MetricSpec(
                icon: Icons.place_outlined,
                label: 'Location',
                value: hasFix
                    ? '${_pos!.latitude.toStringAsFixed(2)},${_pos!.longitude.toStringAsFixed(2)}'
                    : '—',
                onTap: !hasFix
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(
                          text:
                              '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}',
                        ));
                        ScaffoldMessenger.maybeOf(context)
                          ?..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('Coordinates copied',
                                  style: TT.body(size: 12)),
                              backgroundColor: TT.surf2,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                      },
              ),
            ]),
            const SizedBox(height: 14),
            TTCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              onTap: _refreshing ? null : _manualRefresh,
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: TT.emberDim,
                      border: Border.all(color: const Color(0x52FF6A2C), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _refreshing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: TT.ember,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 14, color: TT.ember),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _refreshing ? 'Refreshing GPS' : 'Refresh location',
                          style: TT.body(size: 13, w: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasFix
                              ? 'Last fix +/- ${_pos!.accuracy.toStringAsFixed(0)} m'
                              : 'Tap to request a fresh GPS fix.',
                          style: TT.body(size: 11, color: TT.text3),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: TT.text3),
                ],
              ),
            ),
          ],
        ),
        if (!hasFix && !_waiting)
          Positioned.fill(
            child: _ToolUnavailableOverlay(
              icon: Icons.wb_sunny_outlined,
              title: 'No location fix',
              subtitle: _error ?? 'Tap refresh to enable location for live data.',
            ),
          ),
      ],
    );
  }
}

class _SunPillStrip extends StatelessWidget {
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? goldenStart;
  final DateTime? goldenEnd;
  final String Function(DateTime dt) format;
  final void Function(String label, DateTime? dt) onCopy;
  const _SunPillStrip({
    required this.sunrise,
    required this.sunset,
    required this.goldenStart,
    required this.goldenEnd,
    required this.format,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required IconData icon,
      required String label,
      required DateTime? dt,
      required Color color,
    }) {
      final disabled = dt == null;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => onCopy(label, dt),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(disabled ? 0.04 : 0.10),
            border: Border.all(
              color: color.withOpacity(disabled ? 0.14 : 0.40),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 12,
                  color: disabled ? TT.text3 : color),
              const SizedBox(width: 6),
              Text(
                disabled ? '$label —' : '$label ${format(dt)}',
                style: TT.mono(
                  size: 10,
                  color: disabled ? TT.text3 : color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        pill(
          icon: Icons.wb_twilight,
          label: 'SUNRISE',
          dt: sunrise,
          color: TT.ember,
        ),
        pill(
          icon: Icons.nights_stay_outlined,
          label: 'SUNSET',
          dt: sunset,
          color: TT.blue,
        ),
        pill(
          icon: Icons.wb_iridescent,
          label: 'GOLDEN',
          dt: goldenStart,
          color: TT.amber,
        ),
      ],
    );
  }
}

class _SunArcPainter extends CustomPainter {
  /// 0..1 progress along the daytime arc (left = sunrise, right = sunset).
  final double progress;
  _SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    // Horizon line.
    canvas.drawLine(
      const Offset(0, 130), Offset(w, 130),
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = 1,
    );

    // Arc — Q curve approximation: M 20 130 Q w/2 -20 (w-20) 130
    final arc = Path()
      ..moveTo(20, 130)
      ..quadraticBezierTo(w / 2, -20, w - 20, 130);

    canvas.drawPath(
      arc,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FF8A4D), Color(0xE6FF8A4D), Color(0x00FF8A4D)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, 160))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sun position along the bezier at t = progress.
    final t = progress.clamp(0.0, 1.0);
    final sunX = (1 - t) * (1 - t) * 20 +
        2 * (1 - t) * t * (w / 2) +
        t * t * (w - 20);
    final sunY = (1 - t) * (1 - t) * 130 +
        2 * (1 - t) * t * (-20) +
        t * t * 130;

    // Only show the sun when it's actually above the horizon.
    final visible = t > 0.01 && t < 0.99;

    if (visible) {
      // Sun rays.
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(
          Offset(sunX + math.cos(a) * 18, sunY + math.sin(a) * 18),
          Offset(sunX + math.cos(a) * 24, sunY + math.sin(a) * 24),
          Paint()
            ..color = const Color(0xB3FF8A4D)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
      // Sun glow + disc.
      canvas.drawCircle(
        Offset(sunX, sunY), 22,
        Paint()
          ..color = const Color(0x66FF8A4D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(sunX, sunY), 14,
        Paint()..color = TT.ember2,
      );
    }

    // Sunrise/sunset markers.
    canvas.drawCircle(const Offset(20, 130), 3, Paint()..color = TT.ember3);
    canvas.drawCircle(Offset(w - 20, 130), 3, Paint()..color = TT.blue);
  }

  @override
  bool shouldRepaint(_SunArcPainter old) => old.progress != progress;
}

// ──────────────────────────── INFO ──────────────────────────────────────────

class _InfoTool extends StatelessWidget {
  const _InfoTool();

  static const _tips = <_InfoTip>[
    _InfoTip(
      icon: Icons.ac_unit,
      title: 'Hypothermia warning signs',
      body:
          'Persistent shivering, slurred speech, clumsy hands, drowsiness — '
          'tap for the full field treatment checklist.',
      detail: _hypothermiaDetail,
    ),
    _InfoTip(
      icon: Icons.healing,
      title: 'Snake bite first aid',
      body:
          'Stay calm, immobilise the limb, mark the swelling — never cut, '
          'suck or apply ice. Tap for the full sequence.',
      detail: _snakeBiteDetail,
    ),
    _InfoTip(
      icon: Icons.bolt_outlined,
      title: 'Lightning safety',
      body:
          'If under 30 s between flash and thunder, you are inside the strike '
          'zone. Tap for crouch-and-cover drill.',
      detail: _lightningDetail,
    ),
    _InfoTip(
      icon: Icons.water_drop_outlined,
      title: 'Hydration & heat',
      body:
          'Thirst lags 1-2 h behind real dehydration. Tap for daily intake '
          'targets and warning signs.',
      detail: _hydrationDetail,
    ),
    _InfoTip(
      icon: Icons.local_fire_department_outlined,
      title: 'Layering & cold protection',
      body:
          'Mountain temperatures drop ~6 °C per 1,000 m. Tap for the wicking / '
          'insulation / shell rule of thumb.',
      detail: _layeringDetail,
    ),
    _InfoTip(
      icon: Icons.battery_charging_full,
      title: 'Battery and signal',
      body:
          'Airplane mode + offline maps multiplies battery life. Tap for the '
          'cold-weather charging trick.',
      detail: _batteryDetail,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      itemCount: _tips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _FadeUpDelayed(
        delay: Duration(milliseconds: 100 + i * 70),
        child: _InfoRow(tip: _tips[i]),
      ),
    );
  }
}

class _InfoTip {
  final IconData icon;
  final String title;
  final String body;
  final List<_InfoSection> detail;
  const _InfoTip({
    required this.icon,
    required this.title,
    required this.body,
    required this.detail,
  });
}

class _InfoSection {
  final String heading;
  final List<String> bullets;
  const _InfoSection(this.heading, this.bullets);
}

class _InfoRow extends StatelessWidget {
  final _InfoTip tip;
  const _InfoRow({required this.tip});

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _InfoDetailScreen(tip: tip),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => _open(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: TT.emberDim,
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(tip.icon, size: 16, color: TT.ember),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: TT.body(size: 13.5, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(tip.body,
                    style: TT.body(size: 11.5, color: TT.text2)
                        .copyWith(height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: TT.text3),
        ],
      ),
    );
  }
}

class _InfoDetailScreen extends StatelessWidget {
  final _InfoTip tip;
  const _InfoDetailScreen({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.55)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 18, 8),
                  child: Row(
                    children: [
                      TTIconBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FIELD GUIDE',
                                style: TT.label(
                                    size: 10.5,
                                    color: TT.text3,
                                    letterSpacing: 1.6)),
                            const SizedBox(height: 2),
                            Text(tip.title, style: TT.title(20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      TTCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: TT.emberDim,
                                border: Border.all(
                                    color: const Color(0x52FF6A2C), width: 1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child:
                                  Icon(tip.icon, size: 16, color: TT.ember),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                tip.body,
                                style: TT.body(size: 12.5, color: TT.text2)
                                    .copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final section in tip.detail) ...[
                        TTCard(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section.heading.toUpperCase(),
                                  style: TT.label(
                                      size: 10.5,
                                      color: TT.ember,
                                      letterSpacing: 1.6)),
                              const SizedBox(height: 10),
                              for (var i = 0; i < section.bullets.length; i++)
                                Padding(
                                  padding:
                                      EdgeInsets.only(bottom: i == section.bullets.length - 1 ? 0 : 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 5, height: 5,
                                        decoration: const BoxDecoration(
                                          color: TT.ember,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          section.bullets[i],
                                          style: TT.body(
                                                  size: 12.5, color: TT.text)
                                              .copyWith(height: 1.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const _Callout(
                        icon: Icons.warning_amber_outlined,
                        color: TT.amber,
                        text:
                            'Field reference only. If life is threatened call '
                            'emergency services and arrange evacuation.',
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

// Detail content kept inline so each tip's full guide travels with the file.
const _hypothermiaDetail = <_InfoSection>[
  _InfoSection('Recognise', [
    'Persistent shivering, often violent in early stages.',
    'Slurred speech, fumbling fingers, stumbling gait.',
    'Confusion, apathy, or unusual drowsiness.',
    'Pale or grey skin, blue lips, weak pulse.',
  ]),
  _InfoSection('Stop the heat loss', [
    'Get out of wind and rain — even a rock wall helps.',
    'Replace any wet layer with dry insulation.',
    'Insulate from the ground with packs or foam.',
    'Cover head and neck; most heat escapes there.',
  ]),
  _InfoSection('Rewarm carefully', [
    'Warm sweet drinks for conscious casualties only.',
    'Skin-to-skin contact inside a sleeping bag works fast.',
    'Apply heat to torso and armpits, not just limbs.',
    'Never rub frozen skin or use direct flame.',
  ]),
  _InfoSection('Evacuate if', [
    'The person cannot stop shivering after 30 minutes.',
    'They become drowsy, irrational or unresponsive.',
    'They have fallen into cold water.',
  ]),
];

const _snakeBiteDetail = <_InfoSection>[
  _InfoSection('Stay calm and still', [
    'Move at least two metres clear of the snake.',
    'Sit or lie the casualty down with the bite below the heart.',
    'Keep activity to a minimum — venom spreads with movement.',
  ]),
  _InfoSection('Immobilise the limb', [
    'Apply a firm crepe bandage from fingers/toes upward, then splint.',
    'Mark the swelling outline with a pen every 15 minutes.',
    'Remove rings, watches, tight clothing before swelling sets in.',
  ]),
  _InfoSection('Do not', [
    'Cut, suck or apply ice or a tourniquet.',
    'Give alcohol or aspirin.',
    'Try to catch the snake — a photo from distance is enough.',
  ]),
  _InfoSection('Call for evacuation', [
    'Note the time of the bite — antivenom timing depends on it.',
    'Use Trailtether SOS or a satellite messenger if no signal.',
    'Provide your coordinates, species description, symptom timeline.',
  ]),
];

const _lightningDetail = <_InfoSection>[
  _InfoSection('Count the gap', [
    'Flash-to-thunder under 30 seconds = strike danger now.',
    'Under 10 seconds = take cover immediately.',
    'Wait 30 minutes after the last thunder before moving.',
  ]),
  _InfoSection('Get low and small', [
    'Leave summits, ridges and exposed slabs first.',
    'Avoid lone trees, fence lines and metal hardware.',
    'Crouch on insulating gear, feet together, head tucked.',
    'Spread the group 5+ metres apart to limit casualties.',
  ]),
  _InfoSection('After the strike', [
    'Begin CPR on anyone unresponsive — they hold no charge.',
    'Treat burns at entry and exit points.',
    'Watch for cardiac arrhythmia for at least 24 hours.',
  ]),
];

const _hydrationDetail = <_InfoSection>[
  _InfoSection('Daily intake targets', [
    'Cool-weather hike: 500-750 ml per hour of moving time.',
    'Hot or high-altitude hike: 750 ml-1 L per hour.',
    'Add electrolytes after 90 minutes of sweating.',
  ]),
  _InfoSection('Dehydration warning signs', [
    'Dark or infrequent urine.',
    'Headache, light-headedness, irritability.',
    'Cramping calves, hamstrings or hands.',
    'Resting pulse climbing 20+ bpm above normal.',
  ]),
  _InfoSection('Field rules', [
    'Drink before you feel thirsty — thirst lags 1-2 hours.',
    'Filter or boil water from any natural source.',
    'Eat salty snacks alongside water to retain it.',
  ]),
];

const _layeringDetail = <_InfoSection>[
  _InfoSection('Layer principles', [
    'Base: wicks moisture off the skin (merino / synthetic).',
    'Mid: traps warmth (fleece, light down or synthetic puffy).',
    'Shell: blocks wind and rain (hardshell or wind shirt).',
  ]),
  _InfoSection('Pack the temperature drop', [
    'Mountain temperatures fall ~6 °C per 1,000 m gained.',
    'Wind chill at 30 km/h doubles the felt cold.',
    'Carry a beanie and gloves on any 3-season day-hike.',
  ]),
  _InfoSection('Adjust on the move', [
    'Ventilate before you sweat — open pit zips early.',
    'Stop, layer up, then start again at every rest stop.',
    'Keep one dry insulation layer in a dry bag for camp.',
  ]),
];

const _batteryDetail = <_InfoSection>[
  _InfoSection('Stretch battery life', [
    'Switch to airplane mode and use offline maps.',
    'Set screen to the lowest readable brightness.',
    'Disable background app refresh and live wallpapers.',
    'Pause non-essential notifications during the hike.',
  ]),
  _InfoSection('Cold-weather charging', [
    'Keep the phone in an inside pocket close to your body.',
    'Charge from a warmed power bank, not a frozen one.',
    'Avoid charging below 0 °C — capacity drops sharply.',
  ]),
  _InfoSection('Field power kit', [
    'Carry one power bank with 2x your phone capacity.',
    'Include a short, durable USB-C cable.',
    'Test the kit end-to-end before each trip.',
  ]),
];

// ──────────────────────────── SHARED PIECES ─────────────────────────────────

/// Convert an altitude in metres to the user's preferred unit and round.
/// Used by both the compass and altimeter tiles so the readouts stay consistent.
String _formatAltShared(double metres, bool useImperial) {
  final v = useImperial ? metres * 3.28084 : metres;
  final rounded = v.round();
  if (rounded.abs() < 1000) return '$rounded';
  final s = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buf';
}

class _MetricSpec {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  final VoidCallback? onTap;
  const _MetricSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.ember = false,
    this.onTap,
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricSpec> tiles;
  const _MetricGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.95,
      ),
      itemBuilder: (_, i) => _FadeUpDelayed(
        delay: Duration(milliseconds: 250 + i * 80),
        child: _MetricTile(spec: tiles[i]),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricSpec spec;
  const _MetricTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: spec.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 12, color: spec.ember ? TT.ember : TT.text3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spec.label.toUpperCase(),
                  style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 0.16 * 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (spec.onTap != null)
                const Icon(Icons.copy_outlined, size: 11, color: TT.text4),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  spec.value,
                  style: TT.numStyle(
                    size: 20,
                    color: spec.ember ? TT.ember : TT.text,
                    letterSpacing: -0.02 * 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (spec.unit != null) ...[
                const SizedBox(width: 4),
                Text(spec.unit!, style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Callout({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TT.body(size: 11, w: FontWeight.w600, color: TT.text2).copyWith(height: 1.4),
            ),
          ),
          // Tiny status pill to keep the visual recipe consistent with other screens.
          const SizedBox(width: 8),
          const TTPill(label: 'TIP'),
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

/// Translucent overlay shown on top of a tool view when its sensor is
/// unavailable or permission is denied. Centred icon + title + subtitle on
/// a dim glassy backdrop.
class _ToolUnavailableOverlay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _ToolUnavailableOverlay({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: const Color(0xCC07090C),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TT.surf,
                shape: BoxShape.circle,
                border: Border.all(color: TT.line2, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: TT.text3),
            ),
            const SizedBox(height: 14),
            Text(title, style: TT.title(16), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TT.body(size: 12, color: TT.text3),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
