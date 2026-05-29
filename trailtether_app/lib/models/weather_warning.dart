// Weather warnings derived from Open-Meteo forecast data.
//
// SAWS (South African Weather Service) doesn't publish a free API for
// official severe-weather alerts, and the SAWS website warnings page is
// terms-of-service grey to scrape. Instead we derive our own warning
// classes locally from the same forecast fields the rest of the app
// already consumes — precipitation, wind, weather code, temperature.
//
// The thresholds are tuned for the Drakensberg / SA mountain context:
// rain over 25 mm/24h is enough to flood a stream crossing, wind over
// 60 km/h makes ridge walking dangerous, weather code 95+ means
// thunderstorm (lightning above the treeline is the #1 mountain
// killer here), and snow at any rate matters because most South
// Africans aren't equipped for it.
//
// Severities loosely follow SAWS conventions:
//   watch   — keep an eye out, plan around it (amber)
//   warning — significant; postpone if possible (ember)
//   severe  — don't go, life-safety risk (red)

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import 'weather.dart';

enum WarningKind {
  thunderstorm,
  heavyRain,
  strongWind,
  snow,
  freezing,
  extremeHeat,
  extremeUv,
}

enum WarningSeverity { watch, warning, severe }

class WeatherWarning {
  final WarningKind kind;
  final WarningSeverity severity;
  final String headline;
  final String body;

  /// Date this warning applies to. `null` means it's happening right
  /// now (derived from current conditions, not the daily forecast).
  final DateTime? day;
  final IconData icon;

  const WeatherWarning({
    required this.kind,
    required this.severity,
    required this.headline,
    required this.body,
    required this.day,
    required this.icon,
  });

  Color get color {
    switch (severity) {
      case WarningSeverity.watch:
        return TT.amber;
      case WarningSeverity.warning:
        return TT.ember;
      case WarningSeverity.severe:
        return TT.red;
    }
  }

  /// Stable ordering: severe > warning > watch, then earliest day first.
  /// Used by the UI to surface the worst-and-soonest at the top of the
  /// banner list.
  static int compare(WeatherWarning a, WeatherWarning b) {
    final s = b.severity.index.compareTo(a.severity.index);
    if (s != 0) return s;
    final ad = a.day ?? DateTime.now().subtract(const Duration(days: 1));
    final bd = b.day ?? DateTime.now().subtract(const Duration(days: 1));
    return ad.compareTo(bd);
  }
}

/// Pure function — given a `WeatherData` snapshot, produce the list of
/// derived warnings. Empty list when conditions are benign.
List<WeatherWarning> deriveWarnings(WeatherData data) {
  final out = <WeatherWarning>[];

  // ── CURRENT (no date — render as "RIGHT NOW") ─────────────────────────
  final current = data.current;
  if (current.weatherCode == 95) {
    out.add(const WeatherWarning(
      kind: WarningKind.thunderstorm,
      severity: WarningSeverity.warning,
      headline: 'Thunderstorm right now',
      body: 'Lightning risk above treeline. Descend if exposed.',
      day: null,
      icon: Icons.flash_on_rounded,
    ));
  } else if (current.weatherCode == 96 || current.weatherCode == 99) {
    out.add(const WeatherWarning(
      kind: WarningKind.thunderstorm,
      severity: WarningSeverity.severe,
      headline: 'Thunderstorm with hail',
      body: 'Severe storm in progress. Shelter immediately.',
      day: null,
      icon: Icons.flash_on_rounded,
    ));
  }

  // ── DAILY (next 7 days) ───────────────────────────────────────────────
  for (final d in data.daily) {
    // Thunderstorm — biggest single risk in the Drakensberg.
    if (d.weatherCode == 95) {
      out.add(WeatherWarning(
        kind: WarningKind.thunderstorm,
        severity: WarningSeverity.warning,
        headline: 'Thunderstorm expected',
        body:
            'Avoid ridges and exposed sections. Plan to be off-summit by midday.',
        day: d.date,
        icon: Icons.flash_on_rounded,
      ));
    } else if (d.weatherCode == 96 || d.weatherCode == 99) {
      out.add(WeatherWarning(
        kind: WarningKind.thunderstorm,
        severity: WarningSeverity.severe,
        headline: 'Severe thunderstorm + hail',
        body: 'Hail-bearing storm forecast. Postpone exposed hikes.',
        day: d.date,
        icon: Icons.flash_on_rounded,
      ));
    }

    // Rain — by 24h total.
    if (d.precipSum >= 50) {
      out.add(WeatherWarning(
        kind: WarningKind.heavyRain,
        severity: WarningSeverity.severe,
        headline: 'Severe rain — flash flood risk',
        body:
            '${d.precipSum.toStringAsFixed(0)} mm forecast. Stream crossings will be dangerous.',
        day: d.date,
        icon: Icons.water_drop_rounded,
      ));
    } else if (d.precipSum >= 25 && d.precipProbability >= 70) {
      out.add(WeatherWarning(
        kind: WarningKind.heavyRain,
        severity: WarningSeverity.warning,
        headline: 'Heavy rain likely',
        body:
            '${d.precipSum.toStringAsFixed(0)} mm forecast (${d.precipProbability}% chance). Trails will be slippery.',
        day: d.date,
        icon: Icons.water_drop_rounded,
      ));
    }

    // Wind.
    if (d.windSpeedMax >= 90) {
      out.add(WeatherWarning(
        kind: WarningKind.strongWind,
        severity: WarningSeverity.severe,
        headline: 'Severe wind warning',
        body:
            'Gusts up to ${d.windSpeedMax.toStringAsFixed(0)} km/h. Ridge sections unsafe.',
        day: d.date,
        icon: Icons.air_rounded,
      ));
    } else if (d.windSpeedMax >= 60) {
      out.add(WeatherWarning(
        kind: WarningKind.strongWind,
        severity: WarningSeverity.warning,
        headline: 'Strong wind expected',
        body:
            'Gusts up to ${d.windSpeedMax.toStringAsFixed(0)} km/h. Hard on exposed sections.',
        day: d.date,
        icon: Icons.air_rounded,
      ));
    }

    // Snow — important for unprepared SA hikers.
    if (d.weatherCode >= 71 && d.weatherCode <= 77) {
      out.add(WeatherWarning(
        kind: WarningKind.snow,
        severity: WarningSeverity.warning,
        headline: 'Snow forecast',
        body:
            '${weatherDescription(d.weatherCode)}. Carry layers and traction.',
        day: d.date,
        icon: Icons.ac_unit_rounded,
      ));
    } else if (d.weatherCode == 85 || d.weatherCode == 86) {
      out.add(WeatherWarning(
        kind: WarningKind.snow,
        severity: d.weatherCode == 86
            ? WarningSeverity.warning
            : WarningSeverity.watch,
        headline: d.weatherCode == 86 ? 'Heavy snow showers' : 'Snow showers',
        body: 'Slippery sections and reduced visibility likely.',
        day: d.date,
        icon: Icons.ac_unit_rounded,
      ));
    }

    // Freezing — winter overnights without a 4-season bag are dangerous.
    if (d.tempMin <= -5) {
      out.add(WeatherWarning(
        kind: WarningKind.freezing,
        severity: WarningSeverity.warning,
        headline: 'Hard frost overnight',
        body:
            'Low of ${d.tempMin.toStringAsFixed(0)}°C. Carry a 4-season bag if camping.',
        day: d.date,
        icon: Icons.thermostat_rounded,
      ));
    } else if (d.tempMin <= 0) {
      out.add(WeatherWarning(
        kind: WarningKind.freezing,
        severity: WarningSeverity.watch,
        headline: 'Freezing overnight',
        body:
            'Low of ${d.tempMin.toStringAsFixed(0)}°C. Insulated water + extra layers recommended.',
        day: d.date,
        icon: Icons.thermostat_rounded,
      ));
    }

    // Extreme heat — heatstroke risk on exposed sections.
    if (d.tempMax >= 38) {
      out.add(WeatherWarning(
        kind: WarningKind.extremeHeat,
        severity: WarningSeverity.severe,
        headline: 'Extreme heat',
        body:
            'High of ${d.tempMax.toStringAsFixed(0)}°C. Heatstroke risk; hike early or postpone.',
        day: d.date,
        icon: Icons.local_fire_department_rounded,
      ));
    } else if (d.tempMax >= 33) {
      out.add(WeatherWarning(
        kind: WarningKind.extremeHeat,
        severity: WarningSeverity.warning,
        headline: 'High heat',
        body:
            'High of ${d.tempMax.toStringAsFixed(0)}°C. Start early, double water.',
        day: d.date,
        icon: Icons.local_fire_department_rounded,
      ));
    }

    // UV — informational; mountain UV at altitude burns fast.
    if (d.uvIndexMax >= 11) {
      out.add(WeatherWarning(
        kind: WarningKind.extremeUv,
        severity: WarningSeverity.watch,
        headline: 'Extreme UV',
        body:
            'UV index ${d.uvIndexMax.toStringAsFixed(0)}. SPF 50+ and cover up.',
        day: d.date,
        icon: Icons.wb_sunny_rounded,
      ));
    }
  }

  out.sort(WeatherWarning.compare);
  return out;
}
