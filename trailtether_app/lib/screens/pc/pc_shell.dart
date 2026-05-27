// Trailtether — PC ("Base Camp") shell.
//
// Faithful Flutter port of `pc.html` from the design handoff. The
// desktop window is split into:
//   • A 232-wide sidebar with seven nav targets: Mission Control,
//     Hike Watch, Hikers, History, Alerts, Pair Device, Settings.
//   • A main content area with a page-header band ("eyebrow + title +
//     sub + actions") and a body.
//   • A footer "account card" in the sidebar showing the signed-in
//     watcher + a live "WATCHING · N HIKERS" pulse.
//
// macOS traffic-light circles are drawn as a cosmetic flourish — the
// real platform window chrome lives outside the Flutter view.
//
// Each nav target loads either:
//   • An existing in-app screen (Mission Control = MissionControlTab,
//     Settings = AdminSettingsTab, History = HikeHistoryScreen,
//     Alerts = the notifications-table feed).
//   • Or a new PC-only screen that already uses the design's
//     PC* primitives below (Hikers, Hike Watch, Pair Device).
//
// Replaces the old MainDesktopShell — main.dart routes to this on
// Windows / macOS / Linux. Mobile keeps its 6-tab AppShell.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/design_tokens.dart';
import '../../providers/auth_provider.dart' as ap;
import '../../providers/team_provider.dart';
import '../admin/admin_settings_tab.dart';
import '../admin/mission_control_tab.dart';
import '../hike_history_screen.dart';
import '../team_detail_screen.dart';
import 'pc_trails_screen.dart';

// ─────────────────────────── tokens (pc-local) ──────────────────────────────
//
// Mirrors the `:root` block in `pc.html`. We pull the canonical brand
// colours through `TT` (already shared with mobile) and supplement with
// a couple of PC-only surfaces (window bg, sidebar gradient stops).

class PC {
  static const windowBg = Color(0xFF06080B);
  static const sidebarTop = Color(0xFF0B0E12);
  static const sidebarBottom = Color(0xFF07090C);
  static const titlebarTop = Color(0xFF131820);
  static const titlebarBottom = Color(0xFF0B0E12);
  static const tlRed = Color(0xFFFF5F56);
  static const tlYellow = Color(0xFFFFBD2E);
  static const tlGreen = Color(0xFF27C93F);
}

// ───────────────────────────── nav model ────────────────────────────────────

enum _PcSection {
  dashboard,
  watch,
  hikers,
  history,
  trails,
  alerts,
  pair,
  settings,
}

class _NavSpec {
  final _PcSection id;
  final IconData icon;
  final String label;
  final bool live;
  /// Whether this nav entry should be hidden from non-admin users. RLS
  /// already gates server-side writes, but showing tabs that error on use
  /// is a poor experience — better to hide them entirely.
  final bool adminOnly;
  const _NavSpec({
    required this.id,
    required this.icon,
    required this.label,
    this.live = false,
    this.adminOnly = false,
  });
}

const _kNav = [
  _NavSpec(id: _PcSection.dashboard, icon: Icons.public, label: 'Mission Control'),
  _NavSpec(id: _PcSection.watch,     icon: Icons.visibility_outlined, label: 'Hike Watch', live: true),
  _NavSpec(id: _PcSection.hikers,    icon: Icons.people_outline, label: 'Hikers'),
  _NavSpec(id: _PcSection.history,   icon: Icons.history, label: 'History'),
  _NavSpec(id: _PcSection.trails,    icon: Icons.alt_route_outlined, label: 'Trails', adminOnly: true),
  _NavSpec(id: _PcSection.alerts,    icon: Icons.notifications_none_rounded, label: 'Alerts'),
  _NavSpec(id: _PcSection.pair,      icon: Icons.qr_code_2_rounded, label: 'Pair Device'),
  _NavSpec(id: _PcSection.settings,  icon: Icons.settings_outlined, label: 'Settings', adminOnly: true),
];

// ───────────────────────────── main shell ───────────────────────────────────

class MainPcShell extends StatefulWidget {
  const MainPcShell({super.key});

  @override
  State<MainPcShell> createState() => _MainPcShellState();
}

class _MainPcShellState extends State<MainPcShell> {
  _PcSection _active = _PcSection.dashboard;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      context.read<TeamProvider>().listenForUser(user);
    }
  }

  void _go(_PcSection s) {
    if (!mounted) return;
    setState(() => _active = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PC.windowBg,
      body: SafeArea(
        child: Column(
          children: [
            const _PCTitleBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PCSidebar(
                    active: _active,
                    onSelect: _go,
                  ),
                  Expanded(
                    child: Container(
                      color: TT.bg,
                      child: _PcContent(section: _active, onNavigate: _go),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PcContent extends StatelessWidget {
  final _PcSection section;
  final ValueChanged<_PcSection> onNavigate;
  const _PcContent({required this.section, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case _PcSection.dashboard:
        return _PcDashboard(onNavigate: onNavigate);
      case _PcSection.watch:
        return _PcHikeWatch(onNavigate: onNavigate);
      case _PcSection.hikers:
        return _PcHikersList(onNavigate: onNavigate);
      case _PcSection.history:
        return const _PcHistory();
      case _PcSection.trails:
        return const PcTrailsScreen();
      case _PcSection.alerts:
        return const _PcAlerts();
      case _PcSection.pair:
        return const PcPairDeviceScreen();
      case _PcSection.settings:
        return const _PcSettings();
    }
  }
}

// ──────────────────────────────── chrome ────────────────────────────────────

class _PCTitleBar extends StatelessWidget {
  const _PCTitleBar();

  bool get _supportsWindowControls =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _close()    async { if (_supportsWindowControls) { try { await windowManager.close(); }    catch (_) {} } }
  Future<void> _minimize() async { if (_supportsWindowControls) { try { await windowManager.minimize(); } catch (_) {} } }
  Future<void> _toggleMax() async {
    if (!_supportsWindowControls) return;
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PC.titlebarTop, PC.titlebarBottom],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x0DFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Traffic-light controls. Hit-targets are padded out to 16x16 so
          // the click area is comfortable even though the dot is 12x12.
          Row(
            children: [
              _TrafficLight(color: PC.tlRed,    tooltip: 'Close',          onTap: _close),
              const SizedBox(width: 8),
              _TrafficLight(color: PC.tlYellow, tooltip: 'Minimize',       onTap: _minimize),
              const SizedBox(width: 8),
              _TrafficLight(color: PC.tlGreen,  tooltip: 'Maximize',       onTap: _toggleMax),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                'Trailtether · Base Camp',
                style: TT.body(size: 12.5, w: FontWeight.w600, color: TT.text2)
                    .copyWith(letterSpacing: 0.04 * 12.5),
              ),
            ),
          ),
          // Title-bar right edge — left intentionally empty for now. The
          // earlier decorative "search trails, hikers, plans…" pill was
          // removed because the field wasn't wired to anything; a dead
          // search box is worse than no search box.
          const SizedBox(width: 0),
        ],
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _TrafficLight({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: const Color(0x33000000), width: 0.5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26FFFFFF),
                      blurRadius: 0,
                      spreadRadius: 0.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PCSidebar extends StatelessWidget {
  final _PcSection active;
  final ValueChanged<_PcSection> onSelect;
  const _PCSidebar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<TeamProvider>().teams;
    final watcherName = context.select<ap.AuthProvider, String>((a) {
      final raw = (a.displayName ?? 'Watcher').trim();
      return raw.isEmpty ? 'Watcher' : raw;
    });
    // Filter admin-only nav items (Trails catalogue editor + Hilltrek
    // settings tab) out of the sidebar for non-admin viewers. RLS still
    // gates writes server-side, but showing tabs that error on use is a
    // worse UX than just hiding them.
    final isAdmin = context.watch<ap.AuthProvider>().isAdmin;
    final visibleNav =
        _kNav.where((n) => isAdmin || !n.adminOnly).toList(growable: false);
    final hikerCount = teams.fold<int>(0, (sum, t) => sum + t.members.length);

    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PC.sidebarTop, PC.sidebarBottom],
        ),
        border: Border(
          right: BorderSide(color: Color(0x0DFFFFFF), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand block.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TT.ember,
                    boxShadow: [
                      BoxShadow(
                          color: TT.ember.withOpacity(0.35), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TT.body(size: 12.5, w: FontWeight.w900)
                              .copyWith(letterSpacing: 0.16 * 12.5),
                          children: const [
                            TextSpan(text: 'TRAIL'),
                            TextSpan(
                              text: 'TETHER',
                              style: TextStyle(color: TT.ember),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'BASE CAMP · v3',
                        style: TT.mono(
                            size: 8.5,
                            color: TT.text3,
                            letterSpacing: 0.18 * 8.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final n in visibleNav)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _PCSidebarItem(
                      spec: n,
                      active: n.id == active,
                      onTap: () => onSelect(n.id),
                    ),
                  ),
              ],
            ),
          ),

          // Account footer.
          _AccountFooter(
            watcherName: watcherName,
            hikerCount: hikerCount,
            initials: _initials(watcherName),
            onOpenSettings: () => onSelect(_PcSection.settings),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _PCSidebarItem extends StatelessWidget {
  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;
  const _PCSidebarItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? TT.ember : TT.text2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active ? TT.emberDim : Colors.transparent,
            border: Border.all(
              color: active ? const Color(0x52FF6A2C) : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(spec.icon, size: 15, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  spec.label,
                  style: TT.body(size: 12.5, w: FontWeight.w700, color: color),
                ),
              ),
              if (spec.live) _PulseDot(color: TT.ember),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountFooter extends StatelessWidget {
  final String watcherName;
  final int hikerCount;
  final String initials;
  final VoidCallback onOpenSettings;
  const _AccountFooter({
    required this.watcherName,
    required this.hikerCount,
    required this.initials,
    required this.onOpenSettings,
  });

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line2),
        ),
        title: Text('Sign out?', style: TT.title(17)),
        content: Text(
          'You’ll need to sign back in to keep watching paired hikers.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign out',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await context.read<ap.AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TT.blue, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5AA1D6), Color(0xFF2D6A98)],
              ),
            ),
            child: Text(
              initials,
              style: TT.body(size: 12, w: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(watcherName,
                    style: TT.body(size: 12, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _PulseDot(),
                    const SizedBox(width: 4),
                    Text(
                      'WATCHING · ${hikerCount > 0 ? hikerCount : 0} HIKERS',
                      style: TT.mono(
                          size: 9,
                          color: TT.green,
                          letterSpacing: 0.1 * 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            color: TT.surf2,
            position: PopupMenuPosition.under,
            icon: const Icon(Icons.more_horiz, size: 16, color: TT.text3),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: TT.line2),
            ),
            onSelected: (v) {
              if (v == 'settings') onOpenSettings();
              if (v == 'signout') _confirmSignOut(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined,
                        size: 14, color: TT.text2),
                    const SizedBox(width: 10),
                    Text('Settings',
                        style: TT.body(size: 12.5, color: TT.text)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 14, color: TT.red),
                    const SizedBox(width: 10),
                    Text('Sign out',
                        style: TT.body(
                            size: 12.5, w: FontWeight.w700, color: TT.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  // ignore: unused_element_parameter
  const _PulseDot({this.color = TT.green});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value;
        // Mirrors the JSX `pulse` keyframes: 1 → 0.35 → 1 over 1.4 s.
        final opacity = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(t * math.pi * 2));
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.55), blurRadius: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────── primitives ────────────────────────────────────

class PCPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? sub;
  final List<Widget> actions;
  const PCPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.sub,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TT.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TT.mono(
                      size: 10.5,
                      color: TT.text3,
                      letterSpacing: 0.2 * 10.5),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TT.body(size: 26, w: FontWeight.w900)
                      .copyWith(letterSpacing: -0.018 * 26),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 5),
                  DefaultTextStyle(
                    style: TT.mono(
                        size: 12,
                        color: TT.text2,
                        letterSpacing: 0.04 * 12),
                    child: sub!,
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class PCBtn extends StatelessWidget {
  final String label;
  final IconData? leftIcon;
  final bool primary;
  final bool danger;
  final bool ghost;
  final VoidCallback? onTap;
  const PCBtn({
    super.key,
    required this.label,
    this.leftIcon,
    this.primary = false,
    this.danger = false,
    this.ghost = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, color, border;
    List<BoxShadow>? shadow;
    if (primary) {
      bg = TT.ember;
      color = TT.emberInk;
      border = Colors.transparent;
      shadow = [
        BoxShadow(
            color: TT.ember.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 10)),
      ];
    } else if (danger) {
      bg = const Color(0x1FE63D2E);
      color = TT.red;
      border = const Color(0x5CE63D2E);
    } else if (ghost) {
      bg = Colors.transparent;
      color = TT.text2;
      border = Colors.transparent;
    } else {
      bg = const Color(0x0AFFFFFF);
      color = TT.text;
      border = TT.line2;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          height: 36,
          alignment: Alignment.center,
          decoration: primary
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: shadow,
                )
              : BoxDecoration(
                  color: bg,
                  border: Border.all(color: border, width: 1),
                  borderRadius: BorderRadius.circular(9),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leftIcon != null) ...[
                Icon(leftIcon, size: 13, color: color),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TT.body(size: 11.5, w: FontWeight.w800, color: color)
                    .copyWith(letterSpacing: 0.08 * 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PCCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? borderColor;
  const PCCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: borderColor ?? TT.line, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class PCStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final IconData icon;
  final bool ember;
  final bool danger;
  const PCStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.sub,
    this.ember = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? TT.red : ember ? TT.ember : TT.text;
    final iconTint = danger ? TT.red : ember ? TT.ember : TT.text3;
    return PCCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconTint),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TT.body(size: 10, w: FontWeight.w700, color: TT.text3)
                    .copyWith(letterSpacing: 0.18 * 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TT.mono(size: 26, color: tint, letterSpacing: -0.025 * 26)
                    .copyWith(fontWeight: FontWeight.w900),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: TT.mono(size: 12, color: TT.text2)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub!,
              style: TT.mono(size: 10.5, color: TT.text3, letterSpacing: 0.04 * 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class PCPill extends StatelessWidget {
  final String label;
  final bool live;
  final bool ember;
  final bool success;
  final bool danger;
  const PCPill({
    super.key,
    required this.label,
    this.live = false,
    this.ember = false,
    this.success = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, border, color;
    if (ember) {
      bg = TT.emberDim;
      border = const Color(0x5CFF6A2C);
      color = TT.ember;
    } else if (success) {
      bg = const Color(0x214CC38A);
      border = const Color(0x5C4CC38A);
      color = TT.green;
    } else if (danger) {
      bg = const Color(0x21E63D2E);
      border = const Color(0x5CE63D2E);
      color = TT.red;
    } else {
      bg = const Color(0x0AFFFFFF);
      border = TT.line2;
      color = TT.text2;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            _PulseDot(color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TT.mono(size: 9.5, color: color, letterSpacing: 0.14 * 9.5)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── section: Dashboard ─────────────────────────────

class _PcDashboard extends StatelessWidget {
  final ValueChanged<_PcSection> onNavigate;
  const _PcDashboard({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'OVERVIEW',
          title: 'Mission Control',
          sub: const Text(
            'Live team map + hazard reports · updated each fix',
          ),
          actions: [
            PCBtn(
              label: 'ALERTS',
              leftIcon: Icons.notifications_none_rounded,
              onTap: () => onNavigate(_PcSection.alerts),
            ),
            PCBtn(
              label: 'WATCH HIKE',
              leftIcon: Icons.visibility_outlined,
              primary: true,
              onTap: () => onNavigate(_PcSection.watch),
            ),
          ],
        ),
        const Expanded(
          // The existing MissionControlTab already renders the full
          // team-tracking map + incident overlay. Reusing it keeps the
          // PC Dashboard wired to live realtime data without
          // duplicating the channel subscription code.
          child: MissionControlTab(),
        ),
      ],
    );
  }
}

// ─────────────────────────── section: Hike Watch ────────────────────────────

class _PcHikeWatch extends StatelessWidget {
  final ValueChanged<_PcSection> onNavigate;
  const _PcHikeWatch({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final teams = context.watch<TeamProvider>().teams;
    final hasPaired = teams.any((t) => t.members.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'LIVE',
          title: 'Hike Watch',
          sub: const Text('Per-hike deep-dive · elevation profile + alerts + timeline'),
          actions: hasPaired
              ? [
                  PCBtn(
                    label: 'VIEW HIKERS',
                    leftIcon: Icons.people_outline,
                    onTap: () => onNavigate(_PcSection.hikers),
                  ),
                ]
              : const [],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: PCCard(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 48, color: TT.text3),
                  const SizedBox(height: 16),
                  Text('No active hike to watch',
                      style: TT.title(18, letterSpacing: -0.01 * 18)),
                  const SizedBox(height: 8),
                  Text(
                    hasPaired
                        ? 'A hiker is paired but isn’t recording yet. Start a hike on their mobile app to see live position, elevation, pace, and incident overlay here.'
                        : 'Pair a phone first, then start a hike on the mobile app to see live position, elevation, pace, and incident overlay here.',
                    textAlign: TextAlign.center,
                    style: TT.body(size: 12, color: TT.text2)
                        .copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  PCBtn(
                    label: hasPaired ? 'OPEN MISSION CONTROL' : 'PAIR A DEVICE',
                    leftIcon: hasPaired
                        ? Icons.public
                        : Icons.qr_code_2_rounded,
                    primary: true,
                    onTap: () => onNavigate(
                        hasPaired ? _PcSection.dashboard : _PcSection.pair),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── section: Hikers ────────────────────────────────

class _PcHikersList extends StatelessWidget {
  final ValueChanged<_PcSection> onNavigate;
  const _PcHikersList({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final teamProv = context.watch<TeamProvider>();
    final teams = teamProv.teams;
    final members = [
      for (final t in teams)
        for (final m in t.members) (team: t, member: m),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'PAIRED HIKERS',
          title: 'Hikers',
          sub: Text(
            members.isEmpty
                ? 'No paired hikers yet · pair a device to start watching'
                : '${members.length} hikers across ${teams.length} teams',
          ),
          actions: [
            PCBtn(
              label: 'PAIR DEVICE',
              leftIcon: Icons.qr_code_2_rounded,
              primary: true,
              onTap: () => onNavigate(_PcSection.pair),
            ),
          ],
        ),
        Expanded(
          child: members.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(26),
                  child: PCCard(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 48, color: TT.text3),
                        const SizedBox(height: 16),
                        Text('No hikers paired yet',
                            style: TT.title(18, letterSpacing: -0.01 * 18)),
                        const SizedBox(height: 8),
                        Text(
                          'Open Pair Device, show the QR on this screen, and scan it from the mobile app to attach a phone.',
                          textAlign: TextAlign.center,
                          style: TT.body(size: 12, color: TT.text2)
                              .copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        PCBtn(
                          label: 'OPEN PAIR DEVICE',
                          leftIcon: Icons.qr_code_2_rounded,
                          primary: true,
                          onTap: () => onNavigate(_PcSection.pair),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(26),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = members[i];
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                TeamDetailScreen(team: r.team),
                          ));
                        },
                        child: PCCard(
                          padding:
                              const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              _AvatarCircle(name: r.member.displayName),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.member.displayName,
                                        style: TT.body(
                                            size: 13,
                                            w: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'TEAM · ${r.team.name.toUpperCase()}',
                                      style: TT.mono(
                                          size: 9.5,
                                          color: TT.text3,
                                          letterSpacing: 0.06 * 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              const PCPill(
                                  label: 'TETHERED', success: true),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: TT.text3),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  const _AvatarCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? (parts.first[0] + parts.last[0]).toUpperCase()
        : (parts.first.isEmpty
            ? '?'
            : parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
                .toUpperCase());
    // Cycle through the design's avatar palette by hashing the name.
    const palette = [
      Color(0xFFFF6A2C),
      Color(0xFF4CC38A),
      Color(0xFFF2A93B),
      Color(0xFF5AA1D6),
      Color(0xFFE63D2E),
    ];
    final c = palette[name.hashCode.abs() % palette.length];
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, c.withOpacity(0.66)],
        ),
      ),
      child: Text(
        initials,
        style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────── section: History ───────────────────────────────

class _PcHistory extends StatelessWidget {
  const _PcHistory();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PCPageHeader(
          eyebrow: 'ARCHIVE',
          title: 'History',
          sub: Text('Past hikes, GPX exports, recorded routes'),
        ),
        const Expanded(
          // Embed the existing mobile screen — already shows the full
          // hike list with the new design tokens.
          child: HikeHistoryScreen(embedded: true),
        ),
      ],
    );
  }
}

// ─────────────────────────── section: Alerts ────────────────────────────────

class _PcAlerts extends StatefulWidget {
  const _PcAlerts();
  @override
  State<_PcAlerts> createState() => _PcAlertsState();
}

class _PcAlertsState extends State<_PcAlerts> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await Supabase.instance.client
        .from('notifications')
        .select('*')
        .eq('user_id', uid)
        .order('received_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'INCOMING',
          title: 'Alerts',
          sub: const Text('Field reports, weather warnings, low-battery pings'),
          actions: [
            PCBtn(
              label: 'REFRESH',
              leftIcon: Icons.refresh_rounded,
              ghost: true,
              onTap: _refresh,
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator(color: TT.ember));
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(26),
                  child: PCCard(
                    child: Text('Could not load alerts: ${snap.error}',
                        style: TT.body(size: 12, color: TT.red)),
                  ),
                );
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(26),
                  child: PCCard(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: TT.green),
                        const SizedBox(height: 16),
                        Text('All clear',
                            style:
                                TT.title(18, letterSpacing: -0.01 * 18)),
                        const SizedBox(height: 8),
                        Text(
                          'No open alerts. Field reports + weather warnings will land here as they fire.',
                          textAlign: TextAlign.center,
                          style: TT.body(size: 12, color: TT.text2)
                              .copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(26),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final urgent = r['urgent'] == true;
                  return PCCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    borderColor: urgent ? const Color(0x80E63D2E) : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          urgent
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          size: 18,
                          color: urgent ? TT.red : TT.amber,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((r['title'] ?? '').toString(),
                                  style: TT.body(
                                      size: 13, w: FontWeight.w800)),
                              if (r['sub'] != null &&
                                  (r['sub'] as String).isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(r['sub'].toString(),
                                    style: TT.body(
                                        size: 11.5, color: TT.text2)),
                              ],
                            ],
                          ),
                        ),
                        if (urgent) const PCPill(label: 'URGENT', danger: true),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── section: Pair Device ───────────────────────────

class PcPairDeviceScreen extends StatefulWidget {
  const PcPairDeviceScreen({super.key});
  @override
  State<PcPairDeviceScreen> createState() => _PcPairDeviceScreenState();
}

class _PcPairDeviceScreenState extends State<PcPairDeviceScreen> {
  String? _token;
  DateTime? _expiresAt;
  StreamSubscription? _sub;
  Map<String, dynamic>? _pairedRow;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mintToken();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _mintToken() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _error = 'Sign in to mint a pairing token.');
      return;
    }
    setState(() {
      _error = null;
      _pairedRow = null;
    });
    final rnd = math.Random.secure();
    const alpha = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
    final token = List.generate(8, (_) => alpha[rnd.nextInt(alpha.length)]).join();
    try {
      final inserted = await Supabase.instance.client
          .from('tether_pairings')
          .insert({
            'watcher_uid': uid,
            'token': token,
            'pc_label': 'Base Camp PC',
          })
          .select('id, token, expires_at')
          .single();
      final pairingId = (inserted as Map)['id'] as String;
      final exp = DateTime.tryParse((inserted)['expires_at'] as String? ?? '');
      setState(() {
        _token = token;
        _expiresAt = exp;
      });
      // Subscribe to this row so when the mobile app claims the token
      // we know instantly.
      _sub?.cancel();
      _sub = Supabase.instance.client
          .from('tether_pairings')
          .stream(primaryKey: ['id'])
          .eq('id', pairingId)
          .listen((rows) {
        if (rows.isEmpty) return;
        final r = rows.first;
        if (r['paired_at'] != null && mounted) {
          setState(() => _pairedRow = r);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PCPageHeader(
          eyebrow: 'BASE-CAMP TETHER',
          title: 'Pair Device',
          sub: const Text('Show this QR on the PC · scan from the mobile app to pair'),
          actions: [
            PCBtn(
              label: 'NEW CODE',
              leftIcon: Icons.refresh_rounded,
              ghost: true,
              onTap: _mintToken,
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: PCCard(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: _pairedRow != null
                          ? _PairSuccess(row: _pairedRow!)
                          : _token == null
                              ? const CircularProgressIndicator(color: TT.ember)
                              : _QrPanel(
                                  token: _token!,
                                  expiresAt: _expiresAt,
                                  error: _error,
                                ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: PCCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HOW IT WORKS',
                            style: TT.mono(
                                size: 10.5,
                                color: TT.ember,
                                letterSpacing: 0.2 * 10.5)),
                        const SizedBox(height: 16),
                        _PairStep(
                            n: 1,
                            title: 'Open the mobile app',
                            body:
                                'Tap the QR icon in Settings → "Pair PC". The camera opens.'),
                        _PairStep(
                            n: 2,
                            title: 'Point at this screen',
                            body:
                                'The mobile app reads the 8-character code embedded in the QR.'),
                        _PairStep(
                            n: 3,
                            title: 'Confirm pairing',
                            body:
                                'The PC will hop to "PAIRED" automatically — Mission Control then watches the hiker live.'),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x1F5AA1D6),
                            border: Border.all(
                                color: const Color(0x5C5AA1D6), width: 1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: TT.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tokens expire after 10 minutes. Mint a fresh one any time with NEW CODE.',
                                  style: TT.body(
                                          size: 11.5, color: TT.text2)
                                      .copyWith(height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrPanel extends StatelessWidget {
  final String token;
  final DateTime? expiresAt;
  final String? error;
  const _QrPanel({required this.token, required this.expiresAt, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 36, color: TT.red),
          const SizedBox(height: 12),
          Text(error!,
              textAlign: TextAlign.center,
              style: TT.body(size: 12, color: TT.red)),
        ],
      );
    }
    final payload = 'trailtether://pair?t=$token';
    final mins = expiresAt == null
        ? null
        : expiresAt!.difference(DateTime.now()).inMinutes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: TT.ember.withOpacity(0.20),
                  blurRadius: 40,
                  spreadRadius: -8),
            ],
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 280,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0A0C0F),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0A0C0F),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CODE',
                style: TT.mono(
                    size: 10,
                    color: TT.text3,
                    letterSpacing: 0.2 * 10)),
            const SizedBox(width: 8),
            SelectableText(
              token,
              style: TT.mono(
                  size: 22,
                  color: TT.ember,
                  letterSpacing: 0.18 * 22)
                  .copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      backgroundColor: TT.surf2,
                      content: Text('Code copied',
                          style: TT.body(size: 12, color: TT.text)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy_rounded, size: 14, color: TT.text3),
              ),
            ),
          ],
        ),
        if (mins != null) ...[
          const SizedBox(height: 10),
          Text(
            mins <= 0
                ? 'Expired — tap NEW CODE'
                : 'Expires in $mins min${mins == 1 ? '' : 's'}',
            style: TT.mono(
                size: 11,
                color: mins <= 0 ? TT.red : TT.text2,
                letterSpacing: 0.06 * 11),
          ),
        ],
      ],
    );
  }
}

class _PairSuccess extends StatelessWidget {
  final Map<String, dynamic> row;
  const _PairSuccess({required this.row});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x294CC38A),
            border: Border.all(color: TT.green, width: 2),
          ),
          child: const Icon(Icons.check_rounded, size: 40, color: TT.green),
        ),
        const SizedBox(height: 18),
        Text('PAIRED',
            style: TT.mono(
                size: 12,
                color: TT.green,
                letterSpacing: 0.2 * 12)),
        const SizedBox(height: 8),
        Text('Mission Control is now watching this hiker live.',
            textAlign: TextAlign.center,
            style: TT.body(size: 13, color: TT.text2)),
      ],
    );
  }
}

class _PairStep extends StatelessWidget {
  final int n;
  final String title;
  final String body;
  const _PairStep({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TT.emberDim,
              border: Border.all(color: const Color(0x80FF6A2C), width: 1),
            ),
            child: Text(
              '$n',
              style: TT.mono(size: 10.5, color: TT.ember)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TT.body(size: 13, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body,
                    style: TT.body(size: 11.5, color: TT.text2)
                        .copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── section: Settings ──────────────────────────────

class _PcSettings extends StatelessWidget {
  const _PcSettings();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        PCPageHeader(
          eyebrow: 'PREFERENCES',
          title: 'Settings',
          sub: Text('Account, watcher behaviour, app version'),
        ),
        Expanded(child: AdminSettingsTab()),
      ],
    );
  }
}
