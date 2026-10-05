import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';
import 'common.dart';

/// A ticking clock shared by the bento tiles' little animations.
mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _tk;
  double time = 0;
  @override
  void initState() {
    super.initState();
    _tk = createTicker((d) => setState(() => time = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _tk.dispose();
    super.dispose();
  }
}

class Talents extends StatelessWidget {
  const Talents({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.vp.width;
    final tal = (tr('tal') as List).cast<List>();
    String title(int i) => tal[i][0] as String;
    String body(int i) => tal[i][1] as String;
    final tiles = <Widget>[
      _Tile(title: title(0), body: body(0), height: 520, child: const _Reasoning()),
      _Tile(title: title(1), body: body(1), height: 250, side: true, child: const _CodeSnippet()),
      _Tile(title: title(3), body: body(3), height: 250, child: const _Wave()),
      _Tile(title: title(4), body: body(4), height: 250, child: const _Memory()),
      _Tile(title: title(2), body: body(2), height: 520, image: 'assets/img/coffee.webp', dark: true, child: const _VisionTags()),
      _Tile(title: title(6), body: body(6), height: 250, child: const _Writing()),
      _Tile(title: title(7), body: body(7), height: 250, child: const _Fast()),
      _Tile(title: title(5), body: body(5), height: 250, side: true, child: const _Lock()),
    ];
    Widget r(int i, Widget c) => Reveal(delay: (i % 4) * 90, child: c);

    Widget grid;
    if (w >= 1000) {
      const g = 16.0;
      grid = Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: r(0, tiles[0])),
              const SizedBox(width: g),
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    r(1, tiles[1]),
                    const SizedBox(height: g),
                    Row(
                      children: [
                        Expanded(flex: 3, child: r(2, tiles[2])),
                        const SizedBox(width: g),
                        Expanded(flex: 4, child: r(3, tiles[3])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: g),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: r(0, tiles[4])),
              const SizedBox(width: g),
              Expanded(
                flex: 8,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 5, child: r(1, tiles[5])),
                        const SizedBox(width: g),
                        Expanded(flex: 3, child: r(2, tiles[6])),
                      ],
                    ),
                    const SizedBox(height: g),
                    r(3, tiles[7]),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      grid = Column(
        children: [for (var i = 0; i < tiles.length; i++) Padding(padding: const EdgeInsets.only(bottom: 14), child: r(i, tiles[i]))],
      );
    }

    return Container(
      color: C.white,
      padding: EdgeInsets.fromLTRB(20, context.vh * 16, 20, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              SectionHead(eyebrow: t('talents.eyebrow'), title: t('talents.t'), center: true),
              const SizedBox(height: 56),
              grid,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t('tal.fine'), style: sans(12, c: C.mute)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.body, required this.height, required this.child, this.side = false, this.image, this.dark = false});
  final String title, body;
  final double height;
  final Widget child;
  final bool side, dark;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isNarrow;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: sans(24, w: FontWeight.w700, c: dark ? C.white : C.ink, ls: -.025),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            body,
            style: sans(15.5, c: dark ? C.white.withValues(alpha: .8) : C.mute, h: 1.45, w: FontWeight.w400),
          ),
        ),
      ],
    );
    return Tilt(
      max: 6,
      child: Container(
        height: mobile && !side && height > 300 ? 440 : (mobile && side ? null : height),
        constraints: BoxConstraints(minHeight: mobile ? 230 : 0),
        decoration: BoxDecoration(
          color: dark ? C.ink : C.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: C.line),
          boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .06), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (image != null) ...[
              Positioned.fill(child: Image.asset(image!, fit: BoxFit.cover)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [const Color(0x00000000), C.ink.withValues(alpha: .85)],
                      stops: const [.35, 1],
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(28),
              child: side && !mobile
                  ? Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 20),
                        Expanded(child: child),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image != null) Expanded(child: child) else copy,
                        if (image != null) copy else ...[const SizedBox(height: 22), if (mobile && side) child else Expanded(child: child)],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reasoning extends StatefulWidget {
  const _Reasoning();
  @override
  State<_Reasoning> createState() => _ReasoningState();
}

class _ReasoningState extends State<_Reasoning> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final steps = tl('tal.steps');
    final active = (time / 1.4).floor() % 4;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: i == active ? C.blue : (i < active ? C.mist : C.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: i == active ? C.blue : C.line),
              boxShadow: i == active ? [BoxShadow(color: C.blue.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 10))] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == active ? C.white.withValues(alpha: .2) : C.mist),
                  child: Center(
                    child: Text(i < active ? '✓' : '${i + 1}', style: mono(12, c: i == active ? C.white : (i < active ? C.blue : C.mute), ls: 0)),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  steps[i],
                  style: sans(16, w: FontWeight.w600, c: i == active ? C.white : C.ink),
                ),
                const Spacer(),
                if (i == active) const SpinningMark(size: 18, color: C.white, seconds: 1),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeSnippet extends StatelessWidget {
  const _CodeSnippet();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF0A0D17), borderRadius: BorderRadius.circular(18)),
    child: Text.rich(
      TextSpan(
        style: mono(13.5, c: const Color(0xFFD7DEF5), w: FontWeight.w400, ls: 0).copyWith(height: 1.75),
        children: [
          TextSpan(
            text: 'def ',
            style: mono(13.5, c: const Color(0xFF7AA2FF), ls: 0),
          ),
          TextSpan(
            text: 'greet',
            style: mono(13.5, c: const Color(0xFFC7A6FF), ls: 0),
          ),
          const TextSpan(text: '(name):\n    '),
          TextSpan(
            text: 'return ',
            style: mono(13.5, c: const Color(0xFF7AA2FF), ls: 0),
          ),
          TextSpan(
            text: 'f"Hi {name}, I\'m Sonot"',
            style: mono(13.5, c: const Color(0xFFA5E88F), ls: 0),
          ),
          const TextSpan(text: '\n\n'),
          TextSpan(
            text: 'greet',
            style: mono(13.5, c: const Color(0xFFC7A6FF), ls: 0),
          ),
          const TextSpan(text: '('),
          TextSpan(
            text: '"Maxwell"',
            style: mono(13.5, c: const Color(0xFFA5E88F), ls: 0),
          ),
          const TextSpan(text: ')'),
        ],
      ),
    ),
  );
}

class _Wave extends StatefulWidget {
  const _Wave();
  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WavePainter(time), size: const Size(double.infinity, 80));
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    const n = 30;
    final w = s.width / n;
    for (var i = 0; i < n; i++) {
      final h = s.height * (.15 + .85 * (.5 + .5 * math.sin(t * 4 + i * .55) * math.sin(t * 1.3 + i * .2)).abs());
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(i * w + w / 2, s.height / 2), width: w * .55, height: h), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = Color.lerp(C.blueSoft, C.blue, i / n)!);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => true;
}

class _Memory extends StatefulWidget {
  const _Memory();
  @override
  State<_Memory> createState() => _MemoryState();
}

class _MemoryState extends State<_Memory> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final chips = tl('tal.chips');
    final cycle = time % 7;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < chips.length; i++)
          Builder(
            builder: (_) {
              final v = Curves.easeOutBack.transform(seg(cycle, i * .35, i * .35 + .5)) * (1 - seg(cycle, 6.2, 6.8));
              final forgotten = i == chips.length - 1 && cycle > 4.5;
              return Opacity(
                opacity: clamp01(v),
                child: Transform.scale(
                  scale: .6 + .4 * clamp01(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: forgotten ? C.white : C.mist,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: forgotten ? const Color(0xFFFF6B6B) : C.line),
                    ),
                    child: Text(
                      chips[i],
                      style: sans(13.5, c: forgotten ? const Color(0xFFFF6B6B) : C.ink2).copyWith(decoration: forgotten ? TextDecoration.lineThrough : null),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _VisionTags extends StatefulWidget {
  const _VisionTags();
  @override
  State<_VisionTags> createState() => _VisionTagsState();
}

class _VisionTagsState extends State<_VisionTags> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final c = time % 4;
    Widget tag(String s, Alignment a, double at) => Align(
      alignment: a,
      child: Transform.scale(
        scale: Curves.easeOutBack.transform(seg(c, at, at + .35)) * (1 - seg(c, 3.6, 3.9)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(8)),
          child: Text(s, style: mono(12, c: C.white, ls: 0)),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (_, box) {
        final y = seg(c, 0, 1.6) * box.maxHeight;
        return Stack(
          children: [
            if (c < 1.6)
              Positioned(
                left: 0,
                right: 0,
                top: y,
                child: Container(height: 2, color: C.white, decoration: null),
              ),
            tag('Latte art · rosetta', const Alignment(-.6, -.6), 1),
            tag('Flat white', const Alignment(.6, -.05), 1.4),
          ],
        );
      },
    );
  }
}

class _Writing extends StatefulWidget {
  const _Writing();
  @override
  State<_Writing> createState() => _WritingState();
}

class _WritingState extends State<_Writing> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final tones = tl('tal.tones');
    final texts = tl('tal.toneText');
    final i = (time / 3.2).floor() % 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k < 3; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: k == i ? C.blue : const Color(0x00FFFFFF), borderRadius: BorderRadius.circular(30)),
                  child: Text(
                    tones[k],
                    style: sans(13.5, w: FontWeight.w600, c: k == i ? C.white : C.mute),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: Text(texts[i], key: ValueKey(i), style: sans(17, h: 1.4)),
        ),
      ],
    );
  }
}

class _Fast extends StatefulWidget {
  const _Fast();
  @override
  State<_Fast> createState() => _FastState();
}

class _FastState extends State<_Fast> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final v = Curves.easeOutCubic.transform(clamp01((time % 5) / 1.2));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          (v * .2).toStringAsFixed(1),
          style: sans(72, w: FontWeight.w800, c: C.blue, ls: -.05, h: 1),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            's',
            style: sans(28, w: FontWeight.w700, c: C.blue),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(t('tal.fast'), style: sans(13, c: C.mute)),
          ),
        ),
      ],
    );
  }
}

class _Lock extends StatefulWidget {
  const _Lock();
  @override
  State<_Lock> createState() => _LockState();
}

class _LockState extends State<_Lock> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    final c = time % 4;
    final up = (seg(c, 1.6, 2) - seg(c, 3.2, 3.6)) * 14;
    return Center(
      child: SizedBox(
        width: 120,
        height: 130,
        child: Stack(
          children: [
            Positioned(
              left: 26,
              right: 26,
              top: 4 - up,
              height: 70,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: C.ink, width: 10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  color: C.blue,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .4), blurRadius: 30, offset: const Offset(0, 14))],
                ),
                child: Center(
                  child: SonotMark(size: 46, color: C.white, rotation: time * .6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
