import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import 'common.dart';

/// Three phones that fan out as you scroll. Each phone is drawn on a fixed
/// 390×844 canvas and scaled, so the screens stay pixel-consistent.
class PhonesShowcase extends StatelessWidget {
  const PhonesShowcase({super.key, required this.progress});
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    final pw = math.min(mobile ? vp.width * .5 : vp.width * .2, (vp.height - (mobile ? 260 : 300)) * .46).clamp(120.0, 300.0);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.white, C.mist, C.white]),
      ),
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 20),
      child: Column(
        children: [
          SectionHead(eyebrow: t('phones.eyebrow'), title: t('phones.t'), sub: mobile ? null : t('phones.sub'), center: true),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, p, _) {
                final e = Curves.easeInOutCubic.transform(seg(p, 0, .5));
                final drift = (p - .5) * 50;
                final spread = mobile ? pw * .62 : pw * 1.12;
                Widget phone(Widget screen, double side) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0011)
                    ..translateByDouble(side * spread * e, (1 - e) * 180 - drift * (side == 0 ? 1 : .5) + (side == 0 ? -20 : 10), 0, 1)
                    ..rotateY(-side * (.35 * (1 - e) + .18))
                    ..rotateZ(side * .05 * e)
                    ..scaleByDouble(side == 0 ? 1 : .9, side == 0 ? 1 : .9, 1, 1),
                  child: _Phone(width: pw, child: screen),
                );
                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [phone(const _LockScreen(), -1), phone(const _VoiceScreen(), 1), phone(const _ChatScreen(), 0)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 844 / 390,
    padding: EdgeInsets.all(width * .032),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2D36), Color(0xFF0B0C11), Color(0xFF1C1E26)]),
      borderRadius: BorderRadius.circular(width * .16),
      boxShadow: [
        BoxShadow(color: C.blue.withValues(alpha: .22), blurRadius: 70, offset: const Offset(0, 36)),
        BoxShadow(color: C.ink.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 12)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(width * .13),
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 390,
          height: 844,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              const _PunchHole(),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Android-style punch-hole front camera.
class _PunchHole extends StatelessWidget {
  const _PunchHole();
  @override
  Widget build(BuildContext context) => Positioned(
    top: 16,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
      ),
    ),
  );
}

Widget _status(Color c) => Padding(
  padding: const EdgeInsets.fromLTRB(32, 18, 30, 0),
  child: Row(
    children: [
      Text(
        '10:24',
        style: sans(16, w: FontWeight.w700, c: c),
      ),
      const Spacer(),
      for (final w in const [18.0, 16.0])
        Container(
          margin: const EdgeInsets.only(left: 6),
          width: w,
          height: 11,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
      Container(
        margin: const EdgeInsets.only(left: 6),
        width: 26,
        height: 12,
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.4),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(1.6),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: .8,
          child: Container(color: c),
        ),
      ),
    ],
  ),
);

class _LockScreen extends StatelessWidget {
  const _LockScreen();
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/img/phone-mountain.webp', fit: BoxFit.cover),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.ink.withValues(alpha: .25), const Color(0x00000000), C.ink.withValues(alpha: .35)],
          ),
        ),
      ),
      Column(
        children: [
          _status(C.white),
          const SizedBox(height: 46),
          Text(
            t('ph.date'),
            style: sans(20, w: FontWeight.w600, c: C.white),
          ),
          Text(
            '10:24',
            style: sans(104, w: FontWeight.w600, c: C.white, ls: -.04, h: 1),
          ),
          const Spacer(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.white.withValues(alpha: .86), borderRadius: BorderRadius.circular(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SonotIcon(size: 24),
                    const SizedBox(width: 8),
                    Text('Sonot', style: sans(15, w: FontWeight.w700)),
                    const Spacer(),
                    Text(t('ph.now'), style: sans(13, c: C.mute)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t('ph.widget'), style: sans(15.5, h: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: C.white.withValues(alpha: .78), borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                const SonotIcon(size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sonot', style: sans(14, w: FontWeight.w700)),
                      Text(t('ph.notif'), style: sans(14, c: C.ink2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 46),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: C.ink.withValues(alpha: .3), shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 34),
        ],
      ),
    ],
  );
}

class _ChatScreen extends StatelessWidget {
  const _ChatScreen();
  @override
  Widget build(BuildContext context) => Container(
    color: C.white,
    child: Column(
      children: [
        _status(C.ink),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
          child: Row(
            children: [
              Text('←', style: sans(26, c: C.blue, h: 1)),
              const Spacer(),
              Text(t('ph.chatTitle'), style: sans(17, w: FontWeight.w700)),
              const Spacer(),
              Text('⋮', style: sans(26, c: C.blue, h: 1)),
            ],
          ),
        ),
        Container(height: 1, color: C.line),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: C.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(t('ph.user'), style: sans(16, c: C.white, h: 1.4)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const SonotMark(size: 18),
                    const SizedBox(width: 6),
                    Text('Sonot', style: sans(15, w: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(t('ph.draftIntro'), style: sans(16, c: C.ink2)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.mist,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('ph.draftSubject'), style: sans(15, w: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(t('ph.draft'), style: sans(15, c: C.ink2, h: 1.45)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (i, a) in tl('ph.acts').indexed)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: i == 2 ? C.blue : C.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: i == 2 ? C.blue : C.line),
                        ),
                        child: Text(
                          a,
                          style: sans(14, w: FontWeight.w600, c: i == 2 ? C.white : C.ink),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 34),
          height: 54,
          padding: const EdgeInsets.only(left: 18, right: 6),
          decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              Expanded(
                child: Text(t('ph.msg'), style: sans(16, c: C.mute)),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoiceScreen extends StatefulWidget {
  const _VoiceScreen();
  @override
  State<_VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<_VoiceScreen> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  double time = 0;
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
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(0, -.2), radius: 1.1, colors: [Color(0xFF3B7BFF), C.blue, C.blueDeep]),
    ),
    child: Column(
      children: [
        _status(C.white),
        const SizedBox(height: 50),
        Text(t('ph.listening').toUpperCase(), style: mono(13, c: C.white.withValues(alpha: .75), ls: .25)),
        const SizedBox(height: 40),
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var k = 0; k < 2; k++)
                Builder(
                  builder: (_) {
                    final v = ((time / 2.6) + k * .5) % 1;
                    return Container(
                      width: 180 + v * 140,
                      height: 180 + v * 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: C.white.withValues(alpha: (1 - v) * .5), width: 1.5),
                      ),
                    );
                  },
                ),
              CustomPaint(size: const Size.square(200), painter: _TalkingBloom(time)),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            t('ph.you'),
            textAlign: TextAlign.center,
            style: sans(17, c: C.white.withValues(alpha: .75), h: 1.35),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            t('ph.ans'),
            textAlign: TextAlign.center,
            style: sans(21, w: FontWeight.w700, c: C.white, h: 1.3),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in [C.white.withValues(alpha: .18), const Color(0xFFFF3B30), C.white.withValues(alpha: .18)])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    ),
  );
}

class _TalkingBloom extends CustomPainter {
  _TalkingBloom(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawCircle(
      s.center(Offset.zero),
      s.width * .55,
      Paint()..shader = RadialGradient(colors: [C.white.withValues(alpha: .35), C.white.withValues(alpha: 0)]).createShader(Offset.zero & s),
    );
    paintBloom(canvas, Offset.zero & s, color: C.white, rotation: t * .35, scale: (i) => .82 + .22 * (.5 + .5 * math.sin(t * 6 + i * 1.1)));
  }

  @override
  bool shouldRepaint(_TalkingBloom o) => true;
}
