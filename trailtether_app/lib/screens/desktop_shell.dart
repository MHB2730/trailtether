import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import 'home_tab.dart';
import 'tools_tab.dart';
import 'chat_tab.dart';
import 'teams_tab.dart';
import 'admin/admin_shell.dart';
import 'admin/mission_control_tab.dart';
import 'admin/diagnostic_console.dart';
import '../../providers/team_provider.dart';
import '../../models/team.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainDesktopShell extends StatefulWidget {
  const MainDesktopShell({super.key});

  @override
  State<MainDesktopShell> createState() => _MainDesktopShellState();
}

class _MainDesktopShellState extends State<MainDesktopShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      context.read<TeamProvider>().listenForUser(user);
    }
  }

  /// Build the desktop nav list. The "System Admin" entry is only emitted when
  /// the signed-in user has `profiles.is_admin = true` server-side, so non-admin
  /// users never see the admin console or its 9 sub-tabs.
  List<_DesktopTab> _buildTabs({required bool isAdmin}) => [
        _DesktopTab(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          builder: (context) => HomeTab(onNavigate: (index) {
            // Map HomeTab indices to unified Desktop indices
            int target = 0;
            if (index == 1 || index == 2) {
              target = 1; // Map/Trails -> Command Center
            } else if (index == 3) {
              target = 2; // Tools -> Tools
            } else if (index == 4) {
              target = 3; // Chat -> Community
            } else if (index == 5) {
              target = 4; // Teams -> Teams
            } else if (index == 6) {
              target = 1; // Profile (Redirect to Command for now)
            }
            setState(() => _selectedIndex = target);
          }),
        ),
        _DesktopTab(
          label: 'Command Center',
          icon: Icons.track_changes_rounded,
          selectedIcon: Icons.track_changes,
          builder: (context) => const MissionControlTab(),
        ),
        _DesktopTab(
          label: 'Tools & GPX',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          builder: (context) => const ToolsTab(),
        ),
        _DesktopTab(
          label: 'Community Hub',
          icon: Icons.public_outlined,
          selectedIcon: Icons.public,
          builder: (context) => const ChatTab(),
        ),
        _DesktopTab(
          label: 'Field Teams',
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          builder: (context) => const TeamsTab(),
        ),
        _DesktopTab(
          label: 'System Logs',
          icon: Icons.terminal_outlined,
          selectedIcon: Icons.terminal,
          builder: (context) => const DiagnosticConsole(),
        ),
        if (isAdmin)
          _DesktopTab(
            label: 'System Admin',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings,
            builder: (context) => const AdminShell(),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tabs = _buildTabs(isAdmin: auth.isAdmin);
    // Defend against an admin being demoted mid-session while the Admin tab is
    // selected — clamp the index so the build never reads past the end.
    if (_selectedIndex >= tabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: kColorBg,
      body: Stack(
        children: [
          // Background Grid (Stitch Aesthetic)
          const Positioned.fill(child: _BlueprintGrid()),

          Row(
            children: [
              // Sidebar
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFF080808).withOpacity(0.85),
                  border: const Border(
                      right: BorderSide(color: kColorBorder, width: 1)),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ColorFilter.mode(
                        Colors.black.withOpacity(0.1), BlendMode.darken),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kColorOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: kColorOrange.withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.hub_outlined,
                                        color: kColorOrange, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TRAILTETHER',
                                        style: GoogleFonts.outfit(
                                          color: kColorCream,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      Text(
                                        'FIELD INTELLIGENCE',
                                        style: GoogleFonts.outfit(
                                          color: kColorOrange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 1,
                                width: double.infinity,
                                color: kColorBorder,
                              ),
                              const SizedBox(height: 16),
                              _buildTeamSwitcher(context),
                            ],
                          ),
                        ),

                        // Navigation Items
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: tabs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final tab = tabs[index];
                              final isSelected = _selectedIndex == index;

                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedIndex = index),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kColorOrange.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? kColorOrange.withOpacity(0.4)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? tab.selectedIcon
                                            : tab.icon,
                                        color: isSelected
                                            ? kColorOrange
                                            : kColorCream.withOpacity(0.5),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        tab.label,
                                        style: GoogleFonts.outfit(
                                          color: isSelected
                                              ? kColorCream
                                              : kColorCream.withOpacity(0.5),
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Spacer(),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: kColorOrange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Footer / User Profile
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kColorGlass,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kColorBorder),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: kColorOrange,
                                      child: Text(
                                        auth.email
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            'E',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            auth.displayName ?? 'Explorer',
                                            style: GoogleFonts.outfit(
                                              color: kColorCream,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            auth.email ?? 'Not logged in',
                                            style: GoogleFonts.outfit(
                                              color:
                                                  kColorCream.withOpacity(0.5),
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => auth.signOut(),
                                      icon: const Icon(Icons.logout,
                                          size: 18, color: Colors.redAccent),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: tabs[_selectedIndex].builder(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSwitcher(BuildContext context) {
    final teamProv = context.watch<TeamProvider>();
    final selected = teamProv.selectedTeam;
    final teams = teamProv.teams;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kColorGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined,
                  color: kColorOrange.withOpacity(0.5), size: 12),
              const SizedBox(width: 8),
              Text(
                'ACTIVE OPERATION',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<Team>(
              value: selected,
              isDense: true,
              isExpanded: true,
              dropdownColor: const Color(0xFF0D0D0D),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: kColorCream.withOpacity(0.3), size: 16),
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (team) => teamProv.selectTeam(team),
              items: teams.map((t) {
                return DropdownMenuItem<Team>(
                  value: t,
                  child: Text(t.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueprintGrid extends StatelessWidget {
  const _BlueprintGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kColorBorder.withOpacity(0.05)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    final accentPaint = Paint()
      ..color = kColorOrange.withOpacity(0.03)
      ..strokeWidth = 2;

    const bigStep = step * 5;
    for (double i = 0; i < size.width; i += bigStep) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), accentPaint);
    }
    for (double i = 0; i < size.height; i += bigStep) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DesktopTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const _DesktopTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}
