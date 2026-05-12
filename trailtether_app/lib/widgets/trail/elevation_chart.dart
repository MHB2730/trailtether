import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/trail.dart';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class ElevationChart extends StatelessWidget {
  final List<ElevationPoint> profile;
  final double distanceKm;
  final int minEle;
  final int maxEle;
  final ValueChanged<double>? onCursorChanged;
  final Color color;

  const ElevationChart({
    super.key,
    required this.profile,
    required this.distanceKm,
    required this.minEle,
    required this.maxEle,
    this.onCursorChanged,
    this.color = kColorOrange,
  });

  /// Factory for creating from a Trail model
  factory ElevationChart.fromTrail({
    Key? key,
    required Trail trail,
    void Function(TrailCoord?)? onCursorChanged,
  }) {
    return ElevationChart(
      key: key,
      profile: trail.profile,
      distanceKm: trail.distanceKm,
      minEle: trail.minEle,
      maxEle: trail.maxEle,
      onCursorChanged: onCursorChanged == null
          ? null
          : (dist) => onCursorChanged(trail.coordAtDistanceKm(dist)),
    );
  }

  factory ElevationChart.fromPoints({
    Key? key,
    required List<LatLng> points,
    required List<double> elevations,
    required Color color,
  }) {
    if (points.isEmpty) {
      return ElevationChart(
          profile: const [],
          distanceKm: 0,
          minEle: 0,
          maxEle: 100,
          color: color);
    }

    final double distTotal =
        points.length * 0.01; // Rough estimate if no dist provided
    return ElevationChart(
      key: key,
      profile: List.generate(points.length, (i) {
        final ele = (i < elevations.length)
            ? elevations[i]
            : (elevations.isNotEmpty ? elevations.last : 0.0);
        return ElevationPoint(
          (i / math.max(1, points.length - 1)) * distTotal,
          ele,
        );
      }),
      distanceKm: distTotal,
      minEle: elevations.isEmpty ? 0 : elevations.reduce(math.min).toInt(),
      maxEle: elevations.isEmpty ? 100 : elevations.reduce(math.max).toInt(),
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) return const SizedBox.shrink();

    final spots = profile
        .map((p) => FlSpot(p.distanceKm, p.elevationM.toDouble()))
        .toList();

    final minY = (minEle * 0.995).floorToDouble();
    final maxY =
        (maxEle * 1.005).ceilToDouble().clamp(minY + 10, double.infinity);

    final rawInterval = (maxY - minY) / 4;
    final yInterval = (rawInterval / 50).ceilToDouble() * 50;

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: kColorBorder,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: yInterval,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}m',
                  style: TextStyle(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval:
                    (distanceKm / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) => Text(
                  '${v.toStringAsFixed(0)}km',
                  style: TextStyle(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (onCursorChanged == null) return;
              final touched = response?.lineBarSpots;
              if (!event.isInterestedForInteractions ||
                  touched == null ||
                  touched.isEmpty) {
                return;
              }
              onCursorChanged!(touched.first.x);
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => kColorPanel,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()} m\n${s.x.toStringAsFixed(1)} km',
                        TextStyle(color: color, fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.15, // Sharper, more technical look
              color: color,
              barWidth: 2.0,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.35),
                    color.withOpacity(0.01),
                  ],
                ),
              ),
              shadow: Shadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
