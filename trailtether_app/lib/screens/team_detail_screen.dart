// Trailtether 3.0 — Team detail screen.
//
// Reskin notes:
//   * UI rewritten on top of TT v3 design tokens — TTAmbient + TTTopoBackdrop
//     backdrop, TTPageAppBar with chevron back, TTSegmented tab strip,
//     TTCard panels, TTPill status chips, ember pill primary CTAs, outline
//     secondary CTAs.
//   * All logic is preserved verbatim across the three tabs:
//       - Chat tab embeds [TeamChatScreen] (handles its own messages).
//       - Hike Plans tab: monthly calendar grid, fetch / create / delete /
//         update via [TeamService], RSVP toggling, START HIKE handover to
//         [TeamTrackingProvider], OK / HELP / ARRIVED check-ins.
//       - Members tab: invite-by-username RPC (find_profile_by_username) +
//         add via [TeamProvider.addMember], remove via [TeamProvider.removeMember].
//   * Header actions: QR invite (any member), delete team (admin only),
//     Mission Control (any member) — unchanged.
//
// Owns only this file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design_tokens.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../providers/team_tracking_provider.dart';
import '../services/team_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';
import 'admin/mission_control_tab.dart';
import 'create_hike_plan_screen.dart';
import 'hike_plan_detail_screen.dart';
import 'team_chat_screen.dart';
import 'team_invite_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;
  const TeamDetailScreen({super.key, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  int _tab = 0; // 0 chat, 1 plans, 2 members

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<ap.AuthProvider>().uid ?? '';
    final isAdmin = widget.team.createdBy == currentUid;

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.4)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                TTPageAppBar(
                  title: widget.team.name,
                  trailing: [
                    TTIconBtn(
                      icon: Icons.chevron_left,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    TTIconBtn(
                      icon: Icons.qr_code_rounded,
                      ember: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TeamInviteScreen(team: widget.team),
                        ),
                      ),
                    ),
                    TTIconBtn(
                      icon: Icons.radar,
                      ember: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MissionControlTab()),
                      ),
                    ),
                    if (isAdmin)
                      TTIconBtn(
                        icon: Icons.delete_outline,
                        onTap: () async {
                          final confirmed = await _confirmDelete(context);
                          if (confirmed == true && context.mounted) {
                            await context
                                .read<TeamProvider>()
                                .deleteTeam(widget.team.id);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: TTSegmented(
                    tabs: const ['Chat', 'Hike Plans', 'Members'],
                    active: _tab,
                    onChange: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: TT.dMed,
                    child: _buildActiveTab(currentUid, isAdmin),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTab(String currentUid, bool isAdmin) {
    switch (_tab) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey('chat'),
          child: TeamChatScreen(team: widget.team),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey('plans'),
          child: _HikePlansTab(team: widget.team, currentUid: currentUid),
        );
      case 2:
        return KeyedSubtree(
          key: const ValueKey('members'),
          child: _MembersTab(
              team: widget.team, isAdmin: isAdmin, currentUid: currentUid),
        );
    }
    return const SizedBox.shrink();
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: TT.surf,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TT.rMd),
              side: const BorderSide(color: TT.line, width: 1)),
          title: Text('Delete team?', style: TT.title(16)),
          content: Text(
            'This will remove the team and all its hike plans. '
            'This cannot be undone.',
            style: TT.body(size: 13, color: TT.text2, w: FontWeight.w500)
                .copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TT.body(
                      size: 13, w: FontWeight.w700, color: TT.text2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: TT.body(
                      size: 13, w: FontWeight.w800, color: TT.red)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────── HIKE PLANS ─────────────────────────────

class _HikePlansTab extends StatefulWidget {
  final Team team;
  final String currentUid;
  const _HikePlansTab({required this.team, required this.currentUid});

  @override
  State<_HikePlansTab> createState() => _HikePlansTabState();
}

class _HikePlansTabState extends State<_HikePlansTab> {
  late Future<List<HikePlan>> _plansFuture;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _plansFuture = TeamService.fetchPlansForTeam(widget.team.id);
  }

  void _refresh() {
    setState(() {
      _plansFuture = TeamService.fetchPlansForTeam(widget.team.id);
    });
  }

  Future<void> _planHike([DateTime? date]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateHikePlanScreen(team: widget.team, initialDate: date),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HikePlan>>(
      future: _plansFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: TT.ember, strokeWidth: 2),
          );
        }

        final plans = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _CalendarHeader(
              focusedDay: _focusedDay,
              onPrev: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month - 1, 1)),
              onNext: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month + 1, 1)),
            ),
            const SizedBox(height: 10),
            TTCard(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: _CalendarGrid(
                focusedDay: _focusedDay,
                plans: plans,
                onDaySelected: _planHike,
              ),
            ),
            const SizedBox(height: 14),
            _QuickPlanButton(onTap: () => _planHike()),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('UPCOMING', style: TT.label(color: TT.ember)),
                TTPill(
                  label: '${plans.length}',
                  variant: plans.isEmpty
                      ? TTPillVariant.neutral
                      : TTPillVariant.ember,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (plans.isEmpty)
              TTCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
                child: Column(
                  children: [
                    const Icon(Icons.event_outlined, color: TT.text3, size: 28),
                    const SizedBox(height: 10),
                    Text('No hikes planned yet.',
                        style: TT.body(
                            size: 13, w: FontWeight.w600, color: TT.text2)),
                    const SizedBox(height: 4),
                    Text('Select a date or tap Quick Plan.',
                        style: TT.body(
                            size: 12, w: FontWeight.w500, color: TT.text3)),
                  ],
                ),
              )
            else
              for (var i = 0; i < plans.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == plans.length - 1 ? 0 : 10),
                  child: _PlanCard(
                    plan: plans[i],
                    canDelete: plans[i].createdBy == widget.currentUid,
                    team: widget.team,
                    currentUid: widget.currentUid,
                    onDeleted: _refresh,
                    onUpdated: _refresh,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _CalendarHeader(
      {required this.focusedDay, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('HIKE SCHEDULE', style: TT.label(color: TT.ember)),
        Row(
          children: [
            TTIconBtn(
              icon: Icons.chevron_left,
              size: 32,
              onTap: onPrev,
            ),
            const SizedBox(width: 8),
            Text(DateFormat('MMMM yyyy').format(focusedDay),
                style: TT.body(size: 13.5, w: FontWeight.w800, color: TT.text)),
            const SizedBox(width: 8),
            TTIconBtn(
              icon: Icons.chevron_right,
              size: 32,
              onTap: onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickPlanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickPlanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(TT.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(TT.rMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: TT.line, width: 1),
            borderRadius: BorderRadius.circular(TT.rMd),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: TT.text2, size: 15),
              const SizedBox(width: 8),
              Text('QUICK PLAN',
                  style: TT.body(size: 12.5, w: FontWeight.w800, color: TT.text2)
                      .copyWith(letterSpacing: 0.14 * 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── PLAN CARD ──────────────────────────────

class _PlanCard extends StatefulWidget {
  final HikePlan plan;
  final bool canDelete;
  final Team team;
  final String currentUid;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const _PlanCard({
    required this.plan,
    required this.canDelete,
    required this.team,
    required this.currentUid,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _busy = false;

  Future<void> _startHike() async {
    setState(() => _busy = true);
    try {
      await TeamService.updateHikeStatus(widget.plan.id, 'active');
      if (mounted) {
        context.read<TeamTrackingProvider>().setActiveHike(
              HikePlan.fromMap({
                ...widget.plan.toInsertMap(),
                'id': widget.plan.id,
                'status': 'active',
              }),
            );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error starting hike: $e',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateRsvp(String status) async {
    setState(() => _busy = true);
    final extras = widget.plan.extras;
    final newRsvp = Map<String, String>.from(extras.rsvp);
    newRsvp[widget.currentUid] = status;

    final newPlan = HikePlan(
      id: widget.plan.id,
      teamId: widget.plan.teamId,
      trailId: widget.plan.trailId,
      trailName: widget.plan.trailName,
      hikeDate: widget.plan.hikeDate,
      meetingPoint: widget.plan.meetingPoint,
      notes: extras.copyWith(rsvp: newRsvp).toJsonString(),
      createdBy: widget.plan.createdBy,
      createdAt: widget.plan.createdAt,
    );

    try {
      await TeamService.updatePlan(widget.plan.id, newPlan);
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating RSVP: $e',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, d MMM yyyy').format(widget.plan.hikeDate);
    final isPast = widget.plan.hikeDate.isBefore(DateTime.now());
    final extras = widget.plan.extras;
    final rsvpStatus = extras.rsvp[widget.currentUid];
    final isInvited = extras.invitedMembers.contains(widget.currentUid) ||
        widget.plan.createdBy == widget.currentUid;
    final isActive = widget.plan.status == 'active';

    final invitedNames = widget.team.members
        .where((m) =>
            extras.invitedMembers.contains(m.uid) ||
            m.uid == widget.plan.createdBy)
        .map((m) => m.displayName)
        .toList();

    final goingUids = extras.rsvp.entries
        .where((e) => e.value == 'going')
        .map((e) => e.key)
        .toList();
    final goingNames = widget.team.members
        .where((m) => goingUids.contains(m.uid))
        .map((m) => m.displayName)
        .toList();

    return TTCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HikePlanDetailScreen(plan: widget.plan, team: widget.team),
        ),
      ).then((_) => widget.onUpdated?.call()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.plan.trailName,
                  style: TT.body(
                    size: 14.5,
                    w: FontWeight.w800,
                    color: isPast ? TT.text3 : TT.text,
                  ),
                ),
              ),
              if (!isPast) ...[
                const SizedBox(width: 8),
                TTPill(
                  label: isActive ? 'ACTIVE' : 'UPCOMING',
                  variant: isActive
                      ? TTPillVariant.ember
                      : TTPillVariant.neutral,
                ),
              ],
              if (widget.canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await TeamService.deletePlan(widget.plan.id);
                    widget.onDeleted?.call();
                  },
                  child: const Icon(Icons.close, color: TT.text3, size: 16),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: TT.text3, size: 12),
              const SizedBox(width: 6),
              Text(
                extras.time.isNotEmpty
                    ? '$dateStr · ${extras.time}'
                    : dateStr,
                style: TT.mono(size: 11, color: TT.text2),
              ),
            ],
          ),
          if (widget.plan.meetingPoint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: TT.text3, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.plan.meetingPoint,
                    style: TT.body(
                        size: 12, w: FontWeight.w500, color: TT.text2),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: TT.line),
          const SizedBox(height: 12),

          // RSVP row
          if (!isPast && isInvited) ...[
            Row(
              children: [
                Text('Going?',
                    style: TT.body(
                        size: 12.5, w: FontWeight.w700, color: TT.text)),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: TT.ember),
                  )
                else ...[
                  _RsvpChip(
                    label: 'Going',
                    active: rsvpStatus == 'going',
                    onTap: () => _updateRsvp('going'),
                    activeColor: TT.green,
                  ),
                  const SizedBox(width: 8),
                  _RsvpChip(
                    label: 'No',
                    active: rsvpStatus == 'not_going',
                    onTap: () => _updateRsvp('not_going'),
                    activeColor: TT.red,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],

          if (goingNames.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: TT.green, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Going: ${goingNames.join(", ")}',
                    style: TT.body(size: 11.5, w: FontWeight.w600, color: TT.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (invitedNames.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.people_outline, color: TT.text3, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Team: ${invitedNames.join(", ")}',
                    style: TT.body(size: 11.5, w: FontWeight.w500, color: TT.text2),
                  ),
                ),
              ],
            ),
          ],

          if (extras.weather.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1A5AA1D6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x4D5AA1D6), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_outlined, color: TT.blue, size: 12),
                  const SizedBox(width: 6),
                  Text(extras.weather,
                      style: TT.body(
                          size: 11, w: FontWeight.w600, color: TT.blue)),
                ],
              ),
            ),
          ],

          if (extras.gearList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extras.gearList.map((item) {
                final packed = item.memberStatuses.values.any((v) => v);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: packed
                        ? const Color(0x1A4CC38A)
                        : const Color(0x08FFFFFF),
                    border: Border.all(
                      color: packed
                          ? const Color(0x4D4CC38A)
                          : TT.line2,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (packed) ...[
                        const Icon(Icons.check, size: 10, color: TT.green),
                        const SizedBox(width: 4),
                      ],
                      Text(item.name,
                          style: TT.body(
                              size: 10.5,
                              w: FontWeight.w600,
                              color: packed ? TT.green : TT.text2)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          if (extras.emergencyContacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emergency, color: TT.red, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Emergency: ${extras.emergencyContacts.first}',
                      style: TT.body(
                          size: 11.5, w: FontWeight.w600, color: TT.red)),
                ),
              ],
            ),
          ],

          if (extras.userNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              extras.userNotes,
              style: TT
                  .body(size: 12, color: TT.text3, w: FontWeight.w500)
                  .copyWith(
                      height: 1.45, fontStyle: FontStyle.italic),
            ),
          ],

          // START HIKE
          if (!isPast &&
              widget.plan.status == 'planned' &&
              rsvpStatus == 'going') ...[
            const SizedBox(height: 14),
            _EmberPillButton(
              icon: Icons.play_arrow,
              label: 'START HIKE',
              busy: _busy,
              onTap: _busy ? null : _startHike,
            ),
          ],

          // CHECK IN
          if (isActive && rsvpStatus == 'going') ...[
            const SizedBox(height: 14),
            Container(height: 1, color: TT.line),
            const SizedBox(height: 12),
            Text('CHECK IN', style: TT.label(color: TT.ember)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CheckInBtn(
                    label: 'OK',
                    color: TT.green,
                    icon: Icons.check,
                    onTap: () =>
                        context.read<TeamTrackingProvider>().checkIn('ok'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CheckInBtn(
                    label: 'HELP',
                    color: TT.red,
                    icon: Icons.warning_amber,
                    onTap: () => context
                        .read<TeamTrackingProvider>()
                        .checkIn('help'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CheckInBtn(
                    label: 'ARRIVED',
                    color: TT.blue,
                    icon: Icons.flag,
                    onTap: () async {
                      await context
                          .read<TeamTrackingProvider>()
                          .checkIn('arrived');
                      widget.onUpdated?.call();
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  const _RsvpChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.15) : const Color(0x08FFFFFF),
          border: Border.all(
            color: active ? activeColor : TT.line2,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TT.body(
            size: 11.5,
            w: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? activeColor : TT.text2,
          ),
        ),
      ),
    );
  }
}

class _CheckInBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CheckInBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(TT.rMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(TT.rMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(TT.rMd),
            border: Border.all(color: color.withOpacity(0.45), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: TT.body(
                          size: 9.5, w: FontWeight.w900, color: color)
                      .copyWith(letterSpacing: 0.12 * 9.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmberPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _EmberPillButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: TT.ember,
        borderRadius: BorderRadius.circular(TT.rMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(TT.rMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TT.rMd),
              boxShadow: disabled ? null : TT.shadowEmber,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(TT.emberInk),
                    ),
                  )
                else
                  Icon(icon, color: TT.emberInk, size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: TT.body(
                            size: 12.5,
                            w: FontWeight.w900,
                            color: TT.emberInk)
                        .copyWith(letterSpacing: 0.14 * 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── CALENDAR ──────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedDay;
  final List<HikePlan> plans;
  final void Function(DateTime) onDaySelected;

  const _CalendarGrid({
    required this.focusedDay,
    required this.plans,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedDay.year, focusedDay.month);
    final firstDayOffset =
        DateTime(focusedDay.year, focusedDay.month, 1).weekday % 7;
    final planDays = plans
        .where((p) =>
            p.hikeDate.year == focusedDay.year &&
            p.hikeDate.month == focusedDay.month)
        .map((p) => p.hikeDate.day)
        .toSet();
    final today = DateTime.now();

    final cells = List.generate(42, (i) {
      if (i < firstDayOffset || i >= firstDayOffset + daysInMonth) {
        return const Expanded(child: SizedBox());
      }
      final day = i - firstDayOffset + 1;
      final isToday = today.year == focusedDay.year &&
          today.month == focusedDay.month &&
          today.day == day;
      final hasPlan = planDays.contains(day);

      Color cellColor;
      Color borderColor;
      Color textColor;
      FontWeight textWeight;
      if (isToday) {
        cellColor = TT.emberDim;
        borderColor = const Color(0x59FF6A2C);
        textColor = TT.ember;
        textWeight = FontWeight.w900;
      } else if (hasPlan) {
        cellColor = const Color(0x08FFFFFF);
        borderColor = TT.line2;
        textColor = TT.ember;
        textWeight = FontWeight.w800;
      } else {
        cellColor = const Color(0x05FFFFFF);
        borderColor = TT.line;
        textColor = TT.text2;
        textWeight = FontWeight.w500;
      }

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onDaySelected(DateTime(focusedDay.year, focusedDay.month, day));
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            height: 44,
            decoration: BoxDecoration(
              color: cellColor,
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: TT.numStyle(
                      size: 13,
                      color: textColor,
                      w: textWeight,
                      letterSpacing: 0,
                    )),
                if (hasPlan)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: TT.ember,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });

    return Column(
      children: [
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TT.mono(size: 10.5, color: TT.text3)
                              .copyWith(letterSpacing: 0.1 * 10.5)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        for (int r = 0; r < 6; r++)
          Row(children: cells.sublist(r * 7, r * 7 + 7)),
      ],
    );
  }
}

// ─────────────────────────────────── MEMBERS ───────────────────────────────

class _MembersTab extends StatefulWidget {
  final Team team;
  final bool isAdmin;
  final String currentUid;
  const _MembersTab({
    required this.team,
    required this.isAdmin,
    required this.currentUid,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final _usernameCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _inviteByUsername() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    if (username.isEmpty) return;

    setState(() => _adding = true);

    try {
      final rows = await Supabase.instance.client.rpc(
        'find_profile_by_username',
        params: {'p_username': username},
      );

      if (!mounted) return;

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No account found for that username.',
                style: TT.body(size: 13, color: TT.text)),
            backgroundColor: TT.surf2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final row = rows.first;
        final member = TeamMember(
          uid: row['id'] as String,
          email: '',
          username: row['username'] as String? ?? username,
          displayName: row['display_name'] as String? ?? '@$username',
          photoUrl: row['photo_url'] as String? ?? '',
        );
        if (widget.team.hasMember(member.uid)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('That person is already in the team.',
                  style: TT.body(size: 13, color: TT.text)),
              backgroundColor: TT.surf2,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          await context.read<TeamProvider>().addMember(widget.team.id, member);
          _usernameCtrl.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${member.displayName} added!',
                    style: TT.body(size: 13, color: TT.text)),
                backgroundColor: TT.surf2,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e',
                style: TT.body(size: 13, color: TT.text)),
            backgroundColor: TT.surf2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Confirm + remove a member, refresh the team list, and surface the
  /// result via a snackbar. Previously the row's onTap fired
  /// removeMember() directly with no dialog or refresh — the RPC
  /// succeeded server-side but the local team data stayed stale so it
  /// looked like the delete didn't happen.
  Future<void> _confirmAndRemove(TeamMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Remove ${member.displayName}?', style: TT.title(15)),
        content: Text(
          'They will lose access to the team chat, hike plans, and live tracking. They can be re-invited later.',
          style: TT.body(size: 12, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: TT.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final teamProv = context.read<TeamProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await teamProv.removeMember(widget.team.id, member);
    if (!mounted) return;
    if (success) {
      // Refresh so the row disappears from the live UI.
      await teamProv.refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${member.displayName} removed.',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Could not remove ${member.displayName}. ${teamProv.error ?? "Try again."}',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareInviteLink() async {
    final code = widget.team.inviteCode;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No invite code yet — open the QR screen to generate one.',
            style: TT.body(size: 13, color: TT.text),
          ),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Share.share(
      'Join my Trailtether team "${widget.team.name}"!\n\n'
      'Open the app → Teams → Join Team, and enter code:\n\n'
      '  $code\n\n'
      'See you on the trail!',
      subject: 'Join ${widget.team.name} on Trailtether',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        if (widget.isAdmin) ...[
          TTCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHARE INVITE LINK',
                    style: TT.label(color: TT.ember)),
                const SizedBox(height: 8),
                Text(
                  'Send the team code via WhatsApp, email, SMS, or any installed share target. The recipient enters it in Teams → Join Team.',
                  style:
                      TT.body(size: 12, color: TT.text2).copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _shareInviteLink,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TT.rMd),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TT.ember2, TT.ember],
                      ),
                      boxShadow: TT.shadowEmber,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_outlined,
                            color: TT.emberInk, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'SHARE INVITE',
                          style: TT.label(
                              size: 12, color: TT.emberInk, letterSpacing: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.team.inviteCode.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CODE  ${widget.team.inviteCode}',
                          style: TT.mono(
                              size: 12,
                              color: TT.text2,
                              letterSpacing: 1.2),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.team.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Code copied!',
                                  style: TT.body(size: 13, color: TT.text)),
                              backgroundColor: TT.surf2,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.copy_rounded,
                              size: 16, color: TT.text3),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TTCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVITE BY USERNAME',
                    style: TT.label(color: TT.ember)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: TT.surf,
                          borderRadius: BorderRadius.circular(TT.rMd),
                          border: Border.all(color: TT.line2, width: 1),
                        ),
                        child: TextField(
                          controller: _usernameCtrl,
                          cursorColor: TT.ember,
                          style: TT.body(size: 13, color: TT.text),
                          onSubmitted: (_) => _inviteByUsername(),
                          decoration: InputDecoration(
                            hintText: '@username',
                            hintStyle: TT.body(size: 13, color: TT.text3),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _adding ? null : _inviteByUsername,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [TT.ember2, TT.ember],
                          ),
                          boxShadow: TT.shadowEmber,
                        ),
                        alignment: Alignment.center,
                        child: _adding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      TT.emberInk),
                                ),
                              )
                            : const Icon(Icons.person_add,
                                color: TT.emberInk, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TEAM ROSTER', style: TT.label(color: TT.ember)),
            TTPill(
              label: '${widget.team.members.length}',
              variant: TTPillVariant.ember,
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < widget.team.members.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == widget.team.members.length - 1 ? 0 : 8),
            child: _MemberRow(
              member: widget.team.members[i],
              isOwner: widget.team.members[i].uid == widget.team.createdBy,
              isMe: widget.team.members[i].uid == widget.currentUid,
              canRemove: widget.isAdmin &&
                  widget.team.members[i].uid != widget.team.createdBy,
              onRemove: () => _confirmAndRemove(widget.team.members[i]),
            ),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMember member;
  final bool isOwner;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.member,
    required this.isOwner,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
  });

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TT.ember, width: 1.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B3A1A), TT.ember2],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(member.displayName),
              style:
                  TT.body(size: 12, w: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '${member.displayName} (you)' : member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TT.body(
                            size: 13.5, w: FontWeight.w800, color: TT.text),
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 8),
                      const TTPill(
                          label: 'ADMIN', variant: TTPillVariant.ember),
                    ],
                  ],
                ),
                if (member.username.isNotEmpty || member.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.username.isNotEmpty
                        ? '@${member.username}'
                        : member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TT.mono(size: 10.5, color: TT.text3),
                  ),
                ],
              ],
            ),
          ),
          if (canRemove)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1AE63D2E),
                  borderRadius: BorderRadius.circular(TT.rSm),
                  border:
                      Border.all(color: const Color(0x59E63D2E), width: 1),
                ),
                child: const Icon(Icons.person_remove_outlined,
                    color: TT.red, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}
