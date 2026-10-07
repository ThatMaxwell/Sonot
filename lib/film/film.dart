import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../core/bridge.dart';
import '../core/i18n.dart' as i18n;
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';

/* ==========================================================================
   "IGNITION" — the launch film. One continuous three.js particle shot
   (web/js/film3d.js) locked to the soundtrack (web/js/audio.js):
   128 BPM, 24 bars = 45s. Flutter adds subtitles, flashes and controls.
   ========================================================================== */
const double kBeat = 60 / 128;
const double kBar = kBeat * 4;
const double kLen = kBar * 24;

/// Photos to warm up before the site appears.
const montagePhotos = <String>[];

String moodAt(double tb) {
  if (tb < 8) return 'dark';
  if (tb < 15) return 'blue';
  if (tb < 17) return 'white';
  if (tb < 22) return 'navy';
  return 'white';
}

class FilmPlayer extends StatefulWidget {
  const FilmPlayer({super.key, required this.onReveal, required this.onDone});
  final VoidCallback onReveal;
  final VoidCallback onDone;
  @override
  State<FilmPlayer> createState() => _FilmPlayerState();
}

class _FilmPlayerState extends State<FilmPlayer> with TickerProviderStateMixin {
  late final Ticker tk;
  late final AnimationController fadeIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final AnimationController fadeOut = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final FocusNode focus = FocusNode();
  final clock = ValueNotifier<double>(0);
  double t = 0;
  Duration last = Duration.zero;
  bool finishing = false;
  bool muted = Browser.read('sonot.mute') == '1';

  @override
  void initState() {
    super.initState();
    Audio.setMuted(muted);
    if (Audio.running) Audio.start(0);
    tk = createTicker(_tick)..start();
    Browser.onVisibility((hidden) {
      if (!mounted || finishing) return;
      hidden ? Audio.pause() : Audio.resume();
    });
  }

  void _tick(Duration d) {
    final dt = math.min(.1, (d - last).inMicroseconds / 1e6);
    last = d;
    if (finishing) return;
    if (!Audio.started && Audio.running) Audio.start(t);
    final at = Audio.time();
    setState(() => t = at >= 0 ? at : t + dt);
    clock.value = t;
    if (t >= kLen) finish();
  }

  void finish() {
    if (finishing) return;
    finishing = true;
    Audio.stop();
    widget.onReveal();
    fadeOut.forward().then((_) => widget.onDone());
  }

  void toggleMute() {
    setState(() => muted = !muted);
    Audio.setMuted(muted);
    Browser.write('sonot.mute', muted ? '1' : '0');
    if (!muted) Audio.unlock();
  }

  @override
  void dispose() {
    tk.dispose();
    fadeIn.dispose();
    fadeOut.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.vp;
    final tb = t / kBar;
    final mood = moodAt(tb);
    final light = mood == 'white';
    final fg = light ? C.ink : C.white;
    final bg = switch (mood) {
      'blue' => C.blue,
      'white' => C.white,
      'navy' => const Color(0xFF01030E),
      _ => const Color(0xFF010208),
    };
    return Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.escape) {
          finish();
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyM) {
          toggleMute();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([fadeIn, fadeOut]),
        builder: (context, _) => Opacity(
          opacity: fadeIn.value * (1 - Curves.easeIn.transform(fadeOut.value)),
          child: Container(
            color: bg,
            child: Stack(fit: StackFit.expand, children: [
              ThreeView(kind: 'film', progress: clock),
              ..._subtitles(tb, s, fg),
              _flash(tb),
              _chrome(fg, light),
            ]),
          ),
        ),
      ),
    );
  }

  /* ---------------- impact flashes ---------------- */
  Widget _flash(double tb) {
    double f = 0;
    for (final (at, len, peak) in const [(8.0, .7, .45), (17.0, .5, .2), (22.0, .8, .4)]) {
      if (tb >= at && tb < at + len) f = math.max(f, peak * (1 - (tb - at) / len));
    }
    final black = tb >= 7.78 && tb < 8; // the silence before the drop
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        if (black) Container(color: const Color(0xFF000000)),
        if (f > 0) Container(color: C.white.withValues(alpha: f)),
      ]),
    );
  }

  /* ---------------- subtitles ---------------- */
  List<Widget> _subtitles(double tb, Size s, Color fg) {
    final big = math.min(s.width * (s.width < 700 ? .078 : .058), 64.0);
    final out = <Widget>[];
    Widget place(Alignment a, Widget child) => Align(
          alignment: a,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: s.width * .08), child: child),
        );

    // "Every question / is a spark."
    if (tb < 4) {
      final o = 1 - seg(tb, 3.3, 3.85);
      out.add(place(
        const Alignment(0, .62),
        Opacity(
          opacity: o,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Words(i18n.t('f2.l1'), seg(tb, .5, 1.3), sans(big, w: FontWeight.w600, c: fg, ls: -.03, h: 1.1)),
            _Words(i18n.t('f2.l2'), seg(tb, 1.5, 2.2), sans(big, w: FontWeight.w600, c: fg, ls: -.03, h: 1.1), accent: C.blueSoft),
          ]),
        ),
      ));
    }
    if (tb >= 4.1 && tb < 5.65) {
      out.add(place(
        const Alignment(0, .72),
        Opacity(opacity: 1 - seg(tb, 5.35, 5.65), child: _Words(i18n.t('f2.l3'), seg(tb, 4.1, 4.8), sans(big * .82, w: FontWeight.w600, c: fg, ls: -.03))),
      ));
    }
    if (tb >= 5.7 && tb < 7.6) {
      out.add(place(
        const Alignment(0, .72),
        Opacity(
          opacity: 1 - seg(tb, 7.25, 7.6),
          child: _Words(i18n.t('f2.l4'), seg(tb, 5.7, 6.5), sans(big * .82, w: FontWeight.w600, c: fg, ls: -.03), accent: C.blueSoft),
        ),
      ));
    }
    // "Think in light." under the bloom
    if (tb >= 10.3 && tb < 12) {
      out.add(place(
        const Alignment(0, .82),
        Opacity(opacity: 1 - seg(tb, 11.7, 12), child: _Words(i18n.t('f.tag'), seg(tb, 10.3, 10.9), sans(big, w: FontWeight.w700, c: fg, ls: -.035), accent: C.sky)),
      ));
    }
    // talents counter
    if (tb >= 12 && tb < 15) {
      final k = ((tb - 12) / .5).floor().clamp(0, 5);
      out.add(Align(alignment: const Alignment(0, .8), child: Text('0${k + 1} / 06', style: mono(12, c: fg.withValues(alpha: .75), ls: .3))));
    }
    // "On every screen you own."
    if (tb >= 15.2 && tb < 17) {
      final o = 1 - seg(tb, 16.75, 17);
      out.add(place(
        const Alignment(0, -.8),
        Opacity(opacity: o, child: _Words(i18n.t('f.every'), seg(tb, 15.2, 15.8), sans(big * .9, w: FontWeight.w700, c: fg, ls: -.035))),
      ));
      out.add(Align(
        alignment: const Alignment(0, .84),
        child: Opacity(
          opacity: seg(tb, 15.6, 16) * o,
          child: Text('Windows  ·  Linux  ·  Android', textAlign: TextAlign.center, style: mono(math.min(13, s.width * .028), c: C.blue, ls: .18)),
        ),
      ));
    }
    // warp: people's questions, one per bar
    if (tb >= 17.15 && tb < 22) {
      final prompts = i18n.tl('f.mont');
      final i = (tb - 17).floor().clamp(0, 4);
      final local = tb - 17 - i;
      final v = Curves.easeOutCubic.transform(seg(local, .05, .3));
      final o = 1 - seg(local, .85, 1);
      out.add(place(
        Alignment(0, i.isEven ? -.05 : .05),
        Opacity(
          opacity: v * o,
          child: Transform.scale(
            scale: lerpD(1.25, 1, v) + local * .04,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: (1 - v) * 14, sigmaY: (1 - v) * 14),
              child: Text('“${prompts[i]}”', textAlign: TextAlign.center, style: sans(big * 1.05, w: FontWeight.w700, c: C.white, ls: -.035, h: 1.08)),
            ),
          ),
        ),
      ));
    }
    // arrival lockup
    if (tb >= 22.5) {
      final v1 = Curves.easeOutCubic.transform(seg(tb, 22.55, 22.95));
      final v2 = seg(tb, 22.9, 23.3);
      final v3 = seg(tb, 23.2, 23.55);
      out.add(Align(
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Opacity(
            opacity: v1,
            child: Transform.translate(
              offset: Offset(0, (1 - v1) * 30),
              child: Text('Sonot', style: sans(math.min(s.width * .1, 92), w: FontWeight.w800, ls: -.06, h: 1)),
            ),
          ),
          const SizedBox(height: 4),
          Opacity(opacity: v2, child: Text.rich(TextSpan(children: accent(i18n.t('f.tag'), sans(math.min(s.width * .045, 30), w: FontWeight.w500, ls: -.02))))),
          const SizedBox(height: 16),
          Opacity(
            opacity: v3,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              MaxwellMark(size: 16, color: C.ink, rotation: t * .8),
              const SizedBox(width: 8),
              Text(i18n.t('f.fin.by').toUpperCase(), style: mono(11, c: C.ink)),
            ]),
          ),
          SizedBox(height: s.height * .09),
        ]),
      ));
    }
    return out;
  }

  /* ---------------- controls ---------------- */
  Widget _chrome(Color fg, bool light) {
    final blocked = !Audio.running;
    final label = blocked ? i18n.t('soundTap') : (muted ? i18n.t('soundOff') : i18n.t('soundOn'));
    Widget pill(Widget child, VoidCallback onTap, {bool hot = false}) => Press(
          onTap: onTap,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: hot ? C.blue : fg.withValues(alpha: h ? .14 : .06),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: hot ? C.blue : fg.withValues(alpha: .14)),
            ),
            child: Center(child: child),
          ),
        );
    return Stack(children: [
      Positioned(
        left: 18,
        right: 18,
        bottom: 16,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          pill(
            Row(mainAxisSize: MainAxisSize.min, children: [
              _Eq(on: !muted && !blocked, color: blocked ? C.white : fg, t: t),
              const SizedBox(width: 9),
              Text(label, style: sans(12.5, c: blocked ? C.white : fg)),
            ]),
            blocked ? () => Audio.unlock() : toggleMute,
            hot: blocked,
          ),
          pill(Text('${i18n.t('skip')}  →', style: sans(12.5, c: fg)), finish),
        ]),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: clamp01(t / kLen), child: Container(height: 2, color: light ? C.blue : C.white.withValues(alpha: .7))),
        ),
      ),
    ]);
  }
}

/// A line whose words arrive one after another out of a blur.
/// Text inside *asterisks* takes the italic serif accent.
class _Words extends StatelessWidget {
  const _Words(this.text, this.v, this.style, {this.accent});
  final String text;
  final double v;
  final TextStyle style;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final words = <(String, bool)>[];
    final parts = text.split('*');
    for (var i = 0; i < parts.length; i++) {
      for (final w in parts[i].split(' ')) {
        if (w.isNotEmpty) words.add((w, i.isOdd));
      }
    }
    final n = words.length;
    return Wrap(alignment: WrapAlignment.center, spacing: style.fontSize! * .26, children: [
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final p = Curves.easeOutCubic.transform(seg(v, i / (n + 1), (i + 1.6) / (n + 1)));
          final st = words[i].$2
              ? style.copyWith(
                  fontFamily: F.serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w400, letterSpacing: 0,
                  color: accent ?? C.blue, fontSize: style.fontSize! * 1.1)
              : style;
          return Opacity(
            opacity: p,
            child: Transform.translate(
              offset: Offset(0, (1 - p) * style.fontSize! * .35),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: (1 - p) * 10, sigmaY: (1 - p) * 10),
                child: Text(words[i].$1, style: st),
              ),
            ),
          );
        }),
    ]);
  }
}

class _Eq extends StatelessWidget {
  const _Eq({required this.on, required this.color, required this.t});
  final bool on;
  final Color color;
  final double t;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 14,
        height: 13,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 4; i++) Container(width: 2, height: on ? 3 + 10 * (.5 + .5 * math.sin(t * 9 + i * 1.7)).abs() : 4, color: color),
        ]),
      );
}
