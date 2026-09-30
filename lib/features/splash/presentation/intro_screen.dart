import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/doji_haptics.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/doji_app_icon.dart';
import '../../../core/widgets/doji_wordmark.dart';
import '../domain/launch_destination.dart';

/// The first Flutter screen (~1.5s), after the static native splash.
///
/// Keyframes from design/handoff/Doji Onboarding.dc.html › Splash:
/// - K1 0–250ms     candle rises (green), spring(260, 18)
/// - K2 250–550ms   wiggles down: tilt-orange, drops, recovers green
/// - K3 550–800ms   perfect doji: body → 5px bar, white; light haptic on settle
/// - K4 800–1250ms  lands as the "i"; `_` blinks twice (2×120ms); d-o-j types
///                  at 60ms/char with a selection tick each
/// - K5 1250–1500ms wordmark glides to the header: the route transition
///                  (WordmarkHero), so it is shared-element, not faked
///
/// Reduce motion: the S0 icon cross-fades to the destination in 200ms, no
/// candle, no typing, one light haptic.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: DojiMotion.introBeforeGlide);
  final _candleKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _fired = <String>{};
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(DojiBrandAssets.precache());
    _t.addListener(_haptics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    final haptics = ref.read(hapticsProvider);
    if (DojiMotion.reduced(context)) {
      unawaited(haptics.light());
      _finish();
      return;
    }
    await _t.forward();
    _finish();
  }

  void _finish() {
    if (!mounted) return;
    context.go(ref.read(launchRouteProvider));
  }

  /// Haptic points from the handoff table.
  void _haptics() {
    final ms = _t.value * DojiMotion.introBeforeGlide.inMilliseconds;
    final h = ref.read(hapticsProvider);
    void once(String id, double at, Future<void> Function() f) {
      if (ms >= at && _fired.add(id)) unawaited(f());
    }

    once('settle', 760, h.light);
    once('d', _Timeline.typeStart, h.tick);
    once('o', _Timeline.typeStart + 60, h.tick);
    once('j', _Timeline.typeStart + 120, h.tick);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DojiMotion.reduced(context);
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: Semantics(
        label: 'doji',
        child: reduced
            ? const Center(child: DojiAppIcon())
            : AnimatedBuilder(
                animation: _t,
                builder: (context, _) {
                  final ms = _t.value * DojiMotion.introBeforeGlide.inMilliseconds;
                  final tl = _Timeline(ms);
                  return Stack(
                    key: _stackKey,
                    children: [
                      // Continuity with the native splash: S0 icon, gone by 150ms.
                      if (ms < 150)
                        Center(
                          child: Opacity(opacity: 1 - ms / 150, child: const DojiAppIcon()),
                        ),
                      Center(
                        child: WordmarkHero(
                          child: DojiWordmark(
                            size: 72,
                            typedChars: tl.typedChars,
                            cursorVisible: tl.cursorVisible,
                            showCandle: tl.morphDone,
                            candleKey: _candleKey,
                          ),
                        ),
                      ),
                      if (!tl.morphDone)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CandlePainter(timeline: tl, target: _iRect()),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  /// Where the wordmark's candle-i sits, in this screen's coordinates.
  Rect? _iRect() {
    final i = _candleKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (i == null || stack == null || !i.hasSize) return null;
    final origin = i.localToGlobal(Offset.zero, ancestor: stack);
    return origin & i.size;
  }
}

/// Pure keyframe maths so the painter and the wordmark agree on time.
class _Timeline {
  _Timeline(this.ms);

  final double ms;

  static const morphStart = 800.0;
  static const morphEnd = 880.0;
  static const blinkEnd = morphEnd + 240; // two 120ms blinks
  static const typeStart = blinkEnd;

  bool get morphDone => ms >= morphEnd;

  /// 0–1 through the candle → "i" morph.
  double get morph => ((ms - morphStart) / (morphEnd - morphStart)).clamp(0, 1);

  int get typedChars => ms < typeStart ? 0 : (((ms - typeStart) / 60).floor() + 1).clamp(0, 3);

  bool get cursorVisible {
    if (ms < morphEnd) return false;
    if (ms < blinkEnd) return ((ms - morphEnd) % 120) < 60; // on 60, off 60, twice
    return true; // solid while typing; the header cursor takes over after
  }

  double _seg(double a, double b, Curve c) => c.transform(((ms - a) / (b - a)).clamp(0, 1));

  /// Candle body: vertical offset from centre, height, width, colour.
  ({double dy, double h, double w, Color color}) get body {
    const green = DojiColors.dojiGreen, orange = DojiColors.tiltOrange, white = DojiColors.textPrimary;
    if (ms < 250) {
      final k = _seg(0, 250, DojiMotion.k1);
      return (dy: lerpDouble(0, -24, k)!, h: lerpDouble(0, 120, k)!, w: 36, color: green);
    }
    if (ms < 400) {
      final k = _seg(250, 400, DojiMotion.k2);
      return (dy: lerpDouble(-24, 20, k)!, h: lerpDouble(120, 84, k)!, w: 36, color: orange);
    }
    if (ms < 550) {
      final k = _seg(400, 550, DojiMotion.k2);
      final c = Color.lerp(orange, green, (k * 2.5).clamp(0, 1))!;
      return (dy: lerpDouble(20, -8, k)!, h: lerpDouble(84, 52, k)!, w: 36, color: c);
    }
    final k = _seg(550, 800, DojiMotion.k3);
    return (
      dy: lerpDouble(-8, 0, k)!,
      h: lerpDouble(52, 5, k)!,
      w: lerpDouble(36, 60, k)!,
      color: Color.lerp(green, white, k.clamp(0, 1))!,
    );
  }

  double get wickH {
    if (ms < 250) return lerpDouble(0, 210, _seg(0, 250, DojiMotion.k1))!;
    if (ms < 550) return lerpDouble(210, 180, _seg(250, 550, DojiMotion.k2))!;
    return lerpDouble(180, 150, _seg(550, 800, DojiMotion.k3))!;
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({required this.timeline, required this.target});

  final _Timeline timeline;

  /// The wordmark's i box; the doji morphs onto it from 800 to 880ms.
  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final b = timeline.body;
    var wick = Rect.fromCenter(center: c, width: 4, height: timeline.wickH);
    var bar = Rect.fromCenter(center: c.translate(0, b.dy), width: b.w, height: b.h);
    var wickR = 2.0, barR = 3.0;

    final m = Curves.easeInOutCubic.transform(timeline.morph);
    if (m > 0 && target != null) {
      final em = target!.height / 0.74;
      final toWick = Rect.fromLTWH(target!.center.dx - 0.06 * em, target!.top, 0.12 * em, target!.height);
      final toBar = Rect.fromLTRB(
        target!.left + 0.1 * em,
        target!.center.dy,
        target!.right - 0.1 * em,
        target!.center.dy + 0.11 * em,
      );
      wick = Rect.lerp(wick, toWick, m)!;
      bar = Rect.lerp(bar, toBar, m)!;
      wickR = lerpDouble(2, em / 36, m)!;
      barR = lerpDouble(3, em / 36, m)!;
    }

    // The wick stays white (as in the handoff CSS); only the body carries
    // green / orange until it settles white.
    canvas.drawRRect(
      RRect.fromRectAndRadius(wick, Radius.circular(wickR)),
      Paint()..color = DojiColors.textPrimary,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(bar, Radius.circular(barR)), Paint()..color = b.color);
  }

  @override
  bool shouldRepaint(_CandlePainter old) => old.timeline.ms != timeline.ms || old.target != target;
}
