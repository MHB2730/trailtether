// Trailtether — Admin console shell.
//
// Single tabbed screen that fronts every administrative surface
// (Dashboard, Users, Teams, Trails, Community, Safety, Logs, Settings, 3D).
// Surfaced from desktop_shell.dart only when AuthProvider.isAdmin is true —
// non-admin users never see this entry or its tabs.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import 'admin_3d_tab.dart';
import 'admin_community_tab.dart';
import 'admin_dashboard.dart';
import 'admin_logs_tab.dart';
import 'admin_safety_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_teams_tab.dart';
import 'admin_trails_tab.dart';
import 'admin_users_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell>
    with SingleTickerProviderStateMixin {
  static const _tabs = <_AdminTab>[
    _AdminTab('Overview', Icons.dashboard_outlined, AdminDashboard()),
    _AdminTab('Users', Icons.person_outline, AdminUsersTab()),
    _AdminTab('Teams', Icons.groups_outlined, AdminTeamsTab()),
    _AdminTab('Trails', Icons.alt_route_outlined, AdminTrailsTab()),
    _AdminTab('Community', Icons.public_outlined, AdminCommunityTab()),
    _AdminTab('Safety', Icons.shield_outlined, AdminSafetyTab()),
    _AdminTab('Logs', Icons.terminal_outlined, AdminLogsTab()),
    _AdminTab('3D', Icons.view_in_ar_outlined, Admin3DTab()),
    _AdminTab('Settings', Icons.settings_outlined, AdminSettingsTab()),
  ];

  late final TabController _ctl =
      TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: kColorBg,
          child: TabBar(
            controller: _ctl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kColorOrange,
            unselectedLabelColor: kColorCream.withOpacity(0.5),
            indicatorColor: kColorOrange,
            labelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              for (final t in _tabs)
                Tab(icon: Icon(t.icon, size: 16), text: t.label),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _ctl,
            children: [for (final t in _tabs) t.body],
          ),
        ),
      ],
    );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  final Widget body;
  const _AdminTab(this.label, this.icon, this.body);
}
