import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/trail.dart';
import '../providers/app_state_provider.dart';
import '../providers/gpx_provider.dart';
import '../providers/static_data_provider.dart';
import '../providers/review_provider.dart';
import '../providers/units_provider.dart';
import '../widgets/trail/difficulty_badge.dart';
import 'gpx_upload_screen.dart';
import 'trail_detail_screen.dart';

class TrailsTab extends StatefulWidget {
  final VoidCallback onNavigateToMap;
  final bool embedded;
  const TrailsTab(
      {super.key, required this.onNavigateToMap, this.embedded = false});

  @override
  State<TrailsTab> createState() => _TrailsTabState();
}

class _TrailsTabState extends State<TrailsTab> {
  String _collectionFilter = 'all';
  String _distanceFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (widget.embedded) ...[
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
        ],
        _Entrance(delayMs: 0, child: _TopBar(embedded: widget.embedded)),
        const SizedBox(height: 4),
        if (!widget.embedded) ...[
          const _Entrance(delayMs: 40, child: _AddTrailCta()),
          const SizedBox(height: 8),
        ],
        const _Entrance(delayMs: 80, child: _FilterRow()),
        const SizedBox(height: 8),
        _Entrance(
          delayMs: 120,
          child: _SmartFilterRow(
            collectionFilter: _collectionFilter,
            distanceFilter: _distanceFilter,
            onCollectionChanged: (value) =>
                setState(() => _collectionFilter = value),
            onDistanceChanged: (value) =>
                setState(() => _distanceFilter = value),
          ),
        ),
        const SizedBox(height: 8),
        const _RecentSearchRow(),
        const SizedBox(height: 4),
        Expanded(
          child: _TrailList(
            collectionFilter: _collectionFilter,
            distanceFilter: _distanceFilter,
            onNavigateToMap: () {
              if (widget.embedded) Navigator.pop(context);
              widget.onNavigateToMap();
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kColorBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: kColorBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GpxUploadScreen()),
        ),
        backgroundColor: kColorOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road_outlined),
        label: Text(
          'Add trail',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Entrance extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _Entrance({required this.delayMs, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool embedded;
  const _TopBar({this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          const Icon(Icons.terrain, color: kColorOrange, size: 18),
          const SizedBox(width: 8),
          Text(
            'Trails',
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: _SearchField()),
          if (!embedded) ...[
            const SizedBox(width: 8),
            _GpxButton(),
          ],
        ],
      ),
    );
  }
}

class _AddTrailCta extends StatelessWidget {
  const _AddTrailCta();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<GpxProvider>().tracks.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GpxUploadScreen()),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kColorOrange.withOpacity(count > 0 ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kColorOrange.withOpacity(0.42)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_road_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add a trail',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'Import a GPX route and show it on the map.'
                          : '$count imported route${count == 1 ? '' : 's'} ready on the map.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right,
                  color: Colors.white.withOpacity(0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpxButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<GpxProvider>().tracks.length;
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const GpxUploadScreen())),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: count > 0 ? kColorOrange.withOpacity(0.15) : kColorPanel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      count > 0 ? kColorOrange.withOpacity(0.5) : kColorBorder),
            ),
            child: Icon(Icons.route_outlined,
                color: count > 0 ? kColorOrange : kColorCream.withOpacity(0.5),
                size: 18),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: kColorOrange, shape: BoxShape.circle),
                child: Text('$count',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _updateSearch(String query) {
    context
        .read<StaticDataProvider>()
        .setFilter(query, context.read<StaticDataProvider>().difficulty);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search, color: kColorCream.withOpacity(0.35), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: GoogleFonts.outfit(color: kColorCream, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search trails...',
                hintStyle: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {});
                final d = context.read<StaticDataProvider>().difficulty;
                context.read<StaticDataProvider>().setFilter(value, d);
              },
              onSubmitted: _updateSearch,
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                setState(() {});
                final d = context.read<StaticDataProvider>().difficulty;
                context.read<StaticDataProvider>().setFilter('', d);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  color: kColorCream.withOpacity(0.3),
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<StaticDataProvider>(
      builder: (_, provider, __) {
        return SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: StaticDataProvider.difficulties.map((difficulty) {
              final selected = provider.difficulty == difficulty;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    difficulty,
                    style: GoogleFonts.outfit(fontSize: 11),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    final q = context.read<StaticDataProvider>().query;
                    provider.setFilter(q, difficulty);
                  },
                  selectedColor: kColorOrange.withOpacity(0.2),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: selected ? kColorOrange : kColorBorder,
                  ),
                  labelStyle: TextStyle(
                    color:
                        selected ? kColorOrange : kColorCream.withOpacity(0.6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _SmartFilterRow extends StatelessWidget {
  final String collectionFilter;
  final String distanceFilter;
  final ValueChanged<String> onCollectionChanged;
  final ValueChanged<String> onDistanceChanged;

  const _SmartFilterRow({
    required this.collectionFilter,
    required this.distanceFilter,
    required this.onCollectionChanged,
    required this.onDistanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SegmentedFilter(
                  value: collectionFilter,
                  options: const {
                    'all': 'All',
                    'saved': 'Saved',
                    'done': 'Done',
                  },
                  onChanged: onCollectionChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentedFilter(
                  value: distanceFilter,
                  options: const {
                    'all': 'Any',
                    'short': '<5 km',
                    'day': '5-12 km',
                    'big': '12+ km',
                  },
                  onChanged: onDistanceChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _SegmentedFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final selected = entry.key == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? kColorOrange.withOpacity(0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color:
                        selected ? kColorOrange : kColorCream.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, appState, __) {
        if (appState.recentSearches.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              ...appState.recentSearches.map((query) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        final d = context.read<StaticDataProvider>().difficulty;
                        context.read<StaticDataProvider>().setFilter(query, d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kColorPanel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kColorBorder),
                        ),
                        child: Text(
                          query,
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  )),
              GestureDetector(
                onTap: () =>
                    context.read<AppStateProvider>().clearRecentSearches(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrailList extends StatelessWidget {
  final String collectionFilter;
  final String distanceFilter;
  final VoidCallback onNavigateToMap;

  const _TrailList({
    required this.collectionFilter,
    required this.distanceFilter,
    required this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<StaticDataProvider, AppStateProvider>(
      builder: (context, staticData, appState, __) {
        if (staticData.loading || appState.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: kColorOrange,
              strokeWidth: 2,
            ),
          );
        }

        final visibleTrails = staticData.trails.where((trail) {
          final matchesCollection = switch (collectionFilter) {
            'saved' => appState.favoriteTrailIds.contains(trail.id),
            'done' => appState.completedTrailIds.contains(trail.id),
            _ => true,
          };

          final matchesDistance = switch (distanceFilter) {
            'short' => trail.distanceKm < 5,
            'day' => trail.distanceKm >= 5 && trail.distanceKm <= 12,
            'big' => trail.distanceKm > 12,
            _ => true,
          };

          return matchesCollection && matchesDistance;
        }).toList();

        if (visibleTrails.isEmpty) {
          return Center(
            child: Text(
              'No trails match these filters',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: visibleTrails.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _TrailRow(
            trail: visibleTrails[index],
            index: index,
            onNavigateToMap: onNavigateToMap,
          ),
        );
      },
    );
  }
}

class _TrailRow extends StatelessWidget {
  final Trail trail;
  final int index;
  final VoidCallback onNavigateToMap;

  const _TrailRow({
    required this.trail,
    required this.index,
    required this.onNavigateToMap,
  });

  void _openDetail(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.read<ReviewProvider>().listenTo(trail.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrailDetailScreen(
        trail: trail,
        onNavigateToMap: onNavigateToMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final units = context.watch<UnitsProvider>();
    final isFavorite = appState.isFavorite(trail.id);
    final isCompleted = appState.isCompleted(trail.id);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + math.min(index, 8) * 35),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kColorPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kColorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'trail_name_${trail.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          trail.name,
                          // `decoration: TextDecoration.none` explicitly
                          // overrides the yellow debug underline Flutter
                          // can draw during a Hero flight when the overlay
                          // briefly loses the Material ancestor.
                          style: GoogleFonts.outfit(
                            color: kColorCream,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isFavorite) ...[
                    const Icon(Icons.favorite, color: kColorOrange, size: 14),
                    const SizedBox(width: 6),
                  ],
                  if (isCompleted) ...[
                    const Icon(Icons.check_circle,
                        color: Color(0xFF4CAF50), size: 14),
                    const SizedBox(width: 6),
                  ],
                  DifficultyBadge(trail.difficulty),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                trail.description.isEmpty
                    ? 'Trail details ready for route planning and map review.'
                    : trail.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.45),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(Icons.straighten,
                      units.formatDistance(trail.distanceKm)),
                  const SizedBox(width: 14),
                  _Stat(Icons.trending_up, units.formatElevation(trail.elevationGainM.toDouble())),
                  const SizedBox(width: 14),
                  _Stat(Icons.schedule, trail.formattedTime(1.0)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      unawaited(HapticFeedback.lightImpact());
                      context.read<StaticDataProvider>().selectTrail(trail);
                      await context
                          .read<AppStateProvider>()
                          .addRecentSearch(trail.name);
                      if (!context.mounted) return;
                      onNavigateToMap();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kColorOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: kColorOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined,
                              color: kColorOrange, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Map',
                            style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Stat(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kColorCream.withOpacity(0.3), size: 12),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
