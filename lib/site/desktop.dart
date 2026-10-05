import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/motion.dart';
import 'common.dart';

/// Pinned desktop showcase. The whole "computer" is laid out on a fixed
/// 1600×1000 canvas and scaled to fit, so it looks identical at any size.
class DesktopShowcase extends StatefulWidget {
  const DesktopShowcase({super.key, required this.progress});
  final ValueNotifier<double> progress;
  @override
  State<DesktopShowcase> createState() => _DesktopShowcaseState();
}

class _DesktopShowcaseState extends State<DesktopShowcase> {
  String os = userOS == 'win' || userOS == 'linux' ? userOS : 'mac';

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    return Container(
      color: C.white,
      child: Stack(
        children: [
          const Positioned.fill(child: DotGrid()),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 92, 24, mobile ? 30 : 24),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Flex(
                    direction: mobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: mobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      if (mobile) _head(context) else Expanded(child: _head(context)),
                      SizedBox(height: mobile ? 16 : 0),
                      _tabs(),
                    ],
                  ),
                ),
                SizedBox(height: vp.height < 700 ? 14 : 28),
                Expanded(
                  child: ValueListenableBuilder<double>(valueListenable: widget.progress, builder: (_, p, _) => _stage(p)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _head(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(t('desk.eyebrow')),
      const SizedBox(height: 12),
      Heading(t('desk.t'), size: math.min(math.max(context.vw * 4.6, 32), 64)),
    ],
  );

  Widget _tabs() {
    const tabs = [('mac', 'macOS'), ('win', 'Windows'), ('linux', 'Linux')];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.mist,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs)
            Press(
              onTap: () => setState(() => os = tab.$1),
              builder: (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: os == tab.$1 ? C.blue : const Color(0x00FFFFFF),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: os == tab.$1 ? [BoxShadow(color: C.blue.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))] : null,
                ),
                child: Center(
                  child: Text(
                    tab.$2,
                    style: sans(14, w: FontWeight.w600, c: os == tab.$1 ? C.white : (h ? C.ink : C.mute)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stage(double p) {
    final a = Curves.easeInOutCubic.transform(seg(p, 0, .15));
    final notes = tl('desk.notes');
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0007)
                ..translateByDouble(0, (1 - a) * 60, 0, 1)
                ..rotateX((1 - a) * .62)
                ..scaleByDouble(.78 + a * .22, .78 + a * .22, 1, 1),
              child: AspectRatio(
                aspectRatio: 1.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: C.blue.withValues(alpha: .22), blurRadius: 80, offset: const Offset(0, 40)),
                      BoxShadow(color: C.ink.withValues(alpha: .18), blurRadius: 30, offset: const Offset(0, 14)),
                    ],
                  ),
                  padding: const EdgeInsets.all(7),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: 1600,
                        height: 1000,
                        child: _Computer(os: os, p: p),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: (i == 0 ? p > .18 && p < .66 : p >= .7) ? 1 : 0,
                  child: Text(
                    notes[i],
                    textAlign: TextAlign.center,
                    style: sans(15, c: C.mute),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Computer extends StatelessWidget {
  const _Computer({required this.os, required this.p});
  final String os;
  final double p;

  @override
  Widget build(BuildContext context) {
    final wall = {'mac': 'wall-sonoma', 'win': 'wall-peaks', 'linux': 'wall-starry'}[os]!;
    final w = Curves.easeOutCubic.transform(seg(p, .16, .27));
    final quickOn = p > .69;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Image.asset('assets/img/$wall.webp', key: ValueKey(wall), fit: BoxFit.cover, width: 1600, height: 1000),
          ),
        ),
        if (os == 'mac') _macBar(),
        if (os == 'linux') _linuxBar(),
        // App window
        Positioned(
          left: os == 'linux' ? 250 : 225,
          top: os == 'win' ? 90 : 120,
          width: 1150,
          height: 740,
          child: Opacity(
            opacity: clamp01(w * 2.2),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0, (1 - w) * 260, 0, 1)
                ..scaleByDouble(.12 + .88 * w, .12 + .88 * w, 1, 1),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: quickOn ? .55 : 1,
                child: _AppWindow(os: os, p: p),
              ),
            ),
          ),
        ),
        // Quick Ask
        Positioned(
          left: 480,
          top: 220,
          width: 640,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            offset: Offset(0, quickOn ? 0 : -.08),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: quickOn ? 1 : 0,
              child: _QuickAsk(p: p),
            ),
          ),
        ),
        if (os == 'mac') _dock(w > .4, p),
        if (os == 'win') _taskbar(),
        if (os == 'linux') _dash(),
      ],
    );
  }

  Widget _macBar() => Positioned(
    left: 0,
    right: 0,
    top: 0,
    height: 36,
    child: Container(
      color: C.white.withValues(alpha: .35),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 20),
          Text('Sonot', style: sans(15, w: FontWeight.w700)),
          for (final m in tl('os.menu'))
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(m, style: sans(15)),
            ),
          const Spacer(),
          const SonotMark(size: 18, color: C.ink),
          const SizedBox(width: 18),
          Text(t('os.clock'), style: sans(15)),
        ],
      ),
    ),
  );

  Widget _linuxBar() => Positioned(
    left: 0,
    right: 0,
    top: 0,
    height: 34,
    child: Container(
      color: const Color(0xFF111114),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: C.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Text(
              t('os.activities'),
              style: sans(14, c: C.white, w: FontWeight.w600),
            ),
          ),
          const Spacer(),
          Text(
            t('os.clock'),
            style: sans(14, c: C.white, w: FontWeight.w600),
          ),
          const Spacer(),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(color: C.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(6)),
          ),
        ],
      ),
    ),
  );

  Widget _dock(bool open, double p) {
    final bounce = p > .13 && p < .2 ? math.sin((p - .13) / .07 * math.pi * 2).abs() * 22 : 0.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: C.white.withValues(alpha: .3),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: C.white.withValues(alpha: .4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in const [0xFF46B4FF, 0xFFFF9F1C, 0xFF34D17A, 0xFFFF4D6D]) _appIcon(Color(c)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: Offset(0, -bounce),
                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: SonotIcon(size: 62)),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: open ? C.ink : const Color(0x00000000), shape: BoxShape.circle),
                  ),
                ],
              ),
              for (final c in const [0xFF9B5DE5, 0xFF8D99AE]) _appIcon(Color(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appIcon(Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(15)),
    ),
  );

  Widget _taskbar() => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: 64,
    child: Container(
      color: C.white.withValues(alpha: .78),
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OsGlyph('win', size: 34, color: C.blue),
                const SizedBox(width: 18),
                for (final c in const [0xFFFFC300, 0xFF2EC4B6, 0xFF8338EC])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SonotIcon(size: 38)),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text('9:41\n10/4/2026', textAlign: TextAlign.right, style: sans(13, h: 1.3)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dash() => Positioned(
    left: 14,
    top: 300,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xEE16161A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          for (final c in const [0xFFFF7A00, 0xFF2EC4B6])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(14)),
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: SonotIcon(size: 56)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: const Color(0xFF6C757D), borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppWindow extends StatelessWidget {
  const _AppWindow({required this.os, required this.p});
  final String os;
  final double p;

  @override
  Widget build(BuildContext context) {
    final chats = tl('app.chats');
    return Container(
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(os == 'win' ? 12 : 20),
        border: Border.all(color: C.ink.withValues(alpha: .08)),
        boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .28), blurRadius: 80, offset: const Offset(0, 40))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.line)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                if (os == 'mac')
                  for (final c in const [0xFFFF5F57, 0xFFFEBC2E, 0xFF28C840])
                    Container(
                      margin: const EdgeInsets.only(right: 9),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle),
                    ),
                if (os != 'mac')
                  Text(
                    'Sonot',
                    style: sans(15, w: FontWeight.w600, c: C.ink2),
                  ),
                const Spacer(),
                if (os == 'mac')
                  Text(
                    'Sonot',
                    style: sans(15, w: FontWeight.w600, c: C.ink2),
                  ),
                const Spacer(),
                if (os != 'mac') ...[
                  for (final g in const ['—', '□', '✕'])
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Text(g, style: sans(15, c: C.ink2)),
                    ),
                ] else
                  const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 270,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F9FD),
                    border: Border(right: BorderSide(color: C.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SonotIcon(size: 30),
                          const SizedBox(width: 10),
                          Text('Sonot', style: sans(19, w: FontWeight.w700, ls: -.02)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Text(
                              '+  ${t('app.new')}',
                              style: sans(15, w: FontWeight.w600, c: C.white),
                            ),
                            const Spacer(),
                            Text('⌘N', style: mono(12, c: C.white.withValues(alpha: .7), ls: 0)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.line),
                        ),
                        child: Row(
                          children: [Text(t('app.search'), style: sans(14.5, c: C.mute))],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(t('app.today').toUpperCase(), style: mono(11, ls: .14)),
                      const SizedBox(height: 6),
                      for (var i = 0; i < chats.length; i++) ...[
                        if (i == 3) ...[const SizedBox(height: 12), Text(t('app.week').toUpperCase(), style: mono(11, ls: .14)), const SizedBox(height: 6)],
                        Container(
                          height: 38,
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: i == 0 ? C.sky : const Color(0x00FFFFFF), borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            chats[i],
                            overflow: TextOverflow.ellipsis,
                            style: sans(14.5, c: i == 0 ? C.blue : C.ink2, w: i == 0 ? FontWeight.w600 : FontWeight.w500),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [C.blue, Color(0xFF6A3CFF)]),
                            ),
                            child: Center(
                              child: Text(
                                'M',
                                style: sans(15, w: FontWeight.w700, c: C.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Maxwell', style: sans(14.5, w: FontWeight.w600)),
                              Text(t('app.plan'), style: sans(12, c: C.mute)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: _Chat(p: p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chat extends StatelessWidget {
  const _Chat({required this.p});
  final double p;

  Widget _step(bool on, Widget child) => AnimatedOpacity(
    duration: const Duration(milliseconds: 500),
    opacity: on ? 1 : 0,
    child: AnimatedSlide(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic, offset: Offset(0, on ? 0 : .15), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final stream = t('app.stream');
    final n = (seg(p, .36, .55) * stream.length).round();
    final cards = (tr('app.cards') as List).cast<List>();
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              Text(tl('app.chats')[0], style: sans(16, w: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(20)),
                child: Text('Sonot 1  ▾', style: sans(13, c: C.ink2)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 30, 56, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _step(
                  p > .29,
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: C.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(t('app.user'), style: sans(16, c: C.white, h: 1.45)),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _step(
                  p > .35,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          p < .55 ? const SpinningMark(size: 20, seconds: .9) : const SonotMark(size: 20),
                          const SizedBox(width: 8),
                          Text('Sonot', style: sans(16, w: FontWeight.w700)),
                          const SizedBox(width: 10),
                          Text(t('app.thought'), style: sans(13, c: C.mute)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: Text(
                          stream.substring(0, n),
                          style: sans(16, c: C.ink2, h: 1.6, w: FontWeight.w400),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _step(
                  p > .56,
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 14 : 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: C.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: C.line),
                              boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 8))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((cards[i][0] as String).toUpperCase(), style: mono(11, c: C.blue)),
                                const SizedBox(height: 6),
                                Text(cards[i][1] as String, style: sans(16, w: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(cards[i][2] as String, style: sans(13, c: C.mute)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _step(
                  p > .62,
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in tl('app.chips'))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: C.line),
                          ),
                          child: Text(c, style: sans(13.5, c: C.ink2)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: 58,
          margin: const EdgeInsets.fromLTRB(56, 0, 56, 22),
          padding: const EdgeInsets.only(left: 22, right: 8),
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: C.line),
            boxShadow: [BoxShadow(color: C.blue.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Text('+', style: sans(22, c: C.mute)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(t('app.ask'), style: sans(15.5, c: C.mute)),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '↑',
                    style: sans(18, w: FontWeight.w700, c: C.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAsk extends StatelessWidget {
  const _QuickAsk({required this.p});
  final double p;
  @override
  Widget build(BuildContext context) {
    final q = t('app.quick');
    final n = (seg(p, .71, .79) * q.length).round();
    final res = p > .82;
    return Column(
      children: [
        Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: C.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.blue.withValues(alpha: .35), width: 2),
            boxShadow: [
              BoxShadow(color: C.ink.withValues(alpha: .3), blurRadius: 70, offset: const Offset(0, 30)),
              BoxShadow(color: C.blue.withValues(alpha: .25), blurRadius: 30),
            ],
          ),
          child: Row(
            children: [
              const SonotIcon(size: 38),
              const SizedBox(width: 16),
              Expanded(
                child: Text(q.substring(0, n), style: sans(22, w: FontWeight.w500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: C.mist, borderRadius: BorderRadius.circular(8)),
                child: Text('⌥ Space', style: mono(12, ls: 0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 450),
          opacity: res ? 1 : 0,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: C.ink.withValues(alpha: .25), blurRadius: 60, offset: const Offset(0, 24))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('app.quickRes').toUpperCase(), style: mono(11.5, c: C.blue)),
                const SizedBox(height: 8),
                Text(t('app.quickText'), style: sans(17, h: 1.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('↵ ${t('app.replace')}', style: sans(13, c: C.mute)),
                    const SizedBox(width: 18),
                    Text('⌘C ${t('app.copy')}', style: sans(13, c: C.mute)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
