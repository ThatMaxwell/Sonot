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
   THE LAUNCH FILM — 26 bars at 124 BPM (≈50.3s), locked to the soundtrack.
   bars  0-4  words on black        bars 14-16 it builds (blue)
         4-8  petals assemble       bars 16-18 it sees (break)
         8-10 DROP: SONOT           bars 18-22 DROP 2: montage
        10-12 ask anything          bars 22-24 every screen
        12-14 it reasons (black)    bars 24-26 finale
   ========================================================================== */
const double kBeat = 60 / 124;
const double kBar = kBeat * 4;
const double kLen = kBar * 26;
double barT(double b) => b * kBar;

/// 1 on the kick, decaying through the beat
double pulse(double t) => math.exp(-((t % kBeat) / kBeat) * 7);

const montagePhotos = [
  'assets/img/people-students.webp',
  'assets/img/people-devs.webp',
  'assets/img/people-creator.webp',
  'assets/img/people-pro.webp',
  'assets/img/people-shop.webp',
  'assets/img/people-friends.webp',
  'assets/img/people-portrait.webp',
  'assets/img/earth-night.webp',
];

class FilmPlayer extends StatefulWidget {
  const FilmPlayer({super.key, required this.onReveal, required this.onDone});
  final VoidCallback onReveal; // site starts appearing under the fade
  final VoidCallback onDone;
  @override
  State<FilmPlayer> createState() => _FilmPlayerState();
}

class _FilmPlayerState extends State<FilmPlayer> with TickerProviderStateMixin {
  late final Ticker tk;
  late final AnimationController fadeIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final AnimationController fadeOut = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final FocusNode focus = FocusNode();
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
    // Audio got unlocked mid-film (first tap) → bring the music in, in sync
    if (!Audio.started && Audio.running) Audio.start(t);
    final at = Audio.time();
    setState(() => t = at >= 0 ? at : t + dt);
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

  bool get darkScene {
    final b = t / kBar;
    return b < 4 || (b >= 8 && b < 10) || (b >= 12 && b < 16) || (b >= 18 && b < 22);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.vp;
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
            color: C.ink,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(child: _scene(t, s)),
                _chrome(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ---------------- chrome ---------------- */
  Widget _chrome(Size s) {
    final fg = darkScene ? C.white : C.ink;
    final blocked = !Audio.running;
    final label = blocked ? i18n.t('soundTap') : (muted ? i18n.t('soundOff') : i18n.t('soundOn'));
    final sec = t.floor().clamp(0, 99);
    Widget pill(Widget child, VoidCallback onTap, {bool hot = false}) => Press(
      onTap: onTap,
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hot ? C.blue : fg.withValues(alpha: h ? .16 : .08),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: hot ? C.blue : fg.withValues(alpha: .16)),
        ),
        child: Center(child: child),
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: 24,
          right: 24,
          top: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SonotMark(size: 16, color: fg),
                  const SizedBox(width: 8),
                  Text(i18n.t('filmLabel').toUpperCase(), style: mono(10.5, c: fg.withValues(alpha: .6))),
                ],
              ),
              Text('00:${sec.toString().padLeft(2, '0')} / 00:50', style: mono(10.5, c: fg.withValues(alpha: .6))),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              pill(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Eq(on: !muted && !blocked, color: blocked ? C.white : fg, t: t),
                    const SizedBox(width: 10),
                    Text(label, style: sans(13, c: blocked ? C.white : fg)),
                  ],
                ),
                blocked ? () => Audio.unlock() : toggleMute,
                hot: blocked,
              ),
              pill(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(i18n.t('skip'), style: sans(13, c: fg)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: fg.withValues(alpha: .12), borderRadius: BorderRadius.circular(5)),
                      child: Text('Esc', style: mono(9.5, c: fg, ls: 0)),
                    ),
                  ],
                ),
                finish,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clamp01(t / kLen),
              child: Container(height: 3, color: C.blue),
            ),
          ),
        ),
      ],
    );
  }

  /* ---------------- scenes ---------------- */
  Widget _scene(double t, Size s) {
    final b = t / kBar;
    if (b < 4) return _words(t, s);
    if (b < 8) return _assemble(t - barT(4), s);
    if (b < 10) return _drop(t - barT(8), s);
    if (b < 12) return _ask(t - barT(10), s);
    if (b < 14) return _reason(t - barT(12), s);
    if (b < 16) return _code(t - barT(14), s);
    if (b < 18) return _see(t - barT(16), s);
    if (b < 22) return _montage(t - barT(18), s);
    if (b < 24) return _every(t - barT(22), s);
    return _finale(t - barT(24), s);
  }

  // 0 · "Every big idea starts with a question."
  Widget _words(double t, Size s) {
    final bt = t / kBeat;
    final words = i18n.tl('f.words');
    final m = s.shortestSide;
    final fs = math.min(s.width * .075, 92.0);
    final out = seg(bt, 12.5, 14);
    final wipe = math.pow(seg(bt, 14, 16), 3).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: C.ink),
        Align(
          alignment: const Alignment(0, -.12),
          child: Opacity(
            opacity: 1 - out,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: fs * .28,
                runSpacing: 0,
                children: [
                  for (var i = 0; i < words.length; i++)
                    Builder(
                      builder: (_) {
                        final v = seg(bt, 4.0 + i, 4.45 + i);
                        final e = Curves.easeOutBack.transform(v);
                        final last = i == words.length - 1;
                        final style = last ? serif(fs * 1.12, c: C.blue, h: 1.15) : sans(fs, w: FontWeight.w700, c: C.white, ls: -.04, h: 1.15);
                        return Opacity(
                          opacity: clamp01(v * 2),
                          child: Transform.scale(
                            scale: lerpD(1.6, 1, e),
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(sigmaX: (1 - v) * 10, sigmaY: (1 - v) * 10),
                              child: Text(words[i], style: style),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, .42),
          child: CustomPaint(size: Size.square(m * .5), painter: _Dot(pulse(t), seg(bt, 0, 1), seg(bt, 12, 14))),
        ),
        if (wipe > 0)
          Center(
            child: Container(
              width: wipe * s.longestSide * 2.4,
              height: wipe * s.longestSide * 2.4,
              decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  // 1 · Petals fly in one per beat and lock into the bloom
  Widget _assemble(double t, Size s) {
    final bt = t / kBeat;
    final m = s.shortestSide;
    final rnd = math.Random(8);
    final starts = List.generate(8, (_) => [rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 6 - 3]);
    final zoom = 1 + math.pow(seg(bt, 12, 16), 3) * 9;
    final spin = bt * .05 + math.pow(seg(bt, 8, 16), 2.4) * 7;
    final shake = bt > 14 ? math.sin(t * 90) * 4 * seg(bt, 14, 16) : 0.0;
    return Container(
      color: C.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Ripples(bt)),
          Center(
            child: Transform.translate(
              offset: Offset(shake, 0),
              child: Transform.scale(
                scale: zoom.toDouble(),
                child: CustomPaint(
                  size: Size.square(m * .42),
                  painter: _Painted((c, size) {
                    paintBloom(
                      c,
                      Offset.zero & size,
                      rotation: spin,
                      alpha: (i) => seg(bt, i - .9, i - .4),
                      push: (i) {
                        final v = Curves.easeOutBack.transform(seg(bt, i - .9, i.toDouble()));
                        return (1 - v) * 1400 * (.6 + starts[i][0].abs());
                      },
                      twist: (i) => (1 - Curves.easeOutCubic.transform(seg(bt, i - .9, i.toDouble()))) * starts[i][2],
                      scale: (i) => .5 + .5 * Curves.easeOutBack.transform(seg(bt, i - .9, i.toDouble())),
                    );
                  }),
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .62),
            child: Opacity(
              opacity: seg(bt, 8, 9) * (1 - seg(bt, 11, 12)),
              child: Text('INTRODUCING', style: mono(13, c: C.blue, ls: .4)),
            ),
          ),
        ],
      ),
    );
  }

  // 2 · DROP — S O N O T slams in on the kicks
  Widget _drop(double t, Size s) {
    final bt = t / kBeat;
    final p = pulse(t);
    final fs = math.min(s.width * .24, s.height * .36);
    final flash = 1 - seg(bt, 0, .35);
    return Container(
      color: C.blue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Opacity(
              opacity: .18,
              child: Transform.scale(
                scale: 1 + p * .04,
                child: SonotMark(size: s.longestSide * 1.1, color: C.white, rotation: t * .5),
              ),
            ),
          ),
          CustomPaint(painter: _Glow(C.white, .22 * p + .08)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 + p * .025,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Builder(
                          builder: (_) {
                            final v = seg(bt, i * .8, i * .8 + .3);
                            return Opacity(
                              opacity: v,
                              child: Transform.scale(
                                scale: lerpD(2.4, 1, Curves.easeOutCubic.transform(v)),
                                child: Text(
                                  'SONOT'[i],
                                  style: sans(fs, w: FontWeight.w800, c: C.white, ls: -.05, h: 1),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: fs * .08),
                Opacity(
                  opacity: seg(bt, 4.5, 5.2),
                  child: Transform.translate(
                    offset: Offset(0, (1 - Curves.easeOutCubic.transform(seg(bt, 4.5, 5.4))) * 30),
                    child: Text.rich(
                      TextSpan(
                        children: accent(
                          i18n.t('f.tag'),
                          sans(fs * .26, w: FontWeight.w600, c: C.white, ls: -.03),
                          accentColor: C.sky,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (flash > 0) Container(color: C.white.withValues(alpha: flash)),
        ],
      ),
    );
  }

  // 3 · Ask anything
  Widget _ask(double t, Size s) {
    final bt = t / kBeat;
    final p = pulse(t);
    final w = math.min(720.0, s.width * .9);
    final q = i18n.t('f.ask.q');
    final typed = q.substring(0, (seg(bt, .2, 3) * q.length).round());
    final days = (i18n.tr('f.ask.days') as List).cast<List>();
    final card = Curves.easeOutCubic.transform(seg(bt, 3.4, 4));
    return Container(
      color: C.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Glow(C.blue, .06 + .05 * p, center: const Alignment(0, -.2))),
          Align(alignment: const Alignment(0, -.78), child: _kicker('01', i18n.t('f.ask.k'), C.blue, seg(bt, 0, .5))),
          Center(
            child: SizedBox(
              width: w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1 + p * .006,
                    child: Container(
                      height: 66,
                      padding: const EdgeInsets.only(left: 22, right: 9),
                      decoration: BoxDecoration(
                        color: C.white,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: C.line),
                        boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .14), blurRadius: 40, offset: const Offset(0, 16))],
                      ),
                      child: Row(
                        children: [
                          const SonotMark(size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              typed + (bt < 3.2 && (t * 2).floor().isEven ? '|' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sans(math.min(20, s.width * .042), w: FontWeight.w500),
                            ),
                          ),
                          Transform.scale(
                            scale: 1 + (seg(bt, 3, 3.3) - seg(bt, 3.3, 3.6)) * .25,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: bt >= 3.1 ? C.blue : C.mist, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '↑',
                                  style: sans(20, w: FontWeight.w700, c: bt >= 3.1 ? C.white : C.mute),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: card,
                    child: Transform.translate(
                      offset: Offset(0, (1 - card) * 30),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: C.line),
                          boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .06), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SpinningMark(size: 18, seconds: bt < 4 ? .8 : 3),
                                const SizedBox(width: 8),
                                Text('Sonot', style: sans(15, w: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (var i = 0; i < 3; i++) _dayRow(days[i].cast<String>(), seg(bt, 4 + i * .9, 4.5 + i * .9)),
                            const SizedBox(height: 12),
                            Opacity(
                              opacity: seg(bt, 6.6, 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i18n.t('f.ask.total'), style: mono(12, c: C.ink)),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      children: [
                                        Container(height: 6, color: C.mist),
                                        FractionallySizedBox(
                                          widthFactor: .93 * Curves.easeOutCubic.transform(seg(bt, 6.6, 7.8)),
                                          child: Container(height: 6, color: C.blue),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  Widget _dayRow(List<String> d, double v) {
    final e = Curves.easeOutBack.transform(v);
    return Opacity(
      opacity: clamp01(v * 1.5),
      child: Transform.translate(
        offset: Offset((1 - e) * 60, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(d[0].toUpperCase(), style: mono(10.5, c: C.blue)),
              ),
              Expanded(
                child: Text(
                  d[1],
                  style: sans(16, w: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(d[2], style: mono(13, c: C.ink2, ls: 0)),
            ],
          ),
        ),
      ),
    );
  }

  // 4 · It reasons (black)
  Widget _reason(double t, Size s) {
    final bt = t / kBeat;
    final p = pulse(t);
    final mobile = s.width < 760;
    final steps = i18n.tl('f.think.steps');
    final net = CustomPaint(size: Size(math.min(s.width * (mobile ? .9 : .5), 640), math.min(s.height * (mobile ? .32 : .6), 440)), painter: _Network(bt, p));
    final side = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: seg(bt, .3, 1),
          child: Text.rich(
            TextSpan(
              children: accent(
                i18n.t('f.think.t'),
                sans(math.min(s.width * (mobile ? .09 : .05), 62), w: FontWeight.w700, c: C.white, ls: -.04, h: 1.02),
                accentColor: C.blueSoft,
              ),
            ),
            textAlign: mobile ? TextAlign.center : TextAlign.start,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < steps.length; i++)
          Opacity(
            opacity: seg(bt, 1.5 + i, 2.0 + i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bt > 2.2 + i ? C.blue : const Color(0x00000000),
                      border: Border.all(color: C.blue, width: 1.6),
                      boxShadow: bt > 2.2 + i ? [BoxShadow(color: C.blue.withValues(alpha: .7), blurRadius: 14)] : null,
                    ),
                    child: bt > 2.2 + i
                        ? Center(
                            child: Text(
                              '✓',
                              style: sans(12, w: FontWeight.w700, c: C.white, h: 1),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(steps[i], style: sans(17, c: C.white.withValues(alpha: .85))),
                ],
              ),
            ),
          ),
      ],
    );
    return Container(
      color: C.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(alignment: const Alignment(0, -.82), child: _kicker('02', i18n.t('f.think.k'), C.blueSoft, seg(bt, 0, .5))),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: mobile
                  ? Column(mainAxisSize: MainAxisSize.min, children: [net, const SizedBox(height: 16), side])
                  : Row(mainAxisSize: MainAxisSize.min, children: [net, const SizedBox(width: 50), side]),
            ),
          ),
        ],
      ),
    );
  }

  // 5 · It builds (blue)
  Widget _code(double t, Size s) {
    final bt = t / kBeat;
    final p = pulse(t);
    final mobile = s.width < 760;
    final eighth = bt * 2;
    final fs = mobile ? 11.0 : math.min(15.0, s.width * .012);
    final editor = Transform.scale(
      scale: 1 + p * .006,
      child: Container(
        width: mobile ? s.width * .9 : math.min(620, s.width * .48),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0D17),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .35), blurRadius: 60, offset: const Offset(0, 30))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              child: Row(
                children: [
                  for (final c in [0xFFFF5F57, 0xFFFEBC2E, 0xFF28C840])
                    Container(
                      margin: const EdgeInsets.only(right: 7),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 8),
                  Text('streak.ts', style: mono(11.5, c: C.mute, ls: 0)),
                ],
              ),
            ),
            Container(height: 1, color: C.white.withValues(alpha: .06)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _code1.length; i++)
                    Builder(
                      builder: (_) {
                        final v = seg(eighth, i * 1.1, i * 1.1 + 1);
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: v,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${(i + 1).toString().padLeft(2)}  ',
                                    style: mono(fs, c: const Color(0xFF3A4260), ls: 0),
                                  ),
                                  for (final tok in _code1[i])
                                    TextSpan(
                                      text: tok.$1,
                                      style: mono(fs, c: Color(tok.$2), w: FontWeight.w400, ls: 0),
                                    ),
                                ],
                              ),
                              softWrap: false,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final side = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: seg(bt, .2, .9),
          child: Text.rich(
            TextSpan(
              children: accent(
                i18n.t('f.code.t'),
                sans(math.min(s.width * (mobile ? .1 : .055), 68), w: FontWeight.w700, c: C.white, ls: -.04, h: 1),
                accentColor: C.sky,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Transform.scale(
          scale: Curves.elasticOut.transform(seg(bt, 6.6, 7.6)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✓  ',
                  style: sans(15, w: FontWeight.w800, c: C.green),
                ),
                Text(i18n.t('f.code.pass'), style: mono(13, c: C.ink, ls: 0)),
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      color: C.blue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Glow(C.white, .1 + .08 * p)),
          Align(alignment: const Alignment(0, -.84), child: _kicker('03', i18n.t('f.code.k'), C.white, seg(bt, 0, .5))),
          Center(
            child: mobile
                ? Column(mainAxisSize: MainAxisSize.min, children: [side, const SizedBox(height: 24), editor])
                : Row(mainAxisSize: MainAxisSize.min, children: [editor, const SizedBox(width: 56), side]),
          ),
        ],
      ),
    );
  }

  // 6 · It sees (breakdown — calm)
  Widget _see(double t, Size s) {
    final bt = t / kBeat;
    final w = math.min(math.min(860.0, s.width * .9), (s.height - 280) * 1.5);
    final h = w / 1.5;
    final labels = i18n.tl('f.see.labels');
    const boxes = [
      [.515, .035, .36, .48],
      [.24, .37, .44, .43],
      [.195, .43, .11, .24],
      [.34, .06, .12, .185],
    ];
    return Container(
      color: C.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(alignment: const Alignment(0, -.86), child: _kicker('04', i18n.t('f.see.k'), C.blue, seg(bt, 0, .5))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: seg(bt, 0, .6),
                  child: Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .18), blurRadius: 60, offset: const Offset(0, 24))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.scale(
                            scale: 1.08 - seg(bt, 0, 8) * .08,
                            child: Image.asset('assets/img/desk-coffee.webp', fit: BoxFit.cover),
                          ),
                          CustomPaint(painter: _Scan(seg(bt, .4, 3.2))),
                          for (var i = 0; i < 4; i++)
                            Positioned(
                              left: boxes[i][0] * w,
                              top: boxes[i][1] * h,
                              width: boxes[i][2] * w,
                              height: boxes[i][3] * h,
                              child: Transform.scale(
                                scale: Curves.easeOutBack.transform(seg(bt, 2 + i * .45, 2.5 + i * .45)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: C.blue.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: C.blue, width: 2),
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      margin: const EdgeInsets.all(5),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(6)),
                                      child: Text(labels[i], style: mono(10, c: C.white, ls: 0)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            right: w * .3,
                            child: Opacity(
                              opacity: seg(bt, 4.6, 5.2),
                              child: Transform.translate(
                                offset: Offset(0, (1 - seg(bt, 4.6, 5.3)) * 16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(color: C.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(16)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(padding: EdgeInsets.only(top: 2), child: SonotMark(size: 16)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(i18n.t('f.see.cap'), style: sans(math.min(14, w * .025), c: C.ink, h: 1.4)),
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
                  ),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: seg(bt, 1, 2),
                  child: Text.rich(TextSpan(children: accent(i18n.t('f.see.t'), sans(math.min(s.width * .06, 50), w: FontWeight.w700, ls: -.04)))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 7 · DROP 2 — montage, a cut on every kick
  Widget _montage(double t, Size s) {
    final bt = t / kBeat;
    final cut = bt.floor().clamp(0, 15);
    final within = bt - cut;
    final prompts = i18n.tl('f.mont');
    final pi = (bt / 2).floor().clamp(0, prompts.length - 1);
    final pv = Curves.easeOutCubic.transform(seg(bt, pi * 2.0, pi * 2.0 + .5));
    final fs = math.min(s.width * .065, 76.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1.18 - Curves.easeOutCubic.transform(clamp01(within)) * .18,
          child: ColorFiltered(
            colorFilter: cut.isOdd ? const ColorFilter.mode(Color(0xFF0B5CFF), BlendMode.color) : const ColorFilter.mode(Color(0x00000000), BlendMode.dst),
            child: Image.asset(montagePhotos[cut % montagePhotos.length], fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [C.ink.withValues(alpha: .25), C.ink.withValues(alpha: .7)],
            ),
          ),
        ),
        Container(color: C.white.withValues(alpha: (1 - seg(within, 0, .25)) * .3)),
        Align(
          alignment: const Alignment(0, .1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.width * .08),
            child: Opacity(
              opacity: pv,
              child: Transform.translate(
                offset: Offset(0, (1 - pv) * 40),
                child: Text(
                  '“${prompts[pi]}”',
                  textAlign: TextAlign.center,
                  style: sans(fs, w: FontWeight.w700, c: C.white, ls: -.035, h: 1.05),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          bottom: 70,
          child: Row(
            children: [
              for (var i = 0; i < 16; i++)
                Container(width: 14, height: 3, margin: const EdgeInsets.only(right: 4), color: i <= cut ? C.white : C.white.withValues(alpha: .25)),
            ],
          ),
        ),
      ],
    );
  }

  // 8 · Every screen
  Widget _every(double t, Size s) {
    final bt = t / kBeat;
    final p = pulse(t);
    final os = ['macOS', 'Windows', 'Linux', 'iOS', 'Android'];
    final mobile = s.width < 760;
    final scale = mobile ? s.width / 900 : math.min(1.0, s.width / 1200);
    return Container(
      color: C.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Glow(C.blue, .07 + .06 * p, center: const Alignment(0, .4))),
          Align(
            alignment: const Alignment(0, -.62),
            child: Opacity(
              opacity: seg(bt, 0, .6),
              child: Text.rich(
                TextSpan(children: accent(i18n.t('f.every'), sans(math.min(s.width * .07, 78), w: FontWeight.w700, ls: -.045))),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .35),
            child: Transform.scale(
              scale: scale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _devUp(bt, 0, _laptop(460)),
                  const SizedBox(width: 26),
                  _devUp(bt, 1, _screen(200, 266, 18)),
                  const SizedBox(width: 26),
                  _devUp(bt, 2, _screen(110, 236, 22)),
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .86),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 22,
              children: [
                for (var i = 0; i < os.length; i++)
                  Text(
                    os[i],
                    style: sans(math.min(s.width * .04, 34), w: FontWeight.w700, c: bt >= 3 + i ? C.blue : C.line, ls: -.03),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _devUp(double bt, int i, Widget child) {
    final v = Curves.easeOutBack.transform(seg(bt, i * .9, i * .9 + .8));
    return Opacity(
      opacity: clamp01(v),
      child: Transform.translate(offset: Offset(0, (1 - v) * 160), child: child),
    );
  }

  Widget _screen(double w, double h, double r) => Container(
    width: w,
    height: h,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: C.ink,
      borderRadius: BorderRadius.circular(r + 6),
      boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .25), blurRadius: 40, offset: const Offset(0, 20))],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(r), child: const _MiniUI()),
  );

  Widget _laptop(double w) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: w,
        height: w * .62,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: C.ink,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .25), blurRadius: 50, offset: const Offset(0, 24))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: const _MiniUI()),
      ),
      Container(
        width: w * 1.12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFFD5DAE6),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
      ),
    ],
  );

  // 9 · Finale
  Widget _finale(double t, Size s) {
    final bt = t / kBeat;
    final flash = 1 - Curves.easeOutCubic.transform(seg(bt, 0, 1.2));
    final icon = Curves.elasticOut.transform(seg(bt, .1, 2.2));
    final m = s.shortestSide;
    final endFade = seg(t, kBar * 2 - .7, kBar * 2);
    return Container(
      color: Color.lerp(C.white, C.blue, flash),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _Glow(C.blue, .12 * (1 - flash), center: const Alignment(0, -.3))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: (1 - icon) * -1.2,
                  child: Transform.scale(
                    scale: icon,
                    child: SonotIcon(size: math.min(m * .22, 170), rotation: t * .3),
                  ),
                ),
                SizedBox(height: m * .04),
                Opacity(
                  opacity: seg(bt, 1, 1.6),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: (1 - seg(bt, 1, 1.8)) * 12, sigmaY: (1 - seg(bt, 1, 1.8)) * 12),
                    child: Text('Sonot', style: sans(math.min(s.width * .16, 160), w: FontWeight.w800, ls: -.06, h: .95)),
                  ),
                ),
                Opacity(
                  opacity: seg(bt, 2, 2.6),
                  child: Text.rich(TextSpan(children: accent(i18n.t('f.tag'), sans(math.min(s.width * .05, 40), w: FontWeight.w500, ls: -.02)))),
                ),
                SizedBox(height: m * .05),
                Opacity(
                  opacity: seg(bt, 3, 3.6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MaxwellMark(size: 20, color: C.ink, rotation: t * .8),
                      const SizedBox(width: 10),
                      Text(i18n.t('f.fin.by').toUpperCase(), style: mono(12, c: C.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: seg(bt, 4, 4.6),
                  child: Text(i18n.t('f.fin.avail'), style: sans(14, c: C.mute)),
                ),
              ],
            ),
          ),
          if (endFade > 0) Container(color: C.white.withValues(alpha: endFade)),
        ],
      ),
    );
  }

  Widget _kicker(String n, String text, Color c, double v) => Opacity(
    opacity: v,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$n   ',
            style: mono(12, c: c.withValues(alpha: .5), ls: .25),
          ),
          TextSpan(
            text: text.toUpperCase(),
            style: mono(12, c: c, ls: .25),
          ),
        ],
      ),
    ),
  );
}

/* ---------------- code for the "it builds" scene ---------------- */
const _k = 0xFF7AA2FF, _f = 0xFFC7A6FF, _ty = 0xFF5EE0D0, _n = 0xFFFFB86B, _cm = 0xFF6B7493, _p = 0xFFD7DEF5;
const List<List<(String, int)>> _code1 = [
  [('export function ', _k), ('longestStreak', _f), ('(days: ', _p), ('Date', _ty), ('[]) {', _p)],
  [('  const ', _k), ('seen = ', _p), ('new ', _k), ('Set', _ty), ('(days.', _p), ('map', _f), ('(key));', _p)],
  [('  let ', _k), ('best = ', _p), ('0', _n), (';', _p)],
  [('  for ', _k), ('(', _p), ('const ', _k), ('d ', _p), ('of ', _k), ('seen) {', _p)],
  [('    if ', _k), ('(seen.', _p), ('has', _f), ('(', _p), ('prev', _f), ('(d))) ', _p), ('continue', _k), (';', _p)],
  [('    let ', _k), ('run = ', _p), ('1', _n), (', cur = d;', _p)],
  [('    while ', _k), ('(seen.', _p), ('has', _f), ('(cur = ', _p), ('next', _f), ('(cur))) run++;', _p)],
  [('    best = ', _p), ('Math', _ty), ('.', _p), ('max', _f), ('(best, run);', _p)],
  [('  }', _p)],
  [('  return ', _k), ('best; ', _p), ('// O(n)', _cm)],
  [('}', _p)],
];

/* ---------------- painters ---------------- */
class _Painted extends CustomPainter {
  _Painted(this.fn);
  final void Function(Canvas, Size) fn;
  @override
  void paint(Canvas canvas, Size size) => fn(canvas, size);
  @override
  bool shouldRepaint(_Painted o) => true;
}

class _Dot extends CustomPainter {
  _Dot(this.p, this.intro, this.grow);
  final double p, intro, grow;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = (5 + p * 6) * intro + grow * 30;
    canvas.drawCircle(
      c,
      r * 6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            C.blue.withValues(alpha: .5 * intro),
            C.blue.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 6)),
    );
    canvas.drawCircle(c, r, Paint()..color = Color.lerp(C.blue, C.white, .3 + p * .5)!);
  }

  @override
  bool shouldRepaint(_Dot o) => true;
}

class _Ripples extends CustomPainter {
  _Ripples(this.bt);
  final double bt;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final v = bt - i;
      if (v < 0 || v > 1.4) continue;
      final r = s.shortestSide * (.12 + v * .5);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = C.blue.withValues(alpha: (1 - v / 1.4) * .35),
      );
    }
  }

  @override
  bool shouldRepaint(_Ripples o) => true;
}

class _Glow extends CustomPainter {
  _Glow(this.color, this.a, {this.center = Alignment.center});
  final Color color;
  final double a;
  final Alignment center;
  @override
  void paint(Canvas canvas, Size s) {
    final c = center.alongSize(s);
    final r = s.longestSide * .6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_Glow o) => true;
}

class _Scan extends CustomPainter {
  _Scan(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size s) {
    if (v <= 0 || v >= 1) return;
    final y = s.height * v;
    final r = Rect.fromLTWH(0, y - s.height * .3, s.width, s.height * .3);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.blue.withValues(alpha: 0), C.blue.withValues(alpha: .25)],
        ).createShader(r),
    );
    canvas.drawRect(Rect.fromLTWH(0, y - 2, s.width, 3), Paint()..color = C.white);
  }

  @override
  bool shouldRepaint(_Scan o) => true;
}

class _Network extends CustomPainter {
  _Network(this.bt, this.p);
  final double bt, p;
  static final List<Offset> nodes = () {
    final r = math.Random(42);
    final out = <Offset>[Offset.zero];
    for (final ring in [(7, .2), (11, .38), (15, .56)]) {
      for (var i = 0; i < ring.$1; i++) {
        final a = i / ring.$1 * math.pi * 2 + r.nextDouble() * .4;
        final d = ring.$2 + (r.nextDouble() - .5) * .08;
        out.add(Offset(math.cos(a) * d * 1.3, math.sin(a) * d * .8));
      }
    }
    return out;
  }();
  static final List<(int, int)> edges = () {
    final e = <(int, int)>[];
    for (var i = 1; i < nodes.length; i++) {
      final near = List.generate(nodes.length, (j) => j)..removeWhere((j) => j == i);
      near.sort((a, b) => (nodes[a] - nodes[i]).distance.compareTo((nodes[b] - nodes[i]).distance));
      for (final j in near.take(2)) {
        if (j < i || !e.contains((j, i))) e.add((math.min(i, j), math.max(i, j)));
      }
      if (nodes[i].distance < .3) e.add((0, i));
    }
    return e;
  }();

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    Offset at(int i) => c + Offset(nodes[i].dx * s.width * .72, nodes[i].dy * s.height * 1.05);
    double shown(int i) => seg(bt * 2, i * .5, i * .5 + 1.2); // ~2 nodes per 8th note
    final line = Paint()
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    for (final (a, b) in edges) {
      final v = math.min(shown(a), shown(b));
      if (v <= 0) continue;
      final pa = at(a), pb = at(b);
      line.color = C.blueSoft.withValues(alpha: .55 * v);
      canvas.drawLine(pa, Offset.lerp(pa, pb, v)!, line);
    }
    for (var i = 0; i < nodes.length; i++) {
      final v = Curves.easeOutBack.transform(shown(i));
      if (v <= 0) continue;
      final hub = i == 0;
      final r = (hub ? 13 + p * 5 : 3 + (i % 3)) * v;
      if (hub) {
        canvas.drawCircle(
          at(i),
          r * 4,
          Paint()
            ..shader = RadialGradient(
              colors: [C.blue.withValues(alpha: .6), C.blue.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: at(i), radius: r * 4)),
        );
      }
      canvas.drawCircle(at(i), r, Paint()..color = hub ? C.blue : C.white.withValues(alpha: .9));
    }
  }

  @override
  bool shouldRepaint(_Network o) => true;
}

class _Eq extends StatelessWidget {
  const _Eq({required this.on, required this.color, required this.t});
  final bool on;
  final Color color;
  final double t;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (var i = 0; i < 4; i++) Container(width: 2, height: on ? 3 + 11 * (.5 + .5 * math.sin(t * 9 + i * 1.7)).abs() : 4, color: color)],
    ),
  );
}

class _MiniUI extends StatelessWidget {
  const _MiniUI();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FF), Color(0xFFE6EEFF)]),
    ),
    child: LayoutBuilder(
      builder: (_, c) {
        final u = c.maxWidth / 100;
        return Padding(
          padding: EdgeInsets.all(u * 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SonotMark(size: u * 12),
              SizedBox(height: u * 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: u * 55,
                  height: u * 7,
                  decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(u * 4)),
                ),
              ),
              SizedBox(height: u * 5),
              Container(
                width: u * 80,
                height: u * 5,
                decoration: BoxDecoration(color: C.ink.withValues(alpha: .12), borderRadius: BorderRadius.circular(u * 3)),
              ),
              SizedBox(height: u * 3),
              Container(
                width: u * 62,
                height: u * 5,
                decoration: BoxDecoration(color: C.ink.withValues(alpha: .12), borderRadius: BorderRadius.circular(u * 3)),
              ),
              const Spacer(),
              Container(
                height: u * 11,
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(u * 6),
                  border: Border.all(color: C.line),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
