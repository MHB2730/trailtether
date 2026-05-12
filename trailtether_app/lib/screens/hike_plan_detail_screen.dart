import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../services/team_service.dart';
import '../widgets/common/user_avatar.dart';

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
          SnackBar(content: Text('Error updating gear: $e')),
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
      backgroundColor: kColorBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: kColorBg,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _plan.trailName,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: kColorCream,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, kColorBg],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kColorOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'HIKE PREPARATION',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Trip Schedule ──────────────────────────────────────────
                  const _SectionHeader(
                      title: 'Trip Schedule', icon: Icons.event),
                  const SizedBox(height: 12),
                  _InfoTile(
                    label: 'Start Date',
                    value: extras.time.isNotEmpty
                        ? '$startDateStr @ ${extras.time}'
                        : startDateStr,
                    icon: Icons.calendar_today,
                  ),
                  if (endDateStr != null) ...[
                    const SizedBox(height: 8),
                    _InfoTile(
                      label: 'End Date',
                      value: endDateStr,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                  if (_plan.meetingPoint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoTile(
                      label: 'Meeting Point',
                      value: _plan.meetingPoint,
                      icon: Icons.location_on,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Weather & Safety ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                                title: 'Weather',
                                icon: Icons.wb_sunny_outlined),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kColorPanel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kColorBorder),
                              ),
                              child: Text(
                                extras.weather.isNotEmpty
                                    ? extras.weather
                                    : 'No report added.',
                                style: GoogleFonts.outfit(
                                  color: extras.weather.isNotEmpty
                                      ? kColorCream
                                      : kColorCream.withOpacity(0.3),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(
                                title: 'Emergency',
                                icon: Icons.emergency_outlined),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kColorPanel,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kColorBorder),
                              ),
                              child: Text(
                                extras.emergencyContacts.isNotEmpty
                                    ? extras.emergencyContacts.first
                                    : 'None set.',
                                style: GoogleFonts.outfit(
                                  color: extras.emergencyContacts.isNotEmpty
                                      ? Colors.redAccent
                                      : kColorCream.withOpacity(0.3),
                                  fontSize: 13,
                                  fontWeight:
                                      extras.emergencyContacts.isNotEmpty
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Gear Checklist ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionHeader(
                          title: 'Equipment Checklist', icon: Icons.checklist),
                      if (_busy)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kColorOrange)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track what you and your teammates have packed.',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
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

                  const SizedBox(height: 32),

                  // ── Team RSVP ─────────────────────────────────────────────
                  const _SectionHeader(
                      title: 'Team Attendance',
                      icon: Icons.people_alt_outlined),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: kColorPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Column(
                      children: widget.team.members
                          .where((m) =>
                              extras.invitedMembers.contains(m.uid) ||
                              m.uid == _plan.createdBy)
                          .map((m) {
                        final status = extras.rsvp[m.uid] ?? 'invited';
                        return ListTile(
                          dense: true,
                          leading: UserAvatar(
                            radius: 14,
                            photoUrl: m.photoUrl,
                            displayName: m.displayName,
                            backgroundColor: kColorBg,
                          ),
                          title: Text(m.displayName,
                              style: GoogleFonts.outfit(
                                  color: kColorCream,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'going'
                                  ? Colors.green.withOpacity(0.1)
                                  : kColorBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: status == 'going'
                                      ? Colors.green.withOpacity(0.3)
                                      : kColorBorder),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: status == 'going'
                                    ? Colors.green
                                    : kColorCream.withOpacity(0.3),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kColorOrange, size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kColorBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kColorOrange, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4), fontSize: 11)),
                Text(value,
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final isPackedByMe = item.memberStatuses[currentUid] ?? false;
    final packedMembers =
        team.members.where((m) => item.memberStatuses[m.uid] == true).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPackedByMe ? kColorOrange.withOpacity(0.5) : kColorBorder),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            leading: Icon(
              isPackedByMe ? Icons.check_circle : Icons.circle_outlined,
              color: isPackedByMe ? kColorOrange : kColorCream.withOpacity(0.2),
            ),
            title: Text(
              item.name,
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: isPackedByMe ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(item.category,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4), fontSize: 11)),
            trailing: item.isMandatory
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('REQUIRED',
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                  )
                : null,
          ),
          if (packedMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
              child: Row(
                children: [
                  Text('Packed by: ',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.3), fontSize: 10)),
                  ...packedMembers.map((m) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: m.displayName,
                          child: UserAvatar(
                            radius: 8,
                            photoUrl: m.photoUrl,
                            displayName: m.displayName,
                            backgroundColor: kColorOrange,
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder, style: BorderStyle.none),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.3), fontSize: 13),
      ),
    );
  }
}
