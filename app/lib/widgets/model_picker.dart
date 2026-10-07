import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'glass.dart';

/// The small "Somedin · Medium" chip in the composer.
class ModelChip extends StatelessWidget {
  const ModelChip({super.key, required this.tier, required this.effort, required this.palette, required this.onTap});
  final Tier tier;
  final Effort effort;
  final Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final short = tier.name.replaceFirst('Sonot ', '');
    return Tooltip(
      message: '${tier.name}, ${effort.label.toLowerCase()} effort',
      child: Material(
        type: MaterialType.transparency,
        shape: StadiumBorder(side: BorderSide(color: p.edge, width: .7)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  short,
                  style: sans(13.5, c: p.text, w: FontWeight.w600, h: 1),
                ),
                const SizedBox(width: 7),
                EffortBars(level: effort.index, color: p.accent, track: p.textSoft.withValues(alpha: .3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four little rising bars, filled up to [level]. Reads at a glance.
class EffortBars extends StatelessWidget {
  const EffortBars({super.key, required this.level, required this.color, required this.track, this.height = 12});
  final int level;
  final Color color, track;
  final double height;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < Effort.values.length; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
          width: 3,
          height: height * (.4 + .2 * i),
          decoration: BoxDecoration(color: i <= level ? color : track, borderRadius: BorderRadius.circular(2)),
        ),
    ],
  );
}

Future<void> showModelPicker({
  required BuildContext context,
  required Palette palette,
  required Tier tier,
  required Effort effort,
  required void Function(Tier, Effort) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: .25),
    builder: (ctx) => _Picker(palette: palette, tier: tier, effort: effort, onChanged: onChanged),
  );
}

class _Picker extends StatefulWidget {
  const _Picker({required this.palette, required this.tier, required this.effort, required this.onChanged});
  final Palette palette;
  final Tier tier;
  final Effort effort;
  final void Function(Tier, Effort) onChanged;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> with SingleTickerProviderStateMixin {
  late Tier _tier = widget.tier;
  late Effort _effort = widget.effort;
  late final _max = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));

  static bool _maxed(Tier t, Effort e) => t.id == 'anthem' && e == Effort.max;

  @override
  void dispose() {
    _max.dispose();
    super.dispose();
  }

  /// Anthem on Max: one firm haptic, then a single line of light runs the
  /// effort track and once around the panel's edge while the panel settles.
  void _engageMax() {
    HapticFeedback.heavyImpact();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _max.forward(from: 0);
  }

  void _set({Tier? tier, Effort? effort}) {
    final t = tier ?? _tier;
    // Keep the effort the user chose when the new tier allows it, else the nearest stop.
    final e = t.clamp(effort ?? _effort);
    if (t == _tier && e == _effort) return;
    final engage = _maxed(t, e) && !_maxed(_tier, _effort);
    if (!engage) HapticFeedback.selectionClick();
    setState(() {
      _tier = t;
      _effort = e;
    });
    widget.onChanged(_tier, _effort);
    if (engage) _engageMax();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(context).bottom + 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _Settle(
            animation: _max,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Glass(
                  radius: 30,
                  blur: 30,
                  fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .6)),
                  edge: p.edge,
                  padding: const EdgeInsets.fromLTRB(10, 18, 10, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Model', p),
                      for (final t in tiers) _tierRow(t, p),
                      const SizedBox(height: 14),
                      _label('Effort', p),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _EffortSlider(
                          value: _effort,
                          allowed: _tier.efforts,
                          palette: p,
                          sweep: _max,
                          onChanged: (e) => _set(effort: e),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _EdgeLight(_max, radius: 30))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Palette p) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: Text(
      text.toUpperCase(),
      style: mono(11.5, c: p.textSoft, w: FontWeight.w500),
    ),
  );

  Widget _tierRow(Tier t, Palette p) {
    final on = t == _tier;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _set(tier: t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: ShapeDecoration(
            color: on ? p.text.withValues(alpha: .06) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: on ? p.edge : Colors.transparent, width: .7),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: sans(16, c: p.text, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.blurb,
                      style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(Icons.check_rounded, color: p.accent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A four-stop slider: drag or tap anywhere on the track.
class _EffortSlider extends StatelessWidget {
  const _EffortSlider({
    required this.value,
    required this.allowed,
    required this.palette,
    required this.sweep,
    required this.onChanged,
  });
  final Effort value;
  final Set<Effort> allowed;
  final Palette palette;

  /// Runs 0 → 1 when Max is engaged; draws the light across the track.
  final Animation<double> sweep;
  final ValueChanged<Effort> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final n = Effort.values.length;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        void pick(double dx) => onChanged(Effort.values[((dx / w) * (n - 1)).round().clamp(0, n - 1)]);
        final x = w * value.index / (n - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
              child: SizedBox(
                height: 36,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(color: p.text.withValues(alpha: .08), borderRadius: BorderRadius.circular(3)),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: x.clamp(6, w),
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [p.accent.withValues(alpha: .55), p.accent]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      width: x.clamp(6, w),
                      height: 6,
                      child: _TrackLight(animation: sweep),
                    ),
                    for (var i = 0; i < n; i++)
                      Positioned(
                        left: w * i / (n - 1) - 2,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= value.index
                                ? p.onAccent.withValues(alpha: .8)
                                : p.textSoft.withValues(alpha: allowed.contains(Effort.values[i]) ? .6 : .18),
                          ),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: x - 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: p.accent, width: 2),
                          boxShadow: [BoxShadow(color: p.accent.withValues(alpha: .35), blurRadius: 12)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final e in Effort.values)
                  GestureDetector(
                    onTap: () => onChanged(e),
                    child: Text(
                      e.label,
                      style: sans(
                        12.5,
                        c: e == value ? p.text : p.textSoft.withValues(alpha: allowed.contains(e) ? 1 : .4),
                        w: e == value ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value.blurb,
              style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            if (allowed.length < Effort.values.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Dimmed stops aren\'t available on this model.',
                  style: sans(12, c: p.textSoft.withValues(alpha: .7), w: FontWeight.w400),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Anthem on Max, part 1: the panel settles back a hair (≈0.8 %) and returns,
/// like a precise mechanism locking in.
class _Settle extends AnimatedWidget {
  const _Settle({required Animation<double> animation, required this.child}) : super(listenable: animation);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final dip = t <= 0 || t >= 1 ? 0.0 : math.sin(math.pi * Curves.easeOutCubic.transform((t / .42).clamp(0, 1)));
    return Transform.scale(scale: 1 - .008 * dip, child: child);
  }
}

/// Anthem on Max, part 2: a narrow band of white light crosses the filled
/// effort track, left to right.
class _TrackLight extends AnimatedWidget {
  const _TrackLight({required Animation<double> animation}) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final k = (t / .5).clamp(0.0, 1.0);
    if (k <= 0 || k >= 1) return const SizedBox.shrink();
    final c = Curves.easeInOutCubic.transform(k);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LayoutBuilder(
        builder: (context, box) {
          const band = 56.0;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -band + (box.maxWidth + band) * c,
                width: band,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: .9),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Anthem on Max, part 3: a single hairline of light travels once around the
/// panel's edge (from the effort slider, clockwise), with a soft tail, while
/// the whole edge brightens slightly and settles back.
class _EdgeLight extends CustomPainter {
  _EdgeLight(this.animation, {required this.radius}) : super(repaint: animation);
  final Animation<double> animation;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(.35);
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    final len = metric.length;

    // Whole edge: a quiet lift and release.
    final lift = math.sin(math.pi * t) * .22;
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = Colors.white.withValues(alpha: lift),
    );

    // The travelling light picks up where the track light ends (the Max
    // thumb, bottom right) and runs one lap.
    final k = ((t - .34) / .62).clamp(0.0, 1.0);
    if (k <= 0) return;
    final run = Curves.easeInOutCubic.transform(k);
    final fade = k < .82 ? 1.0 : 1 - (k - .82) / .18;
    final head = (_offsetNear(metric, Offset(size.width - radius, size.height)) + run * len) % len;
    final tail = len * .24;
    const steps = 28;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < steps; i++) {
      final a = i / steps, b = (i + 1) / steps;
      var from = head - tail * (1 - a), to = head - tail * (1 - b);
      from = (from + len) % len;
      to = (to + len) % len;
      paint
        ..strokeWidth = .6 + 1.2 * b
        ..color = Colors.white.withValues(alpha: (b * b) * .95 * fade);
      if (to >= from) {
        canvas.drawPath(metric.extractPath(from, to), paint);
      } else {
        canvas.drawPath(metric.extractPath(from, len), paint);
        canvas.drawPath(metric.extractPath(0, to), paint);
      }
    }
  }

  /// Distance along [metric] of the point closest to [target].
  static double _offsetNear(PathMetric metric, Offset target) {
    var best = 0.0, bestD = double.infinity;
    for (var i = 0; i < 96; i++) {
      final d = metric.length * i / 96;
      final pos = metric.getTangentForOffset(d)!.position;
      final dist = (pos - target).distanceSquared;
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    return best;
  }

  @override
  bool shouldRepaint(_EdgeLight old) => false;
}
