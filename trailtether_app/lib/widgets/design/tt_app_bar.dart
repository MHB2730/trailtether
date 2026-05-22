import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// The TRAILTETHER wordmark block that sits above the page title on every
/// reskinned screen.
class TTBrandMark extends StatelessWidget {
  final double size;
  const TTBrandMark({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _TTLogo(size: 18),
        const SizedBox(width: 9),
        RichText(
          text: TextSpan(
            style: TT.body(size: size, w: FontWeight.w800, color: TT.text)
                .copyWith(letterSpacing: 0.16 * size),
            children: const [
              TextSpan(text: 'TRAIL'),
              TextSpan(text: 'TETHER', style: TextStyle(color: TT.ember)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TTLogo extends StatelessWidget {
  final double size;
  const _TTLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    final p = Path()
      ..moveTo(3 * s, 26 * s)
      ..lineTo(11 * s, 11 * s)
      ..lineTo(17 * s, 19 * s)
      ..lineTo(22 * s, 12 * s)
      ..lineTo(29 * s, 26 * s)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [TT.ember2, TT.ember],
      ).createShader(Offset.zero & size);
    canvas.drawPath(p, paint);
    canvas.drawCircle(
      Offset(22 * s, 7 * s),
      2.6 * s,
      Paint()..color = TT.ember2,
    );
    canvas.drawCircle(
      Offset(22 * s, 7 * s),
      1.0 * s,
      Paint()..color = TT.emberInk,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

/// Page-level app bar matching the design — wordmark + large title with
/// optional avatar/icons on the right.
class TTPageAppBar extends StatelessWidget {
  final String title;
  final List<Widget> trailing;
  final EdgeInsetsGeometry padding;

  const TTPageAppBar({
    super.key,
    required this.title,
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 6),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TTBrandMark(),
                const SizedBox(height: 4),
                Text(title, style: TT.title(24)),
              ],
            ),
          ),
          for (var t in trailing) ...[const SizedBox(width: 8), t],
        ],
      ),
    );
  }
}

/// Square 38×38 icon button with hairline border.
class TTIconBtn extends StatelessWidget {
  final IconData icon;
  final bool ember;
  final VoidCallback? onTap;
  final double size;

  const TTIconBtn({
    super.key,
    required this.icon,
    this.ember = false,
    this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ember ? TT.emberDim : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: ember ? const Color(0x52FF6A2C) : TT.line, width: 1),
        ),
        child: Icon(icon, size: size * 0.45, color: ember ? TT.ember : TT.text2),
      ),
    );
  }
}
