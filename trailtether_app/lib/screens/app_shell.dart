import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design_tokens.dart';
import '../providers/team_provider.dart';
import '../widgets/design/tt_bottom_nav.dart';
import 'tt_community_screen.dart';
import 'tt_home_screen.dart';
import 'tt_map_screen.dart';
import 'tt_profile_screen.dart';
import 'tt_team_screen.dart';
import 'tt_tools_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// App Shell — Trailtether v3.0 6-tab navigation
//   0 Home · 1 Map · 2 Tools · 3 Community · 4 Teams · 5 Profile
// Each tab hosts a TT-skinned screen embedded inside this shell's Scaffold so
// the bottom nav stays persistent across tab switches.
// ══════════════════════════════════════════════════════════════════════════════

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
      backgroundColor: TT.bg,
      body: SafeArea(
        bottom: false,
        child: _LazyTabStack(
          index: _index,
          children: [
            TTHomeScreen(embedded: true, onNavigate: _goTo),
            const TTMapScreen(embedded: true),
            const TTToolsScreen(embedded: true),
            const TTCommunityScreen(embedded: true),
            TTTeamScreen(embedded: true, onNavigate: _goTo),
            const TTProfileScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: TTBottomNav(
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
