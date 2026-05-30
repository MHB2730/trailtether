// PC "Base Camp" — Hikers (paired roster).
//
// Mirrors basecamp/hikers.jsx (Roster tab): one row per team member with the
// live metrics (altitude / ageSeconds / status / battery) when a paired phone
// is reporting, and a neutral "Idle" state when it isn't. Tap → TeamDetail.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/team.dart';
import '../../providers/team_provider.dart';
import '../../providers/team_tracking_provider.dart';
import '../team_detail_screen.dart';
import 'pc_kit.dart';
import 'pc_shell.dart' show PCPageHeader, PCBtn, PCCard, PCPill;

class PcHikersScreen extends StatelessWidget {
  final VoidCallback onOpenPair;
  const PcHikersScreen({super.key, required this.onOpenPair});

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<TeamProvider>().teams;
    final tracking = context.watch<TeamTrackingProvider>();
    final locByUid = {for (final l in tracking.teamLocations) l.uid: l};

    final rows = <_HikerEntry>[];
    for (final t in teams) {
      for (final m in t.members) {
        rows.add(_HikerEntry(team: t, member: m, loc: locByUid[m.uid]));
      }
    }
    final liveCount = rows
        .where((r) => r.loc != null && (r.loc!.isLive || r.loc!.isRecent))
        .length;

    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCPageHeader(
            eyebrow: 'PAIRED HIKERS',
            title: 'Hikers',
            sub: const Text(
                'No paired hikers yet · pair a device to start watching'),
            actions: [
              PCBtn(
                label: 'PAIR DEVICE',
                leftIcon: Icons.qr_code_2_rounded,
                primary: true,
                onTap: onOpenPair,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: PCCard(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline, size: 48, color: TT.text3),
                    const SizedBox(height: 16),
                    Text('No hikers paired yet', style: TT.title(18)),
                    const SizedBox(height: 8),
                    Text(
                      'Open Pair Device, show the QR on this screen, and scan it from the mobile app to attach a phone.',
                      textAlign: TextAlign.center,
                      style: TT
                          .body(size: 12, color: TT.text2)
                          .copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    PCBtn(
                      label: 'OPEN PAIR DEVICE',
                      leftIcon: Icons.qr_code_2_rounded,
                      primary: true,
                      onTap: onOpenPair,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'PAIRED HIKERS',
          title: 'Hikers',
          sub: Text(
              '${rows.length} hiker${rows.length == 1 ? "" : "s"} across ${teams.length} team${teams.length == 1 ? "" : "s"}'
              '${liveCount > 0 ? " · $liveCount live" : ""}'),
          actions: [
            PCBtn(
              label: 'PAIR DEVICE',
              leftIcon: Icons.qr_code_2_rounded,
              primary: true,
              onTap: onOpenPair,
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(26),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = rows[i];
              return _HikerCard(
                team: r.team,
                member: r.member,
                loc: r.loc,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(team: r.team))),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HikerEntry {
  final Team team;
  final TeamMember member;
  final TeamMemberLocation? loc;
  _HikerEntry({required this.team, required this.member, required this.loc});
}

class _HikerCard extends StatelessWidget {
  final Team team;
  final TeamMember member;
  final TeamMemberLocation? loc;
  final VoidCallback onTap;
  const _HikerCard({
    required this.team,
    required this.member,
    required this.loc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = loc;
    final help = l?.status == 'help';
    final isLive = l != null && (l.isLive || l.isRecent);
    final accent = help ? TT.amber : (isLive ? TT.ember : TT.line2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PCCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              PcAvatar(name: member.displayName, size: 38),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: TT.body(size: 13, w: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TEAM · ${team.name.toUpperCase()}',
                      style: TT.mono(
                          size: 9.5,
                          color: TT.text3,
                          letterSpacing: 0.06 * 9.5),
                    ),
                  ],
                ),
              ),
              if (l != null) ...[
                _metric('Elev', '${l.altitude.round()}', 'm'),
                _metric('Ping', _agoShort(l.ageSeconds), ''),
                const SizedBox(width: 6),
              ],
              _statusPill(l, help),
              const SizedBox(width: 10),
              PcMiniBattery(pct: l?.batteryPct),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 18, color: TT.text3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, String unit) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(),
                style: TT.label(size: 9, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TT.numStyle(size: 13)),
                if (unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(unit, style: TT.mono(size: 9, color: TT.text3)),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _statusPill(TeamMemberLocation? l, bool help) {
    if (l == null) return const PCPill(label: 'IDLE');
    if (help) {
      return const PCPill(label: 'NEEDS HELP', warning: true, live: true);
    }
    if (l.isLive) return const PCPill(label: 'LIVE', success: true, live: true);
    if (l.isRecent) return const PCPill(label: 'RECENT', ember: true);
    if (l.isStale) return const PCPill(label: 'STALE', danger: true);
    return const PCPill(label: 'IDLE');
  }
}

String _agoShort(int s) {
  if (s < 60) return '${s}s';
  if (s < 3600) return '${s ~/ 60}m';
  if (s < 86400) return '${s ~/ 3600}h';
  return '${s ~/ 86400}d';
}
