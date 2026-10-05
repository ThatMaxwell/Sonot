import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';
import 'common.dart';

const peoplePhotos = [
  'assets/img/people-students.webp',
  'assets/img/people-devs.webp',
  'assets/img/people-creator.webp',
  'assets/img/people-pro.webp',
  'assets/img/people-shop.webp',
  'assets/img/people-friends.webp',
];

/* ==========================================================================
   PEOPLE — pinned; the cards slide sideways as you scroll down.
   ========================================================================== */
double peopleCardWidth(BuildContext c) => math.min(440, c.vp.width * .8);
double peopleTrackShift(BuildContext c) {
  final cw = peopleCardWidth(c);
  final track = 6 * cw + 5 * 22 + 48;
  return math.max(0, track - c.vp.width);
}

class People extends StatelessWidget {
  const People({super.key, required this.progress});
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final cards = (tr('people') as List).cast<List>();
    final cw = peopleCardWidth(context);
    final ch = math.min(context.vh * 58, 560.0);
    final shift = peopleTrackShift(context);
    return Container(
      color: C.white,
      padding: const EdgeInsets.only(top: 92),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Eyebrow(t('people.eyebrow')), const SizedBox(height: 14), Heading(t('people.t'))],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: ch,
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, p, _) => OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-p * shift, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          _PersonCard(data: cards[i].cast<String>(), photo: peoplePhotos[i], width: cw, height: ch, drift: (p * shift - i * (cw + 22)) * .08),
                          if (i < cards.length - 1) const SizedBox(width: 22),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, p, _) => Container(
              width: 220,
              height: 3,
              decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(3)),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.data, required this.photo, required this.width, required this.height, required this.drift});
  final List<String> data;
  final String photo;
  final double width, height, drift;

  @override
  Widget build(BuildContext context) => Tilt(
    max: 5,
    glow: C.white,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .14), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(drift.clamp(-60.0, 60.0), 0),
            child: Transform.scale(scale: 1.2, child: Image.asset(photo, fit: BoxFit.cover)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [.25, .6, 1],
                colors: [const Color(0x00000000), C.ink.withValues(alpha: .45), C.ink.withValues(alpha: .92)],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20)),
              child: Text(data[0].toUpperCase(), style: mono(11, c: C.blue, ls: .14)),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data[1],
                  style: sans(math.min(28, width * .065), w: FontWeight.w700, c: C.white, ls: -.03, h: 1.1),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: width * .8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: C.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(5),
                      ),
                    ),
                    child: Text(data[2], style: sans(14, c: C.white, h: 1.4)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(maxWidth: width * .85),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: C.white.withValues(alpha: .94),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: SonotMark(size: 15)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(data[3], style: sans(14, c: C.ink, h: 1.4)),
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
  );
}

/* ==========================================================================
   TRY IT — scripted streaming answers.
   ========================================================================== */
class TryIt extends StatefulWidget {
  const TryIt({super.key});
  @override
  State<TryIt> createState() => _TryItState();
}

class _TryItState extends State<TryIt> {
  int current = 0;
  int run = 0;
  String input = '';
  bool asked = false, thinking = false;
  int shown = 0; // characters revealed
  Timer? timer;
  bool started = false;
  String langAtRun = '';

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void ask(int i) {
    timer?.cancel();
    final my = ++run;
    final q = tl('try.q')[i];
    langAtRun = lang.value;
    setState(() {
      current = i;
      asked = false;
      thinking = false;
      shown = 0;
      input = '';
    });
    var k = 0;
    timer = Timer.periodic(const Duration(milliseconds: 16), (tm) {
      if (my != run) return tm.cancel();
      k += 2;
      setState(() => input = q.substring(0, math.min(k, q.length)));
      if (k >= q.length) {
        tm.cancel();
        Future.delayed(const Duration(milliseconds: 260), () {
          if (my != run || !mounted) return;
          setState(() {
            input = '';
            asked = true;
            thinking = true;
          });
          Future.delayed(const Duration(milliseconds: 900), () {
            if (my != run || !mounted) return;
            setState(() => thinking = false);
            final total = _plain(i).length;
            timer = Timer.periodic(const Duration(milliseconds: 16), (tm2) {
              if (my != run || !mounted) return tm2.cancel();
              setState(() => shown = math.min(total, shown + 3));
              if (shown >= total) tm2.cancel();
            });
          });
        });
      }
    });
  }

  String _plain(int i) => tl('try.a').isEmpty
      ? ''
      : (tr('try.a') as List)[i].cast<String>().map((b) => b.substring(b.indexOf(':') + 1).replaceAll('**', '').replaceAll('`', '')).join();

  @override
  Widget build(BuildContext context) {
    if (lang.value != langAtRun && started) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ask(current));
      langAtRun = lang.value;
    }
    final narrow = context.isNarrow;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(eyebrow: t('try.eyebrow'), title: t('try.t'), sub: t('try.sub')),
        const SizedBox(height: 30),
        for (var i = 0; i < 4; i++)
          Reveal(
            delay: 200 + i * 70,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Press(
                onTap: () {
                  started = true;
                  ask(i);
                },
                builder: (h) => AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  transform: Matrix4.translationValues(h ? 6 : 0, 0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: current == i && started ? C.blue : (h ? C.mist : C.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: current == i && started ? C.blue : C.line),
                  ),
                  child: Text(
                    tl('try.prompts')[i],
                    style: sans(15.5, w: FontWeight.w500, c: current == i && started ? C.white : C.ink),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final window = Reveal(
      delay: 150,
      child: OnVisible(
        onVisible: () {
          if (!started) {
            started = true;
            Future.delayed(const Duration(milliseconds: 500), () => ask(0));
          }
        },
        child: Container(
          height: math.min(580, context.vh * 76),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: C.line),
            boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .14), blurRadius: 70, offset: const Offset(0, 30))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: C.line)),
                ),
                child: Row(
                  children: [
                    for (final c in const [0xFFFF5F57, 0xFFFEBC2E, 0xFF28C840])
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                      ),
                    const Spacer(),
                    const SonotIcon(size: 22),
                    const SizedBox(width: 8),
                    Text('Sonot', style: sans(15, w: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: C.sky, borderRadius: BorderRadius.circular(20)),
                      child: Text(t('try.badge').toUpperCase(), style: mono(10, c: C.blue)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (asked)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: C.blue,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(5),
                              ),
                            ),
                            child: Text(tl('try.q')[current], style: sans(15.5, c: C.white, h: 1.4)),
                          ),
                        ),
                      if (asked) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            thinking ? const SpinningMark(size: 18, seconds: .8) : const SonotMark(size: 18),
                            const SizedBox(width: 8),
                            Text('Sonot', style: sans(15, w: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text(thinking ? t('try.thinking') : tl('try.ms')[current], style: mono(11.5, ls: 0)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!thinking) _Answer(blocks: (tr('try.a') as List)[current].cast<String>(), shown: shown),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                height: 54,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.only(left: 20, right: 7),
                decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(28)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        input.isEmpty ? t('app.ask') : input,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(15, c: input.isEmpty ? C.mute : C.ink),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          '↑',
                          style: sans(17, w: FontWeight.w700, c: C.white),
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
    );
    return Container(
      color: C.white,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: context.vh * 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: narrow
              ? Column(children: [copy, const SizedBox(height: 36), window])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 10, child: copy),
                    const SizedBox(width: 60),
                    Expanded(flex: 12, child: window),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Renders answer blocks ("p:", "li:", "c:", "h:") revealing [shown] characters.
class _Answer extends StatelessWidget {
  const _Answer({required this.blocks, required this.shown});
  final List<String> blocks;
  final int shown;

  List<InlineSpan> _rich(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start), style: base));
      final g = m.group(0)!;
      if (g.startsWith('**')) {
        spans.add(
          TextSpan(
            text: g.substring(2, g.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700, color: C.ink),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: g.substring(1, g.length - 1),
            style: mono(base.fontSize! * .9, c: C.blue, ls: 0),
          ),
        );
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last), style: base));
    return spans;
  }

  /// Cut marked-up text so that only [n] visible characters remain.
  String _cut(String s, int n) {
    final out = StringBuffer();
    var vis = 0, i = 0;
    var open = <String>[];
    while (i < s.length && vis < n) {
      if (s.startsWith('**', i)) {
        open.contains('**') ? open.remove('**') : open.add('**');
        out.write('**');
        i += 2;
        continue;
      }
      if (s[i] == '`') {
        open.contains('`') ? open.remove('`') : open.add('`');
        out.write('`');
        i++;
        continue;
      }
      out.write(s[i]);
      vis++;
      i++;
    }
    for (final o in open.reversed) {
      out.write(o);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    var budget = shown;
    final base = sans(16, c: C.ink2, h: 1.6, w: FontWeight.w400);
    final children = <Widget>[];
    for (final b in blocks) {
      if (budget <= 0) break;
      final kind = b.substring(0, b.indexOf(':'));
      final body = b.substring(b.indexOf(':') + 1);
      final visible = body.replaceAll('**', '').replaceAll('`', '').length;
      final text = _cut(body, budget);
      budget -= visible;
      switch (kind) {
        case 'li':
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 12),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text.rich(TextSpan(children: _rich(text, base)))),
                ],
              ),
            ),
          );
        case 'c':
          children.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF0A0D17), borderRadius: BorderRadius.circular(14)),
              child: Text(
                text,
                style: mono(13.5, c: const Color(0xFFD7DEF5), w: FontWeight.w400, ls: 0).copyWith(height: 1.7),
              ),
            ),
          );
        case 'h':
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(text, style: serif(28, c: C.ink, h: 1.3)),
            ),
          );
        default:
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text.rich(TextSpan(children: _rich(text, base))),
            ),
          );
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
