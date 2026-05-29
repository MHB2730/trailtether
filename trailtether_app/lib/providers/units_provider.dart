// Trailtether — global metric / imperial unit preference.
//
// All distance, elevation, temperature, speed and pace values flow through
// this provider so the user's choice on the Profile → Units row is honoured
// everywhere in the app. Internally we still store metric (km, m, °C, km/h)
// — conversion happens only at display time.
//
// Storage: SharedPreferences key `tt_units` (`'metric'` or `'imperial'`).
// The key name matches the existing legacy value so users who already toggled
// the setting in v3.1.3 don't lose their preference on upgrade.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

class UnitsProvider extends ChangeNotifier {
  static const _kKey = 'tt_units';
  static const _kImperial = 'imperial';
  static const _kMetric = 'metric';

  UnitSystem _system = UnitSystem.metric;
  bool _loaded = false;

  UnitsProvider() {
    _load();
  }

  UnitSystem get system => _system;
  bool get isMetric => _system == UnitSystem.metric;
  bool get isImperial => _system == UnitSystem.imperial;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == _kImperial) {
        _system = UnitSystem.imperial;
      } else {
        _system = UnitSystem.metric;
      }
    } catch (_) {
      _system = UnitSystem.metric;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSystem(UnitSystem s) async {
    if (_system == s) return;
    _system = s;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kKey, s == UnitSystem.imperial ? _kImperial : _kMetric);
    } catch (_) {/* best effort */}
  }

  Future<void> toggle() =>
      setSystem(isMetric ? UnitSystem.imperial : UnitSystem.metric);

  // ── Distance ───────────────────────────────────────────────────────────
  /// Convert km → mi if imperial, otherwise return km.
  double distanceFromKm(double km) => isImperial ? km * 0.621371 : km;

  String get distanceUnit => isImperial ? 'mi' : 'km';
  String get distanceUnitLong => isImperial ? 'Miles' : 'Kilometres';

  String formatDistance(double km, {int decimals = 1, bool withUnit = true}) {
    final v = distanceFromKm(km);
    final s = v.toStringAsFixed(decimals);
    return withUnit ? '$s $distanceUnit' : s;
  }

  /// "1.5 km" or "0.9 mi" but with `roundIfLarge` so >=10 shows as integer.
  String formatDistanceCompact(double km) {
    final v = distanceFromKm(km);
    if (v >= 100) return '${v.round()} $distanceUnit';
    if (v >= 10) return '${v.toStringAsFixed(1)} $distanceUnit';
    return '${v.toStringAsFixed(2)} $distanceUnit';
  }

  // ── Elevation ──────────────────────────────────────────────────────────
  double elevationFromM(double m) => isImperial ? m * 3.28084 : m;

  String get elevationUnit => isImperial ? 'ft' : 'm';
  String get elevationUnitLong => isImperial ? 'Feet' : 'Metres';

  String formatElevation(double m, {bool withUnit = true}) {
    final v = elevationFromM(m).round();
    final s = _formatThousands(v);
    return withUnit ? '$s $elevationUnit' : s;
  }

  // ── Temperature ────────────────────────────────────────────────────────
  double temperatureFromC(double c) => isImperial ? c * 9 / 5 + 32 : c;

  String get temperatureUnit => isImperial ? '°F' : '°C';

  String formatTemperature(double c, {bool withUnit = true}) {
    final v = temperatureFromC(c).round();
    return withUnit ? '$v$temperatureUnit' : '$v';
  }

  // ── Speed ──────────────────────────────────────────────────────────────
  double speedFromKmh(double kmh) => isImperial ? kmh * 0.621371 : kmh;

  String get speedUnit => isImperial ? 'mph' : 'km/h';

  String formatSpeed(double kmh, {int decimals = 1, bool withUnit = true}) {
    final v = speedFromKmh(kmh);
    final s = v.toStringAsFixed(decimals);
    return withUnit ? '$s $speedUnit' : s;
  }

  // ── Pace ───────────────────────────────────────────────────────────────
  /// Returns formatted "MM:SS /km" or "MM:SS /mi" from total seconds per
  /// metric km. If totKm is zero, returns "--".
  String formatPace(int totalSeconds, double totKm) {
    if (totKm <= 0) return '--';
    final perMetric = totalSeconds / totKm;
    final perDisplay = isImperial ? perMetric / 0.621371 : perMetric;
    final m = perDisplay ~/ 60;
    final s = (perDisplay % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get paceUnit => isImperial ? '/mi' : '/km';

  // ── Helpers ────────────────────────────────────────────────────────────
  static String _formatThousands(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write(',');
    }
    return v < 0 ? '-${buf.toString()}' : buf.toString();
  }
}
