import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/glass.dart';
import 'bud_avatar.dart';
import 'buds.dart';

/// Make a Bud in three steps: its job, its look, its name and vibe.
Future<Bud?> showMakeBud({required BuildContext context, required Palette palette}) => showModalBottomSheet<Bud>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  barrierColor: Colors.black.withValues(alpha: .25),
  builder: (_) => _MakeBud(palette: palette),
);

const _jobIdeas = [
  'Plan my week and remind me of things',
  'Research a topic and keep me updated',
  'Help me learn something new',
  'Be my writing buddy',
];

class _MakeBud extends StatefulWidget {
  const _MakeBud({required this.palette});
  final Palette palette;

  @override
  State<_MakeBud> createState() => _MakeBudState();
}

class _MakeBudState extends State<_MakeBud> {
  int _step = 0;
  final _job = TextEditingController();
  final _name = TextEditingController();
  final _vibe = TextEditingController(text: 'Friendly and to the point.');
  BudShape _shape = BudShape.circle;
  Color _color = budColors[4];
  final _face = BudFaceController(emotion: BudEmotion.happy);

  @override
  void initState() {
    super.initState();
    for (final c in [_job, _name, _vibe]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _job.dispose();
    _name.dispose();
    _vibe.dispose();
    _face.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
    0 => _job.text.trim().isNotEmpty,
    1 => true,
    _ => _name.text.trim().isNotEmpty,
  };

  void _next() {
    if (!_canNext) return;
    if (_step < 2) {
      setState(() => _step++);
      _face.emotion = _step == 1 ? BudEmotion.curious : BudEmotion.excited;
      return;
    }
    var job = _job.text.trim();
    if (!job.endsWith('.')) job = '$job.';
    Navigator.pop(
      context,
      Bud(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        shape: _shape,
        color: _color,
        job: job[0].toUpperCase() + job.substring(1),
        vibe: _vibe.text.trim().isEmpty ? 'Friendly and to the point.' : _vibe.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Glass(
            radius: 30,
            blur: 30,
            fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .7)),
            edge: p.edge,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('STEP ${_step + 1} OF 3', style: mono(11.5, c: p.textSoft, w: FontWeight.w500)),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 4),
                        width: i == _step ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= _step ? p.accent : p.textSoft.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(child: BudAvatar(shape: _shape, color: _color, size: 96, controller: _face)),
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: switch (_step) {
                    0 => _jobStep(p),
                    1 => _lookStep(p),
                    _ => _nameStep(p),
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: Text('Back', style: sans(15, c: p.textSoft)),
                      ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.accent,
                        disabledBackgroundColor: p.textSoft.withValues(alpha: .2),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _canNext ? _next : null,
                      child: Text(_step == 2 ? 'Make ${_name.text.trim().isEmpty ? 'Bud' : _name.text.trim()}' : 'Next',
                          style: sans(15.5, c: p.onAccent, w: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t, Palette p) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: sans(20, c: p.text, w: FontWeight.w700, ls: -.02)));

  Widget _jobStep(Palette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title("What's its job?", p),
      _Field(controller: _job, hint: 'e.g. Help me train for a half marathon', palette: p, autofocus: true),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final idea in _jobIdeas)
            ActionChip(
              label: Text(idea, style: sans(13, c: p.text, w: FontWeight.w500)),
              backgroundColor: Colors.transparent,
              side: BorderSide(color: p.textSoft.withValues(alpha: .35), width: .7),
              shape: const StadiumBorder(),
              onPressed: () => _job.text = idea,
            ),
        ],
      ),
    ],
  );

  Widget _lookStep(Palette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Pick a look', p),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final s in BudShape.values)
            _Pick(
              selected: s == _shape,
              palette: p,
              onTap: () => setState(() => _shape = s),
              child: BudAvatar(shape: s, color: _color, size: 40),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in budColors)
            GestureDetector(
              onTap: () => setState(() => _color = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: c == _color ? p.text : Colors.transparent, width: 2),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _nameStep(Palette p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('Name and vibe', p),
      _Field(controller: _name, hint: 'Name', palette: p, autofocus: true),
      const SizedBox(height: 10),
      _Field(controller: _vibe, hint: 'Vibe, e.g. upbeat coach, keeps it short', palette: p),
    ],
  );
}

class _Pick extends StatelessWidget {
  const _Pick({required this.selected, required this.palette, required this.onTap, required this.child});
  final bool selected;
  final Palette palette;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: selected ? palette.text.withValues(alpha: .06) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? palette.edge : Colors.transparent, width: .7),
        ),
      ),
      child: child,
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.palette, this.autofocus = false});
  final TextEditingController controller;
  final String hint;
  final Palette palette;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    style: sans(15.5, c: palette.text, w: FontWeight.w400),
    cursorColor: palette.accent,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: sans(15, c: palette.textSoft, w: FontWeight.w400),
      filled: true,
      fillColor: palette.text.withValues(alpha: .04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: palette.edge, width: .7)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: palette.accent)),
    ),
  );
}
