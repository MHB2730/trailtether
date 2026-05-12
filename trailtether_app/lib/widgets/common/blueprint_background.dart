import 'package:flutter/material.dart';
import '../../core/constants.dart';

class BlueprintBackground extends StatelessWidget {
  final Widget? child;
  final bool showGrid;

  const BlueprintBackground({super.key, this.child, this.showGrid = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: kColorBg),
        if (showGrid)
          CustomPaint(
            painter: _GridPainter(),
          ),
        if (child != null) child!,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kColorCream.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const spacing = 30.0;
    const dotRadius = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
