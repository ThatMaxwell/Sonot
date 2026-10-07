import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bud_avatar.dart';
import 'common.dart';

/// The word "buds", always lowercase in its own round font.
TextStyle budsStyle(double size, {Color c = C.ink, double weight = 600}) =>
    TextStyle(fontFamily: F.toy, fontSize: size, height: 1, color: c, fontVariations: [FontVariation('wght', weight)]);

class _SoonBadge extends StatelessWidget {
  const _SoonBadge({this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: dark ? C.white.withValues(alpha: .08) : C.sky,
      borderRadius: BorderRadius.circular(20),
      border: dark ? Border.all(color: C.white.withValues(alpha: .18)) : null,
    ),
    child: Text(t('soon').toUpperCase(), style: mono(10, c: dark ? C.blueSoft : C.blue, ls: .12)),
  );
}

/// Fades and lifts a piece of a pinned scene in as `v` goes 0 → 1.
Widget _rise(double v, Widget child, {double dy = 40}) => Opacity(
  opacity: clamp01(v),
  child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: child),
);

/* ==========================================================================
   SONOT BUDS — pinned scene. The wordmark pops in, then the four starter
   buds drop in one by one (surprised mid-air, happy on landing), settle into
   their own moods, and the features line up underneath.
   ========================================================================== */
const _starters = [
  ('Pip', BudShape.circle, Color(0xFFF6B73C)),
  ('Scout', BudShape.triangle, Color(0xFFFF7A59)),
  ('Byte', BudShape.square, Color(0xFF2F6BFF)),
  ('Moss', BudShape.capsule, Color(0xFF5FBF7A)),
];
const _settled = [BudEmotion.happy, BudEmotion.curious, BudEmotion.focused, BudEmotion.sleepy];
const _finale = [BudEmotion.wink, BudEmotion.excited, BudEmotion.happy, BudEmotion.shy];

class BudsShowcase extends StatelessWidget {
  const BudsShowcase({super.key, required this.progress});
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    final jobs = tl('buds.jobs');
    final feats = (tr('buds.feats') as List).cast<List>();
    final cardW = mobile ? 168.0 : 240.0;
    return Container(
      color: C.mist,
      padding: EdgeInsets.fromLTRB(20, 84, 20, mobile ? 20 : 30),
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, p, _) {
          final word = Curves.easeOutBack.transform(seg(p, 0, .14));
          Widget bud(int i) {
            final land = seg(p, .16 + i * .07, .3 + i * .07);
            final e = Curves.easeOutBack.transform(land);
            final side = (i - 1.5) / 1.5; // -1 … 1
            final emo = land < 1 ? BudEmotion.surprised : (p > .82 ? _finale[i] : (p > .55 ? _settled[i] : BudEmotion.happy));
            final (name, shape, color) = _starters[i];
            return Opacity(
              opacity: clamp01(land * 3),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(side * (1 - e) * 220, (1 - e) * -320, 0, 1)
                  ..rotateZ((1 - e) * side * .6),
                child: Container(
                  width: cardW,
                  padding: EdgeInsets.fromLTRB(16, mobile ? 18 : 24, 16, mobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: C.line),
                  ),
                  child: Column(
                    children: [
                      BudAvatar(shape: shape, color: color, size: mobile ? 70 : 96, emotion: emo),
                      SizedBox(height: mobile ? 12 : 16),
                      Text(name, style: sans(mobile ? 17 : 19, w: FontWeight.w700, ls: -.02)),
                      const SizedBox(height: 5),
                      Text(jobs[i], textAlign: TextAlign.center, style: sans(mobile ? 13 : 14, c: C.mute, w: FontWeight.w400, h: 1.4)),
                    ],
                  ),
                ),
              ),
            );
          }

          final content = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: clamp01(word * 2),
                child: Transform.scale(
                  scale: lerpD(.5, 1, word),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('buds', style: budsStyle(mobile ? 96 : 150)),
                      const SizedBox(width: 12),
                      Padding(padding: EdgeInsets.only(bottom: mobile ? 10 : 18), child: Text(t('buds.by'), style: mono(12, c: C.mute, ls: .16))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _rise(seg(p, .05, .17), Heading(t('buds.t'), align: TextAlign.center, size: mobile ? 34 : 56)),
              if (!mobile) ...[
                const SizedBox(height: 16),
                _rise(
                  seg(p, .09, .21),
                  SizedBox(
                    width: 620,
                    child: Text(t('buds.sub'), textAlign: TextAlign.center, style: sans(18, c: C.mute, h: 1.5, w: FontWeight.w400)),
                  ),
                ),
              ],
              SizedBox(height: mobile ? 30 : 48),
              SizedBox(
                width: mobile ? cardW * 2 + 14 : cardW * 4 + 16 * 3,
                child: Wrap(spacing: mobile ? 14 : 16, runSpacing: 14, alignment: WrapAlignment.center, children: [for (var i = 0; i < 4; i++) bud(i)]),
              ),
              SizedBox(height: mobile ? 24 : 36),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < feats.length; i++)
                    _rise(
                      seg(p, .62 + i * .06, .74 + i * .06),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: C.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(feats[i][0] as String, style: sans(14.5, w: FontWeight.w700)),
                            if (feats[i][2] == true) ...[const SizedBox(width: 8), const _SoonBadge()] else const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      dy: 24,
                    ),
                ],
              ),
            ],
          );
          // Always fits one screen, from small phones to big monitors.
          return Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: math.max(vp.width - 40, 320), child: content)),
          );
        },
      ),
    );
  }
}

/* ==========================================================================
   SONOT CODE — pinned scene. The lights go out (white → ink, the darker
   Code mode), a terminal window rises, and scrolling drives the agent run
   line by line: ask, test, fail, fix, pass, ask before pushing, PR opened.
   ========================================================================== */
class CodeShowcase extends StatelessWidget {
  const CodeShowcase({super.key, required this.progress});
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final stacked = vp.width < 1000;
    final caps = tl('code.caps');
    final run = (tr('code.run') as List).cast<List>();
    final allTabs = tl('code.tabs');
    // Narrow phones show two tabs so the header never overflows.
    final tabs = vp.width < 440 ? allTabs.take(2).toList() : allTabs;
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (_, p, _) {
        final dark = Curves.easeInOutCubic.transform(seg(p, 0, .14));
        final bg = Color.lerp(C.mist, C.ink, dark)!;
        final fg = Color.lerp(C.ink, C.white, dark)!;
        final win = Curves.easeOutCubic.transform(seg(p, .1, .26));
        final lines = (seg(p, .26, .86) * run.length).ceil();
        final done = p > .88;
        final winW = stacked ? math.min(560.0, vp.width - 40) : 600.0;

        final head = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _rise(
              seg(p, .02, .12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [Eyebrow('Sonot Code', color: Color.lerp(C.blue, C.blueSoft, dark)!), const SizedBox(width: 12), _SoonBadge(dark: dark > .5)],
              ),
            ),
            const SizedBox(height: 16),
            _rise(seg(p, .04, .16), Heading(t('code.t'), color: fg, accentColor: C.blueSoft, size: stacked ? 40 : 72)),
            const SizedBox(height: 16),
            _rise(
              seg(p, .08, .2),
              SizedBox(
                width: stacked ? winW : 500,
                child: Text(t('code.sub'), style: sans(stacked ? 16 : 18, c: fg.withValues(alpha: .7), h: 1.5, w: FontWeight.w400)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: stacked ? winW : 500,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < caps.length; i++)
                    _rise(
                      seg(p, .14 + i * .03, .22 + i * .03),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: C.white.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: C.white.withValues(alpha: .16)),
                        ),
                        child: Text(caps[i], style: mono(12.5, c: C.white.withValues(alpha: .85))),
                      ),
                      dy: 16,
                    ),
                ],
              ),
            ),
          ],
        );

        final window = Opacity(
          opacity: clamp01(win * 1.5),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0008)
              ..translateByDouble(0, (1 - win) * 160, 0, 1)
              ..rotateX((1 - win) * .5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: winW,
              decoration: BoxDecoration(
                color: const Color(0xFF0E1018),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: done ? C.green.withValues(alpha: .55) : C.white.withValues(alpha: .12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.white.withValues(alpha: .08)))),
                    child: Row(
                      children: [
                        Text('Sonot Code', style: sans(14, w: FontWeight.w700, c: C.white)),
                        const SizedBox(width: 18),
                        for (var i = 0; i < tabs.length; i++)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: i == 0 ? C.white.withValues(alpha: .1) : const Color(0x00000000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tabs[i], style: mono(11.5, c: C.white.withValues(alpha: i == 0 ? .9 : .45))),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 372,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < math.min(lines, run.length); i++)
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: _line(run[i][0] as String, run[i][1] as String)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final content = stacked
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: winW, child: head), const SizedBox(height: 30), window])
            : Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 520, child: head), const SizedBox(width: 56), window]);
        return Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 84, 20, 20),
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: content)),
        );
      },
    );
  }

  Widget _line(String kind, String text) => switch (kind) {
    'you' => Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: sans(14.5, c: C.white, w: FontWeight.w600)),
      ),
    ),
    'cmd' => Text('\$ $text', style: mono(13.5, c: C.white)),
    'ok' => Text(text, style: mono(13.5, c: C.green)),
    'err' => Text(text, style: mono(13.5, c: const Color(0xFFFF6B6B))),
    'ask' => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5A524).withValues(alpha: .6)),
      ),
      child: Text('✋  $text', style: sans(13.5, c: const Color(0xFFF5C46B), w: FontWeight.w500)),
    ),
    _ => Text('•  $text', style: sans(14, c: C.white.withValues(alpha: .6), w: FontWeight.w400)),
  };
}
