import 'package:flutter/material.dart';
import '../../core/constants.dart';

class StarRatingInput extends StatelessWidget {
  final int value; // 0 = none selected
  final ValueChanged<int> onChanged;

  const StarRatingInput(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () => onChanged(star),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color:
                  star <= value ? kColorOrange : kColorCream.withOpacity(0.25),
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}
