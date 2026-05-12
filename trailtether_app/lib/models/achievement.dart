import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String requirement;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final DateTime? dateUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.requirement,
    required this.icon,
    required this.color,
    this.unlocked = false,
    this.dateUnlocked,
  });

  Achievement copyWith({bool? unlocked, DateTime? dateUnlocked}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      requirement: requirement,
      icon: icon,
      color: color,
      unlocked: unlocked ?? this.unlocked,
      dateUnlocked: dateUnlocked ?? this.dateUnlocked,
    );
  }

  Achievement unlock() {
    return copyWith(unlocked: true, dateUnlocked: DateTime.now());
  }
}

List<Achievement> getDefaultAchievements() {
  return [
    // ── Milestone Achievements ───────────────────────────────────────────────
    const Achievement(
        id: 'first_hike',
        title: 'Trailblazer',
        description: 'Record your very first hike',
        requirement: 'Complete and save 1 hike recording',
        icon: Icons.terrain,
        color: Color(0xFF4CAF50)),
    const Achievement(
        id: 'hike_5',
        title: 'Steady Wanderer',
        description: 'Complete 5 hikes',
        requirement: 'Reach a lifetime count of 5 hikes',
        icon: Icons.hiking,
        color: Color(0xFF81C784)),
    const Achievement(
        id: 'hike_10',
        title: 'Regular Trekker',
        description: 'Complete 10 hikes',
        requirement: 'Reach a lifetime count of 10 hikes',
        icon: Icons.groups,
        color: Color(0xFF66BB6A)),
    const Achievement(
        id: 'hike_25',
        title: 'Pathfinder',
        description: 'Complete 25 hikes',
        requirement: 'Reach a lifetime count of 25 hikes',
        icon: Icons.map,
        color: Color(0xFF43A047)),
    const Achievement(
        id: 'hike_50',
        title: 'Trail Master',
        description: 'Complete 50 hikes',
        requirement: 'Reach a lifetime count of 50 hikes',
        icon: Icons.stars,
        color: Color(0xFF2E7D32)),

    // ── Distance Achievements ────────────────────────────────────────────────
    const Achievement(
        id: 'dist_10',
        title: 'Double Digits',
        description: 'Cover 10km total distance',
        requirement: 'Accumulate 10km of total recorded distance',
        icon: Icons.directions_walk,
        color: Color(0xFF2196F3)),
    const Achievement(
        id: 'dist_50',
        title: 'Half Century',
        description: 'Cover 50km total distance',
        requirement: 'Accumulate 50km of total recorded distance',
        icon: Icons.directions_run,
        color: Color(0xFF1976D2)),
    const Achievement(
        id: 'dist_100',
        title: 'Century Club',
        description: 'Cover 100km total distance',
        requirement: 'Accumulate 100km of total recorded distance',
        icon: Icons.speed,
        color: Color(0xFF1565C0)),
    const Achievement(
        id: 'dist_250',
        title: 'Long Haul',
        description: 'Cover 250km total distance',
        requirement: 'Accumulate 250km of total recorded distance',
        icon: Icons.explore,
        color: Color(0xFF0D47A1)),
    const Achievement(
        id: 'dist_500',
        title: 'Roaming Legend',
        description: 'Cover 500km total distance',
        requirement: 'Accumulate 500km of total recorded distance',
        icon: Icons.public,
        color: Color(0xFF01579B)),

    // ── Single Hike Achievements ─────────────────────────────────────────────
    const Achievement(
        id: 'single_15',
        title: 'Day Tripper',
        description: 'Complete a 15km hike in one go',
        requirement: 'Record a single hike longer than 15km',
        icon: Icons.timer,
        color: Color(0xFF00B8D4)),
    const Achievement(
        id: 'single_25',
        title: 'Endurance Hunter',
        description: 'Complete a 25km hike in one go',
        requirement: 'Record a single hike longer than 25km',
        icon: Icons.bolt,
        color: Color(0xFF0091EA)),
    const Achievement(
        id: 'single_40',
        title: 'Endurance Master',
        description: 'Complete a 40km hike in one go',
        requirement: 'Record a single hike longer than 40km',
        icon: Icons.workspace_premium,
        color: Color(0xFF2962FF)),

    // ── Elevation Achievements ───────────────────────────────────────────────
    const Achievement(
        id: 'elev_500',
        title: 'Hill Climber',
        description: 'Gain 500m total elevation',
        requirement: 'Accumulate 500m of total elevation gain',
        icon: Icons.trending_up,
        color: Color(0xFFFFB74D)),
    const Achievement(
        id: 'elev_1000',
        title: 'Mountain Goat',
        description: 'Gain 1,000m total elevation',
        requirement: 'Accumulate 1,000m of total elevation gain',
        icon: Icons.landscape,
        color: Color(0xFFFF9800)),
    const Achievement(
        id: 'elev_2500',
        title: 'Summit Aspirant',
        description: 'Gain 2,500m total elevation',
        requirement: 'Accumulate 2,500m of total elevation gain',
        icon: Icons.filter_hdr,
        color: Color(0xFFFB8C00)),
    const Achievement(
        id: 'elev_5000',
        title: 'Peak Enthusiast',
        description: 'Gain 5,000m total elevation',
        requirement: 'Accumulate 5,000m of total elevation gain',
        icon: Icons.terrain,
        color: Color(0xFFEF6C00)),
    const Achievement(
        id: 'elev_10000',
        title: 'Sky Walker',
        description: 'Gain 10,000m total elevation',
        requirement: 'Accumulate 10,000m of total elevation gain',
        icon: Icons.cloud,
        color: Color(0xFFE65100)),

    // ── Peak Achievements ───────────────────────────────────────────────────
    const Achievement(
        id: 'peak_1',
        title: 'First Summit',
        description: 'Reach your first 3,000m+ peak',
        requirement: 'Reach an altitude of 3,000m or higher',
        icon: Icons.filter_hdr,
        color: Color(0xFFE91E63)),
    const Achievement(
        id: 'peak_3',
        title: 'Peak Bagger',
        description: 'Summit 3 different peaks',
        requirement: 'Log 3 unique peaks in the Drakensberg',
        icon: Icons.landscape,
        color: Color(0xFFD81B60)),
    const Achievement(
        id: 'peak_5',
        title: 'Summit Seeker',
        description: 'Summit 5 different peaks',
        requirement: 'Log 5 unique peaks in the Drakensberg',
        icon: Icons.terrain,
        color: Color(0xFFC2185B)),
    const Achievement(
        id: 'peak_10',
        title: 'High Altitude Elite',
        description: 'Summit 10 different peaks',
        requirement: 'Log 10 unique peaks in the Drakensberg',
        icon: Icons.ac_unit,
        color: Color(0xFFAD1457)),

    // ── Time & Weather Achievements ──────────────────────────────────────────
    const Achievement(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Start a hike before 6:00 AM',
        requirement: 'Begin a hike recording before 06:00',
        icon: Icons.wb_sunny_outlined,
        color: Color(0xFFFFF176)),
    const Achievement(
        id: 'night_owl',
        title: 'Night Owl',
        description: 'Finish a hike after 7:00 PM',
        requirement: 'Complete a hike recording after 19:00',
        icon: Icons.nights_stay,
        color: Color(0xFF7E57C2)),
    const Achievement(
        id: 'storm_hiker',
        title: 'Weather Proof',
        description: 'Hike during a weather incident report',
        requirement: 'Record a hike during active storm warnings',
        icon: Icons.thunderstorm,
        color: Color(0xFF546E7A)),

    // ── Team & Social Achievements ───────────────────────────────────────────
    const Achievement(
        id: 'team_join',
        title: 'New Recruit',
        description: 'Join your first team',
        requirement: 'Successfully join a team via invite code',
        icon: Icons.person_add,
        color: Color(0xFF9575CD)),
    const Achievement(
        id: 'team_create',
        title: 'Team Leader',
        description: 'Create a new team',
        requirement: 'Register and lead a new hiking team',
        icon: Icons.group_add,
        color: Color(0xFF673AB7)),
    const Achievement(
        id: 'team_mvp',
        title: 'Team Player',
        description: 'Contribute 20km to team distance',
        requirement: 'Log 20km of distance while in a team',
        icon: Icons.military_tech,
        color: Color(0xFF4527A0)),

    // ── Exploration Achievements ─────────────────────────────────────────────
    const Achievement(
        id: 'cave_visit',
        title: 'Speleologist',
        description: 'Visit a Drakensberg cave',
        requirement: 'Check-in at a recorded cave waypoint',
        icon: Icons.door_front_door,
        color: Color(0xFF795548)),
    const Achievement(
        id: 'cave_3',
        title: 'Cave Dweller',
        description: 'Visit 3 different caves',
        requirement: 'Check-in at 3 unique cave waypoints',
        icon: Icons.home,
        color: Color(0xFF5D4037)),
    const Achievement(
        id: 'new_trail',
        title: 'Explorer',
        description: 'Hike a trail you\'ve never done before',
        requirement: 'Complete a trail not in your history',
        icon: Icons.explore_outlined,
        color: Color(0xFF009688)),

    // ── Safety & Reporting Achievements ──────────────────────────────────────
    const Achievement(
        id: 'reporter',
        title: 'Good Samaritan',
        description: 'Report your first trail incident',
        requirement: 'Submit your first verified incident report',
        icon: Icons.report_problem,
        color: Color(0xFFFFC107)),
    const Achievement(
        id: 'guardian',
        title: 'Trail Guardian',
        description: 'Report 5 incidents to help others',
        requirement: 'Submit 5 verified incident reports',
        icon: Icons.verified_user,
        color: Color(0xFFFFD600)),

    // ── Persistence Achievements ─────────────────────────────────────────────
    const Achievement(
        id: 'week_streak',
        title: 'Weekly Warrior',
        description: 'Hike twice in one week',
        requirement: 'Log 2 separate hikes within 7 days',
        icon: Icons.date_range,
        color: Color(0xFF8BC34A)),
    const Achievement(
        id: 'weekend_warrior',
        title: 'Weekend Warrior',
        description: 'Hike on both Saturday and Sunday',
        requirement: 'Record hikes on consecutive weekend days',
        icon: Icons.weekend,
        color: Color(0xFF558B2F)),

    // ── Specific Drakensberg Challenges ──────────────────────────────────────
    const Achievement(
        id: 'sentinel_climb',
        title: 'Chain Ladder King',
        description: 'Complete the Sentinel Peak hike',
        requirement: 'Log a successful Sentinel Peak route',
        icon: Icons.linear_scale,
        color: Color(0xFF3F51B5)),
    const Achievement(
        id: 'tugela_fall',
        title: 'Highest Fall',
        description: 'Visit the Tugela Falls summit',
        requirement: 'Check-in at the Tugela Falls summit',
        icon: Icons.waves,
        color: Color(0xFF0288D1)),
    const Achievement(
        id: 'cathedral_peak',
        title: 'Cathedral Conquest',
        description: 'Summit Cathedral Peak',
        requirement: 'Record a summit of Cathedral Peak',
        icon: Icons.church,
        color: Color(0xFF7B1FA2)),
    const Achievement(
        id: 'giant_castle',
        title: 'The Giant',
        description: 'Hike the Giant\'s Castle main route',
        requirement: 'Log a successful Giant\'s Castle summit',
        icon: Icons.person_search,
        color: Color(0xFF8D6E63)),
    const Achievement(
        id: 'mnweni_explorer',
        title: 'Mnweni Pioneer',
        description: 'Complete a route in the Mnweni area',
        requirement: 'Log a successful Mnweni Pass route',
        icon: Icons.nature_people,
        color: Color(0xFF33691E)),
  ];
}
