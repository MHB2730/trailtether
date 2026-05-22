import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Segmented tabs with a sliding ember indicator — matches the `.segmented`
/// control in stats.jsx. Animates indicator position when the active index
/// changes.
class TTSegmented extends StatefulWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onChange;

  const TTSegmented({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChange,
  });

  @override
  State<TTSegmented> createState() => _TTSegmentedState();
}

class _TTSegmentedState extends State<TTSegmented> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final innerW = c.maxWidth - 8; // 4px padding on each side
      final segW = innerW / widget.tabs.length;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: TT.dMed,
              curve: TT.easeOut,
              left: widget.active * segW,
              top: 0,
              bottom: 0,
              width: segW,
              child: Container(
                decoration: BoxDecoration(
                  color: TT.emberDim,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0x52FF6A2C), width: 1),
                  boxShadow: const [BoxShadow(color: Color(0x2EFF6A2C), blurRadius: 12, spreadRadius: -4)],
                ),
              ),
            ),
            Row(
              children: List.generate(widget.tabs.length, (i) {
                final active = i == widget.active;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onChange(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                      child: AnimatedDefaultTextStyle(
                        duration: TT.dMed,
                        style: TT.body(
                          size: 12,
                          color: active ? TT.ember : TT.text3,
                          w: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(widget.tabs[i], textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    });
  }
}
