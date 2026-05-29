import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Animates a number/string in with the design's `count-up` effect:
/// fade + slight rise + blur deblur. Use for stat tiles, hero counters.
///
/// For pure-string values (e.g. "02:34") it animates the entry; for numeric
/// values you can pass [from] to drive a tween from 0 to the value.
class TTCountUp extends StatefulWidget {
  final String text;
  final double? from;
  final double? to;
  final String Function(double v)? formatter;
  final TextStyle style;
  final Duration delay;
  final Duration duration;

  const TTCountUp({
    super.key,
    required this.text,
    required this.style,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
  })  : from = null,
        to = null,
        formatter = null;

  const TTCountUp.number({
    super.key,
    required double this.from,
    required double this.to,
    required this.formatter,
    required this.style,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
  }) : text = '';

  @override
  State<TTCountUp> createState() => _TTCountUpState();
}

class _TTCountUpState extends State<TTCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        final opacity = t.clamp(0.0, 1.0);
        final dy = (1 - t) * 6.0;
        final display = widget.formatter != null
            ? widget.formatter!(widget.from! + (widget.to! - widget.from!) * t)
            : widget.text;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Text(display, style: widget.style),
          ),
        );
      },
    );
  }
}

/// Stagger wrapper — emits each child with `delay + index * step` baseline.
class TTStagger extends StatelessWidget {
  final List<Widget> children;
  final Duration base;
  final Duration step;
  final EdgeInsetsGeometry? padding;
  final double gap;
  final Axis axis;

  const TTStagger({
    super.key,
    required this.children,
    this.base = const Duration(milliseconds: 100),
    this.step = const Duration(milliseconds: 60),
    this.padding,
    this.gap = 10,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final wrapped = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final delay = base + step * i;
      // If the caller wrapped the row item in Expanded/Flexible, we must keep
      // that as the *direct* child of the surrounding Row so its ParentData is
      // honoured. Push the _FadeUp inside instead.
      Widget entry;
      if (child is Expanded) {
        entry = Expanded(
            flex: child.flex, child: _FadeUp(delay: delay, child: child.child));
      } else if (child is Flexible) {
        entry = Flexible(
          flex: child.flex,
          fit: child.fit,
          child: _FadeUp(delay: delay, child: child.child),
        );
      } else {
        entry = _FadeUp(delay: delay, child: child);
      }
      wrapped.add(entry);
      if (i < children.length - 1) {
        wrapped.add(SizedBox(
          width: axis == Axis.horizontal ? gap : 0,
          height: axis == Axis.vertical ? gap : 0,
        ));
      }
    }
    final layout = axis == Axis.vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: wrapped)
        : Row(children: wrapped);
    return padding == null ? layout : Padding(padding: padding!, child: layout);
  }
}

class _FadeUp extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUp({required this.delay, required this.child});

  @override
  State<_FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<_FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = TT.easeOut.transform(_ctl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
