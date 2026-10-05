import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/theme.dart';

/* ==========================================================================
   PIN — a section [height] tall whose child (one viewport tall) sticks to the
   screen while you scroll through it. The pin offset is computed at paint
   time, so it never lags the scroll. [progress] goes 0 → 1 across the section.
   ========================================================================== */
class Pin extends SingleChildRenderObjectWidget {
  const Pin({super.key, required this.height, required this.viewport, required this.progress, super.child});
  final double height;
  final double viewport;
  final ValueNotifier<double> progress;

  @override
  RenderPin createRenderObject(BuildContext context) => RenderPin(height, viewport, progress);

  @override
  void updateRenderObject(BuildContext context, RenderPin r) {
    r
      ..total = height
      ..vh = viewport
      ..progress = progress;
  }
}

class RenderPin extends RenderProxyBox {
  RenderPin(this._total, this._vh, this.progress);
  double _total, _vh;
  ValueNotifier<double> progress;
  double _shift = 0;
  bool _scheduled = false;
  double _pending = 0;

  set total(double v) {
    if (v != _total) {
      _total = v;
      markNeedsLayout();
    }
  }

  set vh(double v) {
    if (v != _vh) {
      _vh = v;
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    child?.layout(BoxConstraints.tightFor(width: w, height: _vh), parentUsesSize: false);
    size = constraints.constrain(Size(w, math.max(_total, _vh)));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final top = localToGlobal(Offset.zero).dy;
    final range = size.height - _vh;
    _shift = range <= 0 ? 0 : (-top).clamp(0.0, range);
    final p = range <= 0 ? 0.0 : _shift / range;
    if (p != progress.value) {
      _pending = p;
      if (!_scheduled) {
        _scheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scheduled = false;
          progress.value = _pending;
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      }
    }
    // Only paint when any part of the section is on screen
    if (top > _vh * 1.2 || top + size.height < -_vh * .2) return;
    if (child != null) context.paintChild(child!, offset + Offset(0, _shift));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(0, _shift),
      position: position,
      hitTest: (r, p) => child!.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, _shift, 0, 1);
}

/* ==========================================================================
   PARALLAX — shifts its child by (distance from viewport centre) × factor.
   ========================================================================== */
class Parallax extends SingleChildRenderObjectWidget {
  const Parallax({super.key, this.factor = .15, this.horizontal = false, super.child});
  final double factor;
  final bool horizontal;
  @override
  RenderParallax createRenderObject(BuildContext context) => RenderParallax(factor, horizontal);
  @override
  void updateRenderObject(BuildContext context, RenderParallax r) => r
    ..factor = factor
    ..horizontal = horizontal;
}

class RenderParallax extends RenderProxyBox {
  RenderParallax(this.factor, this.horizontal);
  double factor;
  bool horizontal;
  Offset _d = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final view = RendererBinding.instance.renderViews.first.size;
    final g = localToGlobal(size.center(Offset.zero));
    final d = horizontal ? (view.width / 2 - g.dx) * factor : (view.height / 2 - g.dy) * factor;
    _d = horizontal ? Offset(d, 0) : Offset(0, d);
    if (child != null) context.paintChild(child!, offset + _d);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _d,
      position: position,
      hitTest: (r, p) => child!.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(_d.dx, _d.dy, 0, 1);
}

/* ==========================================================================
   PROBE — reports where it sits on screen after each paint (for reveals).
   ========================================================================== */
class _Probe extends SingleChildRenderObjectWidget {
  const _Probe({required this.onPos, super.child});
  final void Function(double top, double bottom) onPos;
  @override
  _RenderProbe createRenderObject(BuildContext context) => _RenderProbe(onPos);
  @override
  void updateRenderObject(BuildContext context, _RenderProbe r) => r.onPos = onPos;
}

class _RenderProbe extends RenderProxyBox {
  _RenderProbe(this.onPos);
  void Function(double, double) onPos;
  bool _scheduled = false;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_scheduled || !attached) return;
    final top = localToGlobal(Offset.zero).dy;
    final bottom = top + size.height;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      onPos(top, bottom);
    });
  }
}

/// Fades / rises / un-blurs its child the first time it scrolls into view.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = 0, this.dy = 40, this.blur = 8, this.duration = 900, this.scale = 1});
  final Widget child;
  final int delay; // ms
  final double dy, blur, scale;
  final int duration;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.duration),
  );
  bool fired = false;

  void _pos(double top, double bottom) {
    if (fired || !mounted) return;
    final vh = MediaQuery.sizeOf(context).height;
    if (top < vh * .9 && bottom > 0) {
      fired = true;
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) c.forward();
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Probe(
      onPos: _pos,
      child: AnimatedBuilder(
        animation: c,
        child: widget.child,
        builder: (_, child) {
          final v = Curves.easeOutCubic.transform(c.value);
          final b = (1 - v) * widget.blur;
          Widget w = Transform.translate(
            offset: Offset(0, (1 - v) * widget.dy),
            child: Transform.scale(scale: lerpD(widget.scale, 1, v), child: child),
          );
          if (b > .3)
            w = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: b, sigmaY: b),
              child: w,
            );
          return Opacity(opacity: v, child: w);
        },
      ),
    );
  }
}

/* ==========================================================================
   MARQUEE — an endless horizontal band.
   ========================================================================== */
class Marquee extends StatefulWidget {
  const Marquee({super.key, required this.child, this.speed = 60, this.reverse = false});
  final Widget child;
  final double speed; // px per second
  final bool reverse;
  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  final ValueNotifier<double> x = ValueNotifier(0);
  double w = 1;
  Duration last = Duration.zero;
  final GlobalKey k = GlobalKey();

  @override
  void initState() {
    super.initState();
    ticker = createTicker((d) {
      final dt = (d - last).inMicroseconds / 1e6;
      last = d;
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) w = box.size.width;
      x.value = (x.value + dt * widget.speed) % w;
    })..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ValueListenableBuilder<double>(
        valueListenable: x,
        builder: (_, v, _) => OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Transform.translate(
            offset: Offset(widget.reverse ? v - w : -v, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(key: k, child: widget.child),
                widget.child,
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ==========================================================================
   TILT — 3D hover tilt with a moving highlight.
   ========================================================================== */
class Tilt extends StatefulWidget {
  const Tilt({super.key, required this.child, this.max = 8, this.radius = 28, this.glow = C.blue});
  final Widget child;
  final double max, radius;
  final Color glow;
  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> with SingleTickerProviderStateMixin {
  Offset target = Offset.zero, cur = Offset.zero, light = const Offset(.5, .5);
  double hover = 0, hoverT = 0;
  late final Ticker tk;

  @override
  void initState() {
    super.initState();
    tk = createTicker((_) {
      final n = Offset.lerp(cur, target, .14)!;
      final h = lerpD(hover, hoverT, .12);
      if ((n - cur).distance < .0005 && (h - hover).abs() < .001) return;
      setState(() {
        cur = n;
        hover = h;
      });
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox;
        final p = e.localPosition;
        light = Offset(p.dx / box.size.width, p.dy / box.size.height);
        target = Offset(light.dx - .5, light.dy - .5);
        hoverT = 1;
      },
      onExit: (_) {
        target = Offset.zero;
        hoverT = 0;
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0012)
          ..rotateX(-cur.dy * widget.max * math.pi / 180)
          ..rotateY(cur.dx * widget.max * math.pi / 180)
          ..scaleByDouble(1 + hover * .015, 1 + hover * .015, 1, 1),
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: Opacity(
                    opacity: hover,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(light.dx * 2 - 1, light.dy * 2 - 1),
                          radius: .9,
                          colors: [widget.glow.withValues(alpha: .14), widget.glow.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ==========================================================================
   MAGNETIC — child leans toward the cursor.
   ========================================================================== */
class Magnetic extends StatefulWidget {
  const Magnetic({super.key, required this.child, this.strength = .25});
  final Widget child;
  final double strength;
  @override
  State<Magnetic> createState() => _MagneticState();
}

class _MagneticState extends State<Magnetic> {
  Offset o = Offset.zero;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox;
        final c = box.size.center(Offset.zero);
        setState(() => o = (e.localPosition - c) * widget.strength);
      },
      onExit: (_) => setState(() => o = Offset.zero),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: o),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.translate(offset: v, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Pressable with hover state + pointer cursor.
class Press extends StatefulWidget {
  const Press({super.key, required this.builder, this.onTap});
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => h = true),
    onExit: (_) => setState(() => h = false),
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: widget.builder(h)),
  );
}

/// Smooth, eased value of a ValueListenable (lerps toward it every frame).
class Smoothed extends StatefulWidget {
  const Smoothed({super.key, required this.source, required this.builder, this.k = .16});
  final ValueListenable<double> source;
  final Widget Function(BuildContext, double) builder;
  final double k;
  @override
  State<Smoothed> createState() => _SmoothedState();
}

class _SmoothedState extends State<Smoothed> with SingleTickerProviderStateMixin {
  double v = 0;
  late final Ticker tk;
  @override
  void initState() {
    super.initState();
    v = widget.source.value;
    tk = createTicker((_) {
      final n = lerpD(v, widget.source.value, widget.k);
      if ((n - v).abs() < .00005) {
        if (v != widget.source.value) setState(() => v = widget.source.value);
        return;
      }
      setState(() => v = n);
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, v);
}

/// Smooth wheel scrolling (Lenis-style) for mouse users.
class SmoothWheel extends StatefulWidget {
  const SmoothWheel({super.key, required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;
  @override
  State<SmoothWheel> createState() => _SmoothWheelState();
}

class _SmoothWheelState extends State<SmoothWheel> with SingleTickerProviderStateMixin {
  double? target;
  late final Ticker tk;
  @override
  void initState() {
    super.initState();
    tk = createTicker((_) {
      final c = widget.controller;
      if (target == null || !c.hasClients) return;
      final p = c.position.pixels;
      final n = lerpD(p, target!, .12);
      if ((n - target!).abs() < .5) {
        c.jumpTo(target!);
        target = null;
        return;
      }
      c.jumpTo(n);
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (e) {
        if (e is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
          final c = widget.controller;
          if (!c.hasClients) return;
          final pos = c.position;
          target = ((target ?? pos.pixels) + (ev as PointerScrollEvent).scrollDelta.dy).clamp(0.0, pos.maxScrollExtent);
        });
      },
      child: widget.child,
    );
  }
}

/// Calls [onVisible] once, the first time the child scrolls into view.
class OnVisible extends StatefulWidget {
  const OnVisible({super.key, required this.child, required this.onVisible, this.at = .8});
  final Widget child;
  final VoidCallback onVisible;
  final double at; // fraction of viewport height
  @override
  State<OnVisible> createState() => _OnVisibleState();
}

class _OnVisibleState extends State<OnVisible> {
  bool fired = false;
  @override
  Widget build(BuildContext context) => _Probe(
    onPos: (top, bottom) {
      if (fired || !mounted) return;
      if (top < MediaQuery.sizeOf(context).height * widget.at && bottom > 0) {
        fired = true;
        widget.onVisible();
      }
    },
    child: widget.child,
  );
}
