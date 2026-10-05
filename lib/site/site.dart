import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/bridge.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';
import 'common.dart';
import 'desktop.dart';
import 'people_try.dart';
import 'phones.dart';
import 'talents.dart';

class Site extends StatefulWidget {
  const Site({super.key, required this.revealed, required this.onReplay});
  final ValueListenable<bool> revealed;
  final VoidCallback onReplay;
  @override
  State<Site> createState() => _SiteState();
}

class _SiteState extends State<Site> {
  final scroll = ScrollController();
  final heroP = ValueNotifier<double>(0);
  final maniP = ValueNotifier<double>(0);
  final deskP = ValueNotifier<double>(0);
  final phoneP = ValueNotifier<double>(0);
  final peopleP = ValueNotifier<double>(0);
  final dlP = ValueNotifier<double>(0);
  final pageP = ValueNotifier<double>(0);
  final keys = List.generate(6, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      final vh = MediaQuery.sizeOf(context).height;
      heroP.value = clamp01(scroll.offset / vh);
      final max = scroll.position.maxScrollExtent;
      pageP.value = max > 0 ? clamp01(scroll.offset / max) : 0;
      dlP.value = max > 0 ? clamp01(1 - (max - scroll.offset) / (vh * 1.6)) : 0;
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void jump(int i) {
    final ctx = keys[i].currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final y = box.localToGlobal(Offset.zero).dy + scroll.offset;
    scroll.animateTo(y.clamp(0, scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 1200), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final vh = context.vp.height;
    return ValueListenableBuilder<String>(
      valueListenable: lang,
      builder: (context, _, _) => Container(
        color: C.white,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: scroll,
              child: SmoothWheel(
                controller: scroll,
                child: Column(
                  children: [
                    _Hero(revealed: widget.revealed, progress: heroP, onFilm: widget.onReplay),
                    const _Bands(),
                    Pin(
                      height: vh * 2.6,
                      viewport: vh,
                      progress: maniP,
                      child: _Manifesto(progress: maniP, revealed: widget.revealed),
                    ),
                    KeyedSubtree(
                      key: keys[0],
                      child: Pin(
                        height: vh * 4.7,
                        viewport: vh,
                        progress: deskP,
                        child: RepaintBoundary(child: DesktopShowcase(progress: deskP)),
                      ),
                    ),
                    KeyedSubtree(
                      key: keys[1],
                      child: Pin(
                        height: vh * 2.8,
                        viewport: vh,
                        progress: phoneP,
                        child: RepaintBoundary(child: PhonesShowcase(progress: phoneP)),
                      ),
                    ),
                    KeyedSubtree(key: keys[2], child: const Talents()),
                    KeyedSubtree(
                      key: keys[3],
                      child: Pin(
                        height: vh * 1.2 + peopleTrackShift(context),
                        viewport: vh,
                        progress: peopleP,
                        child: RepaintBoundary(child: People(progress: peopleP)),
                      ),
                    ),
                    KeyedSubtree(key: keys[4], child: const TryIt()),
                    KeyedSubtree(
                      key: keys[5],
                      child: _Download(revealed: widget.revealed, progress: dlP),
                    ),
                    _Footer(onReplay: widget.onReplay),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _Nav(progress: pageP, scroll: scroll, onJump: jump, revealed: widget.revealed),
            ),
            const _Toast(),
          ],
        ),
      ),
    );
  }
}

/* ==========================================================================
   NAV
   ========================================================================== */
class _Nav extends StatelessWidget {
  const _Nav({required this.progress, required this.scroll, required this.onJump, required this.revealed});
  final ValueNotifier<double> progress;
  final ScrollController scroll;
  final void Function(int) onJump;
  final ValueListenable<bool> revealed;

  @override
  Widget build(BuildContext context) {
    final narrow = context.vp.width < 900;
    final items = tl('nav');
    return ValueListenableBuilder<bool>(
      valueListenable: revealed,
      builder: (_, on, child) =>
          AnimatedSlide(duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, offset: Offset(0, on ? 0 : -1.2), child: child),
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, p, _) {
          final scrolled = scroll.hasClients && scroll.offset > 20;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: scrolled ? 18 : 0, sigmaY: scrolled ? 18 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(
                      color: C.white.withValues(alpha: scrolled ? .78 : 0),
                      border: Border(bottom: BorderSide(color: scrolled ? C.line : const Color(0x00FFFFFF))),
                    ),
                    child: Row(
                      children: [
                        Press(
                          onTap: () => scroll.animateTo(0, duration: const Duration(milliseconds: 1200), curve: Curves.easeInOutCubic),
                          builder: (h) => Row(
                            children: [
                              AnimatedRotation(
                                turns: h ? .125 : 0,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutBack,
                                child: const SonotIcon(size: 30),
                              ),
                              const SizedBox(width: 10),
                              Text('Sonot', style: sans(19, w: FontWeight.w700, ls: -.03)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (!narrow)
                          for (var i = 0; i < items.length; i++)
                            Press(
                              onTap: () => onJump(i),
                              builder: (h) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: h ? C.mist : const Color(0x00FFFFFF), borderRadius: BorderRadius.circular(20)),
                                child: Text(items[i], style: sans(14.5, c: h ? C.ink : C.ink2)),
                              ),
                            ),
                        const Spacer(),
                        Press(
                          onTap: () {
                            final next = lang.value == 'pt' ? 'en' : 'pt';
                            Browser.write('sonot.lang', next);
                            lang.value = next;
                          },
                          builder: (h) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 38,
                            width: 48,
                            decoration: BoxDecoration(
                              color: h ? C.mist : C.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: C.line),
                            ),
                            child: Center(
                              child: Text(t('lang.switch'), style: mono(12, c: C.ink, ls: .1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Btn(label: t('download'), onTap: () => onJump(5)),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: p,
                  child: Container(height: 2, color: C.blue),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ==========================================================================
   HERO — "Think in light." + the 3D glass bloom
   ========================================================================== */
class _Hero extends StatefulWidget {
  const _Hero({required this.revealed, required this.progress, required this.onFilm});
  final ValueListenable<bool> revealed;
  final ValueNotifier<double> progress;
  final VoidCallback onFilm;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool mounted3d = false;

  @override
  void initState() {
    super.initState();
    widget.revealed.addListener(_go);
    _go();
  }

  void _go() {
    if (widget.revealed.value && !intro.isAnimating && intro.value == 0) {
      setState(() => mounted3d = true);
      intro.forward();
    }
  }

  @override
  void dispose() {
    widget.revealed.removeListener(_go);
    intro.dispose();
    super.dispose();
  }

  double _v(double a, double b) => Curves.easeOutCubic.transform(seg(intro.value, a, b));

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    final big = mobile ? vp.width * .26 : math.min(vp.width * .15, vp.height * .27);
    return SizedBox(
      height: mobile ? math.max(vp.height * 1.12, 780) : math.max(vp.height, 640),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(center: Alignment(.55, -.1), radius: 1.0, colors: [Color(0xFFE8F0FF), C.white]),
              ),
            ),
          ),
          const Positioned.fill(child: DotGrid(gap: 30)),
          // 3D bloom
          Positioned(
            right: mobile ? -vp.width * .15 : -vp.width * .04,
            top: mobile ? vp.height * .02 : 0,
            width: mobile ? vp.width * 1.3 : vp.width * .62,
            height: mobile ? vp.height * .5 : vp.height,
            child: mounted3d ? ThreeView(kind: 'bloom', progress: widget.progress) : const SizedBox(),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([intro, widget.progress]),
            builder: (context, _) {
              final hp = widget.progress.value;
              return Transform.translate(
                offset: Offset(0, hp * 120),
                child: Opacity(
                  opacity: clamp01(1 - hp * 1.3),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(mobile ? 24 : vp.width * .07, mobile ? math.min(vp.height * .36, 330) : 0, 24, mobile ? 40 : 0),
                    child: Align(
                      alignment: mobile ? Alignment.topLeft : Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fade(_v(0, .35), _pill()),
                          SizedBox(height: mobile ? 14 : 24),
                          _letters(t('hero.t1'), sans(big, w: FontWeight.w800, ls: -.06, h: .92), 0.05),
                          _accentLine(t('hero.t2'), big),
                          SizedBox(height: mobile ? 16 : 28),
                          _fade(
                            _v(.45, .8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 470),
                              child: Text(
                                t('hero.sub'),
                                style: sans(mobile ? 16.5 : 19, c: C.ink2, h: 1.5, w: FontWeight.w400),
                              ),
                            ),
                          ),
                          SizedBox(height: mobile ? 22 : 34),
                          _fade(
                            _v(.55, .9),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Btn(
                                  label: t('dl.for').replaceAll('{os}', osNames[userOS]!),
                                  big: !mobile,
                                  icon: OsGlyph(userOS, size: 20, color: C.white),
                                  onTap: () => download(userOS),
                                ),
                                Btn(
                                  label: t('hero.film'),
                                  kind: 'ghost',
                                  big: !mobile,
                                  icon: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text('▶', style: sans(10, c: C.white)),
                                    ),
                                  ),
                                  trailing: Text('0:50', style: mono(12, ls: 0)),
                                  onTap: widget.onFilm,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _fade(_v(.7, 1), Text(t('hero.plat').toUpperCase(), style: mono(11.5, ls: .14))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!mobile)
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AnimatedBuilder(
                animation: Listenable.merge([intro, widget.progress]),
                builder: (_, _) => Opacity(
                  opacity: _v(.8, 1) * clamp01(1 - widget.progress.value * 4),
                  child: const Center(child: _ScrollCue()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fade(double v, Widget child) => Opacity(
    opacity: v,
    child: Transform.translate(offset: Offset(0, (1 - v) * 26), child: child),
  );

  Widget _pill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: C.line),
      boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PulseDot(),
        const SizedBox(width: 10),
        Text(t('hero.eyebrow'), style: sans(13.5, w: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('→', style: sans(13.5, c: C.blue)),
      ],
    ),
  );

  /// Letters rise in one by one.
  Widget _letters(String s, TextStyle style, double start) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < s.length; i++)
        Builder(
          builder: (_) {
            final v = Curves.easeOutCubic.transform(seg(intro.value, start + i * .04, start + .3 + i * .04));
            return ClipRect(
              child: Transform.translate(
                offset: Offset(0, (1 - v) * style.fontSize! * .9),
                child: Opacity(
                  opacity: v,
                  child: Text(s[i], style: style),
                ),
              ),
            );
          },
        ),
    ],
  );

  Widget _accentLine(String s, double big) {
    final v = Curves.easeOutCubic.transform(seg(intro.value, .22, .62));
    return Opacity(
      opacity: v,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: (1 - v) * 14, sigmaY: (1 - v) * 14),
        child: Transform.translate(
          offset: Offset((1 - v) * -40, 0),
          child: Text.rich(
            TextSpan(
              children: accent(s, sans(big, w: FontWeight.w800, ls: -.06, h: .98)).map((sp) {
                final ts = sp as TextSpan;
                return ts.style?.fontFamily == F.serif
                    ? TextSpan(
                        text: ts.text,
                        style: ts.style!.copyWith(fontSize: big * 1.12),
                      )
                    : ts;
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 8 + c.value * 10,
            height: 8 + c.value * 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.blue.withValues(alpha: (1 - c.value) * .35),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: C.blue),
          ),
        ],
      ),
    ),
  );
}

class _ScrollCue extends StatefulWidget {
  const _ScrollCue();
  @override
  State<_ScrollCue> createState() => _ScrollCueState();
}

class _ScrollCueState extends State<_ScrollCue> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(t('scroll').toUpperCase(), style: mono(10.5, ls: .3)),
      const SizedBox(height: 10),
      AnimatedBuilder(
        animation: c,
        builder: (_, _) => Container(
          width: 2,
          height: 44,
          color: C.line,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, -14 + c.value * 50),
            child: Container(width: 2, height: 14, color: C.blue),
          ),
        ),
      ),
    ],
  );
}

/* ==========================================================================
   BANDS — two crossing marquees (blue + black)
   ========================================================================== */
class _Bands extends StatelessWidget {
  const _Bands();
  Widget _band(List<String> words, Color bg, Color fg, double angle, bool reverse, double speed) => Transform.rotate(
    angle: angle,
    child: Container(
      height: 86,
      color: bg,
      child: Marquee(
        speed: speed,
        reverse: reverse,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final w in words) ...[
              Text(
                w,
                style: sans(40, w: FontWeight.w800, c: fg, ls: -.03),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SonotMark(size: 30, color: fg == C.white ? C.white : C.blue),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: OverflowBox(
      maxWidth: context.vp.width * 1.3,
      child: Stack(
        alignment: Alignment.center,
        children: [_band(tl('marquee2'), C.ink, C.white, .045, true, 50), _band(tl('marquee'), C.blue, C.white, -.035, false, 70)],
      ),
    ),
  );
}

/* ==========================================================================
   MANIFESTO — black, galaxy behind, words light up as you scroll
   ========================================================================== */
class _Manifesto extends StatelessWidget {
  const _Manifesto({required this.progress, required this.revealed});
  final ValueNotifier<double> progress;
  final ValueListenable<bool> revealed;

  @override
  Widget build(BuildContext context) {
    final words = t('manifesto').split(' ');
    final hot = tl('manifesto.hot');
    final fs = math.min(math.max(context.vw * 4.4, 28), 66).toDouble();
    return Container(
      color: C.ink,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: revealed,
              builder: (_, on, _) => on ? ThreeView(kind: 'galaxy', progress: progress) : const SizedBox(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(radius: .9, colors: [C.ink.withValues(alpha: .35), C.ink.withValues(alpha: .85)])),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, p, _) {
                    final lit = seg(p, .06, .82) * (words.length + 1);
                    return Text.rich(
                      TextSpan(
                        children: [
                          for (var i = 0; i < words.length; i++)
                            TextSpan(
                              text: '${words[i]} ',
                              style: sans(
                                fs,
                                w: FontWeight.w700,
                                ls: -.035,
                                h: 1.14,
                              ).copyWith(color: Color.lerp(C.white.withValues(alpha: .14), hot.contains(words[i]) ? C.blueSoft : C.white, clamp01(lit - i))),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ==========================================================================
   DOWNLOAD — electric blue, particle waves, floating 3D icon
   ========================================================================== */
class _Download extends StatefulWidget {
  const _Download({required this.revealed, required this.progress});
  final ValueListenable<bool> revealed;
  final ValueNotifier<double> progress;
  @override
  State<_Download> createState() => _DownloadState();
}

class _DownloadState extends State<_Download> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  double time = 0;
  Offset tilt = Offset.zero;
  @override
  void initState() {
    super.initState();
    tk = createTicker((d) => setState(() => time = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    final plats = ['mac', 'win', 'linux', 'ios', 'android'];
    final subs = tl('dl.plat');
    final req = (tr('dl.req') as Map)[userOS] as String;
    return MouseRegion(
      onHover: (e) => tilt = Offset(e.position.dx / vp.width - .5, e.position.dy / vp.height - .5),
      child: Container(
        constraints: BoxConstraints(minHeight: vp.height),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1466FF), C.blue, C.blueDeep]),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.revealed,
                builder: (_, on, _) => on ? ThreeView(kind: 'waves', progress: widget.progress) : const SizedBox(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, vp.height * .14, 24, vp.height * .1),
              child: Center(
                child: Column(
                  children: [
                    Reveal(
                      scale: .6,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .002)
                          ..translateByDouble(0, math.sin(time * 1.4) * 10, 0, 1)
                          ..rotateY(tilt.dx * .7 + math.sin(time * .7) * .15)
                          ..rotateX(-tilt.dy * .5),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(46),
                            boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .35), blurRadius: 60, offset: const Offset(0, 30))],
                          ),
                          child: _WhiteIcon(size: mobile ? 120 : 160, rotation: time * .25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Reveal(
                      delay: 100,
                      child: Heading(t('dl.t'), size: math.min(math.max(vp.width * .11, 64), 156), color: C.white, accentColor: C.sky, align: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      delay: 180,
                      child: Text(
                        t('dl.sub'),
                        textAlign: TextAlign.center,
                        style: sans(mobile ? 17 : 20, c: C.white.withValues(alpha: .85), w: FontWeight.w400),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Reveal(
                      delay: 260,
                      child: Btn(
                        label: t('dl.for').replaceAll('{os}', osNames[userOS]!),
                        kind: 'white',
                        big: true,
                        icon: OsGlyph(userOS, size: 22, color: C.blue),
                        onTap: () => download(userOS),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Reveal(
                      delay: 300,
                      child: Text('${t('dl.version')} · $req', style: mono(11.5, c: C.white.withValues(alpha: .7), ls: .08)),
                    ),
                    SizedBox(height: vp.height * .09),
                    Reveal(
                      delay: 340,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < plats.length; i++)
                            Press(
                              onTap: () => download(plats[i]),
                              builder: (h) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: mobile ? (vp.width - 60) / 2 : 176,
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                transform: Matrix4.translationValues(0, h ? -6 : 0, 0),
                                decoration: BoxDecoration(
                                  color: h || plats[i] == userOS ? C.white : C.white.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: C.white.withValues(alpha: .3)),
                                ),
                                child: Column(
                                  children: [
                                    OsGlyph(plats[i], size: 30, color: h || plats[i] == userOS ? C.blue : C.white),
                                    const SizedBox(height: 12),
                                    Text(
                                      osNames[plats[i]] == 'iPhone' ? 'iOS' : osNames[plats[i]]!,
                                      style: sans(17, w: FontWeight.w700, c: h || plats[i] == userOS ? C.ink : C.white),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(subs[i], style: sans(12.5, c: h || plats[i] == userOS ? C.mute : C.white.withValues(alpha: .7))),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteIcon extends StatelessWidget {
  const _WhiteIcon({required this.size, required this.rotation});
  final double size, rotation;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: C.white,
      borderRadius: BorderRadius.circular(size * 268 / 1024),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.white, Color(0xFFE6EEFF)]),
    ),
    child: Center(
      child: SonotMark(size: size, color: C.blue, rotation: rotation),
    ),
  );
}

/* ==========================================================================
   FOOTER — black, ThatMaxwell
   ========================================================================== */
class _Footer extends StatelessWidget {
  const _Footer({required this.onReplay});
  final VoidCallback onReplay;
  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    Widget link(String s, VoidCallback f) => Press(
      onTap: f,
      builder: (h) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(s, style: sans(15, c: h ? C.white : C.white.withValues(alpha: .65))),
      ),
    );
    return Container(
      color: C.ink,
      padding: const EdgeInsets.fromLTRB(28, 64, 28, 0),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: math.min(1200, vp.width - 56)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 24,
              children: [
                Press(
                  onTap: () => Browser.open(SonotConfig.github),
                  builder: (h) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: h ? 1 : 0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutBack,
                        builder: (_, v, _) => MaxwellMark(size: 48, color: C.white, rotation: v * math.pi / 2),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t('foot.made'), style: sans(13, c: C.white.withValues(alpha: .55))),
                          Text(
                            'ThatMaxwell',
                            style: sans(22, w: FontWeight.w700, c: C.white, ls: -.02),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [link('GitHub', () => Browser.open(SonotConfig.github)), link(t('foot.replay'), onReplay)]),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t('foot.rights'), style: sans(13, c: C.white.withValues(alpha: .4))),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: vp.width * .2,
            child: OverflowBox(
              maxHeight: vp.width * .3,
              alignment: Alignment.topCenter,
              child: ShaderMask(
                shaderCallback: (r) =>
                    const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.blue, Color(0x000B5CFF)]).createShader(r),
                child: Text(
                  'Sonot',
                  style: sans(vp.width * .26, w: FontWeight.w800, c: C.white, ls: -.07, h: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: toast,
    builder: (_, msg, _) => Positioned(
      left: 0,
      right: 0,
      bottom: 28,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 350),
          opacity: msg == null ? 0 : 1,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            offset: Offset(0, msg == null ? .5 : 0),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: C.ink,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .3), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SonotMark(size: 18, color: C.blueSoft),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(msg ?? '', style: sans(14.5, c: C.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
