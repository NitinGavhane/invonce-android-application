import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Durations and curves used everywhere so motion reads as one system.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);

  /// Spring-like overshoot for pops (chips, check marks, FAB).
  static const spring = Curves.easeOutBack;

  /// Default ease for most transitions.
  static const ease = Curves.easeOutCubic;

  /// Material "emphasized" curve: quick start, long settle.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

abstract final class Haptics {
  static void tap() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
}

/// Shared-axis page transition: the incoming page slides in a touch from the
/// right and fades; the outgoing page dims slightly underneath.
class DaylitTransitionsBuilder extends PageTransitionsBuilder {
  const DaylitTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(curved);
    final fadeIn = Tween<double>(begin: 0, end: 1).animate(curved);
    final dimOut = Tween<double>(begin: 1, end: 0.9).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Motion.ease),
    );
    return FadeTransition(
      opacity: dimOut,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fadeIn, child: child),
      ),
    );
  }
}

/// Fade + rise entrance; give each sibling an increasing [index] to stagger.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final Duration step;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Motion.emphasized);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.step * widget.index).then((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps a list of widgets so they enter one after another.
List<Widget> stagger(List<Widget> children, {int start = 0}) {
  return [
    for (var i = 0; i < children.length; i++)
      FadeSlideIn(index: start + i, child: children[i]),
  ];
}

/// The "paid" moment: a green circle pops in, then the check draws itself.
/// Fires a haptic when the check completes.
class PaidCheck extends StatefulWidget {
  const PaidCheck({super.key, this.size = 66, this.delay = const Duration(milliseconds: 180)});

  final double size;
  final Duration delay;

  @override
  State<PaidCheck> createState() => _PaidCheckState();
}

class _PaidCheckState extends State<PaidCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  late final Animation<double> _circle = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _check = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) Haptics.success();
    });
    Future<void>.delayed(widget.delay).then((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _PaidCheckPainter(scale: _circle.value, progress: _check.value),
      ),
    );
  }
}

class _PaidCheckPainter extends CustomPainter {
  _PaidCheckPainter({required this.scale, required this.progress});

  final double scale;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * scale.clamp(0.0, 1.2);
    canvas.drawCircle(c, r, Paint()..color = Palette.paidBg);

    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.30, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.36);
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      partial,
      Paint()
        ..color = Palette.paidGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PaidCheckPainter old) =>
      old.scale != scale || old.progress != progress;
}

/// Bars that grow up from the baseline when they first appear.
class GrowIn extends StatelessWidget {
  const GrowIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Motion.emphasized,
      builder: (context, t, child) => Align(
        alignment: Alignment.bottomCenter,
        heightFactor: t,
        child: child,
      ),
      child: child,
    );
  }
}
