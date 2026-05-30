// PC "Base Camp" — Mission Control dashboard.
//
// Wraps the existing live map (MissionControlTab) in the v3 dashboard layout:
// a stat-card row, the live map, an active-hikers panel + summit-weather card,
// and a recent-activity feed. Every panel reads real provider data and shows
// an honest empty state when there's nothing live — no demo numbers.
//
// The map cell embeds MissionControlTab() unchanged, so all realtime wiring
// (team locations, incidents, track points, 3D toggle, trail tap-to-detail)
// is preserved exactly.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/incident.dart';
import '../../models/team.dart';
import '../../models/weather.dart';
import '../../models/weather_warning.dart';
import '../../providers/safety_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/team_tracking_provider.dart';
import '../../providers/weather_provider.dart';
import '../admin/mission_control_tab.dart';
import 'pc_kit.dart';
import 'pc_shell.dart' show PCPageHeader, PCBtn, PCCard, PCStat, PCPill;

class PcMissionControl extends StatelessWidget {
  final VoidCallback onOpenAlerts;
  final VoidCallback onWatchHike;
  const PcMissionControl({
    super.key,
    required this.onOpenAlerts,
    required this.onWatchHike,
  });

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TeamTrackingProvider>();
    final teamProv = context.watch<TeamProvider>();
    final safety = context.watch<SafetyProvider>();
    final weatherProv = context.watch<WeatherProvider>();

    final locs = tracking.teamLocations;
    final live = locs.where((l) => l.isLive || l.isRecent).toList();
    final flagged = locs.where((l) => l.status == 'help' || l.isStale).toList();
    final incidents = safety.incidents;

    final teamName = teamProv.selectedTeam?.name ??
        (teamProv.teams.isNotEmpty ? teamProv.teams.first.name : null);
    final tethered =
        teamProv.teams.fold<int>(0, (s, t) => s + t.members.length);

    final batteries = locs.map((l) => l.batteryPct).whereType<int>().toList();
    final minBattery = batteries.isEmpty ? null : batteries.reduce(math.min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'OVERVIEW',
          title: 'Mission Control',
          sub: Text(_subtitle(
              teamName, tethered, flagged.length, tracking.lastReportAt)),
          actions: [
            PCBtn(
              label:
                  incidents.isEmpty ? 'ALERTS' : 'ALERTS · ${incidents.length}',
              leftIcon: Icons.notifications_none_rounded,
              onTap: onOpenAlerts,
            ),
            PCBtn(
              label: 'WATCH HIKE',
              leftIcon: Icons.visibility_outlined,
              primary: true,
              onTap: onWatchHike,
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 18, 26, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Stat cards ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: PCStat(
                        label: 'Active now',
                        value: '${live.length}',
                        unit: live.length == 1 ? 'hiker' : 'hikers',
                        icon: Icons.people_outline,
                        ember: live.isNotEmpty,
                        sub: live.isEmpty
                            ? 'No hikers live'
                            : (teamName ?? 'Tethered now'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PCStat(
                        label: 'Flagged',
                        value: '${flagged.length}',
                        unit: flagged.length == 1 ? 'hiker' : 'hikers',
                        icon: Icons.warning_amber_rounded,
                        danger: flagged.isNotEmpty,
                        sub: flagged.isEmpty
                            ? 'All on track'
                            : 'Needs attention',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PCStat(
                        label: 'Incidents',
                        value: '${incidents.length}',
                        unit: 'open',
                        icon: Icons.report_gmailerrorred_outlined,
                        warning: incidents.isNotEmpty,
                        sub: incidents.isEmpty
                            ? 'Clean · none open'
                            : 'Across all hikes',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PCStat(
                        label: 'Low battery',
                        value: minBattery?.toString() ?? '—',
                        unit: minBattery != null ? '%' : null,
                        icon: Icons.battery_alert_outlined,
                        warning: minBattery != null && minBattery <= 25,
                        sub: minBattery == null
                            ? 'No battery reported'
                            : 'Lowest reported',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Map + side panels ───────────────────────────────────
                SizedBox(
                  height: 460,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: TT.line),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: const MissionControlTab(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 372,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ActiveHikersPanel(
                                  locations: live.isEmpty ? locs : live),
                            ),
                            const SizedBox(height: 14),
                            _WeatherPanel(
                              weather: weatherProv.currentWeather,
                              warnings: weatherProv.warnings,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _ActivityFeed(
                  incidents: incidents,
                  locations: locs,
                  streaming: live.isNotEmpty,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _subtitle(
      String? team, int tethered, int flagged, DateTime? updated) {
    final parts = <String>[
      team ?? 'No team',
      '$tethered tethered',
      '$flagged flagged',
    ];
    if (updated != null) parts.add('updated ${_hhmm(updated)}');
    return parts.join(' · ');
  }
}

// ── Active hikers ───────────────────────────────────────────────────────────

class _ActiveHikersPanel extends StatelessWidget {
  final List<TeamMemberLocation> locations;
  const _ActiveHikersPanel({required this.locations});

  @override
  Widget build(BuildContext context) {
    return PCCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const PcSectionLabel('Active hikers'),
                const Spacer(),
                if (locations.isNotEmpty)
                  PCPill(
                      label: '${locations.length} LIVE',
                      live: true,
                      ember: true),
              ],
            ),
          ),
          Expanded(
            child: locations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No hikers live.\nPaired phones appear here while recording.',
                        textAlign: TextAlign.center,
                        style: TT.body(size: 12, color: TT.text3),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    itemCount: locations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _HikerRow(loc: locations[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HikerRow extends StatelessWidget {
  final TeamMemberLocation loc;
  const _HikerRow({required this.loc});

  @override
  Widget build(BuildContext context) {
    final help = loc.status == 'help';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        border: Border(
          top: const BorderSide(color: TT.line),
          right: const BorderSide(color: TT.line),
          bottom: const BorderSide(color: TT.line),
          left: BorderSide(color: help ? TT.amber : TT.ember, width: 3),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          PcAvatar(name: loc.displayName, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(loc.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TT.body(size: 12.5, w: FontWeight.w800)),
                    ),
                    if (help) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.warning_amber_rounded,
                          size: 11, color: TT.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${loc.altitude.round()} m · ${_agoSecs(loc.ageSeconds)}',
                  style: TT.mono(
                      size: 9.5,
                      color: help ? TT.amber : TT.text3,
                      letterSpacing: 0.04 * 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PcMiniBattery(pct: loc.batteryPct),
        ],
      ),
    );
  }
}

// ── Summit weather ──────────────────────────────────────────────────────────

class _WeatherPanel extends StatelessWidget {
  final WeatherData? weather;
  final List<WeatherWarning> warnings;
  const _WeatherPanel({required this.weather, required this.warnings});

  @override
  Widget build(BuildContext context) {
    final w = weather?.current;
    return PCCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const PcSectionLabel('Summit weather'),
                const Spacer(),
                if (warnings.isNotEmpty)
                  const PCPill(label: 'ADVISORY', warning: true, live: true),
              ],
            ),
          ),
          if (w == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Weather unavailable.',
                  style: TT.body(size: 12, color: TT.text3)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${w.temperature.round()}°',
                      style: TT
                          .numStyle(size: 38, letterSpacing: -0.03 * 38)
                          .copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${_compass(w.windDirection)} ${w.windSpeed.round()} km/h\n${weatherDescription(w.weatherCode)}',
                      style: TT.mono(size: 10.5, color: TT.text3),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: TT.line)),
              ),
              child: Row(
                children: [
                  _WxTile(
                      label: 'WIND',
                      value: '${w.windSpeed.round()}',
                      unit: 'km/h'),
                  _WxTile(
                      label: 'FEELS',
                      value: '${w.feelsLike.round()}°',
                      unit: 'C'),
                  _WxTile(label: 'HUMIDITY', value: '${w.humidity}', unit: '%'),
                  _WxTile(
                      label: 'CLOUD',
                      value: '${w.cloudCover}',
                      unit: '%',
                      last: true),
                ],
              ),
            ),
            if (warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(warnings.first.icon,
                        size: 13, color: warnings.first.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${warnings.first.headline} — ${warnings.first.body}',
                        style: TT
                            .body(size: 10.5, color: TT.text2)
                            .copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _WxTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool last;
  const _WxTile({
    required this.label,
    required this.value,
    required this.unit,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : const BorderSide(color: TT.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TT
                    .body(size: 8, w: FontWeight.w700, color: TT.text3)
                    .copyWith(letterSpacing: 0.14 * 8)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TT.numStyle(size: 16)),
                const SizedBox(width: 2),
                Text(unit, style: TT.mono(size: 8.5, color: TT.text3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity feed ─────────────────────────────────────────────────────────--

class _ActivityFeed extends StatelessWidget {
  final List<Incident> incidents;
  final List<TeamMemberLocation> locations;
  final bool streaming;
  const _ActivityFeed({
    required this.incidents,
    required this.locations,
    required this.streaming,
  });

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 4));
    final entries = <_FeedEntry>[];
    for (final i in incidents) {
      if (i.reportedAt.isAfter(cutoff)) {
        entries.add(_FeedEntry(
          time: i.reportedAt,
          who: i.type.label,
          text: i.description.isNotEmpty
              ? i.description
              : '${i.type.label} reported${i.trailName != null ? " · ${i.trailName}" : ""}',
          color: i.isEmergency ? TT.red : TT.amber,
        ));
      }
    }
    for (final l in locations) {
      if (l.timestamp.isAfter(cutoff)) {
        entries.add(_FeedEntry(
          time: l.timestamp,
          who: l.displayName,
          text: 'Position update · ${l.altitude.round()} m',
          color: l.status == 'help' ? TT.amber : TT.ember,
        ));
      }
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    final shown = entries.take(8).toList();

    return PCCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                const PcSectionLabel('Activity · last 4 hours'),
                const SizedBox(width: 9),
                if (streaming)
                  const PCPill(label: 'STREAMING', live: true, ember: true),
              ],
            ),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Text('No activity in the last 4 hours.',
                  style: TT.body(size: 12, color: TT.text3)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
              child: Column(
                children: [
                  for (final e in shown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e.color,
                              boxShadow: [
                                BoxShadow(
                                    color: e.color.withOpacity(0.5),
                                    blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 46,
                            child: Text(_hhmm(e.time),
                                style: TT.mono(size: 11, color: TT.text2)),
                          ),
                          SizedBox(
                            width: 96,
                            child: Text(e.who,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TT.body(
                                    size: 11.5,
                                    w: FontWeight.w800,
                                    color: e.color)),
                          ),
                          Expanded(
                            child: Text(e.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TT.body(size: 11.5, color: TT.text2)),
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

class _FeedEntry {
  final DateTime time;
  final String who;
  final String text;
  final Color color;
  _FeedEntry({
    required this.time,
    required this.who,
    required this.text,
    required this.color,
  });
}

// ── helpers ───────────────────────────────────────────────────────────────--

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _agoSecs(int s) {
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60}m ago';
  if (s < 86400) return '${s ~/ 3600}h ago';
  return '${s ~/ 86400}d ago';
}

String _compass(int deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[((deg % 360) / 45).round() % 8];
}
