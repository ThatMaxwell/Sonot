import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/glass.dart';
import '../widgets/message.dart';
import '../widgets/model_picker.dart';

/// The one screen: a conversation over a soft backdrop, a glass top bar with
/// the Sonot / Code switch, and a glass composer.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.settings, required this.onSignOut});
  final Settings settings;
  final VoidCallback onSignOut;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  Mode _mode = Mode.chat;
  late final AnimationController _moodCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _mood = CurvedAnimation(parent: _moodCtl, curve: Curves.easeInOutCubic);

  /// Each mode keeps its own conversation.
  final Map<Mode, List<ChatMessage>> _threads = {Mode.chat: [], Mode.code: []};
  List<ChatMessage> get _messages => _threads[_mode]!;

  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  /// Each mode remembers its own model; Code starts on the strongest.
  late final Map<Mode, (Tier, Effort)> _models = {for (final m in Mode.values) m: widget.settings.modelFor(m)};
  Tier get _tier => _models[_mode]!.$1;
  Effort get _effort => _models[_mode]!.$2;
  StreamSubscription<String>? _reply;
  ChatMessage? _streaming;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final typing = _input.text.trim().isNotEmpty;
      if (typing != _typing) setState(() => _typing = typing);
    });
  }

  @override
  void dispose() {
    _reply?.cancel();
    _moodCtl.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _busy => _reply != null;

  void _setMode(Mode m) {
    if (m == _mode) return;
    _stop();
    setState(() => _mode = m);
    m == Mode.code ? _moodCtl.forward() : _moodCtl.reverse();
  }

  void _newChat() {
    _stop();
    setState(() => _messages.clear());
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    // Failed turns stay on screen but aren't sent back to the model.
    final history = [..._messages.where((m) => !m.error), ChatMessage('user', text)];
    final reply = ChatMessage('assistant', '');
    setState(() {
      _messages
        ..add(history.last)
        ..add(reply);
      _streaming = reply;
      _input.clear();
    });
    _scrollToEnd();
    final req = ChatRequest(history: history, mode: _mode, tier: _tier, effort: _effort);
    _reply = widget.settings.chatProvider.chat(req).listen(
      (chunk) {
        setState(() => reply.text += chunk);
        _scrollToEnd();
      },
      onError: (Object e) {
        setState(() {
          reply.error = true;
          if (reply.text.isEmpty) reply.text = e.toString();
        });
        if (e is ApiException && e.signedOut) _offerSignIn();
      },
      // The stream always closes after an error, so this runs either way.
      onDone: _finish,
    );
  }

  void _offerSignIn() {
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

  void _stop() {
    if (!_busy) return;
    _reply?.cancel();
    final s = _streaming;
    if (s != null && s.text.isEmpty) _threads.forEach((_, list) => list.remove(s));
    _finish();
  }

  void _finish() {
    if (!mounted) return;
    setState(() {
      _reply = null;
      _streaming = null;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mood,
      builder: (context, _) {
        final p = Palette.lerp(Palette.chat, Palette.code, _mood.value);
        final dark = _mood.value > .5;
        final pad = MediaQuery.paddingOf(context);
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
                        opacity: _messages.isEmpty && !_typing ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: AnimatedScale(
                          scale: _messages.isEmpty && !_typing ? 1 : .92,
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
                  Positioned.fill(child: _list(p, pad)),
                  Positioned(top: 0, left: 0, right: 0, child: _topBar(p, pad)),
                  Positioned(left: 0, right: 0, bottom: 0, child: _composer(p, pad)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _list(Palette p, EdgeInsets pad) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(18, pad.top + 84, 18, pad.bottom + 120),
          itemCount: _messages.length,
          itemBuilder: (_, i) {
            final m = _messages[i];
            return MessageView(
              key: ObjectKey(m),
              message: m,
              palette: p,
              mode: _mode,
              waiting: identical(m, _streaming) && m.text.isEmpty,
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(Palette p, EdgeInsets pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, pad.top + 10, 14, 0),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New chat',
            onTap: _newChat,
            color: p.text,
            fill: p.glass,
            edge: p.edge,
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

  Widget _composer(Palette p, EdgeInsets pad) {
    final canSend = _typing && !_busy;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, pad.bottom + 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Glass(
            radius: 28,
            fill: p.glass,
            edge: p.edge,
            padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: CallbackShortcuts(
                      // Desktop: Enter sends, Shift+Enter adds a line.
                      bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: (_mode == Mode.code ? mono(15, c: p.text) : sans(16, c: p.text, w: FontWeight.w400)),
                        cursorColor: p.accent,
                        decoration: InputDecoration.collapsed(
                          hintText: _mode == Mode.code ? 'Describe the code task…' : 'Ask Sonot anything',
                          hintStyle: sans(16, c: p.textSoft, w: FontWeight.w400),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ModelChip(tier: _tier, effort: _effort, palette: p, onTap: () => _pickModel(p)),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend || _busy ? p.accent : p.textSoft.withValues(alpha: .18),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _busy ? _stop : (canSend ? _send : null),
                      child: Icon(
                        _busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        size: 22,
                        color: canSend || _busy ? p.onAccent : p.textSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

/// "Sonot | Code" glass segmented switch.
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
        children: [seg(Mode.chat, 'Sonot'), seg(Mode.code, 'Code')],
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
