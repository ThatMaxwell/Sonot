import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/bud_avatar.dart';
import '../widgets/motion.dart';
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

/* ==========================================================================
   SONOT BUDS — helpers with a face, a job and memory you can see.
   ========================================================================== */
const _starters = [
  ('Pip', BudShape.circle, Color(0xFFF6B73C)),
  ('Scout', BudShape.triangle, Color(0xFFFF7A59)),
  ('Byte', BudShape.square, Color(0xFF2F6BFF)),
  ('Moss', BudShape.capsule, Color(0xFF5FBF7A)),
];

class BudsShowcase extends StatelessWidget {
  const BudsShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = context.isMobile;
    final jobs = tl('buds.jobs');
    final feats = (tr('buds.feats') as List).cast<List>();
    final cardW = mobile ? ((vp.width - 48 - 16) / 2).floorToDouble() : 250.0;
    return Container(
      color: C.mist,
      padding: EdgeInsets.fromLTRB(24, mobile ? 90 : 130, 24, mobile ? 90 : 130),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Reveal(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('buds', style: budsStyle(math.min(math.max(vp.width * .14, 84), 170))),
                    const SizedBox(width: 14),
                    Padding(
                      padding: EdgeInsets.only(bottom: mobile ? 10 : 22),
                      child: Text(t('buds.by'), style: mono(12, c: C.mute, ls: .16)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Reveal(
                delay: 80,
                child: Heading(t('buds.t'), align: TextAlign.center, size: math.min(math.max(vp.width * .045, 32), 60)),
              ),
              const SizedBox(height: 18),
              Reveal(
                delay: 160,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    t('buds.sub'),
                    textAlign: TextAlign.center,
                    style: sans(math.min(19, math.max(16, context.vw * 1.4)), c: C.mute, h: 1.5, w: FontWeight.w400),
                  ),
                ),
              ),
              SizedBox(height: mobile ? 44 : 64),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < _starters.length; i++)
                    Reveal(
                      delay: 120 + i * 90,
                      child: _BudCard(index: i, width: cardW, job: jobs[i]),
                    ),
                ],
              ),
              SizedBox(height: mobile ? 28 : 40),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < feats.length; i++)
                    Reveal(
                      delay: 200 + i * 80,
                      child: Container(
                        width: mobile ? vp.width - 48 : 340,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: C.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: C.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(feats[i][0] as String, style: sans(16.5, w: FontWeight.w700)),
                                ),
                                if (feats[i][2] == true) ...[const SizedBox(width: 10), const _SoonBadge()],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              feats[i][1] as String,
                              style: sans(14.5, c: C.mute, w: FontWeight.w400, h: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One starter bud, cycling through a few moods so the face feels alive.
class _BudCard extends StatefulWidget {
  const _BudCard({required this.index, required this.width, required this.job});
  final int index;
  final double width;
  final String job;
  @override
  State<_BudCard> createState() => _BudCardState();
}

class _BudCardState extends State<_BudCard> with SingleTickerProviderStateMixin {
  static const _moods = [
    [BudEmotion.happy, BudEmotion.curious, BudEmotion.wink, BudEmotion.neutral],
    [BudEmotion.curious, BudEmotion.thinking, BudEmotion.surprised, BudEmotion.focused],
    [BudEmotion.focused, BudEmotion.thinking, BudEmotion.happy, BudEmotion.serious],
    [BudEmotion.sleepy, BudEmotion.neutral, BudEmotion.shy, BudEmotion.happy],
  ];
  final face = BudFaceController();
  late final Ticker tk;
  int step = -1;

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      final s = ((d.inMilliseconds + widget.index * 700) / 2600).floor();
      if (s != step) {
        step = s;
        final m = _moods[widget.index];
        face.value = m[s % m.length];
      }
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    face.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (name, shape, color) = _starters[widget.index];
    return Press(
      onTap: () => face.value = BudEmotion.excited,
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: widget.width,
        transform: Matrix4.translationValues(0, h ? -6 : 0, 0),
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: h ? color.withValues(alpha: .6) : C.line),
        ),
        child: Column(
          children: [
            BudAvatar(shape: shape, color: color, size: widget.width < 200 ? 72 : 96, controller: face),
            const SizedBox(height: 18),
            Text(name, style: sans(19, w: FontWeight.w700, ls: -.02)),
            const SizedBox(height: 6),
            Text(
              widget.job,
              textAlign: TextAlign.center,
              style: sans(14, c: C.mute, w: FontWeight.w400, h: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/* ==========================================================================
   SONOT CODE — the darker, serious mode: an agent for real software.
   ========================================================================== */
class CodeShowcase extends StatelessWidget {
  const CodeShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    final vp = context.vp;
    final mobile = vp.width < 1000;
    final caps = tl('code.caps');
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow('Sonot Code', color: C.blueSoft),
              const SizedBox(width: 12),
              const _SoonBadge(dark: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Reveal(
          delay: 80,
          child: Heading(t('code.t'), color: C.white, accentColor: C.blueSoft, size: math.min(math.max(vp.width * .055, 40), 78)),
        ),
        const SizedBox(height: 18),
        Reveal(
          delay: 160,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              t('code.sub'),
              style: sans(math.min(19, math.max(16, context.vw * 1.4)), c: C.white.withValues(alpha: .7), h: 1.5, w: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Reveal(
          delay: 220,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in caps)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: C.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.white.withValues(alpha: .16)),
                  ),
                  child: Text(c, style: mono(12.5, c: C.white.withValues(alpha: .85), ls: .04)),
                ),
            ],
          ),
        ),
      ],
    );
    return Container(
      color: C.ink,
      padding: EdgeInsets.fromLTRB(24, mobile ? 90 : 140, 24, mobile ? 90 : 140),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    head,
                    const SizedBox(height: 44),
                    const Reveal(delay: 200, child: _AgentRun()),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: head),
                    const SizedBox(width: 56),
                    const Expanded(flex: 6, child: Reveal(delay: 200, child: _AgentRun())),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A scripted agent run that plays on a loop: ask → steps → commands → PR.
class _AgentRun extends StatefulWidget {
  const _AgentRun();
  @override
  State<_AgentRun> createState() => _AgentRunState();
}

class _AgentRunState extends State<_AgentRun> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  double time = 0;

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      final v = d.inMilliseconds / 1000;
      // Only rebuild when a new line is due (about 4 times a second), not every frame.
      if ((v * 4).floor() != (time * 4).floor()) setState(() => time = v);
    })..start();
  }

  @override
  void dispose() {
    tk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = (tr('code.run') as List).cast<List>();
    const per = 1.1, hold = 3.5;
    final cycle = run.length * per + hold;
    final local = time % cycle;
    final shown = (local / per).floor() + 1;
    final allTabs = tl('code.tabs');
    return LayoutBuilder(
      builder: (_, box) {
        // Narrow phones show two tabs so the header never overflows.
        final tabs = box.maxWidth < 400 ? allTabs.take(2).toList() : allTabs;
        return _window(tabs, run, shown, local, per);
      },
    );
  }

  Widget _window(List<String> tabs, List<List> run, int shown, double local, double per) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1018),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: C.white.withValues(alpha: .08))),
            ),
            child: Row(
              children: [
                Text(
                  'Sonot Code',
                  style: sans(14, w: FontWeight.w700, c: C.white),
                ),
                const SizedBox(width: 18),
                for (var i = 0; i < tabs.length; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: i == 0 ? C.white.withValues(alpha: .1) : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      tabs[i],
                      style: mono(11.5, c: C.white.withValues(alpha: i == 0 ? .9 : .45)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < math.min(shown, run.length); i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _line(run[i][0] as String, run[i][1] as String, i == shown - 1 && local < run.length * per),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String kind, String text, bool fresh) {
    final w = switch (kind) {
      'you' => Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(16)),
          child: Text(
            text,
            style: sans(14.5, c: C.white, w: FontWeight.w600),
          ),
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
        child: Text(
          '✋  $text',
          style: sans(13.5, c: const Color(0xFFF5C46B), w: FontWeight.w500),
        ),
      ),
      _ => Text(
        '•  $text',
        style: sans(14, c: C.white.withValues(alpha: .6), w: FontWeight.w400),
      ),
    };
    return AnimatedOpacity(duration: const Duration(milliseconds: 350), opacity: fresh ? .9 : 1, child: w);
  }
}
