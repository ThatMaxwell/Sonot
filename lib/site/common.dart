import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../core/bridge.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/motion.dart';

final ValueNotifier<String?> toast = ValueNotifier(null);
int _toastSeq = 0;
void showToast(String msg) {
  toast.value = msg;
  final id = ++_toastSeq;
  Future.delayed(const Duration(milliseconds: 3200), () {
    if (_toastSeq == id) toast.value = null;
  });
}

final String userOS = Browser.detectOS();

void download(String os) {
  final url = SonotConfig.downloads[os] ?? '';
  if (url.isNotEmpty) {
    Browser.open(url);
  } else {
    showToast(t('dl.soon').replaceAll('{os}', osNames[os]!));
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = C.blue, this.center = false});
  final String text;
  final Color color;
  final bool center;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Text(text.toUpperCase(), style: mono(12, c: color, ls: .22)),
    ],
  );
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.size, this.color = C.ink, this.accentColor, this.align = TextAlign.start});
  final String text;
  final double? size;
  final Color color;
  final Color? accentColor;
  final TextAlign align;
  @override
  Widget build(BuildContext context) {
    final fs = size ?? math.min(math.max(context.vw * 6, 38), 84);
    return Text.rich(
      TextSpan(
        children: accent(
          text,
          sans(fs, w: FontWeight.w700, c: color, ls: -.045, h: 1.02),
          accentColor: accentColor,
        ),
      ),
      textAlign: align,
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.eyebrow, required this.title, this.sub, this.center = false, this.dark = false});
  final String eyebrow, title;
  final String? sub;
  final bool center, dark;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      Reveal(child: Eyebrow(eyebrow, color: dark ? C.blueSoft : C.blue)),
      const SizedBox(height: 18),
      Reveal(
        delay: 80,
        child: Heading(title, color: dark ? C.white : C.ink, accentColor: dark ? C.blueSoft : C.blue, align: center ? TextAlign.center : TextAlign.start),
      ),
      if (sub != null) ...[
        const SizedBox(height: 18),
        Reveal(
          delay: 160,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              sub!,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: sans(math.min(19, math.max(16, context.vw * 1.4)), c: dark ? C.white.withValues(alpha: .7) : C.mute, h: 1.5, w: FontWeight.w400),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Primary / ghost / white pill buttons with hover shine + magnetic lean.
class Btn extends StatelessWidget {
  const Btn({super.key, required this.label, this.onTap, this.icon, this.kind = 'primary', this.big = false, this.trailing});
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final Widget? trailing;
  final String kind; // primary | ghost | white | dark
  final bool big;

  @override
  Widget build(BuildContext context) {
    final h = big ? 60.0 : 50.0;
    return Magnetic(
      strength: .18,
      child: Press(
        onTap: onTap,
        builder: (hover) {
          final (bg, fg, border) = switch (kind) {
            'ghost' => (hover ? C.mist : C.white, C.ink, C.line),
            'white' => (C.white, C.blue, C.white),
            'dark' => (hover ? C.ink2 : C.ink, C.white, C.ink),
            _ => (hover ? const Color(0xFF2A70FF) : C.blue, C.white, C.blue),
          };
          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: h,
            padding: EdgeInsets.symmetric(horizontal: big ? 30 : 22),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(h),
              border: Border.all(color: border, width: 1.2),
              boxShadow: [
                if (kind == 'primary')
                  BoxShadow(
                    color: C.blue.withValues(alpha: hover ? .5 : .32),
                    blurRadius: hover ? 34 : 22,
                    offset: const Offset(0, 10),
                  ),
                if (kind == 'white')
                  BoxShadow(
                    color: C.ink.withValues(alpha: hover ? .25 : .12),
                    blurRadius: hover ? 34 : 20,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: fg),
                    child: icon!,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: sans(big ? 18 : 15.5, w: FontWeight.w600, c: fg, ls: -.01),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Simple vector platform glyphs (drawn, so no icon font needed).
class OsGlyph extends StatelessWidget {
  const OsGlyph(this.os, {super.key, this.size = 20, this.color});
  final String os;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? C.ink;
    return CustomPaint(size: Size.square(size), painter: _OsPainter(os, c));
  }
}

class _OsPainter extends CustomPainter {
  _OsPainter(this.os, this.c);
  final String os;
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 24;
    canvas.scale(u);
    final stroke = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = c;
    switch (os) {
      case 'win':
        canvas.drawPath(Path()..addPolygon(const [Offset(3, 5.6), Offset(10.4, 4.5), Offset(10.4, 11.5), Offset(3, 11.5)], true), fill);
        canvas.drawPath(Path()..addPolygon(const [Offset(11.6, 4.3), Offset(21, 3), Offset(21, 11.5), Offset(11.6, 11.5)], true), fill);
        canvas.drawPath(Path()..addPolygon(const [Offset(3, 12.6), Offset(10.4, 12.6), Offset(10.4, 19.6), Offset(3, 18.4)], true), fill);
        canvas.drawPath(Path()..addPolygon(const [Offset(11.6, 12.6), Offset(21, 12.6), Offset(21, 21), Offset(11.6, 19.7)], true), fill);
      case 'linux':
        canvas.drawRRect(RRect.fromLTRBR(3, 4, 21, 20, const Radius.circular(2.6)), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(7, 9.5)
            ..lineTo(10, 12)
            ..lineTo(7, 14.5),
          stroke,
        );
        canvas.drawLine(const Offset(12.5, 15), const Offset(17, 15), stroke);
      case 'android':
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 17)
            ..arcToPoint(const Offset(19.2, 17), radius: const Radius.circular(7.2))
            ..close(),
          fill,
        );
        canvas.drawLine(const Offset(8, 10.3), const Offset(6.4, 7.8), stroke..strokeWidth = 1.5);
        canvas.drawLine(const Offset(16, 10.3), const Offset(17.6, 7.8), stroke);
    }
  }

  @override
  bool shouldRepaint(_OsPainter o) => o.os != os || o.c != c;
}

/// Gentle dotted grid used as a backdrop on white sections.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, this.color = C.line, this.gap = 28, this.fade = true});
  final Color color;
  final double gap;
  final bool fade;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotGrid(color, gap, fade));
}

class _DotGrid extends CustomPainter {
  _DotGrid(this.c, this.gap, this.fade);
  final Color c;
  final double gap;
  final bool fade;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c;
    final center = s.center(Offset.zero);
    final maxD = s.longestSide * .6;
    for (double x = gap / 2; x < s.width; x += gap) {
      for (double y = gap / 2; y < s.height; y += gap) {
        final a = fade ? clamp01(1 - (Offset(x, y) - center).distance / maxD) : 1.0;
        if (a <= .02) continue;
        p.color = c.withValues(alpha: c.a * a);
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid o) => false;
}
