import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../models/trail.dart';
import 'difficulty_badge.dart';

class TrailListItem extends StatelessWidget {
  final Trail trail;
  final bool selected;
  final VoidCallback onTap;

  const TrailListItem({
    super.key,
    required this.trail,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kColorOrange.withOpacity(0.12) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? kColorOrange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trail.name,
                    style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${trail.distanceKm.toStringAsFixed(1)} km · '
                        '+${trail.elevationGainM} m',
                        style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trail.isCave) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF795548).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF795548).withOpacity(0.5)),
                ),
                child: const Text('🕳 Cave', style: TextStyle(fontSize: 9)),
              ),
              const SizedBox(width: 6),
            ],
            DifficultyBadge(trail.difficulty, small: true),
          ],
        ),
      ),
    );
  }
}
