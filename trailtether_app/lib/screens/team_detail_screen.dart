import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../services/team_service.dart';
import '../providers/team_tracking_provider.dart';
import 'create_hike_plan_screen.dart';
import 'team_chat_screen.dart';
import 'team_invite_screen.dart';
import 'hike_plan_detail_screen.dart';
import 'admin/mission_control_tab.dart';

class TeamDetailScreen extends StatelessWidget {
  final Team team;
  const TeamDetailScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<ap.AuthProvider>().uid ?? '';
    final isAdmin = team.createdBy == currentUid;

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        elevation: 0,
        title: Text(
          team.name,
          style: GoogleFonts.outfit(
              color: kColorCream, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Invite via QR — available to all members
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: kColorOrange),
            tooltip: 'Invite with QR code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamInviteScreen(team: team),
              ),
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.redAccent.withOpacity(0.8)),
              tooltip: 'Delete team',
              onPressed: () async {
                final confirmed = await _confirmDelete(context);
                if (confirmed == true && context.mounted) {
                  await context.read<TeamProvider>().deleteTeam(team.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          // Mission Control shortcut
          IconButton(
            icon: const Icon(Icons.radar, color: kColorOrange),
            tooltip: 'Mission Control',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MissionControlTab()),
            ),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // ── Tab bar ─────────────────────────────────────────────
            Container(
              color: kColorBg,
              child: TabBar(
                labelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
                labelColor: kColorOrange,
                unselectedLabelColor: kColorCream.withOpacity(0.4),
                indicatorColor: kColorOrange,
                tabs: const [
                  Tab(text: 'Team Chat'),
                  Tab(text: 'Hike Plans'),
                  Tab(text: 'Members'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // ── Team chat tab ─────────────────────────────────
                  TeamChatScreen(team: team),
                  // ── Hike plans tab ───────────────────────────────
                  _HikePlansTab(team: team, currentUid: currentUid),
                  // ── Members tab ──────────────────────────────────
                  _MembersTab(
                      team: team, isAdmin: isAdmin, currentUid: currentUid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kColorPanel,
          title: Text('Delete team?',
              style: GoogleFonts.outfit(color: kColorCream)),
          content: Text(
            'This will remove the team and all its hike plans. This cannot be undone.',
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.6), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancel', style: GoogleFonts.outfit(color: kColorCream)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: GoogleFonts.outfit(color: Colors.redAccent)),
            ),
          ],
        ),
      );
}

// ── Hike plans tab ─────────────────────────────────────────────────────────────
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

  void _planHike([DateTime? date]) async {
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
            child:
                CircularProgressIndicator(color: kColorOrange, strokeWidth: 2),
          );
        }

        final plans = snap.data ?? [];

        return Column(
          children: [
            // ── Calendar Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hike Schedule',
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: kColorCream, size: 20),
                      onPressed: () => setState(() => _focusedDay =
                          DateTime(_focusedDay.year, _focusedDay.month - 1, 1)),
                    ),
                    Text(DateFormat('MMMM yyyy').format(_focusedDay),
                        style: GoogleFonts.outfit(
                            color: kColorOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: kColorCream, size: 20),
                      onPressed: () => setState(() => _focusedDay =
                          DateTime(_focusedDay.year, _focusedDay.month + 1, 1)),
                    ),
                  ]),
                ],
              ),
            ),

            // ── Calendar Grid ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _CalendarGrid(
                focusedDay: _focusedDay,
                plans: plans,
                onDaySelected: _planHike,
              ),
            ),

            const SizedBox(height: 16),

            // ── Add plan button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Quick Plan',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kColorOrange,
                    side: BorderSide(color: kColorOrange.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _planHike(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Plan list ────────────────────────────────────────────
            if (plans.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No hikes planned yet.\nSelect a date or tap "Quick Plan".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.3),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _PlanCard(
                    plan: plans[i],
                    canDelete: plans[i].createdBy == widget.currentUid,
                    team: widget.team,
                    currentUid: widget.currentUid,
                    onDeleted: _refresh,
                    onUpdated: _refresh,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
        context.read<TeamTrackingProvider>().setActiveHike(HikePlan.fromMap({
              ...widget.plan.toInsertMap(),
              'id': widget.plan.id,
              'status': 'active'
            }));
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error starting hike: $e')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error updating RSVP: $e')));
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

    // Resolve member names
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HikePlanDetailScreen(plan: widget.plan, team: widget.team),
        ),
      ).then((_) => widget.onUpdated?.call()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPast
                ? kColorBorder
                : (rsvpStatus == 'going'
                    ? kColorOrange
                    : kColorOrange.withOpacity(0.3)),
            width: rsvpStatus == 'going' ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.plan.trailName,
                    style: GoogleFonts.outfit(
                      color:
                          isPast ? kColorCream.withOpacity(0.5) : kColorCream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isPast)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kColorOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.plan.status == 'active' ? 'ACTIVE' : 'Upcoming',
                      style: GoogleFonts.outfit(
                        color: kColorOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (widget.canDelete) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      await TeamService.deletePlan(widget.plan.id);
                      widget.onDeleted?.call();
                    },
                    child: Icon(Icons.close,
                        color: kColorCream.withOpacity(0.3), size: 16),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: kColorCream.withOpacity(0.35), size: 12),
                const SizedBox(width: 4),
                Text(
                  extras.time.isNotEmpty
                      ? '$dateStr @ ${extras.time}'
                      : dateStr,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
            if (widget.plan.meetingPoint.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: kColorCream.withOpacity(0.35), size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.plan.meetingPoint,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.55), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20, color: kColorBorder),

            // ── RSVP Section ──────────────────────────────────────────
            if (!isPast && isInvited) ...[
              Row(
                children: [
                  Text('Are you going?',
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (_busy)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kColorOrange))
                  else ...[
                    _RsvpBtn(
                      label: 'Going',
                      active: rsvpStatus == 'going',
                      onTap: () => _updateRsvp('going'),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _RsvpBtn(
                      label: 'No',
                      active: rsvpStatus == 'not_going',
                      onTap: () => _updateRsvp('not_going'),
                      color: Colors.redAccent,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (goingNames.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Going: ${goingNames.join(", ")}',
                      style: GoogleFonts.outfit(
                          color: Colors.green.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            if (invitedNames.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.people_outline,
                      color: kColorCream.withOpacity(0.4), size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Team: ${invitedNames.join(", ")}',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.5), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],

            if (extras.weather.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_outlined,
                        color: Colors.blue, size: 12),
                    const SizedBox(width: 4),
                    Text(extras.weather,
                        style: GoogleFonts.outfit(
                            color: Colors.blue, fontSize: 11)),
                  ],
                ),
              ),
            ],

            if (extras.gearList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: extras.gearList
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.memberStatuses.values.any((v) => v)
                                ? Colors.green.withOpacity(0.2)
                                : kColorPanel,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: item.memberStatuses.values.any((v) => v)
                                    ? Colors.green.withOpacity(0.5)
                                    : kColorBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.memberStatuses.values.any((v) => v))
                                const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check,
                                        size: 10, color: Colors.green)),
                              Text(item.name,
                                  style: GoogleFonts.outfit(
                                      color: kColorCream.withOpacity(0.7),
                                      fontSize: 10)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],

            if (extras.emergencyContacts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.emergency,
                      color: Colors.redAccent, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Emergency: ${extras.emergencyContacts.first}',
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],

            if (extras.userNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                extras.userNotes,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // ── Management Controls ──
            if (!isPast &&
                widget.plan.status == 'planned' &&
                rsvpStatus == 'going') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _startHike,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START HIKE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],

            if (widget.plan.status == 'active' && rsvpStatus == 'going') ...[
              const SizedBox(height: 16),
              const Divider(color: kColorBorder),
              const SizedBox(height: 8),
              Text('CHECK IN',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _CheckInBtn(
                          label: 'OK',
                          color: Colors.green,
                          icon: Icons.check,
                          onTap: () => context
                              .read<TeamTrackingProvider>()
                              .checkIn('ok'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _CheckInBtn(
                          label: 'HELP',
                          color: Colors.redAccent,
                          icon: Icons.warning_amber,
                          onTap: () => context
                              .read<TeamTrackingProvider>()
                              .checkIn('help'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _CheckInBtn(
                          label: 'ARRIVED',
                          color: Colors.blue,
                          icon: Icons.flag,
                          onTap: () async {
                            await context
                                .read<TeamTrackingProvider>()
                                .checkIn('arrived');
                            widget.onUpdated?.call();
                          })),
                ],
              ),
            ],
          ],
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
  const _CheckInBtn(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RsvpBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _RsvpBtn(
      {required this.label,
      required this.active,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : kColorPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : kColorBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: active ? color : kColorCream.withOpacity(0.5),
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Members tab ────────────────────────────────────────────────────────────────
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

    // Look up a teammate by public username.
    try {
      final rows = await Supabase.instance.client.rpc(
        'find_profile_by_username',
        params: {'p_username': username},
      );

      if (!mounted) return;

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found for that username.'),
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
            const SnackBar(
                content: Text('That person is already in the team.')),
          );
        } else {
          await context.read<TeamProvider>().addMember(widget.team.id, member);
          _usernameCtrl.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${member.displayName} added!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Invite field (admin only) ────────────────────────────────
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: kColorPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: TextField(
                      controller: _usernameCtrl,
                      style:
                          GoogleFonts.outfit(color: kColorCream, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Invite by username...',
                        hintStyle: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.3), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _adding ? null : _inviteByUsername,
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: kColorOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _adding
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.person_add,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // ── Member list ──────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            itemCount: widget.team.members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (ctx, i) {
              final m = widget.team.members[i];
              final isOwner = m.uid == widget.team.createdBy;
              final isMe = m.uid == widget.currentUid;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kColorOrange.withOpacity(0.15),
                      child: Text(
                        _initials(m.displayName),
                        style: GoogleFonts.outfit(
                          color: kColorOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isMe ? '${m.displayName} (you)' : m.displayName,
                                style: GoogleFonts.outfit(
                                  color: kColorCream,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: kColorOrange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: GoogleFonts.outfit(
                                      color: kColorOrange,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (m.username.isNotEmpty || m.email.isNotEmpty)
                            Text(
                              m.username.isNotEmpty
                                  ? '@${m.username}'
                                  : m.email,
                              style: GoogleFonts.outfit(
                                color: kColorCream.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Admin can remove non-owner members
                    if (widget.isAdmin && !isOwner)
                      GestureDetector(
                        onTap: () => context
                            .read<TeamProvider>()
                            .removeMember(widget.team.id, m),
                        child: Icon(Icons.person_remove_outlined,
                            color: kColorCream.withOpacity(0.3), size: 18),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedDay;
  final List<HikePlan> plans;
  final Function(DateTime) onDaySelected;

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

      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onDaySelected(DateTime(focusedDay.year, focusedDay.month, day));
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            height: 48,
            decoration: BoxDecoration(
              color: isToday ? kColorOrange.withOpacity(0.1) : kColorPanel,
              border: Border.all(
                  color:
                      isToday ? kColorOrange.withOpacity(0.5) : kColorBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: GoogleFonts.outfit(
                        color: hasPlan
                            ? kColorOrange
                            : (isToday
                                ? Colors.white
                                : kColorCream.withOpacity(0.6)),
                        fontWeight: hasPlan || isToday
                            ? FontWeight.w900
                            : FontWeight.w500,
                        fontSize: 14)),
                if (hasPlan)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: kColorOrange, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      );
    });

    return Column(children: [
      Row(
        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
            .map((d) => Expanded(
                  child: Center(
                      child: Text(d,
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3),
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                ))
            .toList(),
      ),
      const SizedBox(height: 6),
      for (int r = 0; r < 6; r++)
        Row(children: cells.sublist(r * 7, r * 7 + 7)),
    ]);
  }
}
