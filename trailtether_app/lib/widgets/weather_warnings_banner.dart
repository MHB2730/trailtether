// Weather warnings banner.
//
// Renders the top 1-2 derived warnings from `WeatherProvider.warnings`
// as compact severity-coloured cards. Auto-hides when the list is
// empty so calm forecasts add zero chrome to the screen.
//
// Severity → colour mapping (via `WeatherWarning.color`):
//   watch    → amber
//   warning  → ember
//   severe   → red
//
// Tap a card to expand into a full bottom-sheet listing every active
// warning so the user can scan a full multi-day picture before
// committing to a hike.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/weather_warning.dart';
import '../providers/weather_provider.dart';

class WeatherWarningsBanner extends StatelessWidget {
  /// Horizontal padding for the banner itself. Match the surrounding
  /// screen's gutter so the cards align with the other Home blocks.
  final EdgeInsetsGeometry padding;
  final int maxVisible;

  const WeatherWarningsBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 0),
    this.maxVisible = 2,
  });

  @override
  Widget build(BuildContext context) {
    // Selector keeps this widget cheap — only rebuilds when the warnings
    // *list identity* changes (which only happens when the weather data
    // itself swaps), not on every WeatherProvider notify.
    return Selector<WeatherProvider, List<WeatherWarning>>(
      selector: (_, w) => w.warnings,
      shouldRebuild: (a, b) {
        if (a.length != b.length) return true;
        for (var i = 0; i < a.length; i++) {
          if (a[i].kind != b[i].kind ||
              a[i].severity != b[i].severity ||
              a[i].day != b[i].day) {
            return true;
          }
        }
        return false;
      },
      builder: (_, warnings, __) {
        if (warnings.isEmpty) return const SizedBox.shrink();
        final visible = warnings.take(maxVisible).toList();
        final hiddenCount = warnings.length - visible.length;
        return Padding(
          padding: padding,
          child: Column(
            children: [
              for (final w in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WarningCard(
                    warning: w,
                    onTap: () => _showAll(context, warnings),
                  ),
                ),
              if (hiddenCount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => _showAll(context, warnings),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+ $hiddenCount more — tap to view',
                        style: TT.mono(
                            size: 10.5,
                            color: TT.text3,
                            letterSpacing: 0.08 * 10.5),
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

  void _showAll(BuildContext context, List<WeatherWarning> all) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WarningsSheet(warnings: all),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final WeatherWarning warning;
  final VoidCallback onTap;
  const _WarningCard({required this.warning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = warning.color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          border: Border.all(color: c.withOpacity(0.55), width: 1),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withOpacity(0.18),
                border: Border.all(color: c.withOpacity(0.55), width: 1),
              ),
              child: Icon(warning.icon, size: 16, color: c),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.headline,
                    style: TT.body(size: 13, w: FontWeight.w800, color: TT.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    warning.body,
                    style: TT.body(size: 11, color: TT.text2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _DayBadge(day: warning.day, color: c),
          ],
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final DateTime? day;
  final Color color;
  const _DayBadge({required this.day, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = _dayLabel(day);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TT.mono(size: 9.5, color: color, letterSpacing: 0.12 * 9.5)
            .copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  static String _dayLabel(DateTime? d) {
    if (d == null) return 'NOW';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TMRW';
    if (diff > 1 && diff <= 6) {
      const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return names[d.weekday - 1];
    }
    return '+${diff}D';
  }
}

// ── Bottom sheet: full warning list ─────────────────────────────────────────

class _WarningsSheet extends StatelessWidget {
  final List<WeatherWarning> warnings;
  const _WarningsSheet({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: TT.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: TT.line2, width: 1),
          ),
        ),
        child: Column(
          children: [
            // Grab handle.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: TT.ember, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Weather warnings',
                    style: TT.title(18, letterSpacing: -0.01 * 18),
                  ),
                  const Spacer(),
                  Text(
                    '${warnings.length}',
                    style: TT.mono(
                        size: 12,
                        color: TT.text3,
                        letterSpacing: 0.1 * 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemCount: warnings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final w = warnings[i];
                  return _WarningCard(
                    warning: w,
                    onTap: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
