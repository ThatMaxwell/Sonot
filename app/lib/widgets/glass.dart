import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Frosted glass: a backdrop blur, a faint fill and a hairline white edge.
///
/// Blurs share one backdrop pass when they sit under a [BackdropGroup]
/// (the chat and setup screens add one), which keeps scrolling smooth even
/// with several glass pieces on screen.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 22,
    this.fill = const Color(0x1FFFFFFF),
    this.edge = const Color(0x40FFFFFF),
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color fill;
  final Color edge;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: edge, width: .7),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // A touch brighter at the top-left, like light catching glass.
              colors: [Color.alphaBlend(const Color(0x0FFFFFFF), fill), fill],
            ),
          ),
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// A round glass button for icons.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
    required this.fill,
    required this.edge,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color, fill, edge;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Glass(
      radius: size / 2,
      fill: fill,
      edge: edge,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: size, child: Icon(icon, size: size * .45, color: color)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Soft colour blobs behind the glass so the blur has something to bend.
/// Painted once and cached by a [RepaintBoundary].
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.base, required this.blobs});
  final Color base;
  final List<Color> blobs;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _BackdropPainter(base, blobs), size: Size.infinite),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.base, this.blobs);
  final Color base;
  final List<Color> blobs;

  static const _spots = [Alignment(-1.1, -0.85), Alignment(1.15, -0.2), Alignment(-0.6, 1.1), Alignment(0.9, 0.95)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final r = size.shortestSide * .75;
    for (var i = 0; i < blobs.length && i < _spots.length; i++) {
      final c = _spots[i].alongSize(size);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [blobs[i], blobs[i].withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter o) => o.base != base || !listEquals(o.blobs, blobs);
}
