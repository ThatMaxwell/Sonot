import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/bridge.dart';
import '../core/i18n.dart' as i18n;
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';

/* ==========================================================================
   LANGUAGE GATE — the very first screen. No logo, no name.
   ========================================================================== */
class LanguageGate extends StatefulWidget {
  const LanguageGate({super.key, required this.onPicked});
  final void Function(String lang) onPicked;
  @override
  State<LanguageGate> createState() => _LanguageGateState();
}

class _LanguageGateState extends State<LanguageGate> with TickerProviderStateMixin {
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final AnimationController out = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Ticker drift;
  double time = 0;
  String? picked;
  final guess = Browser.language.toLowerCase().startsWith('pt') ? 'pt' : 'en';

  @override
  void initState() {
    super.initState();
    drift = createTicker((d) => setState(() => time = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    intro.dispose();
    out.dispose();
    drift.dispose();
    super.dispose();
  }

  void pick(String l) {
    if (picked != null) return;
    Audio.unlock(); // this click is the gesture that lets the intro play music
    setState(() => picked = l);
    i18n.lang.value = l;
    Browser.write('sonot.lang', l);
    out.forward().then((_) => widget.onPicked(l));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    return AnimatedBuilder(
      animation: Listenable.merge([intro, out]),
      builder: (context, _) {
        final o = Curves.easeInCubic.transform(out.value);
        return Opacity(
          opacity: 1 - o,
          child: Container(
            color: C.white,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _Aurora(time, o))),
                Center(
                  child: Transform.scale(
                    scale: 1 - o * .04,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _rise(
                              0,
                              Text(
                                'Choose your language',
                                textAlign: TextAlign.center,
                                style: sans(mobile ? 30 : 44, w: FontWeight.w600, ls: -.035, h: 1.05),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _rise(
                              1,
                              Text(
                                'Escolha seu idioma',
                                textAlign: TextAlign.center,
                                style: serif(mobile ? 28 : 40, c: C.blue),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Flex(
                              direction: mobile ? Axis.vertical : Axis.horizontal,
                              children: [
                                _opt(2, 'en', 'English', 'Continue in English', mobile),
                                SizedBox(width: 14, height: 14),
                                _opt(3, 'pt', 'Português', 'Continuar em português', mobile),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rise(int i, Widget child) {
    final v = Curves.easeOutCubic.transform(seg(intro.value, i * .1, .55 + i * .1));
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: child),
    );
  }

  Widget _opt(int i, String code, String title, String sub, bool mobile) {
    final tile = Press(
      onTap: () => pick(code),
      builder: (h) {
        final on = h || picked == code;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          transform: Matrix4.translationValues(0, on ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: on ? C.blue : C.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: on ? C.blue : (code == guess ? C.blue.withValues(alpha: .35) : C.line), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: C.blue.withValues(alpha: on ? .35 : .06),
                blurRadius: on ? 40 : 20,
                offset: Offset(0, on ? 18 : 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: sans(24, w: FontWeight.w600, c: on ? C.white : C.ink, ls: -.02),
                      child: Text(title),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: sans(14, c: on ? C.white.withValues(alpha: .8) : C.mute),
                      child: Text(sub),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                offset: Offset(on ? .3 : 0, 0),
                child: Text('→', style: sans(22, c: on ? C.white : C.mute)),
              ),
            ],
          ),
        );
      },
    );
    final w = _rise(i, tile);
    return mobile ? SizedBox(width: double.infinity, child: w) : Expanded(child: w);
  }
}

class _Aurora extends CustomPainter {
  _Aurora(this.t, this.out);
  final double t, out;
  @override
  void paint(Canvas canvas, Size s) {
    final blobs = [
      [.25, .3, .55, const Color(0xFF0B5CFF), .10],
      [.78, .65, .5, const Color(0xFF6EA2FF), .12],
      [.55, .9, .45, const Color(0xFF0B5CFF), .07],
    ];
    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final c = Offset(s.width * ((b[0] as double) + math.sin(t * .25 + i * 2) * .06), s.height * ((b[1] as double) + math.cos(t * .2 + i) * .06));
      final r = math.max(s.width, s.height) * (b[2] as double);
      final col = b[3] as Color;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              col.withValues(alpha: (b[4] as double) * (1 + out)),
              col.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_Aurora o) => true;
}

/* ==========================================================================
   LOADER — exactly 3 seconds. Petals fly in, the icon forms around them.
   ========================================================================== */
class Loader extends StatefulWidget {
  const Loader({super.key, required this.onDone, required this.onExit});
  final VoidCallback onDone; // fires at exactly 3.0s
  final VoidCallback onExit; // fires when the exit animation has finished
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  double t = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      setState(() => t = d.inMicroseconds / 1e6);
      if (!done && t >= 3.0) {
        done = true;
        widget.onDone();
      }
      if (t >= 3.75) {
        tk.stop();
        widget.onExit();
      }
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = clamp01(t / 3);
    final e = p < .5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;
    final exit = Curves.easeInCubic.transform(seg(t, 3.0, 3.7));
    final size = math.min(context.vp.shortestSide * .26, 170.0);
    final sq = Curves.elasticOut.transform(seg(t, 1.95, 2.9));
    final whiteness = seg(t, 2.0, 2.35);
    return IgnorePointer(
      ignoring: done,
      child: Opacity(
        opacity: 1 - exit,
        child: Container(
          color: Color.lerp(C.white, C.ink, exit)!,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 1 + exit * 1.6,
                      child: CustomPaint(size: Size.square(size), painter: _LoaderMark(t, sq, whiteness)),
                    ),
                    const SizedBox(height: 34),
                    _word(t),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: math.max(40, context.vh * 8),
                child: Center(
                  child: SizedBox(
                    width: math.min(280, context.vp.width * .7),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(height: 2, color: C.line),
                              FractionallySizedBox(
                                widthFactor: e,
                                child: Container(height: 2, color: C.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(i18n.t('loader').toUpperCase(), style: mono(11)),
                            Text('${(e * 100).round()}%', style: mono(11, c: C.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _word(double t) {
    const letters = 'Sonot';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          Builder(
            builder: (_) {
              final v = Curves.easeOutCubic.transform(seg(t, 1.15 + i * .06, 1.75 + i * .06));
              return ClipRect(
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 40),
                  child: Opacity(
                    opacity: v,
                    child: Text(letters[i], style: sans(38, w: FontWeight.w700, ls: -.04)),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LoaderMark extends CustomPainter {
  _LoaderMark(this.t, this.sq, this.white);
  final double t, sq, white;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    // halo
    canvas.drawCircle(
      rect.center,
      s.width * 1.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            C.blue.withValues(alpha: .10 * seg(t, 0, 1)),
            C.blue.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: rect.center, radius: s.width * 1.2)),
    );
    paintIconSquare(canvas, rect, t: sq);
    final spin = (1 - Curves.easeOutCubic.transform(clamp01(t / 3))) * -2.4;
    paintBloom(
      canvas,
      rect,
      rotation: spin,
      colorOf: (_) => Color.lerp(C.blue, C.white, white)!,
      alpha: (i) => Curves.easeOut.transform(seg(t, .12 + i * .2, .5 + i * .2)),
      push: (i) => (1 - Curves.easeOutBack.transform(seg(t, .12 + i * .2, .72 + i * .2))) * 260,
      scale: (i) => .4 + .6 * Curves.easeOutBack.transform(seg(t, .12 + i * .2, .72 + i * .2)),
    );
  }

  @override
  bool shouldRepaint(_LoaderMark o) => true;
}
