import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import 'home_tab.dart';
import 'map_screen.dart';
import 'tools_tab.dart';
import 'chat_tab.dart';
import 'teams_tab.dart';
import 'profile_tab.dart';

// ══════════════════════════════════════════════════════════════════════════════
// App Shell — 6-tab navigation (Trails moved to Map button)
//   0 Home · 1 Map · 2 Tools · 3 Community · 4 Teams · 5 Profile
// ══════════════════════════════════════════════════════════════════════════════
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/team_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      context.read<TeamProvider>().listenForUser(user);
    }
  }

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _LazyTabStack(
        index: _index,
        children: [
          HomeTab(onNavigate: (i) {
            // Adjust home navigation indices to match new shell
            // Home originally pointed to: 1 Trails, 2 Map, 3 Tools, 4 Chat...
            // Now: 1 Map, 2 Tools, 3 Community...
            if (i == 1) _goTo(1); // Trails -> Map (since trails are on map now)
            if (i == 2) _goTo(1); // Map -> Map
            if (i == 3) _goTo(2); // Tools -> Tools
            if (i == 4) _goTo(3); // Chat -> Community
            if (i == 5) _goTo(4); // Teams -> Teams
            if (i == 6) _goTo(5); // Profile -> Profile
          }),
          const MapScreen(), // 1 Map
          const ToolsTab(), // 2 Tools
          const ChatTab(), // 3 Community
          const TeamsTab(), // 4 Teams
          const ProfileTab(), // 5 Profile
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: _goTo,
      ),
    );
  }
}

class _LazyTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _LazyTabStack({required this.index, required this.children});
  @override
  State<_LazyTabStack> createState() => _LazyTabStackState();
}

class _LazyTabStackState extends State<_LazyTabStack> {
  late final Set<int> _built = {0};

  @override
  void didUpdateWidget(_LazyTabStack old) {
    super.didUpdateWidget(old);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        if (!_built.contains(i)) return const SizedBox.shrink();
        return Offstage(
          offstage: i != widget.index,
          child: widget.children[i],
        );
      }),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
      _NavItem(Icons.explore_outlined, Icons.explore, 'Tools'),
      _NavItem(Icons.public_outlined, Icons.public_rounded, 'Community'),
      _NavItem(Icons.group_outlined, Icons.group, 'Teams'),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kColorBg,
        border: Border(top: BorderSide(color: kColorBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final sel = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: sel ? 20 : 0,
                          height: sel ? 3 : 0,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: kColorOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          sel ? item.activeIcon : item.icon,
                          color: sel
                              ? kColorOrange
                              : kColorCream.withOpacity(0.35),
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: GoogleFonts.outfit(
                            color: sel
                                ? kColorOrange
                                : kColorCream.withOpacity(0.35),
                            fontSize: 9,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
