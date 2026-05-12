import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../models/review.dart';

class ReviewSummaryBar extends StatelessWidget {
  final ReviewSummary summary;
  const ReviewSummaryBar({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.count == 0) {
      return Text(
        'No reviews yet — be the first!',
        style: GoogleFonts.outfit(
          color: kColorCream.withOpacity(0.4),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Row(
      children: [
        Text(
          summary.averageRating.toStringAsFixed(1),
          style: GoogleFonts.outfit(
            color: kColorOrange,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                        i < summary.averageRating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: kColorOrange,
                        size: 16,
                      )),
            ),
            Text(
              '${summary.count} review${summary.count != 1 ? "s" : ""}',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
