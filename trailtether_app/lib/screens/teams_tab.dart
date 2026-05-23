import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/runtime_config.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../widgets/common/blueprint_background.dart';
import '../widgets/common/glass_panel.dart';
import 'team_detail_screen.dart';
import 'create_team_screen.dart';
import 'join_team_screen.dart';

class TeamsTab extends StatefulWidget {
  const TeamsTab({super.key});

  @override
  State<TeamsTab> createState() => _TeamsTabState();
}

class _TeamsTabState extends State<TeamsTab> {
  String? _lastUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kSupabaseAvailable) return;
    final auth = context.read<ap.AuthProvider>();
    final uid = auth.uid;
    if (uid != null && uid != _lastUid) {
      _lastUid = uid;
      final user = auth.user;
      if (user != null) {
        // Defer to avoid triggering notifyListeners during a build frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<TeamProvider>().listenForUser(user);
        });
      }
    } else if (uid == null && _lastUid != null) {
      _lastUid = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<TeamProvider>().clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ──────────────── Supabase not configured ─────────────────────────────────
    if (!kSupabaseAvailable) {
      return const _AuthRequired();
    }

    final authProv = context.watch<ap.AuthProvider>();
    // ──────────────── Not signed in ───────────────────────────────────────────
    if (authProv.user == null) {
      return const _SignInRequired();
    }

    final tp = context.watch<TeamProvider>();

    return Scaffold(
      backgroundColor: kColorBg,
      body: BlueprintBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ──────────────── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: kColorOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Teams'.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Action buttons in a scrollable row to prevent overflow
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Join team button
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const JoinTeamScreen()),
                            ),
                            child: GlassPanel(
                              opacity: 0.1,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kColorOrange.withOpacity(0.3)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.qr_code_scanner,
                                      color: kColorOrange, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'JOIN',
                                    style: GoogleFonts.outfit(
                                      color: kColorOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Create team button
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CreateTeamScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: kColorOrange,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: kColorOrange.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add,
                                      color: kColorBg, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'NEW TEAM',
                                    style: GoogleFonts.outfit(
                                      color: kColorBg,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ──────────────── Body ────────────────────────────────────────────
              if (tp.loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: kColorOrange, strokeWidth: 2),
                  ),
                )
              else if (tp.teams.isEmpty)
                const Expanded(child: _EmptyState())
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: tp.teams.length,
                    cacheExtent: 1000,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final team = tp.teams[i];
                      final isSelected = tp.selectedTeam?.id == team.id;

                      return _TeamCard(
                        rank: i + 1,
                        team: team,
                        isSelected: isSelected,
                        currentUid: authProv.uid ?? '',
                        onSelect: () => tp.selectTeam(team),
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => TeamDetailScreen(team: team),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Team card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TeamCard extends StatelessWidget {
  final Team team;
  final int rank;
  final bool isSelected;
  final String currentUid;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  const _TeamCard({
    required this.team,
    required this.rank,
    required this.isSelected,
    required this.currentUid,
    required this.onTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color:
              isSelected ? kColorOrange.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? kColorOrange.withOpacity(0.5)
                : kColorOrange.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: GlassPanel(
          opacity: 0.7,
          blur: 10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kColorOrange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: kColorOrange.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.group,
                          color: kColorOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: GoogleFonts.outfit(
                              color: kColorCream,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (team.description.isNotEmpty)
                            Text(
                              team.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: kColorCream.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kColorOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: kColorOrange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'RANK #$rank',
                        style: GoogleFonts.outfit(
                          color: kColorOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatBadge(
                      icon: Icons.person_outline,
                      label: '${team.members.length}',
                      color: kColorCream.withOpacity(0.5),
                    ),
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: Icons.straighten,
                      label: '${team.totalDistanceKm.toStringAsFixed(1)} KM',
                      color: kColorOrange,
                    ),
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: Icons.trending_up,
                      label: '${team.totalAscent.toInt()} m',
                      color: Colors.blueAccent,
                    ),
                    const Spacer(),
                    if (!isSelected)
                      TextButton(
                        onPressed: onSelect,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: kColorOrange.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'SELECT',
                          style: GoogleFonts.outfit(
                            color: kColorOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kColorOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.outfit(
                            color: kColorBg,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Empty / placeholder states ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined,
                color: kColorCream.withOpacity(0.2), size: 48),
            const SizedBox(height: 16),
            Text(
              'No teams yet',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a team to plan hikes with friends,\nor join one with an invite code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.3),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinTeamScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorOrange.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner,
                        color: kColorOrange, size: 16),
                    const SizedBox(width: 8),
                    Text('Join with Invite Code',
                        style: GoogleFonts.outfit(
                            color: kColorOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthRequired extends StatelessWidget {
  const _AuthRequired();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kColorOrange.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group_outlined,
                    color: kColorOrange.withOpacity(0.5), size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'Teams need a connection',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.7),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Teams, hike planning, and invites are stored in the cloud.\n\n'
                'Make sure the app is connected to Supabase and that\n'
                'you are signed in to use this feature.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  color: kColorCream.withOpacity(0.2), size: 48),
              const SizedBox(height: 16),
              Text(
                'Sign in to use Teams',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
