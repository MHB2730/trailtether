// PC "Base Camp" — Hike Watch (per-hiker deep dive).
//
// v1: when there are live hikers, render a switchable hiker-tab strip and a
// vitals card (elevation/speed/heading/battery/signal/last-ping) for the
// selected one, alongside a chat panel placeholder. When nothing is live,
// show the polished empty state guiding the user to pair / Mission Control.
//
// The full per-hike map + elevation replay + live chat from the design
// (basecamp/hike-watch.jsx) will land in a follow-up pass; for now we
// surface the existing live-position data honestly without faking it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/team.dart';
import '../../providers/team_provider.dart';
import '../../providers/team_tracking_provider.dart';
import 'pc_kit.dart';
import 'pc_shell.dart' show PCPageHeader, PCBtn, PCCard, PCPill;

class PcHikeWatchScreen extends StatefulWidget {
  final VoidCallback onOpenPair;
  final VoidCallback onOpenMissionControl;
  final VoidCallback onOpenHikers;
  const PcHikeWatchScreen({
    super.key,
    required this.onOpenPair,
    required this.onOpenMissionControl,
    required this.onOpenHikers,
  });

  @override
  State<PcHikeWatchScreen> createState() => _PcHikeWatchScreenState();
}

class _PcHikeWatchScreenState extends State<PcHikeWatchScreen> {
  String? _focusUid;

  @override
  Widget build(BuildContext context) {
    final locs = context.watch<TeamTrackingProvider>().teamLocations;
    final teams = context.watch<TeamProvider>().teams;
    final live = locs.where((l) => l.isLive || l.isRecent).toList();
    final hasPaired = teams.any((t) => t.members.isNotEmpty);

    if (live.isEmpty) {
      return _empty(context, hasPaired);
    }

    final focused =
        live.firstWhere((l) => l.uid == _focusUid, orElse: () => live.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'LIVE',
          title: 'Hike Watch',
          sub: Text(
              '${focused.displayName} · ${live.length} hiker${live.length == 1 ? "" : "s"} live'),
          actions: [
            PCBtn(
              label: 'VIEW HIKERS',
              leftIcon: Icons.people_outline,
              onTap: widget.onOpenHikers,
            ),
            PCBtn(
              label: 'OPEN MAP',
              leftIcon: Icons.public,
              primary: true,
              onTap: widget.onOpenMissionControl,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: TT.line)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in live)
                _HikerTab(
                  loc: l,
                  active: l.uid == focused.uid,
                  onTap: () => setState(() => _focusUid = l.uid),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: _Vitals(
              loc: focused,
              onOpenMap: widget.onOpenMissionControl,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context, bool hasPaired) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'LIVE',
          title: 'Hike Watch',
          sub: const Text(
              'Per-hike deep-dive · elevation profile + alerts + timeline'),
          actions: hasPaired
              ? [
                  PCBtn(
                    label: 'VIEW HIKERS',
                    leftIcon: Icons.people_outline,
                    onTap: widget.onOpenHikers,
                  ),
                ]
              : const [],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: PCCard(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 48, color: TT.text3),
                  const SizedBox(height: 16),
                  Text('No active hike to watch', style: TT.title(18)),
                  const SizedBox(height: 8),
                  Text(
                    hasPaired
                        ? 'A hiker is paired but isn\'t recording yet. Start a hike on their mobile app to see live position, elevation, pace, and incident overlay here.'
                        : 'Pair a phone first, then start a hike on the mobile app to see live position, elevation, pace, and incident overlay here.',
                    textAlign: TextAlign.center,
                    style: TT
                        .body(size: 12, color: TT.text2)
                        .copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  PCBtn(
                    label: hasPaired ? 'OPEN MISSION CONTROL' : 'PAIR A DEVICE',
                    leftIcon:
                        hasPaired ? Icons.public : Icons.qr_code_2_rounded,
                    primary: true,
                    onTap: hasPaired
                        ? widget.onOpenMissionControl
                        : widget.onOpenPair,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HikerTab extends StatelessWidget {
  final TeamMemberLocation loc;
  final bool active;
  final VoidCallback onTap;
  const _HikerTab({
    required this.loc,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final help = loc.status == 'help';
    final accent = help ? TT.amber : TT.ember;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? TT.emberDim : TT.surf,
            border: Border.all(color: active ? accent : TT.line2),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PcAvatar(name: loc.displayName, size: 28),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.displayName,
                    style: TT.body(
                        size: 12,
                        w: FontWeight.w800,
                        color: active ? TT.ember : TT.text),
                  ),
                  Text(
                    '${_agoShort(loc.ageSeconds)} · ${loc.altitude.round()} m',
                    style: TT.mono(size: 9.5, color: TT.text3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vitals extends StatelessWidget {
  final TeamMemberLocation loc;
  final VoidCallback onOpenMap;
  const _Vitals({required this.loc, required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: PCCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PcAvatar(name: loc.displayName, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.displayName, style: TT.title(20)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _statusPill(loc),
                              const SizedBox(width: 8),
                              Text('${_agoShort(loc.ageSeconds)} ago',
                                  style: TT.mono(size: 11, color: TT.text3)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _vital('Elevation', '${loc.altitude.round()}', 'm'),
                    _vital(
                        'Speed',
                        loc.speed > 0 ? loc.speed.toStringAsFixed(1) : '—',
                        'km/h'),
                    _vital('Heading',
                        loc.heading > 0 ? '${loc.heading.round()}°' : '—', ''),
                    _vital('Battery', loc.batteryPct?.toString() ?? '—',
                        loc.batteryPct != null ? '%' : ''),
                    _vital('Signal', loc.connectivity ?? '—', ''),
                    _vital('Last ping', _agoShort(loc.ageSeconds), 'ago'),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    PCBtn(
                      label: 'OPEN ON MAP',
                      leftIcon: Icons.public,
                      primary: true,
                      onTap: onOpenMap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 320,
          child: PCCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PcSectionLabel('Direct chat'),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Direct chat with this hiker isn\'t wired into Hike Watch yet — open the team detail screen to chat from there.',
                        textAlign: TextAlign.center,
                        style: TT.body(size: 12, color: TT.text3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vital(String label, String value, String unit) => SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TT.label(size: 9.5, letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TT.numStyle(size: 22)),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child:
                        Text(unit, style: TT.mono(size: 10, color: TT.text3)),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _statusPill(TeamMemberLocation l) {
    if (l.status == 'help') {
      return const PCPill(label: 'NEEDS HELP', warning: true, live: true);
    }
    if (l.isLive) return const PCPill(label: 'LIVE', success: true, live: true);
    if (l.isStale) return const PCPill(label: 'STALE', danger: true);
    return const PCPill(label: 'RECENT', ember: true);
  }
}

String _agoShort(int s) {
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m';
  if (s < 86400) return '${s ~/ 3600}h';
  return '${s ~/ 86400}d';
}
