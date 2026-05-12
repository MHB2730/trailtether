import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../models/trail.dart';

class TrailStatsRow extends StatelessWidget {
  final Trail trail;
  final double paceFactor;
  const TrailStatsRow({super.key, required this.trail, this.paceFactor = 1.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('${trail.distanceKm.toStringAsFixed(1)} km', 'Distance'),
        _divider(),
        _stat('+${trail.elevationGainM} m', 'Ascent'),
        _divider(),
        _stat('−${trail.elevationDescentM} m', 'Descent'),
        _divider(),
        _stat('${trail.avgGradePct.toStringAsFixed(1)}%', 'Avg grade'),
        _divider(),
        _stat(trail.formattedTime(paceFactor), 'Est. time'),
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: kColorOrange,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.4),
                fontSize: 8,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: kColorBorder,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}
