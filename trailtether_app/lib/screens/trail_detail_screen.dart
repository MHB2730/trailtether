import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/trail.dart';
import '../providers/app_state_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/review_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/common/glass_panel.dart';
import '../widgets/review/review_card.dart';
import '../widgets/review/review_summary_bar.dart';
import '../widgets/trail/difficulty_badge.dart';
import '../widgets/trail/elevation_chart.dart';
import '../widgets/trail/trail_stats_row.dart';
import 'reviews_screen.dart';
import 'safety_center_screen.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final VoidCallback onNavigateToMap;
  const TrailDetailScreen(
      {super.key, required this.trail, required this.onNavigateToMap});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  double _paceFactor = 1.0;
  late StaticDataProvider _staticDataProvider;

  @override
  void initState() {
    super.initState();
    context.read<ReviewProvider>().listenTo(widget.trail.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _staticDataProvider = context.read<StaticDataProvider>();
  }

  @override
  void dispose() {
    _staticDataProvider.clearProfileCursor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trail = widget.trail;
    final appState = context.watch<AppStateProvider>();
    final isFavorite = appState.isFavorite(trail.id);
    final isCompleted = appState.isCompleted(trail.id);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => GlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        opacity: 0.98,
        blur: 20,
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kColorCream.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Hero(
                    tag: 'trail_name_${trail.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        trail.name,
                        style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (trail.isCave) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF795548).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF795548).withOpacity(0.5)),
                    ),
                    child: const Text('🕳 Cave Route',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
                DifficultyBadge(trail.difficulty),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${trail.minEle}-${trail.maxEle} m elevation',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            TrailStatsRow(trail: trail, paceFactor: _paceFactor),
            const SizedBox(height: 14),
            _ActionRow(
              trail: trail,
              favoriteLabel: isFavorite ? 'Saved' : 'Save',
              completedLabel: isCompleted ? 'Done' : 'Complete',
              onToggleFavorite: () =>
                  context.read<AppStateProvider>().toggleFavorite(trail.id),
              onToggleCompleted: () =>
                  context.read<AppStateProvider>().toggleCompleted(trail.id),
              onFollow: () {
                final rec = context.read<RecordingProvider>();
                rec.setTargetTrail(trail);
                Navigator.pop(context);
                widget.onNavigateToMap();
              },
              onOpenMap: () {
                context.read<StaticDataProvider>().selectTrail(trail);
                Navigator.pop(context);
                widget.onNavigateToMap();
              },
              onShare: () => Share.share(
                'Check out ${trail.name} on Trailtether: '
                '${trail.distanceKm.toStringAsFixed(1)} km, '
                '${trail.elevationGainM} m gain.',
              ),
              onSafety: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SafetyCenterScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _PaceSelector(
              paceFactor: _paceFactor,
              onChanged: (value) => setState(() => _paceFactor = value),
            ),
            const SizedBox(height: 16),
            Text(
              'ELEVATION PROFILE',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ElevationChart.fromTrail(
              trail: trail,
              onCursorChanged: (coord) =>
                  context.read<StaticDataProvider>().setProfileCursor(coord),
            ),
            const SizedBox(height: 20),
            _PlanningNotes(trail: trail),
            const SizedBox(height: 20),
            if (trail.description.isNotEmpty) ...[
              Text(
                trail.description,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Consumer<ReviewProvider>(
              builder: (_, prov, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'COMMUNITY REVIEWS',
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.4),
                            fontSize: 10,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewsScreen(trail: trail),
                          ),
                        ),
                        child: Text(
                          'See all & review',
                          style: GoogleFonts.outfit(
                            color: kColorOrange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ReviewSummaryBar(summary: prov.summary),
                  const SizedBox(height: 12),
                  ...prov.reviews
                      .take(3)
                      .map((review) => ReviewCard(review: review)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Trail trail;
  final String favoriteLabel;
  final String completedLabel;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleCompleted;
  final VoidCallback onFollow;
  final VoidCallback onOpenMap;
  final VoidCallback onShare;
  final VoidCallback onSafety;

  const _ActionRow({
    required this.trail,
    required this.favoriteLabel,
    required this.completedLabel,
    required this.onToggleFavorite,
    required this.onToggleCompleted,
    required this.onFollow,
    required this.onOpenMap,
    required this.onShare,
    required this.onSafety,
  });

  @override
  Widget build(BuildContext context) {
    final following =
        context.watch<RecordingProvider>().targetTrail?.id == trail.id;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon:
              following ? Icons.play_circle_filled : Icons.play_circle_outline,
          label: following ? 'Following' : 'Follow',
          onTap: onFollow,
          color: following ? Colors.greenAccent : null,
        ),
        _ActionChip(
          icon: Icons.favorite_border,
          label: favoriteLabel,
          onTap: onToggleFavorite,
        ),
        _ActionChip(
          icon: Icons.check_circle_outline,
          label: completedLabel,
          onTap: onToggleCompleted,
        ),
        _ActionChip(
          icon: Icons.map_outlined,
          label: 'Map',
          onTap: onOpenMap,
        ),
        _ActionChip(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: onShare,
        ),
        _ActionChip(
          icon: Icons.shield_outlined,
          label: 'Safety',
          onTap: onSafety,
        ),
        _PeakCheckInChip(trail: trail),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                unawaited(HapticFeedback.lightImpact());
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1) ?? Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color?.withOpacity(0.5) ?? kColorBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color ?? kColorOrange, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: color ?? kColorCream,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlanningNotes extends StatelessWidget {
  final Trail trail;

  const _PlanningNotes({required this.trail});

  @override
  Widget build(BuildContext context) {
    final note = switch (trail.distanceKm) {
      < 5 => 'Short outing. Good for low-commitment mornings and skill drills.',
      < 12 => 'Solid day hike. Start early and carry full weather layers.',
      _ =>
        'Long day or overnight effort. Plan nutrition, water, and exit time carefully.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kColorBg.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLANNING NOTES',
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.4),
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.7),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceSelector extends StatelessWidget {
  final double paceFactor;
  final ValueChanged<double> onChanged;

  static const _options = [0.7, 1.0, 1.3];
  static final _labels = {0.7: 'Fast', 1.0: 'Moderate', 1.3: 'Slow'};

  const _PaceSelector({
    required this.paceFactor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Pace: ',
          style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        ..._options.map((value) {
          final selected = paceFactor == value;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? kColorOrange.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? kColorOrange : kColorBorder,
                  ),
                ),
                child: Text(
                  _labels[value]!,
                  style: GoogleFonts.outfit(
                    color:
                        selected ? kColorOrange : kColorCream.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PeakCheckInChip extends StatefulWidget {
  final Trail trail;
  const _PeakCheckInChip({required this.trail});

  @override
  State<_PeakCheckInChip> createState() => _PeakCheckInChipState();
}

class _PeakCheckInChipState extends State<_PeakCheckInChip> {
  bool _verifying = false;
  String? _status;

  Future<void> _checkIn() async {
    setState(() {
      _verifying = true;
      _status = 'Verifying...';
    });

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      // Most trails end at the peak. Check proximity to the last coordinate.
      final lastCoord = widget.trail.coords.last;
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, lastCoord.lat, lastCoord.lon);

      if (dist < 250) {
        setState(() => _status = 'Verified! 🏔');
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        final userEmail =
            Supabase.instance.client.auth.currentUser?.email ?? 'A hiker';

        await Supabase.instance.client.from('community_activities').insert({
          'user_id': uid,
          'user_name': userEmail.split('@')[0],
          'type': 'check_in',
          'title': 'Summited Peak',
          'subtitle': 'Verified at ${widget.trail.name}',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        unawaited(context.read<CommunityProvider>().refresh());
        setState(() => _status = 'Done!');
        unawaited(HapticFeedback.heavyImpact());
      } else {
        setState(() => _status = 'Too far');
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Err');
    } finally {
      if (mounted) {
        unawaited(Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _verifying = false;
              _status = null;
            });
          }
        }));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show if it looks like a peak/summit/pass
    final isPeak = widget.trail.name.toLowerCase().contains('peak') ||
        widget.trail.name.toLowerCase().contains('summit') ||
        widget.trail.name.toLowerCase().contains('pass');
    if (!isPeak) return const SizedBox.shrink();

    return _ActionChip(
      icon: _status == 'Done!' ? Icons.check : Icons.landscape,
      label: _status ?? 'Check-in',
      onTap: _verifying ? null : _checkIn,
      color: _status == 'Done!' ? Colors.greenAccent : Colors.lightBlueAccent,
    );
  }
}
