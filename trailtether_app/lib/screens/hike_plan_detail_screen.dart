// Trailtether 3.0 — Hike-plan detail screen, reskinned to TT tokens.
//
// Renders one HikePlan stored in Supabase with its trip schedule, weather /
// emergency, equipment checklist (per-member packed state), and RSVP roster.
// Tapping a gear row toggles the packed state for the current user via
// TeamService.updatePlan — unchanged from before.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../services/team_service.dart';
import '../widgets/common/user_avatar.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class HikePlanDetailScreen extends StatefulWidget {
  final HikePlan plan;
  final Team team;

  const HikePlanDetailScreen({
    super.key,
    required this.plan,
    required this.team,
  });

  @override
  State<HikePlanDetailScreen> createState() => _HikePlanDetailScreenState();
}

class _HikePlanDetailScreenState extends State<HikePlanDetailScreen> {
  late HikePlan _plan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  Future<void> _togglePacked(String gearId) async {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    setState(() => _busy = true);

    final extras = _plan.extras;
    final newGearList = extras.gearList.map((item) {
      if (item.id == gearId) {
        final newStatuses = Map<String, bool>.from(item.memberStatuses);
        newStatuses[uid] = !(newStatuses[uid] ?? false);
        return GearItem(
          id: item.id,
          name: item.name,
          category: item.category,
          isMandatory: item.isMandatory,
          memberStatuses: newStatuses,
        );
      }
      return item;
    }).toList();

    final newPlan = HikePlan(
      id: _plan.id,
      teamId: _plan.teamId,
      trailId: _plan.trailId,
      trailName: _plan.trailName,
      hikeDate: _plan.hikeDate,
      meetingPoint: _plan.meetingPoint,
      notes: extras.copyWith(gearList: newGearList).toJsonString(),
      createdBy: _plan.createdBy,
      createdAt: _plan.createdAt,
      status: _plan.status,
    );

    try {
      await TeamService.updatePlan(_plan.id, newPlan);
      setState(() => _plan = newPlan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TT.surf,
            behavior: SnackBarBehavior.floating,
            content: Text('Error updating gear: $e',
                style: TT.body(size: 13, color: TT.text)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = _plan.extras;
    final currentUid = context.watch<AuthProvider>().uid;

    final startDateStr = DateFormat('EEEE, d MMMM yyyy').format(_plan.hikeDate);
    final endDateStr = extras.endDate != null
        ? DateFormat('EEEE, d MMMM yyyy').format(extras.endDate!)
        : null;

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _DetailAppBar(
                  title: _plan.trailName,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                    children: [
                      // ── Hero card ────────────────────────────────────────
                      _HeroCard(plan: _plan),

                      const SizedBox(height: 18),

                      // ── Trip Schedule ────────────────────────────────────
                      const _SectionLabel(
                          title: 'TRIP SCHEDULE', icon: Icons.event),
                      const SizedBox(height: 10),
                      _InfoTile(
                        label: 'Start Date',
                        value: extras.time.isNotEmpty
                            ? '$startDateStr • ${extras.time}'
                            : startDateStr,
                        icon: Icons.calendar_today,
                      ),
                      if (endDateStr != null) ...[
                        const SizedBox(height: 10),
                        _InfoTile(
                          label: 'End Date',
                          value: endDateStr,
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                      if (_plan.meetingPoint.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoTile(
                          label: 'Meeting Point',
                          value: _plan.meetingPoint,
                          icon: Icons.location_on,
                        ),
                      ],

                      const SizedBox(height: 22),

                      // ── Weather & Emergency ──────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _NoteCard(
                              title: 'WEATHER',
                              icon: Icons.wb_sunny_outlined,
                              body: extras.weather.isNotEmpty
                                  ? extras.weather
                                  : 'No report added.',
                              empty: extras.weather.isEmpty,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NoteCard(
                              title: 'EMERGENCY',
                              icon: Icons.health_and_safety_outlined,
                              body: extras.emergencyContacts.isNotEmpty
                                  ? extras.emergencyContacts.first
                                  : 'None set.',
                              empty: extras.emergencyContacts.isEmpty,
                              danger: extras.emergencyContacts.isNotEmpty,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ── Gear Checklist ───────────────────────────────────
                      Row(
                        children: [
                          const _SectionLabel(
                              title: 'EQUIPMENT CHECKLIST',
                              icon: Icons.checklist),
                          const Spacer(),
                          if (_busy)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TT.ember,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track what you and your teammates have packed.',
                        style: TT.body(size: 12, color: TT.text3),
                      ),
                      const SizedBox(height: 12),
                      if (extras.gearList.isEmpty)
                        const _EmptyState(
                            message: 'No gear items specified for this hike.')
                      else
                        ...extras.gearList.map((item) => _GearItemTile(
                              item: item,
                              team: widget.team,
                              currentUid: currentUid ?? '',
                              onToggle: () => _togglePacked(item.id),
                            )),

                      const SizedBox(height: 22),

                      // ── RSVP ─────────────────────────────────────────────
                      const _SectionLabel(
                          title: 'TEAM ATTENDANCE',
                          icon: Icons.people_alt_outlined),
                      const SizedBox(height: 10),
                      _RsvpList(plan: _plan, team: widget.team),

                      const SizedBox(height: 36),
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

// ── App bar ───────────────────────────────────────────────────────────────

class _DetailAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _DetailAppBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          TTIconBtn(icon: Icons.chevron_left, size: 38, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TT.title(20, letterSpacing: -0.01 * 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final HikePlan plan;
  const _HeroCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final extras = plan.extras;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(plan.hikeDate);
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TTPill(
                label: 'HIKE PREPARATION',
                variant: TTPillVariant.ember,
              ),
              const Spacer(),
              TTPill(
                label: plan.status.toUpperCase(),
                variant: plan.status == 'completed'
                    ? TTPillVariant.neutral
                    : TTPillVariant.ember,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plan.trailName,
            style: TT.title(22, letterSpacing: -0.01 * 22),
          ),
          const SizedBox(height: 6),
          Text(
            extras.time.isNotEmpty ? '$dateStr • ${extras.time}' : dateStr,
            style: TT.mono(size: 11, color: TT.text3),
          ),
          if (extras.invitedMembers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: TT.line),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.group_outlined, size: 14, color: TT.ember),
                const SizedBox(width: 6),
                Text(
                  '${extras.invitedMembers.length} invited',
                  style:
                      TT.label(size: 10.5, color: TT.text2, letterSpacing: 1.4),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TT.ember, size: 14),
        const SizedBox(width: 8),
        Text(
          title,
          style: TT.label(size: 11, color: TT.ember, letterSpacing: 1.4),
        ),
      ],
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TT.emberDim,
              borderRadius: BorderRadius.circular(TT.rSm),
              border: Border.all(color: const Color(0x52FF6A2C)),
            ),
            child: Icon(icon, color: TT.ember, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TT.label(
                        size: 9.5, color: TT.text3, letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TT.body(size: 14, color: TT.text, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note card (weather / emergency) ───────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;
  final bool empty;
  final bool danger;
  const _NoteCard({
    required this.title,
    required this.icon,
    required this.body,
    required this.empty,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = empty ? TT.text3 : (danger ? TT.red : TT.text);
    return TTCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TT.ember, size: 14),
              const SizedBox(width: 8),
              Text(title,
                  style:
                      TT.label(size: 10, color: TT.ember, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TT.body(
              size: 13,
              color: fg,
              w: danger ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gear tile ─────────────────────────────────────────────────────────────

class _GearItemTile extends StatelessWidget {
  final GearItem item;
  final Team team;
  final String currentUid;
  final VoidCallback onToggle;

  const _GearItemTile({
    required this.item,
    required this.team,
    required this.currentUid,
    required this.onToggle,
  });

  IconData get _icon {
    switch (item.category) {
      case 'Safety':
        return Icons.health_and_safety_outlined;
      case 'Nutrition':
        return Icons.restaurant_outlined;
      case 'Group':
        return Icons.groups_outlined;
      case 'Clothing':
        return Icons.checkroom_outlined;
      default:
        return Icons.backpack_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPackedByMe = item.memberStatuses[currentUid] ?? false;
    final packedMembers =
        team.members.where((m) => item.memberStatuses[m.uid] == true).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: TT.surf,
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(
              color: isPackedByMe ? const Color(0x59FF6A2C) : TT.line),
          boxShadow: TT.shadowCard,
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _Check(checked: isPackedByMe),
                    const SizedBox(width: 12),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TT.emberSoft,
                        borderRadius: BorderRadius.circular(TT.rSm),
                      ),
                      child: Icon(_icon, size: 14, color: TT.ember),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TT
                                .body(
                                  size: 14,
                                  w: FontWeight.w700,
                                  color: TT.text,
                                )
                                .copyWith(
                                  decoration: isPackedByMe
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: TT.text3,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.category.toUpperCase(),
                            style: TT.label(
                                size: 9.5, color: TT.text3, letterSpacing: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (item.isMandatory)
                      const TTPill(
                          label: 'REQUIRED', variant: TTPillVariant.danger),
                  ],
                ),
              ),
            ),
            if (packedMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(58, 0, 14, 12),
                child: Row(
                  children: [
                    Text('Packed by:',
                        style: TT.label(size: 9.5, color: TT.text3)),
                    const SizedBox(width: 6),
                    ...packedMembers.map((m) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Tooltip(
                            message: m.displayName,
                            child: UserAvatar(
                              radius: 9,
                              photoUrl: m.photoUrl,
                              displayName: m.displayName,
                              backgroundColor: TT.ember,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? TT.ember : TT.surf2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: checked ? TT.ember : TT.line2, width: 1.4),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: TT.emberInk)
          : null,
    );
  }
}

// ── RSVP list ─────────────────────────────────────────────────────────────

class _RsvpList extends StatelessWidget {
  final HikePlan plan;
  final Team team;
  const _RsvpList({required this.plan, required this.team});

  @override
  Widget build(BuildContext context) {
    final extras = plan.extras;
    final rows = team.members
        .where((m) =>
            extras.invitedMembers.contains(m.uid) || m.uid == plan.createdBy)
        .toList();
    if (rows.isEmpty) {
      return const _EmptyState(message: 'No invitees yet for this plan.');
    }
    return TTCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _RsvpRow(
              member: rows[i],
              status: extras.rsvp[rows[i].uid] ?? 'invited',
            ),
            if (i < rows.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(height: 1, color: TT.line),
              ),
          ],
        ],
      ),
    );
  }
}

class _RsvpRow extends StatelessWidget {
  final TeamMember member;
  final String status;
  const _RsvpRow({required this.member, required this.status});

  @override
  Widget build(BuildContext context) {
    final going = status == 'going';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            radius: 15,
            photoUrl: member.photoUrl,
            displayName: member.displayName,
            backgroundColor: TT.surf2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(member.displayName,
                style: TT.body(size: 13.5, w: FontWeight.w700, color: TT.text)),
          ),
          _RsvpBadge(label: status.toUpperCase(), going: going),
        ],
      ),
    );
  }
}

class _RsvpBadge extends StatelessWidget {
  final String label;
  final bool going;
  const _RsvpBadge({required this.label, required this.going});

  @override
  Widget build(BuildContext context) {
    final fg = going ? TT.green : TT.text3;
    final bg = going ? const Color(0x1A4CC38A) : const Color(0x07FFFFFF);
    final border = going ? const Color(0x594CC38A) : TT.line2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TT.mono(size: 9.5, color: fg, letterSpacing: 1.14)),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TT.body(size: 13, color: TT.text3),
      ),
    );
  }
}
