import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

/// The launch flash. Sits over the real first screen, which builds underneath
/// so the hand-off is seamless: the receipt mark springs in, a lemon light
/// sweeps across it (the "flash"), the wordmark rises, then the whole layer
/// dissolves. Removes itself from the tree when done.
///
/// [onFirstFrame] runs once the first Flutter frame is up — `main.dart` uses it
/// to drop the native launch screen so the wine background simply continues.
class LaunchFlash extends StatefulWidget {
  const LaunchFlash({super.key, required this.child, this.onFirstFrame});

  final Widget child;
  final VoidCallback? onFirstFrame;

  static const duration = Duration(milliseconds: 1750);
  static const reducedDuration = Duration(milliseconds: 650);

  @override
  State<LaunchFlash> createState() => _LaunchFlashState();
}

class _LaunchFlashState extends State<LaunchFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: LaunchFlash.duration);
  bool _done = false;

  // Timeline, as fractions of the whole run.
  late final _markScale = Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.32, curve: Motion.spring)));
  late final _markFade = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.22, curve: Motion.ease));
  late final _sweep = CurvedAnimation(parent: _c, curve: const Interval(0.30, 0.60, curve: Curves.easeInOutCubic));
  late final _pulse = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.0), weight: 2),
  ]).animate(CurvedAnimation(parent: _c, curve: const Interval(0.38, 0.56)));
  late final _word = CurvedAnimation(parent: _c, curve: const Interval(0.44, 0.74, curve: Motion.emphasized));
  late final _tag = CurvedAnimation(parent: _c, curve: const Interval(0.56, 0.84, curve: Motion.ease));
  late final _exit = CurvedAnimation(parent: _c, curve: const Interval(0.82, 1.0, curve: Motion.ease));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFirstFrame?.call();
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) _c.duration = LaunchFlash.reducedDuration;
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The real app, settling into place as the flash lifts.
        AnimatedBuilder(
          animation: _exit,
          builder: (_, child) => Transform.scale(scale: 0.985 + 0.015 * _exit.value, child: child),
          child: widget.child,
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => IgnorePointer(
            child: Opacity(
              opacity: 1 - _exit.value,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: ColoredBox(
                  color: Palette.wine,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Soft whole-screen pulse at the moment the light crosses the mark.
                      ColoredBox(color: Palette.lemon.withValues(alpha: _pulse.value)),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: _markFade.value,
                            child: Transform.scale(
                              scale: _markScale.value,
                              child: _Shine(
                                t: _sweep.value,
                                child: const ReceiptMark(size: 104, paper: Palette.lemon, ink: Palette.wine),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Opacity(
                            opacity: _word.value,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - _word.value)),
                              child: Text(
                                'Invonce',
                                style: Fonts.sans(size: 36, weight: FontWeight.w800, tracking: -0.04, color: Palette.white, height: 1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _tag.value,
                            child: Text(
                              'INVOICES THAT GET YOU PAID',
                              style: Fonts.mono(size: 10.5, weight: FontWeight.w600, tracking: 0.12, color: Palette.rose),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A narrow band of light that travels diagonally across [child], painted
/// only where the child has pixels (so it reads as a highlight on the mark,
/// not a stripe over the background).
class _Shine extends StatelessWidget {
  const _Shine({required this.t, required this.child});

  final double t; // 0 → 1 sweeps from bottom-left to top-right
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return child;
    final pos = -1.6 + 3.2 * t;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(pos - 0.9, pos + 0.9),
        end: Alignment(pos + 0.9, pos - 0.9),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(bounds),
      child: child,
    );
  }
}
