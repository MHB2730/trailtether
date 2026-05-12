import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/review.dart';

class ReviewCard extends StatelessWidget {
  final Review review;
  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < review.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < review.rating
                              ? kColorOrange
                              : kColorCream.withOpacity(0.2),
                          size: 16,
                        )),
              ),
              const Spacer(),
              if (review.condition.isNotEmpty) _conditionChip(review.condition),
              const SizedBox(width: 8),
              Text(
                DateFormat('d MMM yyyy').format(review.createdAt),
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.35),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.text,
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _conditionChip(String condition) {
    final Color color;
    switch (condition) {
      case 'good':
        color = const Color(0xFF4CAF50);
        break;
      case 'fair':
        color = const Color(0xFFFFC107);
        break;
      case 'poor':
        color = const Color(0xFFE53935);
        break;
      default:
        color = kColorCream;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        condition[0].toUpperCase() + condition.substring(1),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
