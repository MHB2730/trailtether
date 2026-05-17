import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'sos_screen.dart';
import 'live_tracking_screen.dart';

import '../core/constants.dart';
import '../models/team.dart';
import '../models/weather.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../services/team_service.dart';
import '../services/weather_service.dart';
import '../providers/weather_provider.dart';
import '../providers/hike_history_provider.dart';
import '../models/saved_hike.dart';
import '../widgets/common/glass_panel.dart';
import '../widgets/common/user_avatar.dart';
import 'hike_history_screen.dart';
import '../providers/profile_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// HomeTab
// ════════════════════════════════════════════════════════════════════════════
class HomeTab extends StatefulWidget {
  final void Function(int tabIndex) onNavigate;
  const HomeTab({super.key, required this.onNavigate});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Plans future cached here so FutureBuilder doesn't re-fetch on every rebuild.
  Future<List<HikePlan>> _plansFuture = Future.value([]);
  // Guard: only recreate the future when the actual team ID changes.
  String? _lastTeamId;
  // Guard: only push hike stats into ProfileProvider when the set actually changed.
  int? _lastHikesSignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final teams = context.read<TeamProvider>().teams;
    final teamIds = teams.map((t) => t.id).join(',');
    if (teamIds != _lastTeamId) {
      _lastTeamId = teamIds;
      if (teams.isEmpty) {
        _plansFuture = Future.value([]);
      } else {
        _plansFuture =
            Future.wait(teams.map((t) => TeamService.fetchPlansForTeam(t.id)))
                .then((listOfLists) {
          final allPlans = listOfLists.expand((l) => l).toList();
          allPlans.sort((a, b) => a.hikeDate.compareTo(b.hikeDate));
          return allPlans;
        });
      }
    }

    // Sync hike stats into the profile provider only when the hike list changes.
    final hikeProv = context.read<HikeHistoryProvider>();
    if (hikeProv.loaded) {
      final sig = Object.hashAll(hikeProv.hikes.map((h) => h.id));
      if (sig != _lastHikesSignature) {
        _lastHikesSignature = sig;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ProfileProvider>().updateStats(hikeProv.hikes);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    // Watch teams + history so didChangeDependencies fires on changes.
    context.watch<TeamProvider>();
    context.watch<HikeHistoryProvider>();

    // No Scaffold here — we live inside AppShell's Scaffold.
    // ScrollConfiguration disables the automatic Windows scrollbar that
    // fights the scroll position when _WeatherSection changes height.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo Hero Banner ─────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'home_banner',
                        child: Image.asset(
                          'assets/icon/hero_mountains.jpg',
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF1E1E1E).withOpacity(0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ── Header ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,',
                              style: GoogleFonts.outfit(
                                  color: kColorOrange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0)),
                          const SizedBox(height: 4),
                          Text(auth.displayName ?? 'Explorer',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5)),
                        ]),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onNavigate(6); // Profile Tab
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [kColorOrange, Colors.orangeAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: kColorOrange.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2)
                          ],
                        ),
                        child: Hero(
                          tag: 'user_avatar',
                          child: UserAvatar(
                            photoUrl: auth.photoUrl,
                            displayName: auth.displayName ?? 'Explorer',
                            radius: 28,
                            backgroundColor: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Quick Actions ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        label: 'SOS ALERT',
                        icon: Icons.emergency_share,
                        color: Colors.red,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SosScreen()));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QuickActionButton(
                        label: 'LIVE TRACK',
                        icon: Icons.my_location,
                        color: Colors.blueAccent,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LiveTrackingScreen()));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Weather — standalone section ───────────────────────────
                const RepaintBoundary(
                  child: _WeatherSection(),
                ),
                const SizedBox(height: 32),

                // ── Recent Activities (Strava-style Feed) ────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Activities',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    TextButton(
                      onPressed: () => widget
                          .onNavigate(2), // Navigate to Tools
                      child: Text('View All',
                          style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _HikeActivityFeed(),
                const SizedBox(height: 32),

                const SizedBox(height: 32),

                // ── Planned Hikes ────────────────
                FutureBuilder<List<HikePlan>>(
                  future: _plansFuture,
                  builder: (context, snapshot) {
                    final plans = snapshot.data ?? [];
                    return RepaintBoundary(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Planned Hikes',
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 12),
                            _UpcomingHikes(plans: plans),
                          ]),
                    );
                  },
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ); // ScrollConfiguration
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _UpcomingHikes
// ════════════════════════════════════════════════════════════════════════════
class _UpcomingHikes extends StatelessWidget {
  final List<HikePlan> plans;
  const _UpcomingHikes({required this.plans});

  @override
  Widget build(BuildContext context) {
    final upcoming = plans
        .where((p) => p.hikeDate
            .isAfter(DateTime.now().subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.hikeDate.compareTo(b.hikeDate));

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Center(
            child: Column(children: [
          const Icon(Icons.event_busy, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          Text('No upcoming hikes scheduled.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center),
        ])),
      );
    }

    return Column(
      children: upcoming
          .map((plan) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kColorOrange.withOpacity(0.15),
                      Colors.transparent
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kColorOrange.withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kColorOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kColorOrange.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.terrain,
                        color: kColorOrange, size: 28),
                  ),
                  title: Text(plan.trailName,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        plan.extras.time.isNotEmpty
                            ? '${DateFormat('EEEE, MMM d').format(plan.hikeDate)} @ ${plan.extras.time}'
                            : DateFormat('EEEE, MMM d').format(plan.hikeDate),
                        style: GoogleFonts.outfit(
                            color: kColorOrange.withOpacity(0.8),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _WeatherSection — STATEFUL, self-contained.
// Standalone widget — does NOT feed data into the calendar.
// ════════════════════════════════════════════════════════════════════════════
class _WeatherSection extends StatefulWidget {
  const _WeatherSection();

  @override
  State<_WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<_WeatherSection> {
  int _locationIndex = 0;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_fetch());
    });
  }

  void _showAddLocationDialog() {
    final wp = context.read<WeatherProvider>();
    showDialog(
      context: context,
      builder: (context) => const _LocationSearchDialog(),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        wp.addLocation(result['name'], result['lat'], result['lon']).then((_) {
          setState(() {
            _locationIndex = wp.locations.length - 1;
            _selectedDayIndex = 0;
          });
          _fetch();
        });
      }
    });
  }

  Future<void> _fetch() async {
    final wp = context.read<WeatherProvider>();
    if (wp.locations.isEmpty) return;
    if (_locationIndex >= wp.locations.length) _locationIndex = 0;
    await wp.fetchWeatherForLocation(_locationIndex);
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WeatherProvider>();
    final weather = wp.currentWeather;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Section header ───────────────────────────────────────────────
      Row(children: [
        const Icon(Icons.cloud_outlined, color: kColorOrange, size: 20),
        const SizedBox(width: 8),
        Text('Weather Forecast',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const Spacer(),
        GestureDetector(
          onTap: _fetch,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: wp.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kColorOrange))
                : const Icon(Icons.refresh, color: Colors.white54, size: 18),
          ),
        ),
      ]),
      const SizedBox(height: 12),

      // ── Location picker ──────────────────────────────────────────────
      Consumer<WeatherProvider>(
        builder: (context, wp, child) => SizedBox(
          height: 36,
          child: ListView.separated(
            key: const ValueKey('location-chips'),
            scrollDirection: Axis.horizontal,
            primary: false,
            itemCount: wp.locations.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == wp.locations.length) {
                return GestureDetector(
                  onTap: _showAddLocationDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Colors.white60, size: 14),
                        const SizedBox(width: 4),
                        Text('Add',
                            style: GoogleFonts.outfit(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }
              final sel = i == _locationIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _locationIndex = i;
                    _selectedDayIndex = 0;
                  });
                  _fetch();
                },
                onLongPress: () {
                  if (wp.locations.length > 1) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: kColorPanel,
                        title: Text('Remove Location?',
                            style: GoogleFonts.outfit(color: Colors.white)),
                        content: Text(
                            'Do you want to remove "${wp.locations[i]['name']}"?',
                            style: GoogleFonts.outfit(color: Colors.white70)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CANCEL')),
                          TextButton(
                            onPressed: () {
                              wp.removeLocation(i);
                              Navigator.pop(context);
                              if (_locationIndex >= wp.locations.length) {
                                setState(() => _locationIndex = 0);
                              }
                              _fetch();
                            },
                            child: const Text('REMOVE',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? kColorOrange : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            sel ? kColorOrange : Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(wp.locations[i]['name'] as String,
                      style: GoogleFonts.outfit(
                          color: sel ? Colors.white : Colors.white60,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 16),

      // ── Error ────────────────────────────────────────────────────────
      if (wp.error != null)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.wifi_off, color: Colors.red, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(wp.error!,
                    style: GoogleFonts.outfit(
                        color: Colors.white60, fontSize: 13))),
            TextButton(
                onPressed: _fetch,
                child: Text('Retry',
                    style: GoogleFonts.outfit(color: kColorOrange))),
          ]),
        ),

      // ── Loading placeholder ──────────────────────────────────────────
      if (wp.loading && weather == null)
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Center(
            child:
                CircularProgressIndicator(strokeWidth: 2, color: kColorOrange),
          ),
        ),

      // ── Loaded ───────────────────────────────────────────────────────
      if (weather != null) ...[
        _CurrentCard(weather: weather),
        const SizedBox(height: 16),
        Text('7-Day Forecast',
            style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.separated(
            key: const ValueKey('daily-forecast'),
            scrollDirection: Axis.horizontal,
            primary: false,
            itemCount: weather.daily.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _DayCard(
              day: weather.daily[i],
              isToday: i == 0,
              selected: i == _selectedDayIndex,
              onTap: () => setState(() => _selectedDayIndex = i),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _HourlyDetail(
          day: weather.daily[_selectedDayIndex],
          hours: weather.hoursForDay(_selectedDayIndex),
        ),
      ],
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Current conditions card
// ════════════════════════════════════════════════════════════════════════════
class _CurrentCard extends StatelessWidget {
  final WeatherData weather;
  const _CurrentCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final c = weather.current;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A2A3A).withOpacity(0.9),
            const Color(0xFF0D1520).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(weatherEmoji(c.weatherCode),
                    style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 8),
                Text(weatherDescription(c.weatherCode).toUpperCase(),
                    style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('Refreshed ${_ago(weather.fetchedAt)}',
                    style: GoogleFonts.outfit(
                        color: Colors.white24, fontSize: 10)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${c.temperature.round()}°',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            Text('Feels like ${c.feelsLike.round()}°C',
                style: GoogleFonts.outfit(
                    color: kColorOrange.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: Colors.white10, height: 1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Metric(Icons.water_drop_outlined, '${c.humidity}%', 'HUMIDITY'),
            _Metric(Icons.air, '${c.windSpeed.round()} km/h', 'WIND'),
            _Metric(Icons.wb_sunny_outlined, _uvLabel(c.uvIndex), 'UV INDEX'),
            _Metric(Icons.grain, '${c.precipitation} mm', 'PRECIP'),
          ],
        ),
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t).inMinutes;
    if (d < 1) return 'just now';
    if (d == 1) return '1 min ago';
    return '$d mins ago';
  }

  static String _uvLabel(double uv) {
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'V.High';
    return 'Extreme';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Single daily forecast card
// ════════════════════════════════════════════════════════════════════════════
class _DayCard extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;
  const _DayCard(
      {required this.day,
      required this.isToday,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cond = day.hikingCondition;
    final border = _condColor(cond);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? border.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? border : Colors.white.withOpacity(0.08),
              width: selected ? 1.5 : 1),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isToday ? 'Today' : DateFormat('EEE').format(day.date),
                  style: GoogleFonts.outfit(
                      color: isToday ? kColorOrange : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Text(weatherEmoji(day.weatherCode),
                  style: const TextStyle(fontSize: 24)),
              Text('${day.tempMax.round()}°/${day.tempMin.round()}°',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.water_drop, color: Colors.lightBlue, size: 10),
                const SizedBox(width: 2),
                Text('${day.precipProbability}%',
                    style: GoogleFonts.outfit(
                        color: Colors.lightBlue, fontSize: 10)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(cond.label,
                    style: GoogleFonts.outfit(
                        color: border,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
      ),
    );
  }

  static Color _condColor(HikingCondition c) {
    switch (c) {
      case HikingCondition.good:
        return const Color(0xFF4CAF50);
      case HikingCondition.caution:
        return const Color(0xFFFFC107);
      case HikingCondition.bad:
        return const Color(0xFFE53935);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Hourly detail panel
// ════════════════════════════════════════════════════════════════════════════
class _HourlyDetail extends StatelessWidget {
  final DailyForecast day;
  final List<HourlySlice> hours;
  const _HourlyDetail({required this.day, required this.hours});

  @override
  Widget build(BuildContext context) {
    final keyHours = hours.where((h) {
      final hr = h.time.hour;
      return hr == 5 ||
          hr == 7 ||
          hr == 9 ||
          hr == 11 ||
          hr == 13 ||
          hr == 15 ||
          hr == 17 ||
          hr == 19;
    }).toList();
    final display = keyHours.isNotEmpty ? keyHours : hours;
    final cond = day.hikingCondition;
    final condColor = _condColor(cond);
    final daylightH = day.daylightHours.inMinutes / 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(DateFormat('EEEE, d MMMM').format(day.date),
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: condColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: condColor.withOpacity(0.4)),
            ),
            child: Text('${cond.emoji} ${cond.label} for Hiking',
                style: GoogleFonts.outfit(
                    color: condColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _DetailStat(
              '${day.tempMin.round()}°–${day.tempMax.round()}°C', 'Temp'),
          _DetailStat('${day.windSpeedMax.round()} km/h', 'Max Wind'),
          _DetailStat('${day.precipSum.toStringAsFixed(1)} mm', 'Rain'),
          _DetailStat('UV ${day.uvIndexMax.toStringAsFixed(1)}', 'UV'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.wb_twilight, color: Colors.orange, size: 14),
          const SizedBox(width: 4),
          Text('Sunrise ${DateFormat('HH:mm').format(day.sunrise)}',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 12),
          const Icon(Icons.nights_stay_outlined,
              color: Colors.blueGrey, size: 14),
          const SizedBox(width: 4),
          Text('Sunset ${DateFormat('HH:mm').format(day.sunset)}',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 12),
          const Icon(Icons.light_mode_outlined, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text('${daylightH.toStringAsFixed(1)}h daylight',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
        ]),
        if (display.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Text('Hourly Breakdown',
              style: GoogleFonts.outfit(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              key: ValueKey(display.length),
              scrollDirection: Axis.horizontal,
              primary: false,
              itemCount: display.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _HourCard(h: display[i]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),
        _AssessmentText(day: day, cond: cond),
      ]),
    );
  }

  static Color _condColor(HikingCondition c) {
    switch (c) {
      case HikingCondition.good:
        return const Color(0xFF4CAF50);
      case HikingCondition.caution:
        return const Color(0xFFFFC107);
      case HikingCondition.bad:
        return const Color(0xFFE53935);
    }
  }
}

class _DetailStat extends StatelessWidget {
  final String value;
  final String label;
  const _DetailStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Single hour column
// ════════════════════════════════════════════════════════════════════════════
class _HourCard extends StatelessWidget {
  final HourlySlice h;
  const _HourCard({required this.h});

  @override
  Widget build(BuildContext context) {
    final isNight = h.time.hour < 6 || h.time.hour >= 19;
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isNight ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child:
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('HH:mm').format(h.time),
            style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        Text(weatherEmoji(h.weatherCode), style: const TextStyle(fontSize: 18)),
        Text('${h.temperature.round()}°',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.water_drop, color: Colors.lightBlue, size: 9),
          Text(' ${h.precipProbability}%',
              style: GoogleFonts.outfit(color: Colors.lightBlue, fontSize: 9)),
        ]),
        Text('${h.windSpeed.round()}km/h',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Hiking assessment text
// ════════════════════════════════════════════════════════════════════════════
class _AssessmentText extends StatelessWidget {
  final DailyForecast day;
  final HikingCondition cond;
  const _AssessmentText({required this.day, required this.cond});

  @override
  Widget build(BuildContext context) {
    final bullets = <String>[];
    if (day.tempMin < 0) {
      bullets.add(
          '❄️ Sub-zero low (${day.tempMin.round()}°C) — extra insulation required');
    } else if (day.tempMin < 5) {
      bullets.add(
          '🥶 Cold low (${day.tempMin.round()}°C) — warm layers on ridges');
    }
    if (day.tempMax > 33) {
      bullets.add(
          '🌡 High heat (${day.tempMax.round()}°C) — early start, extra water');
    }
    if (day.windSpeedMax > 65) {
      bullets.add(
          '💨 Gale-force wind (${day.windSpeedMax.round()} km/h) — exposed ridges unsafe');
    } else if (day.windSpeedMax > 40) {
      bullets.add(
          '🌬 Strong wind (${day.windSpeedMax.round()} km/h) — caution on ridgelines');
    }
    if (day.precipProbability > 65) {
      bullets.add(
          '🌧 High rain chance (${day.precipProbability}%) — ${day.precipSum.toStringAsFixed(1)} mm expected');
    } else if (day.precipProbability > 35) {
      bullets.add(
          '🌦 Chance of rain (${day.precipProbability}%) — pack waterproofs');
    }
    if (day.weatherCode >= 95) {
      bullets.add('⛈ Thunderstorm forecast — avoid open peaks after midday');
    }
    if (day.uvIndexMax >= 8) {
      bullets.add(
          '🌞 Very high UV (${day.uvIndexMax.toStringAsFixed(1)}) — sunscreen + hat essential');
    }
    if (cond == HikingCondition.good) {
      bullets.add('✅ Conditions look good — ideal for the trail');
    }
    if (bullets.isEmpty) {
      bullets.add('ℹ️ Standard mountain precautions apply');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Assessment',
          style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: 8),
      for (final b in bullets)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(b,
              style: GoogleFonts.outfit(
                  color: Colors.white70, fontSize: 12, height: 1.4)),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ════════════════════════════════════════════════════════════════════════════
class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Metric(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: kColorOrange, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// _LocationSearchDialog — interactive search for open-meteo geocoding
// ════════════════════════════════════════════════════════════════════════════
class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog();

  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search();
    });
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final res = await WeatherService.searchLocation(query);
    if (mounted) {
      setState(() {
        _results = res;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text('Search Location',
          style: GoogleFonts.outfit(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Drakensberg',
                hintStyle: const TextStyle(color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: kColorOrange),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: kColorOrange))
            else if (_results.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _ctrl.text.length < 2
                        ? 'Type to search...'
                        : 'No results found',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (ctx, i) {
                    final r = _results[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['name'],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                          '${r['lat'].toStringAsFixed(3)}, ${r['lon'].toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _HikeActivityFeed
// ════════════════════════════════════════════════════════════════════════════
class _HikeActivityFeed extends StatelessWidget {
  const _HikeActivityFeed();

  @override
  Widget build(BuildContext context) {
    return Consumer<HikeHistoryProvider>(
      builder: (_, history, __) {
        if (!history.loaded) {
          return const Center(
              child: CircularProgressIndicator(color: kColorOrange));
        }
        if (history.hikes.isEmpty) {
          return GlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Icon(Icons.directions_walk,
                  color: kColorCream.withOpacity(0.2), size: 32),
              const SizedBox(height: 12),
              Text('No activities yet',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 4),
              Text('Your recorded hikes will appear here.',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.3), fontSize: 12)),
            ]),
          );
        }

        final recent = history.hikes.take(3).toList();
        return Column(
          children:
              recent.map((hike) => _HikeActivityItem(hike: hike)).toList(),
        );
      },
    );
  }
}

class _HikeActivityItem extends StatelessWidget {
  final SavedHike hike;
  const _HikeActivityItem({required this.hike});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => HikeDetailScreen(hike: hike))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kColorOrange.withOpacity(0.1),
                  child:
                      const Icon(Icons.person, color: kColorOrange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hike.name,
                          style: GoogleFonts.outfit(
                              color: kColorCream,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(
                          DateFormat('MMM d, yyyy • h:mm a')
                              .format(hike.startedAt),
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.4),
                              fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActivityMetric(
                    label: 'Distance',
                    value: '${hike.distanceKm.toStringAsFixed(2)} km'),
                _ActivityMetric(label: 'Elev Gain', value: '${hike.ascentM} m'),
                _ActivityMetric(
                    label: 'Time',
                    value: _formatActivityDuration(hike.durationSeconds)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatActivityDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _ActivityMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ActivityMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.outfit(
                color: kColorCream, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
