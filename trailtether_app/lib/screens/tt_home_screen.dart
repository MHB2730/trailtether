// Trailtether 2.0 — Home screen.
//
// Recreates project/screens/home.jsx from the design bundle: layered mountain
// hero with an ember sun, welcome row, 4 quick-action tiles, upcoming hike
// with countdown, weather card (animated sun rotation + cloud drift + 5-hour
// strip), last-hike card backed by TTBigElevChart, and a field-intel strip.
// All sections enter via staggered fade-up animations.
//
// Every value is sourced from the live providers (`AuthProvider`,
// `HikeHistoryProvider`, `WeatherProvider`, `TeamProvider`, `SafetyProvider`,
// `RecordingProvider`) with intentional fallback copy when no data is present.
// Every interactive surface routes to a real screen — no empty onTap handlers.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/incident.dart';
import '../models/saved_hike.dart';
import '../models/team.dart';
import '../models/weather.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/hike_history_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/safety_provider.dart';
import '../providers/team_provider.dart';
import '../providers/units_provider.dart';
import '../providers/weather_provider.dart';
import '../services/team_service.dart';
import '../services/weather_service.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_elev_chart.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import 'create_hike_plan_screen.dart';
import 'hike_history_screen.dart' show HikeDetailScreen, HikeHistoryScreen;
import 'hike_plan_detail_screen.dart';
import 'incident_detail_sheet.dart';
import 'sos_screen.dart';

class TTHomeScreen extends StatefulWidget {
  final bool embedded;
  final ValueChanged<int>? onNavigate;

  const TTHomeScreen({
    super.key,
    this.embedded = false,
    this.onNavigate,
  });

  @override
  State<TTHomeScreen> createState() => _TTHomeScreenState();
}

class _TTHomeScreenState extends State<TTHomeScreen> {
  // Cache of upcoming-hike plans across the user's teams. Recomputed when the
  // team set changes so we don't refetch on every rebuild.
  Future<List<HikePlan>> _plansFuture = Future.value(const []);
  String? _lastTeamId;
  bool _weatherKicked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Refresh team-plans future when the team list changes.
    final teams = context.watch<TeamProvider>().teams;
    final teamIds = teams.map((t) => t.id).join(',');
    if (teamIds != _lastTeamId) {
      _lastTeamId = teamIds;
      if (teams.isEmpty) {
        _plansFuture = Future.value(const []);
      } else {
        _plansFuture =
            Future.wait(teams.map((t) => TeamService.fetchPlansForTeam(t.id)))
                .then((listOfLists) {
          final all = listOfLists.expand((l) => l).toList();
          all.sort((a, b) => a.hikeDate.compareTo(b.hikeDate));
          return all;
        }).catchError((_) => <HikePlan>[]);
      }
    }

    // Wire up weather provider with the current user, and kick off the first
    // fetch of the first stored location so the weather card has something
    // to show by default. Guarded so it only fires once per screen lifetime.
    final auth = context.read<ap.AuthProvider>();
    final weather = context.read<WeatherProvider>();
    weather.setUserId(auth.uid);
    if (!_weatherKicked &&
        weather.currentWeather == null &&
        weather.locations.isNotEmpty &&
        !weather.loading) {
      _weatherKicked = true;
      // Defer to next frame so we don't notify during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(weather.fetchWeatherForLocation(0));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onNavigate = widget.onNavigate;
    final body = Stack(
      children: [
        // ── Full-page hero image background ────────────────────────────────
        // Sits behind every other layer. Swaps between the dark
        // "no-snow" hero and the snowy daytime hero based on real
        // Drakensberg weather (WeatherProvider.isSnowingInDrakensberg).
        // AnimatedSwitcher crossfades the two images over 600 ms so the
        // change is smooth, not a hard cut.
        // Hero photo — swaps between dark and snowy hero based on
        // real Drakensberg conditions. Uses Selector (not Consumer)
        // so we ONLY rebuild when the snow flag flips, not on every
        // weather notifyListeners() — that previously confused the
        // image stream and rendered black. AnimatedCrossFade keeps
        // both images in the tree at all times so the swap is a true
        // cross-fade with no "decode from scratch" gap.
        Positioned.fill(
          child: Selector<WeatherProvider, bool>(
            selector: (_, w) => w.isSnowingInDrakensberg,
            builder: (_, snow, __) {
              return AnimatedCrossFade(
                duration: const Duration(milliseconds: 600),
                crossFadeState: snow
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeOut,
                sizeCurve: Curves.easeOut,
                firstChild: Image.asset(
                  'assets/icon/hero_mountain.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Container(color: TT.bg),
                ),
                secondChild: Image.asset(
                  'assets/icon/hero_snow.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Container(color: TT.bg),
                ),
              );
            },
          ),
        ),
        // Scrim — kept light at the top so the peak / orange trail stays
        // visible behind the brand row + greeting, then ramps to nearly-
        // opaque body colour below so cards have a calm background to sit
        // on. The topo backdrop is removed entirely (the image is now the
        // backdrop), and TTAmbient is dropped so its ember bloom doesn't
        // fight the orange trail in the photo.
        const Positioned.fill(
          child: IgnorePointer(child: _HomeBackgroundScrim()),
        ),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _HomeHero(onNavigate: onNavigate),
              const SizedBox(height: 4),
              _HomeQuickActions(onNavigate: onNavigate),
              _UpcomingHikeCard(
                plansFuture: _plansFuture,
                onNavigateToTeams: () => onNavigate?.call(4),
              ),
              const _WeatherCard(),
              _LastHikeCard(onNavigateToMap: () => onNavigate?.call(1)),
              _FieldIntelStrip(onNavigate: onNavigate),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

/// Layered scrim that sits over the home page's hero photo. Light at the top
/// (the peak / orange trail stay visible), heavy at the bottom (cards stay
/// readable on the solid body colour). Pulled out as a separate widget so
/// the gradient stops are in one place if we want to tweak the falloff.
class _HomeBackgroundScrim extends StatelessWidget {
  const _HomeBackgroundScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // Top 30%: transparent so the hero peak / topo trail show
            // at full strength behind the brand row + greeting.
            Color(0x00000000),
            // Light tint behind the greeting so the white text stays
            // legible without crushing the ember lines.
            Color(0x4007090C),
            // From ~55% down: ramp up so the cards have a calm dark
            // surface to land on instead of fighting the photo.
            Color(0xE807090C),
            TT.bg,
          ],
          stops: [0.0, 0.32, 0.55, 0.85],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── HERO ───────────────────────────────────

class _HomeHero extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const _HomeHero({this.onNavigate});

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero> with SingleTickerProviderStateMixin {
  late final AnimationController _starCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  late final AnimationController _entryCtl = AnimationController(
    vsync: this,
    duration: TT.dSlow,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _entryCtl.forward();
    });
  }

  @override
  void dispose() {
    _starCtl.dispose();
    _entryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final firstName = _firstName(auth);

    // The full-page hero image is rendered by the parent screen as a true
    // page-background layer; this hero block stays as a transparent
    // 260-tall region so the brand row + greeting sit over the most
    // dramatic part of the photo (the peak / glowing trail) without
    // re-drawing the image and double-darkening it.
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          // Top brand row
          Positioned(
            top: 14,
            left: 18,
            right: 18,
            child: _HeroBrandRow(
              entry: _entryCtl,
              auth: auth,
              onAvatarTap: () => widget.onNavigate?.call(5),
            ),
          ),
          // Greeting overlay
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: AnimatedBuilder(
              animation: _entryCtl,
              builder: (_, child) {
                final t = TT.easeOut.transform(_entryCtl.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 14),
                    child: child,
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WELCOME BACK,',
                    style: TT.mono(size: 11, color: TT.ember).copyWith(
                      letterSpacing: 0.2 * 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    firstName,
                    style: TT.title(32, letterSpacing: -0.025 * 32).copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Derive a friendly first-name greeting from the auth user.
///
/// Priority: `displayName` first token → email local part → "Hiker".
String _firstName(ap.AuthProvider auth) {
  final dn = auth.displayName?.trim();
  if (dn != null && dn.isNotEmpty) {
    final first = dn.split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Hiker' : first;
  }
  final email = auth.email;
  if (email != null && email.contains('@')) {
    final prefix = email.split('@').first.trim();
    if (prefix.isNotEmpty) return _capitalize(prefix);
  }
  return 'Hiker';
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// 1- or 2-letter avatar initials derived from displayName / email.
String _avatarInitials(ap.AuthProvider auth) {
  final dn = auth.displayName?.trim();
  if (dn != null && dn.isNotEmpty) {
    final parts = dn.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
  }
  final email = auth.email;
  if (email != null && email.isNotEmpty) {
    final prefix = email.split('@').first;
    return prefix.substring(0, math.min(2, prefix.length)).toUpperCase();
  }
  return 'TT';
}

class _HeroBrandRow extends StatelessWidget {
  final AnimationController entry;
  final ap.AuthProvider auth;
  final VoidCallback onAvatarTap;
  const _HeroBrandRow({
    required this.entry,
    required this.auth,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final photo = auth.photoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initials = _avatarInitials(auth);
    return AnimatedBuilder(
      animation: entry,
      builder: (_, child) {
        final t = TT.easeOut.transform(entry.value);
        return Opacity(opacity: t, child: child);
      },
      child: Row(
        children: [
          const Expanded(child: TTBrandMark()),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TT.ember, width: 2),
                gradient: hasPhoto
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6B3A1A), TT.ember2],
                      ),
                boxShadow: const [
                  BoxShadow(color: Color(0x73FF6A2C), blurRadius: 14),
                ],
              ),
              alignment: Alignment.center,
              clipBehavior: hasPhoto ? Clip.antiAlias : Clip.none,
              child: hasPhoto
                  ? Image.network(
                      photo,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6B3A1A), TT.ember2],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: TT.body(
                              size: 13,
                              w: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    )
                  : Text(
                      initials,
                      style: TT.body(
                          size: 13, w: FontWeight.w800, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────── QUICK ACTION TILES ─────────────────────────────

class _HomeQuickActions extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const _HomeQuickActions({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final isRecording = recording.isRecording || recording.isPaused;

    final actions = <_QuickAction>[
      _QuickAction(
        icon: isRecording ? Icons.pause_rounded : Icons.play_arrow_rounded,
        label: isRecording ? 'Recording' : 'Start Hike',
        color: TT.ember,
        primary: true,
        // Map tab hosts the live recording controls (start/pause/stop, GPS
        // status, target-trail overlay). Routes the user there in either
        // direction — fresh start or resume of an in-progress recording.
        onTap: () => onNavigate?.call(1),
      ),
      _QuickAction(
        icon: Icons.alt_route_rounded,
        label: 'Plan Route',
        color: TT.text2,
        // Map tab is also where trails are browsed and routes drafted before
        // saving to a team plan.
        onTap: () => onNavigate?.call(1),
      ),
      _QuickAction(
        icon: Icons.visibility_outlined,
        label: 'Live Track',
        color: TT.blue,
        // Live tracking surfaces team members on the map — Teams tab (4)
        // holds the live tracking experience, not Tools.
        onTap: () => onNavigate?.call(4),
      ),
      _QuickAction(
        icon: Icons.radio_button_checked,
        label: 'SOS',
        color: TT.red,
        // Route to the real SOS screen (LocationService + IncidentService
        // + 5-second hold to trigger) — never to a visual mock. SOS is
        // safety-critical and must work end-to-end.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SosScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: TTStagger(
        axis: Axis.horizontal,
        base: const Duration(milliseconds: 350),
        step: const Duration(milliseconds: 70),
        gap: 8,
        children: actions.map((a) => Expanded(child: _QuickActionTile(action: a))).toList(),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final bool primary;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.primary = false,
    required this.onTap,
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final primary = a.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: a.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: TT.dFast,
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: primary ? TT.emberDim : TT.surf,
            border: Border.all(
              color: primary ? const Color(0x5CFF6A2C) : TT.line,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: primary
                ? const [
                    BoxShadow(
                      color: Color(0x2EFF6A2C),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary
                      ? const Color(0x2EFF6A2C)
                      : Color.alphaBlend(a.color.withOpacity(0.06), TT.surf),
                  border: Border.all(
                    color: primary ? const Color(0x80FF6A2C) : TT.line2,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(a.icon, size: 17, color: a.color),
              ),
              const SizedBox(height: 7),
              Text(
                a.label.toUpperCase(),
                style: TT.body(
                  size: 9.5,
                  w: FontWeight.w800,
                  color: primary ? TT.ember : TT.text,
                ).copyWith(letterSpacing: 0.1 * 9.5),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── UPCOMING HIKE CARD ─────────────────────────────

class _UpcomingHikeCard extends StatefulWidget {
  final Future<List<HikePlan>> plansFuture;
  // Fallback when there's no selected team and no plans yet — sends the user
  // to the Teams tab where they can create or join a team.
  final VoidCallback onNavigateToTeams;
  const _UpcomingHikeCard({
    required this.plansFuture,
    required this.onNavigateToTeams,
  });

  @override
  State<_UpcomingHikeCard> createState() => _UpcomingHikeCardState();
}

class _UpcomingHikeCardState extends State<_UpcomingHikeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Push the plan detail screen using the team that owns this plan. The
  /// plan-list future doesn't return Team objects, so we look up the parent
  /// team in TeamProvider by id (it's already in memory for the home screen).
  void _openPlan(HikePlan plan) {
    final teams = context.read<TeamProvider>().teams;
    final team = teams.firstWhere(
      (t) => t.id == plan.teamId,
      orElse: () => teams.isNotEmpty
          ? teams.first
          : Team(
              id: plan.teamId,
              name: 'Team',
              description: '',
              createdBy: plan.createdBy,
              members: const [],
              memberUids: const [],
              createdAt: DateTime.now(),
            ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HikePlanDetailScreen(plan: plan, team: team),
      ),
    );
  }

  /// Open the plan-creation flow for the user's currently selected team. If
  /// they aren't in a team yet, send them to the Teams tab to create or join
  /// one — CreateHikePlanScreen requires a Team object to anchor the plan.
  void _openCreatePlan() {
    final teamProvider = context.read<TeamProvider>();
    final team = teamProvider.selectedTeam ??
        (teamProvider.teams.isNotEmpty ? teamProvider.teams.first : null);
    if (team == null) {
      widget.onNavigateToTeams();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateHikePlanScreen(team: team),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, child) {
          final t = TT.easeOut.transform(_ctl.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
          );
        },
        child: FutureBuilder<List<HikePlan>>(
          future: widget.plansFuture,
          builder: (context, snap) {
            final all = snap.data ?? const <HikePlan>[];
            final now = DateTime.now();
            // First future plan, sorted by date (the future itself sorts them).
            final next = all
                .where((p) => p.hikeDate.isAfter(now) && p.status != 'completed')
                .toList();
            final plan = next.isNotEmpty ? next.first : null;
            return TTCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              onTap: plan == null ? _openCreatePlan : () => _openPlan(plan),
              child: plan == null
                  ? _UpcomingEmptyContent(onTap: _openCreatePlan)
                  : _UpcomingPlanContent(plan: plan),
            );
          },
        ),
      ),
    );
  }
}

class _UpcomingEmptyContent extends StatelessWidget {
  final VoidCallback onTap;
  const _UpcomingEmptyContent({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ember corner glow
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x38FF6A2C), Color(0x00FF6A2C)],
                stops: [0.0, 0.7],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _PulseDot(color: TT.ember),
                const SizedBox(width: 6),
                Text(
                  'NO UPCOMING HIKES',
                  style: TT.mono(size: 10, color: TT.ember).copyWith(
                    letterSpacing: 0.18 * 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Plan your next adventure',
              style: TT.title(19, letterSpacing: -0.01 * 19),
            ),
            const SizedBox(height: 3),
            Text(
              'TAP TO PLAN A ROUTE · DRAKENSBERG',
              style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                  .copyWith(letterSpacing: 0.04 * 11),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: TT.emberDim,
                      border:
                          Border.all(color: const Color(0x52FF6A2C), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 13, color: TT.ember),
                        const SizedBox(width: 5),
                        Text(
                          'PLAN HIKE',
                          style: TT
                              .mono(
                                  size: 10.5,
                                  color: TT.ember,
                                  w: FontWeight.w800)
                              .copyWith(letterSpacing: 0.12 * 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: TT.text3),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingPlanContent extends StatelessWidget {
  final HikePlan plan;
  const _UpcomingPlanContent({required this.plan});

  @override
  Widget build(BuildContext context) {
    final extras = plan.extras;
    final rsvp = extras.rsvp;
    // Going count: rsvp entries marked "going". Always at least 1 (creator).
    final going = rsvp.entries.where((e) => e.value == 'going').length;
    final goingCount = going > 0 ? going : 1;

    final now = DateTime.now();
    final diff = plan.hikeDate.difference(now);
    final countdownLabel = _formatCountdown(diff);
    final headerLabel = _formatHeaderRelative(diff);

    final dateStr = DateFormat('MMM d').format(plan.hikeDate).toUpperCase();
    final timeStr = extras.time.isNotEmpty
        ? extras.time
        : DateFormat('HH:mm').format(plan.hikeDate);
    final subtitle =
        '$dateStr · $timeStr START${plan.meetingPoint.isNotEmpty ? ' · ${plan.meetingPoint.toUpperCase()}' : ''}';

    // Avatar stack: derive deterministic initials/colors from rsvp uids if any,
    // else from invited members or fall back to a single creator marker.
    final attendees = _deriveAttendees(plan);

    return Stack(
      children: [
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x38FF6A2C), Color(0x00FF6A2C)],
                stops: [0.0, 0.7],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulseDot(color: TT.ember),
                    const SizedBox(width: 6),
                    Text(
                      headerLabel,
                      style: TT.mono(size: 10, color: TT.ember).copyWith(
                        letterSpacing: 0.18 * 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                TTPill(
                    label: '$goingCount GOING', variant: TTPillVariant.ember),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan.trailName.isNotEmpty ? plan.trailName : 'Planned hike',
              style: TT.title(19, letterSpacing: -0.01 * 19),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                  .copyWith(letterSpacing: 0.04 * 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AvatarStack(entries: attendees),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'STARTS IN',
                          style: TT.body(
                                  size: 9, w: FontWeight.w700, color: TT.text3)
                              .copyWith(letterSpacing: 0.16 * 9),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          countdownLabel,
                          style: TT.numStyle(
                              size: 17, letterSpacing: -0.02 * 17),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: TT.text3),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static List<_AvatarEntry> _deriveAttendees(HikePlan plan) {
    const palette = [
      Color(0xFFFF6A2C),
      Color(0xFFFF8A4D),
      Color(0xFF4CC38A),
      Color(0xFFF2A93B),
      Color(0xFF5AA1D6),
    ];
    final extras = plan.extras;
    // Prefer "going" RSVPs, then invited members, then fall back to creator.
    final goingIds = extras.rsvp.entries
        .where((e) => e.value == 'going')
        .map((e) => e.key)
        .toList();
    final source = goingIds.isNotEmpty
        ? goingIds
        : (extras.invitedMembers.isNotEmpty
            ? extras.invitedMembers
            : [plan.createdBy]);
    final entries = <_AvatarEntry>[];
    for (var i = 0; i < math.min(4, source.length); i++) {
      final id = source[i];
      final initial = (id.isEmpty ? 'H' : id[0]).toUpperCase();
      entries.add(_AvatarEntry(initial, palette[i % palette.length]));
    }
    if (entries.isEmpty) {
      entries.add(const _AvatarEntry('H', Color(0xFFFF6A2C)));
    }
    return entries;
  }

  static String _formatCountdown(Duration d) {
    if (d.isNegative) return 'NOW';
    final days = d.inDays;
    final hours = d.inHours - days * 24;
    if (days > 0) return '${days}d ${hours}h';
    final mins = d.inMinutes - d.inHours * 60;
    if (d.inHours > 0) return '${d.inHours}h ${mins}m';
    return '${d.inMinutes}m';
  }

  static String _formatHeaderRelative(Duration d) {
    if (d.isNegative) return 'UPCOMING · STARTING NOW';
    final days = d.inDays;
    if (days <= 0) return 'UPCOMING · TODAY';
    if (days == 1) return 'UPCOMING · TOMORROW';
    return 'UPCOMING · IN $days DAYS';
  }
}

class _AvatarEntry {
  final String initial;
  final Color color;
  const _AvatarEntry(this.initial, this.color);
}

class _AvatarStack extends StatelessWidget {
  final List<_AvatarEntry> entries;
  const _AvatarStack({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 30.0 + (entries.length - 1) * 20.0,
      child: Stack(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          return Positioned(
            left: i * 20.0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: e.color,
                shape: BoxShape.circle,
                border: Border.all(color: TT.surf, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                e.initial,
                style: TT.body(size: 11, w: FontWeight.w800, color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_ctl),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
        ),
      ),
    );
  }
}

// ───────────────────────────── WEATHER CARD ─────────────────────────────────

class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> with TickerProviderStateMixin {
  late final AnimationController _sunCtl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _rayCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final AnimationController _cloudCtl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);
  late final AnimationController _entryCtl =
      AnimationController(vsync: this, duration: TT.dSlow);

  // Active location + day. Both default to "first" so cold-start renders
  // today's forecast for whichever location was saved first (Royal Natal
  // by default — see WeatherProvider's seed list).
  int _locationIndex = 0;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _entryCtl.forward();
    });
  }

  @override
  void dispose() {
    _sunCtl.dispose();
    _rayCtl.dispose();
    _cloudCtl.dispose();
    _entryCtl.dispose();
    super.dispose();
  }

  /// Hand off to the location-search dialog and, if the user picks something,
  /// persist it, fetch its forecast, and snap the chips strip to the new
  /// entry. Skipped silently when the dialog is dismissed.
  Future<void> _addLocation() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddWeatherLocationDialog(),
    );
    if (result == null || !mounted) return;
    final wp = context.read<WeatherProvider>();
    await wp.addLocation(
      result['name'] as String,
      (result['lat'] as num).toDouble(),
      (result['lon'] as num).toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _locationIndex = wp.locations.length - 1;
      _selectedDayIndex = 0;
    });
    unawaited(wp.fetchWeatherForLocation(_locationIndex));
  }

  Future<void> _confirmRemoveLocation(int index) async {
    final wp = context.read<WeatherProvider>();
    if (wp.locations.length <= 1) return;
    final name = wp.locations[index]['name'] as String? ?? 'this location';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Remove location?',
            style: TT.body(size: 16, w: FontWeight.w800)),
        content: Text('Drop "$name" from your weather list?',
            style: TT.body(size: 13, color: TT.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child:
                Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Remove',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await wp.removeLocation(index);
    if (!mounted) return;
    setState(() {
      if (_locationIndex >= wp.locations.length) _locationIndex = 0;
      _selectedDayIndex = 0;
    });
    unawaited(wp.fetchWeatherForLocation(_locationIndex));
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WeatherProvider>();
    final weather = wp.currentWeather;

    // Clamp indices so a location being removed by another tab can't crash
    // us mid-build.
    if (wp.locations.isEmpty) {
      _locationIndex = 0;
    } else if (_locationIndex >= wp.locations.length) {
      _locationIndex = wp.locations.length - 1;
    }
    final locationName = wp.locations.isNotEmpty
        ? (wp.locations[_locationIndex]['name'] as String? ?? 'DRAKENSBERG')
        : 'DRAKENSBERG';

    if (weather != null) {
      if (_selectedDayIndex < 0 ||
          _selectedDayIndex >= weather.daily.length) {
        _selectedDayIndex = 0;
      }
    }

    // Tap-to-refresh handler. Skipped while a fetch is already in flight so we
    // don't queue overlapping network calls; otherwise re-runs the multi-source
    // aggregator for the currently selected location.
    final canRefresh = !wp.loading && wp.locations.isNotEmpty;
    void refresh() {
      if (!canRefresh) return;
      unawaited(wp.fetchWeatherForLocation(_locationIndex));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: AnimatedBuilder(
        animation: _entryCtl,
        builder: (_, child) {
          final t = TT.easeOut.transform(_entryCtl.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
          );
        },
        child: TTCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: canRefresh ? refresh : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location chips — switch between saved spots, long-press to
              // remove, or tap the + chip to search-add a new one.
              _LocationChipsStrip(
                locations: wp.locations,
                selectedIndex: _locationIndex,
                onSelect: (i) {
                  if (i == _locationIndex) return;
                  setState(() {
                    _locationIndex = i;
                    _selectedDayIndex = 0;
                  });
                  unawaited(wp.fetchWeatherForLocation(i));
                },
                onRemove: _confirmRemoveLocation,
                onAdd: _addLocation,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TT.body(
                                size: 11, w: FontWeight.w700, color: TT.text2)
                            .copyWith(letterSpacing: 0.16 * 11),
                        children: [
                          const TextSpan(text: 'CONDITIONS · '),
                          TextSpan(
                            text: locationName.toUpperCase(),
                            style: const TextStyle(color: TT.text3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canRefresh ? refresh : null,
                    child: Text(
                      wp.loading ? 'LOADING…' : 'REFRESH →',
                      style: TT
                          .mono(size: 10, color: TT.ember, w: FontWeight.w800)
                          .copyWith(letterSpacing: 0.1 * 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (weather == null)
                _WeatherSkeleton(loading: wp.loading, error: wp.error)
              else
                _WeatherBody(
                  weather: weather,
                  sunCtl: _sunCtl,
                  rayCtl: _rayCtl,
                  cloudCtl: _cloudCtl,
                ),
              // ── 7-day forecast strip ─────────────────────────────────
              if (weather != null && weather.daily.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('7-DAY FORECAST',
                    style: TT.label(
                      size: 10.5,
                      color: TT.text3,
                      letterSpacing: 0.16 * 10.5,
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: weather.daily.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _TTDayCard(
                      day: weather.daily[i],
                      isToday: i == 0,
                      selected: i == _selectedDayIndex,
                      onTap: () =>
                          setState(() => _selectedDayIndex = i),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: TT.line, width: 1)),
                ),
                // Hourly strip is now day-aware — shows the selected day's
                // hourly slices, not just "next 5 from now".
                child: _HourStrip(
                  weather: weather,
                  dayIndex: _selectedDayIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── LOCATION CHIPS STRIP ────────────────────────────

class _LocationChipsStrip extends StatelessWidget {
  final List<Map<String, dynamic>> locations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;
  const _LocationChipsStrip({
    required this.locations,
    required this.selectedIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // Total chips = saved locations + one "+ Add" chip at the end.
    final total = locations.length + 1;
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == locations.length) {
            return _AddLocationChip(onTap: onAdd);
          }
          final name = locations[i]['name'] as String? ?? 'Spot';
          final isSelected = i == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            onLongPress:
                locations.length > 1 ? () => onRemove(i) : null,
            child: AnimatedContainer(
              duration: TT.dFast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? TT.emberSoft : TT.surf2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? TT.ember : TT.line2,
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                name,
                style: TT.body(
                  size: 11.5,
                  w: FontWeight.w800,
                  color: isSelected ? TT.ember : TT.text2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddLocationChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddLocationChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x14FF6A2C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x4DFF6A2C), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 13, color: TT.ember),
            const SizedBox(width: 4),
            Text(
              'ADD',
              style: TT
                  .body(size: 10.5, w: FontWeight.w800, color: TT.ember)
                  .copyWith(letterSpacing: 0.12 * 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── TT-themed DAY CARD ──────────────────────────────

class _TTDayCard extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;
  const _TTDayCard({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  Color _condColor(HikingCondition c) {
    switch (c) {
      case HikingCondition.good:
        return TT.green;
      case HikingCondition.caution:
        return TT.amber;
      case HikingCondition.bad:
        return TT.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final cond = day.hikingCondition;
    final accent = _condColor(cond);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: TT.dFast,
        width: 78,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.14) : TT.surf2,
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(
            color: selected ? accent : TT.line2,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isToday ? 'TODAY' : DateFormat('EEE').format(day.date).toUpperCase(),
              style: TT.mono(
                size: 10,
                color: isToday ? TT.ember : TT.text2,
                w: FontWeight.w800,
              ).copyWith(letterSpacing: 0.08 * 10),
            ),
            Text(weatherEmoji(day.weatherCode),
                style: const TextStyle(fontSize: 22)),
            Text(
              '${units.temperatureFromC(day.tempMax).round()}°/${units.temperatureFromC(day.tempMin).round()}°',
              style: TT.body(size: 11, w: FontWeight.w800, color: TT.text),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop,
                    color: Color(0xFF6FB6FF), size: 9),
                const SizedBox(width: 2),
                Text(
                  '${day.precipProbability}%',
                  style: TT.mono(size: 9, color: const Color(0xFF6FB6FF)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                cond.label.toUpperCase(),
                style: TT.mono(
                  size: 8.5,
                  color: accent,
                  w: FontWeight.w800,
                ).copyWith(letterSpacing: 0.1 * 8.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── ADD-LOCATION DIALOG ─────────────────────────────

class _AddWeatherLocationDialog extends StatefulWidget {
  const _AddWeatherLocationDialog();

  @override
  State<_AddWeatherLocationDialog> createState() =>
      _AddWeatherLocationDialogState();
}

class _AddWeatherLocationDialogState extends State<_AddWeatherLocationDialog> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final res = await WeatherService.searchLocation(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TT.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TT.rLg),
        side: const BorderSide(color: TT.line2, width: 1),
      ),
      title: Text('Add weather location',
          style: TT.body(size: 16, w: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              // visiblePassword keyboardType disables the Android keyboard's
              // spellcheck underline + autocorrect so "Drakensberg" doesn't
              // get auto-replaced into something else.
              keyboardType: TextInputType.visiblePassword,
              cursorColor: TT.ember,
              style: TT.body(size: 14, color: TT.text),
              onSubmitted: (_) => _search(),
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'e.g. Cathedral Peak, Mont Aux Sources',
                hintStyle: TT.body(size: 13, color: TT.text3),
                filled: true,
                fillColor: TT.bg3,
                prefixIcon: const Icon(Icons.search,
                    color: TT.text3, size: 18),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: TT.text3, size: 16),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {
                            _results = const [];
                            _loading = false;
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TT.rMd),
                  borderSide: const BorderSide(color: TT.line2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TT.rMd),
                  borderSide: const BorderSide(color: TT.line2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TT.rMd),
                  borderSide: const BorderSide(color: TT.ember, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: TT.ember,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _ctrl.text.trim().length < 2
                                ? 'Type at least 2 characters'
                                : 'No matches yet',
                            style: TT.body(size: 13, color: TT.text3),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: TT.line, height: 1),
                          itemBuilder: (_, i) {
                            final r = _results[i];
                            final name = r['name']?.toString() ?? 'Spot';
                            final lat = (r['lat'] as num?)?.toDouble() ?? 0;
                            final lon = (r['lon'] as num?)?.toDouble() ?? 0;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                name,
                                style: TT.body(
                                    size: 13.5, w: FontWeight.w800),
                              ),
                              subtitle: Text(
                                '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}',
                                style: TT.mono(size: 10.5, color: TT.text3),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: TT.ember,
                                size: 18,
                              ),
                              onTap: () => Navigator.pop(context, r),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
        ),
      ],
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  final bool loading;
  final String? error;
  const _WeatherSkeleton({required this.loading, this.error});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: TT.line2, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(
            loading
                ? Icons.refresh_rounded
                : (error != null
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_outlined),
            size: 28,
            color: TT.text3,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loading ? 'Fetching…' : 'Tap to load weather',
                style:
                    TT.title(20, letterSpacing: -0.02 * 20).copyWith(height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                loading
                    ? 'CONNECTING TO STATIONS'
                    : (error != null
                        ? 'NO RECENT DATA · TAP TO RETRY'
                        : 'PICK A LOCATION IN WEATHER TAB'),
                style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                    .copyWith(letterSpacing: 0.05 * 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeatherBody extends StatelessWidget {
  final WeatherData weather;
  final AnimationController sunCtl;
  final AnimationController rayCtl;
  final AnimationController cloudCtl;
  const _WeatherBody({
    required this.weather,
    required this.sunCtl,
    required this.rayCtl,
    required this.cloudCtl,
  });

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final cur = weather.current;
    final tempInt = units.temperatureFromC(cur.temperature).round();
    final tempSymbol = units.isImperial ? 'F' : 'C';
    final condition = weatherDescription(cur.weatherCode).toUpperCase();
    final wind = units.speedFromKmh(cur.windSpeed).round();
    final windUnit = units.speedUnit;
    final score = _hikeScore(weather);
    final scoreColor = score >= 7
        ? TT.green
        : (score >= 4 ? TT.amber : TT.red);
    final scoreBg = score >= 7
        ? const Color(0x244CC38A)
        : (score >= 4 ? const Color(0x24F2A93B) : const Color(0x24E63D2E));
    final scoreBorder = score >= 7
        ? const Color(0x524CC38A)
        : (score >= 4 ? const Color(0x52F2A93B) : const Color(0x52E63D2E));

    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: Listenable.merge([sunCtl, rayCtl, cloudCtl]),
            builder: (_, __) => CustomPaint(
              painter: _WeatherIconPainter(
                sunPhase: sunCtl.value,
                rayPhase: rayCtl.value,
                cloudPhase: cloudCtl.value,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tempInt°',
                    style: TT.numStyle(
                      size: 32,
                      letterSpacing: -0.025 * 32,
                    ).copyWith(height: 1.0),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tempSymbol,
                      style: TT.body(
                        size: 14,
                        color: TT.text2,
                        w: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$condition · WIND $wind $windUnit',
                style: TT.mono(size: 11, color: TT.text3, w: FontWeight.w600)
                    .copyWith(letterSpacing: 0.05 * 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scoreBg,
                border: Border.all(color: scoreBorder, width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: TT.numStyle(size: 13, color: scoreColor),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '/10',
                    style:
                        TT.body(size: 9.5, color: scoreColor, w: FontWeight.w600)
                            .copyWith(letterSpacing: 0.08 * 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'HIKE SCORE',
              style: TT.body(size: 9, color: scoreColor, w: FontWeight.w700)
                  .copyWith(letterSpacing: 0.14 * 9),
            ),
          ],
        ),
      ],
    );
  }
}

/// Derived hike-friendliness score on a 1–10 scale.
///
/// Higher precip probability and stronger winds pull the score down.
/// Anchored at 10 when conditions are dry and calm. Clamped 1..10.
int _hikeScore(WeatherData weather) {
  final cur = weather.current;
  // Today's forecast supplies the precip-probability metric when available.
  final today = weather.daily.isNotEmpty ? weather.daily.first : null;
  final precipProb = today?.precipProbability ?? 0;
  final windKmh = cur.windSpeed; // Already km/h from aggregator.
  // Wind penalty grows linearly past 10 km/h, capped at ~4 points at 50 km/h.
  final windPenalty = ((windKmh - 10).clamp(0, 50)) / 50 * 4;
  final raw = (1 - precipProb / 100) * 10 - windPenalty;
  return raw.clamp(1, 10).round();
}

class _HourStrip extends StatelessWidget {
  final WeatherData? weather;
  final int dayIndex;
  const _HourStrip({required this.weather, this.dayIndex = 0});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final entries = _buildEntries(units);
    return Row(
      children: List.generate(entries.length, (i) {
        final h = entries[i];
        return Expanded(
          child: Column(
            children: [
              Text(
                h.hour,
                style: TT.mono(size: 9, color: TT.text3, w: FontWeight.w700)
                    .copyWith(letterSpacing: 0.06 * 9),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 18,
                child: Center(
                  child: CustomPaint(
                    size: const Size(20, 18),
                    painter: _WxMiniIconPainter(h.icon),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(h.temp, style: TT.mono(size: 11, w: FontWeight.w700)),
            ],
          ),
        );
      }),
    );
  }

  List<_HourEntry> _buildEntries(UnitsProvider units) {
    final w = weather;
    if (w == null || w.hourly.isEmpty) {
      // Skeleton: 5 dashes that match the design layout when no data exists.
      return const [
        _HourEntry('--', '--', _WxKind.cloud),
        _HourEntry('--', '--', _WxKind.cloud),
        _HourEntry('--', '--', _WxKind.cloud),
        _HourEntry('--', '--', _WxKind.cloud),
        _HourEntry('--', '--', _WxKind.cloud),
      ];
    }

    // Day-aware picks. If the user has selected a future day, show that
    // day's 5 representative hours (sunrise-ish through evening); if it's
    // today (or no selection), step forward from "now" so the user sees
    // what's coming next.
    final dayHours = w.hoursForDay(dayIndex);
    final pool = dayHours.isNotEmpty ? dayHours : w.hourly;
    final picks = <HourlySlice>[];
    if (dayIndex <= 0) {
      final now = DateTime.now();
      final forward = pool.where((h) => !h.time.isBefore(now)).toList();
      final start = forward.isNotEmpty ? forward.first.time : pool.first.time;
      for (final s in (forward.isNotEmpty ? forward : pool)) {
        if (picks.isEmpty) {
          picks.add(s);
        } else {
          final gap = s.time.difference(start).inHours;
          if (gap >= picks.length * 3) picks.add(s);
        }
        if (picks.length >= 5) break;
      }
    } else {
      // Future day — pick the 5 most useful daylight hours (06, 09, 12, 15, 18).
      const desired = [6, 9, 12, 15, 18];
      for (final hour in desired) {
        for (final s in pool) {
          if (s.time.hour == hour) {
            picks.add(s);
            break;
          }
        }
      }
      if (picks.isEmpty) picks.addAll(pool.take(5));
    }

    if (picks.isEmpty) return const [];
    return picks
        .map((s) => _HourEntry(
              DateFormat('HH').format(s.time),
              '${units.temperatureFromC(s.temperature).round()}°',
              _kindFor(s),
            ))
        .toList();
  }

  static _WxKind _kindFor(HourlySlice s) {
    final isNight = s.time.hour < 6 || s.time.hour >= 19;
    final code = s.weatherCode;
    if (code == 0 || code == 1) {
      return isNight ? _WxKind.moon : _WxKind.sun;
    }
    return _WxKind.cloud;
  }
}

enum _WxKind { sun, cloud, moon }

class _HourEntry {
  final String hour;
  final String temp;
  final _WxKind icon;
  const _HourEntry(this.hour, this.temp, this.icon);
}

class _WxMiniIconPainter extends CustomPainter {
  final _WxKind kind;
  _WxMiniIconPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    switch (kind) {
      case _WxKind.sun:
        final p = Paint()..color = TT.ember2;
        canvas.drawCircle(Offset(cx, cy), 3, p);
        final ray = Paint()
          ..color = TT.ember2
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(cx + math.cos(a) * 5, cy + math.sin(a) * 5),
            Offset(cx + math.cos(a) * 7, cy + math.sin(a) * 7),
            ray,
          );
        }
        break;
      case _WxKind.cloud:
        final c = Paint()..color = const Color(0xFF5A6470);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - 3, cy + 2), width: 10, height: 6), c);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + 3, cy + 2), width: 8, height: 5), c);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 1), width: 7, height: 5), c);
        break;
      case _WxKind.moon:
        final m = Paint()..color = const Color(0xFF98A1AC);
        final path = Path()
          ..moveTo(cx + 3, cy + 1.5)
          ..arcToPoint(
            Offset(cx - 2.5, cy - 4),
            radius: const Radius.circular(4.5),
            clockwise: true,
          )
          ..arcToPoint(
            Offset(cx + 3, cy + 1.5),
            radius: const Radius.circular(3.5),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(path, m);
        break;
    }
  }

  @override
  bool shouldRepaint(_WxMiniIconPainter old) => old.kind != kind;
}

class _WeatherIconPainter extends CustomPainter {
  final double sunPhase;
  final double rayPhase;
  final double cloudPhase;
  _WeatherIconPainter({
    required this.sunPhase,
    required this.rayPhase,
    required this.cloudPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const sunCenter = Offset(24, 24);

    // Sun core
    canvas.drawCircle(
      sunCenter,
      14,
      Paint()
        ..shader = const RadialGradient(
          colors: [TT.ember3, TT.ember],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 14)),
    );

    // Rotating rays
    final rayBase = sunPhase * 2 * math.pi;
    for (var i = 0; i < 8; i++) {
      final a = rayBase + i * math.pi / 4;
      final twinkleOffset = (rayPhase + i * 0.1) % 1.0;
      final opacity = 0.4 + 0.5 * math.sin(twinkleOffset * 2 * math.pi).abs();
      final ray = Paint()
        ..color = TT.ember2.withOpacity(opacity.clamp(0.0, 1.0))
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(sunCenter.dx + math.cos(a) * 18, sunCenter.dy + math.sin(a) * 18),
        Offset(sunCenter.dx + math.cos(a) * 24, sunCenter.dy + math.sin(a) * 24),
        ray,
      );
    }

    // Drifting cloud
    final drift = math.sin(cloudPhase * math.pi) * 3.0;
    final c = Paint()..color = const Color(0xFF2A313C);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(40 + drift, 44), width: 28, height: 18),
      c,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50 + drift, 46), width: 22, height: 14),
      c,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(44 + drift, 38), width: 18, height: 12),
      c,
    );
  }

  @override
  bool shouldRepaint(_WeatherIconPainter old) =>
      old.sunPhase != sunPhase ||
      old.rayPhase != rayPhase ||
      old.cloudPhase != cloudPhase;
}

// ───────────────────────────── LAST HIKE CARD ───────────────────────────────

class _LastHikeCard extends StatefulWidget {
  final VoidCallback onNavigateToMap;
  const _LastHikeCard({required this.onNavigateToMap});

  @override
  State<_LastHikeCard> createState() => _LastHikeCardState();
}

class _LastHikeCardState extends State<_LastHikeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _openHike(SavedHike hike) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HikeDetailScreen(hike: hike),
      ),
    );
  }

  /// "VIEW ALL" → push the full activity history list. Previously this
  /// jumped straight to the most recent hike or bounced to the Map tab,
  /// which surprised users — the affordance reads as "show me all my
  /// activities", so that's what it now does. The list itself handles
  /// empty state.
  void _onViewAll() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HikeHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HikeHistoryProvider>();
    final hikes = history.hikes;
    final SavedHike? latest = hikes.isNotEmpty ? hikes.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LAST HIKE',
                  style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                      .copyWith(letterSpacing: 0.16 * 11),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onViewAll,
                  child: Text(
                    'VIEW ALL →',
                    style: TT
                        .body(size: 10, w: FontWeight.w800, color: TT.ember)
                        .copyWith(letterSpacing: 0.1 * 10),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, child) {
              final t = TT.easeOut.transform(_ctl.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 14),
                  child: child,
                ),
              );
            },
            child: TTCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              onTap: latest != null
                  ? () => _openHike(latest)
                  : widget.onNavigateToMap,
              child: latest == null
                  ? _LastHikeEmpty(onTap: widget.onNavigateToMap)
                  : _LastHikeContent(hike: latest),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastHikeEmpty extends StatelessWidget {
  final VoidCallback onTap;
  const _LastHikeEmpty({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: TT.emberDim,
                border: Border.all(color: const Color(0x52FF6A2C), width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.flag_outlined,
                  size: 18, color: TT.ember),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recorded hikes yet',
                    style: TT.body(size: 14, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'START YOUR FIRST · TAP TO BEGIN',
                    style: TT.mono(size: 10.5, color: TT.text3, w: FontWeight.w600)
                        .copyWith(letterSpacing: 0.04 * 10.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 15, color: TT.text3),
          ],
        ),
        const SizedBox(height: 12),
        TTBigElevChart(peakLabel: 'No data yet', elevationUnit: units.elevationUnit),
      ],
    );
  }
}

class _LastHikeContent extends StatelessWidget {
  final SavedHike hike;
  const _LastHikeContent({required this.hike});

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final distStr = units.distanceFromKm(hike.distanceKm).toStringAsFixed(1);
    final distUnit = units.distanceUnit;
    final dur = Duration(seconds: hike.durationSeconds);
    final durText =
        '${dur.inHours}:${(dur.inMinutes % 60).toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    final dateStr = DateFormat('MMM d').format(hike.startedAt).toUpperCase();
    final ascentVal = NumberFormat.decimalPattern()
        .format(units.elevationFromM(hike.ascentM.toDouble()).round());
    final elevUnit = units.elevationUnit;
    final peakLabel = '$distStr $distUnit · $ascentVal $elevUnit';

    // Calories: ~117 kcal per mile (rough but matches activity screen heuristic).
    final kcal = NumberFormat.decimalPattern()
        .format((hike.distanceKm * 116.7).round());
    // Steps: ~1312 steps per km (rough hiking cadence).
    final steps = NumberFormat.decimalPattern()
        .format((hike.distanceKm * 1312).round());

    final samples = hike.points.length > 4
        ? hike.points.map((p) => p.altitude).toList()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hike.name,
                    style: TT.body(size: 14, w: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dateStr · $distStr $distUnit · $durText',
                    style:
                        TT.mono(size: 10.5, color: TT.text3, w: FontWeight.w600)
                            .copyWith(letterSpacing: 0.04 * 10.5),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x214CC38A),
                border: Border.all(color: const Color(0x4D4CC38A), width: 1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'SYNCED',
                style: TT.mono(size: 9, color: TT.green, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.12 * 9),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.chevron_right, size: 15, color: TT.text3),
          ],
        ),
        const SizedBox(height: 8),
        TTBigElevChart(samples: samples, peakLabel: peakLabel, elevationUnit: elevUnit),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatChip(
              leading: '↑',
              value: ascentVal,
              unit: elevUnit,
              valueColor: TT.ember,
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 12, color: TT.line3),
            const SizedBox(width: 14),
            _StatChip(leading: 'kcal', value: kcal, unit: 'kcal'),
            const SizedBox(width: 14),
            Container(width: 1, height: 12, color: TT.line3),
            const SizedBox(width: 14),
            _StatChip(leading: 'steps', value: steps, unit: ''),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String leading;
  final String value;
  final String unit;
  final Color? valueColor;
  const _StatChip({
    required this.leading,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          leading,
          style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TT.numStyle(size: 11, color: valueColor ?? TT.text, w: FontWeight.w800),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(unit, style: TT.mono(size: 10, color: TT.text2, w: FontWeight.w700)),
        ],
      ],
    );
  }
}

// ───────────────────────────── FIELD INTEL STRIP ────────────────────────────

/// Semantic destinations for a field-intel row. Each row carries the tab to
/// navigate to (Map for off-trail, Teams for team intel) or an Incident to
/// open in the bottom-sheet detail. Static-fallback rows route to whichever
/// tab best matches their copy (storms → Map, join-team → Teams).
enum _IntelDest { map, teams, incident }

class _FieldIntelStrip extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const _FieldIntelStrip({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // Pull live safety + team data so the strip surfaces real intel when
    // available. Curated Drakensberg-anchored fallbacks fill the slots when
    // no live data exists yet so the strip never looks empty.
    final safety = context.watch<SafetyProvider>();
    final teams = context.watch<TeamProvider>();
    final recording = context.watch<RecordingProvider>();

    final rows = _buildRows(safety, teams, recording);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'FIELD INTEL',
              style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                  .copyWith(letterSpacing: 0.16 * 11),
            ),
          ),
          TTStagger(
            base: const Duration(milliseconds: 1050),
            step: const Duration(milliseconds: 80),
            gap: 8,
            children: rows
                .map((e) => _IntelRow(
                      entry: e,
                      onTap: () => _handleTap(context, e),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, _IntelEntry entry) {
    switch (entry.dest) {
      case _IntelDest.incident:
        final incident = entry.incident;
        if (incident != null) {
          IncidentDetailSheet.show(context, incident);
        } else {
          // Defensive fallback so a missing incident never produces a dead tap.
          onNavigate?.call(1);
        }
        break;
      case _IntelDest.teams:
        onNavigate?.call(4);
        break;
      case _IntelDest.map:
        onNavigate?.call(1);
        break;
    }
  }

  List<_IntelEntry> _buildRows(SafetyProvider safety, TeamProvider teams,
      RecordingProvider recording) {
    final rows = <_IntelEntry>[];

    // 1) If recording is active and the user has drifted off-trail, surface
    //    that first — most important live signal. Routes to the Map tab so
    //    the user can see the "head back" arrow on the live tracking view.
    if (recording.isOffTrail) {
      final dist = recording.offTrailDist.round();
      rows.add(_IntelEntry(
        icon: Icons.warning_amber_rounded,
        color: TT.amber,
        title: 'Off trail by ${dist}m',
        sub: 'Head ${recording.returnDirection} to return to route',
        dest: _IntelDest.map,
      ));
    }

    // 2) Most recent hazard/incident from SafetyProvider's live stream.
    final hazards = safety.incidents
        .where((i) =>
            i.severity != IncidentSeverity.low &&
            i.type != IncidentType.viewpoint &&
            i.type != IncidentType.waterSource)
        .toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    if (hazards.isNotEmpty) {
      final h = hazards.first;
      rows.add(_IntelEntry(
        icon: _iconForIncident(h.type),
        color: _colorForSeverity(h.severity),
        title: _shortTitle(h),
        sub:
            '${h.trailName ?? "Drakensberg"} · reported ${_ago(h.reportedAt)}',
        dest: _IntelDest.incident,
        incident: h,
      ));
    }

    // 3) Team activity — selected team's name + member count. Routes to the
    //    Teams tab where live tracking + chat live.
    final t = teams.selectedTeam;
    if (t != null) {
      rows.add(_IntelEntry(
        icon: Icons.group_outlined,
        color: TT.green,
        title: '${t.members.length} hikers in ${t.name}',
        sub: 'TAP TEAMS TAB FOR LIVE TRACKING',
        dest: _IntelDest.teams,
      ));
    }

    // Fall back to curated Drakensberg-focused content when the live signals
    // aren't ready yet — keeps the strip looking intentional. Each fallback
    // routes to the tab that matches its copy so taps still produce real
    // navigation, never a dead end.
    if (rows.isEmpty) {
      return const [
        _IntelEntry(
          icon: Icons.warning_amber_rounded,
          color: TT.amber,
          title: 'Loose rock near Tugela Gorge',
          sub: 'Drakensberg North · advisory standing',
          dest: _IntelDest.map,
        ),
        _IntelEntry(
          icon: Icons.air,
          color: TT.blue,
          title: 'Afternoon storms possible',
          sub: 'Check weather card before late departures',
          dest: _IntelDest.map,
        ),
        _IntelEntry(
          icon: Icons.group_outlined,
          color: TT.green,
          title: 'Join a Trailtether team',
          sub: 'Share live location with hiking partners',
          dest: _IntelDest.teams,
        ),
      ];
    }

    return rows.take(3).toList();
  }

  static IconData _iconForIncident(IncidentType t) {
    switch (t) {
      case IncidentType.weatherEvent:
        return Icons.air;
      case IncidentType.rockfall:
      case IncidentType.trailDamage:
        return Icons.warning_amber_rounded;
      case IncidentType.wildlifeEncounter:
      case IncidentType.snakeBite:
        return Icons.pets;
      case IncidentType.medicalEmergency:
      case IncidentType.stuckOrTrapped:
        return Icons.medical_services_outlined;
      default:
        return Icons.report_outlined;
    }
  }

  static Color _colorForSeverity(IncidentSeverity s) {
    switch (s) {
      case IncidentSeverity.critical:
        return TT.red;
      case IncidentSeverity.serious:
        return TT.amber;
      case IncidentSeverity.moderate:
        return TT.amber;
      case IncidentSeverity.low:
        return TT.blue;
    }
  }

  static String _shortTitle(Incident h) {
    if (h.description.isNotEmpty) {
      final first = h.description.split('. ').first;
      return first.length > 60 ? '${first.substring(0, 57)}…' : first;
    }
    return h.type.label;
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _IntelEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final _IntelDest dest;
  final Incident? incident;
  const _IntelEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.dest,
    this.incident,
  });
}

class _IntelRow extends StatelessWidget {
  final _IntelEntry entry;
  final VoidCallback onTap;
  const _IntelRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border(
            top: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            right: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            bottom: BorderSide(color: entry.color.withOpacity(0.2), width: 1),
            left: BorderSide(color: entry.color, width: 3),
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: entry.color.withOpacity(0.12),
                border: Border.all(color: entry.color.withOpacity(0.25), width: 1),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(entry.icon, size: 14, color: entry.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TT.body(size: 12, w: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.sub,
                    style: TT.mono(size: 10, color: TT.text3, w: FontWeight.w500)
                        .copyWith(letterSpacing: 0.02 * 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: TT.text3),
          ],
        ),
      ),
    );
  }
}
