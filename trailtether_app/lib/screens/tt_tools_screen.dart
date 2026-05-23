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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

import '../core/design_tokens.dart';
import '../providers/units_provider.dart';
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
  static const _kSunTime24 = 'tt_tool_sun_24h';

  double _declination = 0.0; // user-entered declination in degrees (east +)
  bool _useImperial = false; // mirrored from global UnitsProvider; never written
  bool _sunTime24 = true;    // 24h vs 12h sunrise/sunset readout

  double get declination => _declination;
  bool get useImperial => _useImperial;
  bool get sunTime24 => _sunTime24;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _declination = p.getDouble(_kDeclination) ?? 0.0;
    _sunTime24 = p.getBool(_kSunTime24) ?? true;
    notifyListeners();
  }

  /// Pushed in from the host widget every build so the tools UI stays in sync
  /// with the user's global Profile → Units choice without owning its own copy.
  void syncUnits(bool imperial) {
    if (_useImperial == imperial) return;
    _useImperial = imperial;
    notifyListeners();
  }

  Future<void> setDeclination(double v) async {
    _declination = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kDeclination, v);
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
    // Mirror the global Profile → Units selection into the tool's local
    // ChangeNotifier so every tool sub-widget (altimeter, sun, info) sees the
    // user's choice without managing its own duplicate switch.
    final globalUnits = context.watch<UnitsProvider>();
    _prefs.syncUnits(globalUnits.isImperial);
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

            // Units mirror — read-only. The single source of truth lives in
            // Profile → Units (Settings) so the user can't get into a state
            // where the altimeter shows ft but everything else shows m.
            _SettingsRow(
              icon: Icons.straighten,
              title: 'Altitude unit',
              subtitle: widget.prefs.useImperial
                  ? 'Showing feet · change in Profile → Units'
                  : 'Showing metres · change in Profile → Units',
              trailing: Text(
                widget.prefs.useImperial ? 'FT' : 'M',
                style: TT.mono(
                  size: 13,
                  color: TT.ember,
                  letterSpacing: 0.06 * 13,
                  w: FontWeight.w800,
                ),
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
      // 1. Are location services even on at the OS level?
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        // Bounce the user out to Android's Location Services settings.
        await Geolocator.openLocationSettings();
        throw Exception('Location services are turned off');
      }
      // 2. Check + request permission. If the user permanently denied
      //    previously, requestPermission() will short-circuit back to
      //    deniedForever without re-prompting — we have to send them to
      //    the app settings screen so they can grant it manually.
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        throw Exception(
          'Location permission permanently denied. Enable it in the app settings page, then come back.',
        );
      }
      if (perm == LocationPermission.denied) {
        throw Exception('Location permission required');
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
    _InfoTip(
      icon: Icons.healing_outlined,
      title: 'Blisters and foot care',
      body:
          'Five minutes of taping saves a day of misery. Catch the hot spot '
          'BEFORE the blister.',
      detail: _blistersDetail,
    ),
    _InfoTip(
      icon: Icons.accessible_forward,
      title: 'Sprains, strains and ankles',
      body:
          'The most common hiking injury. RICE in the first hour, walk out on '
          'poles. Tap for the full protocol.',
      detail: _sprainDetail,
    ),
    _InfoTip(
      icon: Icons.thermostat,
      title: 'Heatstroke vs heat exhaustion',
      body:
          'Cool clammy = treat. Hot dry + confused = SOS. Knowing the '
          'difference saves lives.',
      detail: _heatstrokeDetail,
    ),
    _InfoTip(
      icon: Icons.travel_explore,
      title: 'Getting lost — the STOP rule',
      body:
          'Stop. Think. Observe. Plan. Down beats up — but staying put beats '
          'wandering.',
      detail: _gettingLostDetail,
    ),
    _InfoTip(
      icon: Icons.waves,
      title: 'River and stream crossings',
      body:
          'Widest point, unclip the hip belt, face upstream. When in doubt, '
          'walk away — rivers fall fast.',
      detail: _riverCrossingDetail,
    ),
    _InfoTip(
      icon: Icons.terrain,
      title: 'Altitude sickness (AMS)',
      body:
          'The escarpment sits at 3,000 m+. Hangover = mild AMS. Confused or '
          'breathless at rest = descend NOW.',
      detail: _altitudeDetail,
    ),
    _InfoTip(
      icon: Icons.pets_outlined,
      title: 'Wild animal encounters',
      body:
          'Baboons, snakes, ticks. Most flee — give them the option. Tap for '
          'species-specific protocols.',
      detail: _animalsDetail,
    ),
    _InfoTip(
      icon: Icons.signpost_outlined,
      title: 'Reading maps and trail markers',
      body:
          'V points uphill = stream. Two compass bearings = a fix. Sun at '
          'noon = roughly North (SH).',
      detail: _navigationDetail,
    ),
    _InfoTip(
      icon: Icons.luggage_outlined,
      title: 'Pack weight and load',
      body:
          '10% bodyweight for day, 20% overnight. Heavy items HIGH and CLOSE '
          'to your back, not at the bottom.',
      detail: _packLoadDetail,
    ),
    _InfoTip(
      icon: Icons.hiking,
      title: 'Trekking poles',
      body:
          'Cut knee impact by 25% on descents. Shorten on ups, lengthen on '
          'downs. Plant opposite leg.',
      detail: _trekkingPolesDetail,
    ),
    _InfoTip(
      icon: Icons.timer_outlined,
      title: 'Naismith\'s rule — hike timing',
      body:
          '1 hour per 5 km, plus 1 hour per 600 m up. Add 33% for a heavy '
          'pack. Then multiply by 1.3 for breaks.',
      detail: _timingDetail,
    ),
    _InfoTip(
      icon: Icons.alarm_outlined,
      title: 'Turnaround time discipline',
      body:
          'Pick the clock time before you leave. Summit fever is the #1 '
          'killer in mountain accident reports.',
      detail: _turnaroundDetail,
    ),
    _InfoTip(
      icon: Icons.thunderstorm_outlined,
      title: 'Drakensberg afternoon storms',
      body:
          'Off the escarpment by midday in summer. Towering anvil clouds = '
          'thunderstorm within 2 h.',
      detail: _bergStormsDetail,
    ),
    _InfoTip(
      icon: Icons.cottage_outlined,
      title: 'Cave and shelter etiquette',
      body:
          '125 surveyed caves in the bundle. No fires near rock art, no '
          'trace inside, share the space.',
      detail: _caveEtiquetteDetail,
    ),
    _InfoTip(
      icon: Icons.opacity_outlined,
      title: 'Water purification',
      body:
          'Looks pristine, carries Giardia. Boil, filter, or treat — always. '
          'Tap for the three field methods.',
      detail: _waterDetail,
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

// ──────────────────────────── NEW FIELD-GUIDE TIPS ──────────────────────────
// Beginner essentials + experienced-hiker depth. South-Africa /
// Drakensberg flavoured where relevant. Keep `_InfoSection` blocks
// to 3-5 short bullets so the detail screen stays scannable.

const _blistersDetail = <_InfoSection>[
  _InfoSection('Prevent before you hike', [
    'Break boots in over at least 30 km of normal walking first.',
    'Wear a synthetic or merino liner sock under a thicker hiking sock — friction goes between the socks, not your skin.',
    'Tape known hot spots (heel, ball of foot, little toe) with Leukotape or KT-tape BEFORE the hike, not after.',
    'Trim toenails square and short — long nails crash into the toe box on descents.',
  ]),
  _InfoSection('Catch a hot spot fast', [
    'Any warm or stinging patch = stop now. Five minutes of taping saves a day of misery.',
    'Dry the foot completely, then apply tape over the hot spot AND about 2 cm of skin around it.',
    'Check the matching foot — most hikers blister symmetrically.',
  ]),
  _InfoSection('When a blister is already there', [
    'Do not pop a small intact blister — the skin is your dressing.',
    'For large painful blisters: sterilise a needle, drain from the edge at 2-3 points, leave the skin on.',
    'Cover with a hydrocolloid (Compeed) and tape over the top so the dressing does not migrate.',
  ]),
  _InfoSection('Field repair kit', [
    'Leukotape P · hydrocolloid plasters · sterile needle · alcohol wipes · scissors.',
    'Keep it in a ziplock at the top of your pack — buried = useless.',
  ]),
];

const _sprainDetail = <_InfoSection>[
  _InfoSection('Recognise it on the trail', [
    'Sudden pain + pop or rolling sensation at the ankle/knee.',
    'Swelling within 30 minutes, bruising within hours.',
    'Bearing weight is painful but possible = grade I/II sprain; impossible = grade III or fracture, treat as evacuation.',
  ]),
  _InfoSection('RICE in the first hour', [
    'Rest — stop, do not "walk it off" until you have assessed.',
    'Ice — cold stream water in a buff wrapped around the joint for 15 min.',
    'Compress — figure-of-eight wrap with an elastic bandage or buff. Snug, not numb.',
    'Elevate — joint above heart level while you wait.',
  ]),
  _InfoSection('Walk out safely', [
    'Lace boots tight over the joint and use trekking poles as crutches.',
    'Take the shortest, flattest line out — descend slowly, side-step on steep ground.',
    'Anti-inflammatory (ibuprofen) helps swelling but masks pain — do not push past your real limit.',
  ]),
  _InfoSection('When to call SOS', [
    'Cannot bear weight after 10 minutes of rest.',
    'Joint is visibly deformed or you heard a snap.',
    'Numbness, tingling, or blue toes below the injury — circulation may be compromised.',
  ]),
];

const _heatstrokeDetail = <_InfoSection>[
  _InfoSection('Heat exhaustion (early)', [
    'Heavy sweating, cool clammy skin, weakness, nausea, headache.',
    'Pulse is fast but skin temperature is still normal-ish.',
    'STILL TREATABLE — act now before it tips into heatstroke.',
  ]),
  _InfoSection('Heatstroke (life-threatening)', [
    'Skin is hot and dry OR dripping sweat with confusion / aggression / slurred speech.',
    'Body core above 40 °C. Without rapid cooling, organ damage in 30 minutes.',
    'This is a 911-level emergency — trigger SOS while you start treatment.',
  ]),
  _InfoSection('Cool aggressively', [
    'Move to shade or improvise shade with a tarp / rain jacket.',
    'Strip outer layers. Wet the skin (water, even sweat) and fan continuously — evaporative cooling is the fastest field method.',
    'Cold packs (improvise with a wet buff in a stream) on neck, armpits, groin.',
    'If conscious: sip cool water with electrolytes. Never force fluids on an unconscious casualty.',
  ]),
  _InfoSection('Prevent it tomorrow', [
    'Start hydrated — 500 ml on waking, 250 ml every 30 min while moving in heat.',
    'Add electrolytes (Rehidrat / Game / homemade: 1 L water + ¼ tsp salt + 6 tsp sugar).',
    'Hike before 10:00 and after 15:00 in summer. Long-sleeved white merino beats sunscreen alone.',
  ]),
];

const _gettingLostDetail = <_InfoSection>[
  _InfoSection('STOP — the four letters that save lives', [
    'Stop moving the second you realise you are off-track.',
    'Think — last confirmed landmark, time since, direction.',
    'Observe — terrain, sun position, water flow, sounds (cars, rivers).',
    'Plan — do not act on the first idea; pick the safest option.',
  ]),
  _InfoSection('Stay put rules', [
    'If anyone knows your route + return time, stay where you are. Rescue searches outward from your last known plan.',
    'Make yourself visible: bright clothing on a bush, mirror, headlamp on strobe at dusk.',
    'Three of anything = international distress (3 whistle blasts, 3 fires, 3 stones).',
  ]),
  _InfoSection('Self-rescue priorities (only if no one knows your plan)', [
    'Down beats up. Follow water downhill — most rivers eventually meet a road.',
    'Mark your trail (cairns, broken branches pointing back the way you came) so a search team can follow.',
    'Conserve battery — phone in airplane mode, only check at high points where signal might exist.',
  ]),
  _InfoSection('Before the next hike', [
    'File a tether plan with someone reliable (use Trailtether — that is what it is built for).',
    'Carry a paper backup map of the area, even with offline tiles loaded.',
    'Practice triangulating your position from two visible landmarks until it is muscle memory.',
  ]),
];

const _riverCrossingDetail = <_InfoSection>[
  _InfoSection('Read the water first', [
    'Cross at the WIDEST point — wider means shallower and slower.',
    'Avoid bends — water is fastest and deepest on the outside of a curve.',
    'Look 50 m downstream for what happens if you fall — waterfalls, rapids, strainers (fallen trees) = do not cross here.',
    'Test depth with a trekking pole before each step.',
  ]),
  _InfoSection('Technique', [
    'Unclip hip belt and sternum strap — you must be able to ditch the pack instantly.',
    'Face upstream and side-step, using two trekking poles as a tripod.',
    'In a group: link arms in a line PARALLEL to the flow, strongest at the upstream end.',
    'Footwear stays on. Wet boots beat cut feet on submerged rocks.',
  ]),
  _InfoSection('When to walk away', [
    'Water above mid-thigh on the smallest member of the group.',
    'You cannot see the bottom (silty / fast).',
    'Cannot stand still in the current without bracing.',
    'Camp, wait for levels to drop, or detour. Rivers fall fast after rain — 6 h often halves the flow.',
  ]),
  _InfoSection('If you are swept off', [
    'Feet downstream, on your back, knees bent — push off rocks with your feet, not your hands.',
    'Aggressively swim across the current (not against it) towards the nearest bank.',
    'Ditch the pack only if it is dragging you under — otherwise its buoyancy helps.',
  ]),
];

const _altitudeDetail = <_InfoSection>[
  _InfoSection('Where it kicks in', [
    'Most people feel something above ~2,500 m. The Drakensberg escarpment sits at 3,000–3,400 m — assume mild AMS is normal.',
    'Symptoms are dose-dependent on how fast you ascended, not just elevation.',
    'Genetics matter — some hikers never feel it, others do at 2,000 m.',
  ]),
  _InfoSection('Recognise AMS (mild)', [
    'Headache + one of: nausea, fatigue, dizziness, poor sleep.',
    'It feels like a hangover. If your headache lifts with paracetamol + rest, you are fine to continue cautiously.',
    'Do NOT ascend further on the day symptoms appear.',
  ]),
  _InfoSection('Red flags — descend NOW', [
    'HACE: confusion, ataxia (cannot walk a straight line, drunk-like), severe headache that ignores paracetamol.',
    'HAPE: breathlessness AT REST, pink frothy sputum, crackles in chest, blue lips.',
    'Both are killers in hours, not days. Lose altitude immediately — even 300 m down helps.',
  ]),
  _InfoSection('Acclimatise smart', [
    'Climb high, sleep low. Day hike to the summit, sleep in the valley.',
    'Hydrate aggressively — high altitude air is brutally dry.',
    'No alcohol or sleeping pills above 2,500 m on day one.',
    'Diamox (acetazolamide) helps if started 24 h before ascent. Talk to a doctor before counting on it.',
  ]),
];

const _animalsDetail = <_InfoSection>[
  _InfoSection('Baboons (Drakensberg + Cape)', [
    'Never look one in the eye — that is a threat display. Eyes down, walk past calmly.',
    'Do NOT show food. Hide snacks the moment you spot a troop.',
    'If approached: face them, back away slowly, hold ground. Running triggers chase.',
    'Carry food in dry-bags inside your pack — a backpack pocket is breakfast.',
  ]),
  _InfoSection('Snakes', [
    'Most SA snakes flee. Stomp the ground as you walk through long grass — vibration warns them.',
    'Never put hands or feet anywhere you cannot see — under logs, into rock cracks, into your boots in the morning.',
    'If bitten: stay calm, immobilise the limb, mark the swelling edge with time, evacuate (see Snake bite tip).',
  ]),
  _InfoSection('Insects', [
    'Ticks: check legs, groin, behind knees, hairline at every break. Pull straight out with tweezers, do not twist.',
    'Bees: if attacked, run downwind in a straight line through dense brush. Do not jump in water — they wait.',
  ]),
  _InfoSection('Larger wildlife', [
    'Eland, antelope: keep 50 m. Mothers with young are unpredictable.',
    'Leopard sightings in the Berg are extremely rare and they avoid humans. If you do see one: stand tall, do not turn your back, back away slowly.',
  ]),
];

const _navigationDetail = <_InfoSection>[
  _InfoSection('Reading contour lines', [
    'Close together = steep. Far apart = gentle.',
    'V or U pointing UPHILL = a stream or valley (water flows through the V).',
    'V pointing DOWNHILL = a ridge.',
    'Concentric closed loops = a summit; loops with hachures inside = a depression.',
  ]),
  _InfoSection('Trail markers', [
    'Cairns (stacked rocks): trail goes this way — but verify, vandals build false ones.',
    'Paint blazes: colour tells you which route; double blaze = turn ahead.',
    'No markers for 10+ minutes on a "marked" trail = you have probably stepped off. Backtrack to last confirmed marker.',
  ]),
  _InfoSection('Triangulating your position', [
    'Identify two distant landmarks visible on your map (peaks, river bends).',
    'Take a compass bearing to each, then draw the back-bearings on the map.',
    'You are where the two lines cross. A third bearing tightens the fix.',
  ]),
  _InfoSection('Sun-and-time backup', [
    'In the Southern Hemisphere, the sun is roughly NORTH at midday.',
    'Watch trick: point 12 o\'clock at the sun. Halfway between 12 and the hour hand is NORTH.',
    'Useful when your phone is dead — but always carry a real baseplate compass.',
  ]),
];

const _packLoadDetail = <_InfoSection>[
  _InfoSection('Pack weight rules', [
    'Day hike: max 10% of bodyweight is comfortable.',
    'Overnight: 20% is the upper edge for most people.',
    'Multi-day: under 25% — past that, pace drops 30%+ and injury risk spikes.',
  ]),
  _InfoSection('Load it for balance', [
    'HEAVY items (water, tent, food bag) ride HIGH and CLOSE to your back, between shoulder blades.',
    'Medium items (clothes, cook kit) wrap around the heavy core.',
    'Light items (sleeping bag, puffy) sit at the bottom.',
    'Snacks, map, headlamp, rain jacket = hip-belt pockets / lid for one-handed access.',
  ]),
  _InfoSection('Fit it to your body', [
    'Hip belt sits on the iliac crest (top of hip bones), not the waist. It carries 80% of the load.',
    'Shoulder straps SNUG, not pulling down. Sternum strap horizontal across the chest.',
    'Load lifters: 45° angle between top of strap and pack — if they are flat, the pack is too small.',
  ]),
  _InfoSection('Cut weight smart', [
    'Weigh everything once. The "Big 3" (pack + shelter + sleep system) is where 60% of the weight lives.',
    'Repackage food and toiletries — no boxes, no bottles, no aerosols.',
    'Two of anything is one too many, except socks and emergency comms.',
  ]),
];

const _trekkingPolesDetail = <_InfoSection>[
  _InfoSection('Why they matter', [
    'Reduce knee impact on descents by up to 25%.',
    'Add two more "legs" for balance on river crossings, scree, and uneven ground.',
    'Engage upper body — you carry more weight further with less leg fatigue.',
  ]),
  _InfoSection('Get the length right', [
    'Standing on flat ground: elbow at 90° when the tip touches the ground.',
    'Going UP: shorten by ~5 cm. Going DOWN: lengthen by ~5 cm.',
    'Most modern poles are flick-lock — twist-locks slip when wet, prefer flick.',
  ]),
  _InfoSection('Technique', [
    'Opposite arm + opposite leg, like a natural walk. Hand goes UP through the strap from below.',
    'Plant the pole at the same time as the opposite foot, slightly ahead.',
    'On steep descent: plant both poles together a step ahead, then walk down to them.',
  ]),
  _InfoSection('Care', [
    'Disassemble after every wet hike. Trapped water rusts the springs and freezes joints.',
    'Replace rubber tips before they wear through to metal — metal slips on rock.',
  ]),
];

const _timingDetail = <_InfoSection>[
  _InfoSection('Naismith\'s rule (1892, still works)', [
    '1 hour per 5 km of horizontal distance.',
    'Plus 1 hour per 600 m of ascent.',
    'Example: 12 km with 900 m up = (12/5) + (900/600) = 2.4 + 1.5 = 3.9 hours moving time.',
  ]),
  _InfoSection('Adjustments', [
    'Add 33% for a heavy pack (over 15 kg).',
    'Add 25% for technical terrain (scrambling, boulder fields, soft snow).',
    'Add 1 hr per 300 m of descent below 1,500 m (descent fatigue is real, especially on knees).',
    'Group of 4+: add 20%. You move at the pace of the slowest member, plus regrouping time.',
  ]),
  _InfoSection('Break time matters', [
    'Naismith does not include breaks. Add 10 min snack stop every 2 hours, plus 30-60 min for a real lunch.',
    'Total trip time = moving time × 1.3-1.5 is a realistic plan.',
  ]),
  _InfoSection('Calibrate to YOU', [
    'After every recorded hike, compare actual moving time to Naismith\'s estimate.',
    'Your personal multiplier (e.g. 1.15× faster, 0.9× slower) is more useful than the formula.',
  ]),
];

const _turnaroundDetail = <_InfoSection>[
  _InfoSection('Pick the time before you leave', [
    'A turnaround time is a CLOCK — not a place. "We turn at 14:00 wherever we are."',
    'Calculate it as: sunset − descent time − 1 hr safety buffer.',
    'In the Berg in summer, sunset ~19:00 = turnaround often 13:00-14:00 for a long route.',
  ]),
  _InfoSection('Why it is non-negotiable', [
    'Most mountain accidents happen on the descent, in fading light, on tired legs.',
    '"Summit fever" — pushing for the top despite slipping schedule — is the #1 killer in alpine accident reports.',
    'A summit you do not reach today is a summit you can reach next month.',
  ]),
  _InfoSection('Adjust en route', [
    'If you hit the halfway point AFTER 50% of your moving budget, turn around there. You will not catch up.',
    'Weather closing in (cumulus building, wind shift, temp drop) = bring turnaround forward, not back.',
    'Slowest member sets the pace. Their fitness IS the group\'s capability.',
  ]),
  _InfoSection('Failure modes', [
    'Phone clock not adjusted to local time / DST. Set it manually at the trailhead.',
    'Group disagreement at the deadline. Decide the rule BEFORE you start, not at 13:55 with the summit in sight.',
  ]),
];

const _bergStormsDetail = <_InfoSection>[
  _InfoSection('The Drakensberg pattern', [
    'October-April: classic afternoon thunderstorm cycle. Build from ~13:00, peak 15:00-17:00, often clear by 19:00.',
    'Winter (May-Aug): cold fronts sweep in fast from the SW. Snow above 2,500 m is normal.',
    'Mist forms in valleys overnight, lifts by 09:00. If it sits past 10:00, expect rain.',
  ]),
  _InfoSection('Read the sky', [
    'Towering cumulus with anvil tops = thunderstorm within 2 hours. Get off the escarpment.',
    'Lenticular cloud (lens-shaped) over peaks = high winds aloft, often a front incoming.',
    'Halo around sun or moon = ice crystals high up, warm front in 12-24 h, likely rain.',
  ]),
  _InfoSection('Pre-storm checklist', [
    'Be off ridges and summits by midday in summer. No exceptions on the Amphitheatre.',
    'Identify your bail-out cave or shelter before you commit to the high ground.',
    'Trekking poles + camera tripod = lightning rods. Stow them.',
  ]),
  _InfoSection('Caught out anyway', [
    'Lightning safety: see the Lightning Safety tip — count flash-to-thunder, crouch-and-cover at <30 s.',
    'In hail: face away from the strike direction, hood up, kneel low. Most hail in the Berg is pea-sized but stings.',
    'After the front passes: rivers rise fast. Re-evaluate any planned crossings.',
  ]),
];

const _caveEtiquetteDetail = <_InfoSection>[
  _InfoSection('Find them safely', [
    'The 125 surveyed caves in Trailtether are real overhang shelters, not show-caves.',
    'Approach from below, in daylight. Many entrances are hidden by overhangs and hard to spot from above.',
    'Some are accessed via short scrambles — assess before committing.',
  ]),
  _InfoSection('Leave-no-trace inside', [
    'No fires inside caves with rock art — soot destroys irreplaceable San paintings.',
    'Sleep on a groundsheet, never directly on the cave floor (sand-and-bone middens are archaeology).',
    'Pack out EVERY scrap of food + wrapper. Baboons learn caves and become problem animals.',
    'No graffiti, no carving, no rock-stacking inside cave entrances.',
  ]),
  _InfoSection('Share fairly', [
    'First-come picks their spot, but always leave room for late arrivals — they may be in worse shape than you.',
    'Multi-night occupants take the back; through-hikers get the easy-access front.',
    'Quiet hours from sundown — sound carries oddly inside.',
  ]),
  _InfoSection('Hazards', [
    'Snakes shelter in cracks. Check before placing kit, sleeping in alcoves, or reaching into gear bags.',
    'Loose roof flakes — never camp directly under a fresh-looking scar in the rock.',
    'Floor often slopes towards a drip line. Pitch uphill of any visible water marks.',
  ]),
];

const _waterDetail = <_InfoSection>[
  _InfoSection('Why you must treat it', [
    'Drakensberg streams look pristine but most carry Giardia, Cryptosporidium, or bacterial contamination from livestock.',
    'Symptoms hit 1-7 days after drinking — by then you are off the mountain and have already infected your travel partners.',
    'Even crystal-clear water above the snowline is not safe — wild animals defaecate everywhere.',
  ]),
  _InfoSection('Method 1: boil', [
    'Bring water to a ROLLING boil. At sea level, instant kill. Above 2,000 m, hold for 3 minutes.',
    'Slowest method but kills everything (bacteria, viruses, protozoa).',
    'Burns fuel — not the best multi-day choice.',
  ]),
  _InfoSection('Method 2: filter', [
    'Squeeze filters (Sawyer, Katadyn BeFree) remove bacteria + protozoa, not viruses. Fine for SA mountains.',
    'Backflush after every use — pore clogging is the #1 failure mode.',
    'Freezing destroys hollow-fibre filters. In winter, sleep with the filter in your sleeping bag.',
  ]),
  _InfoSection('Method 3: chemical', [
    'Aquatabs / iodine: 30 min contact time, double for cold or murky water.',
    'Lightest backup option (3 g per trip). Always carry as a redundancy for a broken filter.',
    'Pre-filter visibly cloudy water through a buff or coffee filter first.',
  ]),
  _InfoSection('When you cannot treat', [
    'Source matters: highest possible point on a flowing stream, above any visible animal trail.',
    'Avoid still pools, stagnant tarns, anything downstream of a campsite.',
    'Better thirsty for 2 hours than sick for 2 weeks — but in true emergency, drink. Dehydration kills faster than Giardia.',
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
