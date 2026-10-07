// Sonot Buds: animated Bud face.
//
// One flat shape (circle, square, triangle, capsule) with two big ink eyes.
// Emotions only change the eyes (size, lids, gaze), so a Bud always looks
// like itself. No gradients, glow, shadow or outline.
//
// Usage:
//   final face = BudFaceController(emotion: BudEmotion.neutral);
//   BudAvatar(shape: BudShape.square, color: Color(0xFF2F6BFF), size: 96, controller: face)
//   face.emotion = BudEmotion.happy;   // e.g. from a `bud.emotion` server event
//
// At 24 px and below the face is drawn still (neutral pose, no blinking).
// With reduced motion (MediaQuery.disableAnimations) emotions switch instantly
// and blinks, glances and hops are skipped.
//
// Reference: bud-faces.html (same numbers, same behaviour).

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

enum BudShape { circle, square, triangle, capsule }

enum BudEmotion {
  neutral,
  happy,
  excited,
  curious,
  thinking,
  focused,
  surprised,
  sad,
  sleepy,
  wink,
  confused,
  shy,
  serious;

  /// Parses the NAME in a hidden `[[emo:NAME]]` tag. Unknown names → neutral.
  static BudEmotion parse(String name) =>
      BudEmotion.values.firstWhere((e) => e.name == name, orElse: () => BudEmotion.neutral);
}

const Color _ink = Color(0xFF0B0F1A);

/// One eye's pose. `slant` > 0 lowers the inner side of the upper lid
/// (serious), < 0 lowers the outer side (sad). `bot` raises an arched lower
/// lid (happy).
@immutable
class _Eye {
  const _Eye({this.sx = 1, this.sy = 1, this.top = 0, this.slant = 0, this.bot = 0});
  final double sx, sy, top, slant, bot;

  _Eye lerpTo(_Eye b, double k) => _Eye(
        sx: sx + (b.sx - sx) * k,
        sy: sy + (b.sy - sy) * k,
        top: top + (b.top - top) * k,
        slant: slant + (b.slant - slant) * k,
        bot: bot + (b.bot - bot) * k,
      );
}

@immutable
class _Pose {
  const _Pose(this.l, this.r, this.lx, this.ly);
  final _Eye l, r;
  final double lx, ly; // gaze, -1..1

  _Pose lerpTo(_Pose b, double k) =>
      _Pose(l.lerpTo(b.l, k), r.lerpTo(b.r, k), lx + (b.lx - lx) * k, ly + (b.ly - ly) * k);
}

class _EmotionSpec {
  const _EmotionSpec(this.pose, {this.wander = 0, this.drift = false, this.hop = false, this.slowBlink = false});
  final _Pose pose;
  final double wander; // 0..1, random glances
  final bool drift, hop, slowBlink;
}

const _e = _Eye();
const Map<BudEmotion, _EmotionSpec> _specs = {
  BudEmotion.neutral: _EmotionSpec(_Pose(_e, _e, 0, 0), wander: 1),
  BudEmotion.happy: _EmotionSpec(_Pose(_Eye(bot: .52), _Eye(bot: .52), 0, -.2)),
  BudEmotion.excited: _EmotionSpec(_Pose(_Eye(sx: 1.08, sy: 1.16, bot: .28), _Eye(sx: 1.08, sy: 1.16, bot: .28), 0, -.25), hop: true),
  BudEmotion.curious: _EmotionSpec(_Pose(_Eye(sx: 1.06, sy: 1.14), _Eye(top: .3), .5, -.3)),
  BudEmotion.thinking: _EmotionSpec(_Pose(_Eye(sy: .94), _Eye(sy: .94), -.7, -.75), drift: true),
  BudEmotion.focused: _EmotionSpec(_Pose(_Eye(top: .34, sy: .96), _Eye(top: .34, sy: .96), .35, .5), wander: .4),
  BudEmotion.surprised: _EmotionSpec(_Pose(_Eye(sx: 1.2, sy: 1.26), _Eye(sx: 1.2, sy: 1.26), 0, 0)),
  BudEmotion.sad: _EmotionSpec(_Pose(_Eye(top: .4, slant: -.55, sy: .96), _Eye(top: .4, slant: -.55, sy: .96), 0, .5)),
  BudEmotion.sleepy: _EmotionSpec(_Pose(_Eye(top: .64, sy: .92), _Eye(top: .64, sy: .92), 0, .35), slowBlink: true),
  BudEmotion.wink: _EmotionSpec(_Pose(_e, _Eye(sy: .12), .15, -.1)),
  BudEmotion.confused: _EmotionSpec(_Pose(_Eye(top: .32, slant: .6, sy: .92), _Eye(sx: 1.1, sy: 1.12), -.35, -.25)),
  BudEmotion.shy: _EmotionSpec(_Pose(_Eye(sx: .86, sy: .84, bot: .22), _Eye(sx: .86, sy: .84, bot: .22), -.6, .55)),
  BudEmotion.serious: _EmotionSpec(_Pose(_Eye(top: .3, slant: .5), _Eye(top: .3, slant: .5), 0, 0)),
};

/// Eye layout per shape, in units of the avatar size (origin at the center).
class _EyeLayout {
  const _EyeLayout(this.dx, this.cy, this.w, this.h);
  final double dx, cy, w, h;
}

const Map<BudShape, _EyeLayout> _layouts = {
  BudShape.circle: _EyeLayout(.165, -.03, .17, .27),
  BudShape.square: _EyeLayout(.17, -.02, .17, .27),
  BudShape.triangle: _EyeLayout(.115, .15, .125, .2),
  BudShape.capsule: _EyeLayout(.19, 0, .15, .24),
};

/// Holds the current emotion. Set [emotion] from anywhere (e.g. the chat
/// stream) and every avatar listening to this controller follows.
class BudFaceController extends ValueNotifier<BudEmotion> {
  BudFaceController({BudEmotion emotion = BudEmotion.neutral}) : super(emotion);
  BudEmotion get emotion => value;
  set emotion(BudEmotion e) => value = e;
}

class BudAvatar extends StatefulWidget {
  const BudAvatar({
    super.key,
    required this.shape,
    required this.color,
    this.size = 96,
    this.controller,
    this.emotion = BudEmotion.neutral,
    this.semanticLabel,
  });

  final BudShape shape;
  final Color color;
  final double size;

  /// Drives the emotion live. If null, [emotion] is used.
  final BudFaceController? controller;
  final BudEmotion emotion;
  final String? semanticLabel;

  @override
  State<BudAvatar> createState() => _BudAvatarState();
}

class _BudAvatarState extends State<BudAvatar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _rng = math.Random();
  final _frame = ValueNotifier<int>(0);

  late _Pose _pose;
  Duration _last = Duration.zero;
  double _now = 0; // seconds since start

  double _blinkAt = 0, _blinkStart = -1, _blinkLen = .15, _blink = 0;
  double _glanceAt = 0, _gx = 0, _gy = 0;
  double _hopStart = 0, _hop = 0;

  BudEmotion get _emotion => widget.controller?.value ?? widget.emotion;
  bool _reduceMotion = false;
  bool get _still => widget.size <= 24 || _reduceMotion;

  @override
  void initState() {
    super.initState();
    _pose = _specs[_emotion]!.pose;
    _blinkAt = 1 + _rng.nextDouble() * 3;
    widget.controller?.addListener(_onEmotion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(BudAvatar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onEmotion);
      widget.controller?.addListener(_onEmotion);
    }
    if (old.emotion != widget.emotion || old.controller != widget.controller) _onEmotion();
    _syncTicker();
  }

  void _syncTicker() {
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _pose = _specs[widget.size <= 24 ? BudEmotion.neutral : _emotion]!.pose;
      _blink = _hop = 0;
      _frame.value++;
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onEmotion() {
    final spec = _specs[_emotion]!;
    if (spec.hop) _hopStart = _now;
    if (_still) {
      _pose = _specs[widget.size <= 24 ? BudEmotion.neutral : _emotion]!.pose;
      _frame.value++;
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : math.min(.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _now += dt;
    final spec = _specs[_emotion]!;

    // Glances (idle look-around) or a slow drift while thinking.
    if (_now > _glanceAt) {
      _gx = spec.wander > 0 ? (_rng.nextDouble() * 2 - 1) * .45 * spec.wander : 0;
      _gy = spec.wander > 0 ? (_rng.nextDouble() * 2 - 1) * .3 * spec.wander : 0;
      _glanceAt = _now + 1.2 + _rng.nextDouble() * 2.6;
    }
    var gx = _gx, gy = _gy;
    if (spec.drift) {
      gx = math.sin(_now * .9) * .18;
      gy = math.cos(_now * .7) * .12;
    }
    final t = spec.pose;
    final target = _Pose(t.l, t.r, t.lx + gx, t.ly + gy);
    _pose = _pose.lerpTo(target, 1 - math.exp(-dt * 12));

    // Blinks: 2.5–6 s apart, sometimes a double blink; slow and sparse when sleepy.
    if (_now > _blinkAt) {
      _blinkStart = _now;
      _blinkLen = spec.slowBlink ? .42 : .15;
      _blinkAt = _now + (spec.slowBlink ? 3.5 + _rng.nextDouble() * 3 : 2.5 + _rng.nextDouble() * 3.5);
      if (!spec.slowBlink && _rng.nextDouble() < .18) _blinkAt = _now + .26;
    }
    final bp = _blinkStart < 0 ? 1.0 : (_now - _blinkStart) / _blinkLen;
    _blink = bp < 1 ? math.sin(bp * math.pi) : 0;

    // One small hop every 2.4 s while excited.
    if (spec.hop) {
      final hp = ((_now - _hopStart) % 2.4) / .36;
      _hop = hp < 1 ? math.sin(hp * math.pi) : 0;
    } else {
      _hop = 0;
    }
    _frame.value++;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onEmotion);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _BudPainter(
            repaint: _frame,
            shape: widget.shape,
            color: widget.color,
            pose: () => _pose,
            blink: () => _blink,
            hop: () => _hop,
          ),
        ),
      ),
    );
  }
}

class _BudPainter extends CustomPainter {
  _BudPainter({
    required Listenable repaint,
    required this.shape,
    required this.color,
    required this.pose,
    required this.blink,
    required this.hop,
  }) : super(repaint: repaint);

  final BudShape shape;
  final Color color;
  final _Pose Function() pose;
  final double Function() blink, hop;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 - hop() * s * .035);

    final body = _bodyPath(shape, s);
    canvas.drawPath(body, Paint()..color = color..isAntiAlias = true);
    canvas.clipPath(body);

    final g = _layouts[shape]!;
    final p = pose();
    final lookX = p.lx * .06 * s, lookY = p.ly * .05 * s;
    final ink = Paint()..color = _ink..isAntiAlias = true;
    for (final (eye, sign) in [(p.l, -1.0), (p.r, 1.0)]) {
      final w = g.w * s * eye.sx;
      final h = g.h * s * eye.sy * (1 - blink() * .9);
      final c = Offset(sign * g.dx * s + lookX, g.cy * s + lookY);
      _paintEye(canvas, ink, c, w, h, eye, sign);
    }
    canvas.restore();
  }

  /// Fills ink once into (eye capsule) minus (lids), so edges stay crisp.
  void _paintEye(Canvas canvas, Paint ink, Offset c, double w, double h, _Eye e, double sign) {
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    final x = rect.left, y = rect.top, yb = rect.bottom;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.min(w, h) / 2)));

    var yL = y - 2, yR = y - 2;
    if (e.top > .01) {
      final y0 = y + e.top * h, sl = e.slant * h * .38;
      final inner = -sign; // the inner side faces the other eye
      yL = y0 + (inner < 0 ? sl : -sl);
      yR = y0 + (inner > 0 ? sl : -sl);
    }
    var edge = yb + 2, peak = yb + 2;
    if (e.bot > .01) {
      edge = yb - e.bot * h * .4;
      peak = yb - e.bot * h * 1.6;
    }
    final open = Path()
      ..moveTo(x - 2, yL)
      ..lineTo(x + w + 2, yR)
      ..lineTo(x + w + 2, edge)
      ..quadraticBezierTo(c.dx, peak, x - 2, edge)
      ..close();
    canvas.drawPath(open, ink);
    canvas.restore();
  }

  static Path _bodyPath(BudShape shape, double s) {
    switch (shape) {
      case BudShape.circle:
        return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: .45 * s));
      case BudShape.square:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: .84 * s, height: .84 * s), Radius.circular(.2 * s)));
      case BudShape.capsule:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: .94 * s, height: .6 * s), Radius.circular(.3 * s)));
      case BudShape.triangle:
        return _roundedPolygon([Offset(0, -.43 * s), Offset(.48 * s, .38 * s), Offset(-.48 * s, .38 * s)], .12 * s);
    }
  }

  /// Polygon with circular corners of radius [r] (same as canvas arcTo).
  static Path _roundedPolygon(List<Offset> pts, double r) {
    final path = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n];
      final a = (prev - cur), b = (next - cur);
      final ua = a / a.distance, ub = b / b.distance;
      final angle = math.acos((ua.dx * ub.dx + ua.dy * ub.dy).clamp(-1.0, 1.0));
      final t = r / math.tan(angle / 2); // distance from corner to tangent points
      final p1 = cur + ua * t, p2 = cur + ub * t;
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.arcToPoint(p2, radius: Radius.circular(r), clockwise: _cross(ua, ub) < 0);
    }
    return path..close();
  }

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  @override
  bool shouldRepaint(_BudPainter old) => old.shape != shape || old.color != color;
}

/// Strips hidden `[[emo:NAME]]` tags from a streamed reply. Feed it chunks;
/// it returns the clean text to show and calls [onEmotion] for each tag,
/// including tags split across chunks. (The server does the same thing; this
/// is a safety net so a raw tag never reaches the screen.)
class EmotionTagFilter {
  EmotionTagFilter(this.onEmotion);
  final void Function(BudEmotion) onEmotion;
  String _buf = '';
  static final _tag = RegExp(r'\[\[emo:([a-z]+)\]\]');

  String add(String chunk) {
    _buf += chunk;
    final out = StringBuffer();
    while (true) {
      final m = _tag.firstMatch(_buf);
      if (m == null) break;
      out.write(_buf.substring(0, m.start));
      onEmotion(BudEmotion.parse(m.group(1)!));
      _buf = _buf.substring(m.end);
    }
    final open = _buf.lastIndexOf('[[');
    if (open == -1 || _buf.length - open > 24) {
      out.write(_buf);
      _buf = '';
    } else {
      out.write(_buf.substring(0, open));
      _buf = _buf.substring(open);
    }
    return out.toString();
  }

  /// Call when the stream ends to flush anything held back.
  String close() {
    final rest = _buf;
    _buf = '';
    return rest;
  }
}
