import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../core/theme.dart';

/// The Sonot petal (traced from the app icon) on a 1024 grid, pointing up.
final Path sonotPetal = Path()
  ..moveTo(512, 512)
  ..cubicTo(500, 440, 457, 322, 440, 262)
  ..arcToPoint(const Offset(584, 262), radius: const Radius.circular(75), largeArc: true, clockwise: true)
  ..cubicTo(567, 322, 524, 440, 512, 512)
  ..close();

/// ThatMaxwell's chunkier petal, on a 1254 grid (centre 627).
final Path maxwellPetal = Path()
  ..moveTo(627, 627)
  ..cubicTo(585, 549, 531, 437, 535, 333)
  ..cubicTo(539, 241, 592, 237, 627, 237)
  ..cubicTo(662, 237, 715, 241, 719, 333)
  ..cubicTo(723, 437, 669, 549, 627, 627)
  ..close();

typedef PetalFn = double Function(int i);

/// Paints the 8-petal bloom into [rect]. Per-petal callbacks let animations
/// fly, fade, scale and push petals outward individually.
void paintBloom(
  Canvas canvas,
  Rect rect, {
  Color color = C.blue,
  double rotation = 0,
  PetalFn? alpha,
  PetalFn? push, // outward offset in grid units
  PetalFn? scale,
  PetalFn? twist, // extra per-petal rotation (radians)
  Color Function(int i)? colorOf,
}) {
  final s = rect.width / 1024;
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(s);
  canvas.translate(512, 512);
  canvas.rotate(rotation);
  for (var i = 0; i < 8; i++) {
    final a = alpha?.call(i) ?? 1;
    if (a <= 0.001) continue;
    canvas.save();
    canvas.rotate(i * math.pi / 4 + (twist?.call(i) ?? 0));
    canvas.translate(0, -(push?.call(i) ?? 0));
    final sc = scale?.call(i) ?? 1;
    canvas.scale(sc);
    canvas.translate(-512, -512);
    final c = colorOf?.call(i) ?? color;
    canvas.drawPath(
      sonotPetal,
      Paint()
        ..color = c.withValues(alpha: c.a * a)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }
  canvas.restore();
}

void paintIconSquare(Canvas canvas, Rect rect, {double t = 1}) {
  if (t <= 0) return;
  final r = rect.width * 268 / 1024;
  final sq = Rect.fromCenter(center: rect.center, width: rect.width * t, height: rect.height * t);
  final rr = RRect.fromRectAndRadius(sq, Radius.circular(r * t));
  canvas.drawRRect(
    rr,
    Paint()..shader = const LinearGradient(begin: Alignment(-0.2, -1), end: Alignment(0.1, 1), colors: [Color(0xFF0B5CFF), Color(0xFF0029C9)]).createShader(sq),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.8),
        radius: 0.9,
        colors: [const Color(0xFFFFFFFF).withValues(alpha: .22), const Color(0x00FFFFFF)],
      ).createShader(sq),
  );
}

class _BloomPainter extends CustomPainter {
  _BloomPainter(this.color, this.rotation, this.icon);
  final Color color;
  final double rotation;
  final bool icon;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (icon) paintIconSquare(canvas, rect);
    paintBloom(canvas, rect, color: icon ? C.white : color, rotation: rotation);
  }

  @override
  bool shouldRepaint(_BloomPainter o) => o.color != color || o.rotation != rotation || o.icon != icon;
}

/// Static Sonot mark (petals only). The mark's petals reach ~68% of the box.
class SonotMark extends StatelessWidget {
  const SonotMark({super.key, this.size = 24, this.color = C.blue, this.rotation = 0});
  final double size;
  final Color color;
  final double rotation;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _BloomPainter(color, rotation, false));
}

/// The app icon: blue rounded square + white petals.
class SonotIcon extends StatelessWidget {
  const SonotIcon({super.key, this.size = 32, this.rotation = 0});
  final double size;
  final double rotation;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _BloomPainter(C.white, rotation, true));
}

class _MaxwellPainter extends CustomPainter {
  _MaxwellPainter(this.color, this.rotation);
  final Color color;
  final double rotation;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1254;
    canvas.scale(s);
    canvas.translate(627, 627);
    canvas.rotate(rotation);
    canvas.translate(-627, -627);
    final p = Paint()..color = color;
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(627, 627);
      canvas.rotate(i * math.pi / 4);
      canvas.translate(-627, -627);
      canvas.drawPath(maxwellPetal, p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MaxwellPainter o) => o.color != color || o.rotation != rotation;
}

/// ThatMaxwell's emblem.
class MaxwellMark extends StatelessWidget {
  const MaxwellMark({super.key, this.size = 40, this.color = C.ink, this.rotation = 0});
  final double size;
  final Color color;
  final double rotation;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MaxwellPainter(color, rotation));
}

/// A bloom that spins forever (used for "thinking" states).
class SpinningMark extends StatefulWidget {
  const SpinningMark({super.key, this.size = 18, this.color = C.blue, this.seconds = 2.4});
  final double size;
  final Color color;
  final double seconds;
  @override
  State<SpinningMark> createState() => _SpinningMarkState();
}

class _SpinningMarkState extends State<SpinningMark> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  )..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => SonotMark(size: widget.size, color: widget.color, rotation: c.value * math.pi * 2),
  );
}
