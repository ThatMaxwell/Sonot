import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buds/buds.dart';
import '../buds/buds_home.dart';
import '../core/api.dart';
import '../core/conversation.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/composer.dart';
import '../widgets/glass.dart';
import '../widgets/model_picker.dart';

/// The main screen: a glass top bar with the Sonot / Code / Buds switch over
/// a soft backdrop. Sonot and Code are conversations; Buds is the Buds home.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.settings, required this.buds, required this.onSignOut});
  final Settings settings;
  final BudStore buds;
  final VoidCallback onSignOut;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  Mode _mode = Mode.chat;

  /// Cross-fades the palette from [_from] to the current mode's.
  late final AnimationController _moodCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
  late final Animation<double> _mood = CurvedAnimation(parent: _moodCtl, curve: Curves.easeInOutCubic);
  Palette _from = Palette.chat;

  /// Each mode keeps its own conversation and model; Code starts on the strongest.
  final Map<Mode, Conversation> _threads = {Mode.chat: Conversation(), Mode.code: Conversation()};
  late final Map<Mode, (Tier, Effort)> _models = {for (final m in Mode.values) m: widget.settings.modelFor(m)};
  Conversation get _convo => _threads[_mode] ?? _threads[Mode.chat]!;
  Tier get _tier => _models[_mode]!.$1;
  Effort get _effort => _models[_mode]!.$2;

  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    for (final c in _threads.values) {
      c.addListener(_onConvo);
    }
    _input.addListener(() {
      final typing = _input.text.trim().isNotEmpty;
      if (typing != _typing) setState(() => _typing = typing);
    });
  }

  void _onConvo() {
    if (!mounted) return;
    setState(() {});
    scrollToEnd(_scroll);
  }

  @override
  void dispose() {
    for (final c in _threads.values) {
      c.dispose();
    }
    _moodCtl.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Palette get _palette => Palette.lerp(_from, Palette.of(_mode), _mood.value);

  void _setMode(Mode m) {
    if (m == _mode) return;
    _convo.stop();
    _from = _palette;
    setState(() => _mode = m);
    _moodCtl.forward(from: 0);
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || _convo.busy) return;
    _input.clear();
    final mode = _mode;
    _convo.send(
      text,
      provider: widget.settings.chatProvider,
      build: (history) => ChatRequest(history: history, mode: mode, tier: _tier, effort: _effort),
      onError: (e) {
        if (e.signedOut) _offerSignIn();
      },
    );
  }

  void _offerSignIn() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Your sign-in expired.'),
        action: SnackBarAction(label: 'Sign in', onPressed: widget.onSignOut),
      ),
    );
  }

  Future<void> _pickModel(Palette p) async {
    await showModelPicker(
      context: context,
      palette: p,
      tier: _tier,
      effort: _effort,
      onChanged: (t, e) {
        setState(() => _models[_mode] = (t, e));
        widget.settings.setModelFor(_mode, t, e);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mood,
      builder: (context, _) {
        final p = _palette;
        final dark = p.bg.computeLuminance() < .3;
        final pad = MediaQuery.paddingOf(context);
        final buds = _mode == Mode.buds;
        final empty = _convo.messages.isEmpty && !_typing;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: p.bg,
            resizeToAvoidBottomInset: true,
            body: BackdropGroup(
              child: Stack(
                children: [
                  Positioned.fill(child: Backdrop(base: p.bg, blobs: p.blobs)),
                  // The mark sits behind an empty chat and steps aside once you type.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: empty && !buds ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: AnimatedScale(
                          scale: empty && !buds ? 1 : .92,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          child: Center(
                            child: LayoutBuilder(
                              builder: (_, c) => SonotMark(size: (c.biggest.shortestSide * .62).clamp(160, 420), color: p.watermark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: buds
                          ? BudsHome(key: const ValueKey('buds'), store: widget.buds, settings: widget.settings, palette: p)
                          : ThreadView(
                              key: const ValueKey('thread'),
                              messages: _convo.messages,
                              streaming: _convo.streaming,
                              palette: p,
                              mode: _mode,
                              controller: _scroll,
                            ),
                    ),
                  ),
                  Positioned(top: 0, left: 0, right: 0, child: _topBar(p, pad)),
                  if (!buds)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Composer(
                        controller: _input,
                        focus: _focus,
                        palette: p,
                        hint: _mode == Mode.code ? 'Describe the code task…' : 'Ask Sonot anything',
                        monoInput: _mode == Mode.code,
                        busy: _convo.busy,
                        onSend: _send,
                        onStop: _convo.stop,
                        trailing: ModelChip(tier: _tier, effort: _effort, palette: p, onTap: () => _pickModel(p)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(Palette p, EdgeInsets pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, pad.top + 10, 14, 0),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: _mode == Mode.buds ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _mode == Mode.buds,
              child: GlassIconButton(
                icon: Icons.add_rounded,
                tooltip: 'New chat',
                onTap: _convo.clear,
                color: p.text,
                fill: p.glass,
                edge: p.edge,
              ),
            ),
          ),
          const Spacer(),
          _ModeSwitch(mode: _mode, palette: p, onChanged: _setMode),
          const Spacer(),
          GlassIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: () => _openSettings(p),
            color: p.text,
            fill: p.glass,
            edge: p.edge,
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings(Palette p) async {
    final st = widget.settings;
    final puter = st.provider == 'puter';
    final server = TextEditingController(text: st.server);
    final token = TextEditingController(text: st.token);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .25),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Glass(
              radius: 30,
              blur: 30,
              fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .6)),
              edge: p.edge,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Account', style: sans(20, c: p.text, w: FontWeight.w700, ls: -.02)),
                  const SizedBox(height: 6),
                  Text(
                    puter
                        ? 'Signed in to Puter as ${st.puterUser.isEmpty ? 'you' : st.puterUser}. Your Puter account covers your AI usage.'
                        : 'Using your own Sonot server.',
                    style: sans(14.5, c: p.textSoft, w: FontWeight.w400),
                  ),
                  if (!puter) ...[
                    const SizedBox(height: 16),
                    _SheetField(controller: server, label: 'Server address', palette: p),
                    const SizedBox(height: 10),
                    _SheetField(controller: token, label: 'App token', palette: p, obscure: true),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onSignOut();
                        },
                        child: Text(puter ? 'Sign out' : 'Switch to Puter', style: sans(14.5, c: p.textSoft)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          if (!puter) {
                            st.server = server.text;
                            st.token = token.text;
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text('Done', style: sans(15, c: p.accent, w: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    server.dispose();
    token.dispose();
  }
}

/// "Sonot | Code | Buds" glass segmented switch.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.palette, required this.onChanged});
  final Mode mode;
  final Palette palette;
  final ValueChanged<Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget seg(Mode m, String label) {
      final on = m == mode;
      return GestureDetector(
        onTap: () => onChanged(m),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: on ? p.edge : Colors.transparent, width: .7)),
            color: on ? p.text.withValues(alpha: .08) : Colors.transparent,
          ),
          child: Text(
            label,
            style: m == Mode.code
                ? mono(13.5, c: on ? p.text : p.textSoft, w: FontWeight.w500, h: 1.2)
                : sans(14.5, c: on ? p.text : p.textSoft, w: FontWeight.w600, h: 1.2),
          ),
        ),
      );
    }

    return Glass(
      radius: 24,
      fill: p.glass,
      edge: p.edge,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(Mode.chat, 'Sonot'), seg(Mode.code, 'Code'), seg(Mode.buds, 'Buds')],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.controller, required this.label, required this.palette, this.obscure = false});
  final TextEditingController controller;
  final String label;
  final Palette palette;
  final bool obscure;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    autocorrect: false,
    style: sans(15.5, c: palette.text, w: FontWeight.w400),
    cursorColor: palette.accent,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: sans(14, c: palette.textSoft),
      filled: true,
      fillColor: palette.text.withValues(alpha: .05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.edge, width: .7)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: palette.accent, width: 1)),
    ),
  );
}
