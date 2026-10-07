import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../buds/buds.dart';
import '../buds/buds_home.dart';
import '../code/agent.dart';
import '../code/browser.dart';
import '../code/code_ui.dart';
import '../code/github.dart';
import '../code/notify.dart';
import '../code/permissions.dart';
import '../code/tools.dart';
import '../core/api.dart';
import '../core/conversation.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/bloom.dart';
import '../widgets/composer.dart';
import '../widgets/glass.dart';
import '../widgets/model_picker.dart';
import 'settings_screen.dart';

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

  /// Sonot Code's hands: commands, Node.js, files, the browser, GitHub.
  late final _github = GitHub(widget.settings);
  late final _permissions = Permissions(widget.settings);
  late final _browser = BrowserRunner(
    cloudServer: () => widget.settings.server,
    cloudToken: () => widget.settings.token,
    cloudCuaKey: () => widget.settings.cuaApiKey,
  );
  late final _toolbox = Toolbox(settings: widget.settings, permissions: _permissions, browser: _browser, github: _github);

  /// Each mode keeps its own conversation and model; Code starts on the strongest.
  late final Map<Mode, Conversation> _threads = {Mode.chat: Conversation(), Mode.code: CodeAgent(_toolbox)};
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
    _permissions.onAsk = (ask) async {
      if (!mounted) return Approval.deny;
      final a = await showApproval(context, _palette, ask, onOpen: (close) => _permissions.cancelAsk = close);
      _permissions.cancelAsk = null;
      return a;
    };
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
    _toolbox.shell.killAll();
    _browser.dispose();
    _moodCtl.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Palette get _palette => Palette.lerp(_from, Palette.of(_mode), _mood.value);

  void _setMode(Mode m) {
    if (m == _mode) return;
    // Code keeps working in the background; only plain chat stops on switch.
    if (_mode != Mode.code) _convo.stop();
    if (m == Mode.code) Notifier.instance.init();
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
                  Positioned.fill(
                    child: Backdrop(base: p.bg, blobs: p.blobs),
                  ),
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
                        hint: _mode == Mode.code ? 'Build, run, browse, ship…' : 'Ask Sonot anything',
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
              child: GlassIconButton(icon: Icons.add_rounded, tooltip: 'New chat', onTap: _convo.clear, color: p.text, fill: p.glass, edge: p.edge),
            ),
          ),
          // Code's tools button, mirrored by an empty slot on the right so the switch stays centred.
          _codeSlot(
            GlassIconButton(
              icon: Icons.terminal_rounded,
              tooltip: 'Code settings',
              onTap: () => showCodeSettings(context, p, widget.settings, _github),
              color: p.text,
              fill: p.glass,
              edge: p.edge,
            ),
          ),
          const Spacer(),
          _ModeSwitch(mode: _mode, palette: p, onChanged: _setMode),
          const Spacer(),
          _codeSlot(const SizedBox.square(dimension: 44)),
          GlassIconButton(icon: Icons.tune_rounded, tooltip: 'Settings', onTap: () => _openSettings(p), color: p.text, fill: p.glass, edge: p.edge),
        ],
      ),
    );
  }

  Widget _codeSlot(Widget child) => AnimatedSize(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    child: _mode == Mode.code ? Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child) : const SizedBox(height: 44),
  );

  Future<void> _openSettings(Palette p) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => SettingsScreen(settings: widget.settings, github: _github, palette: p, onSignOut: widget.onSignOut),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    // Default models may have changed.
    if (mounted) setState(() => _models.addAll({for (final m in Mode.values) m: widget.settings.modelFor(m)}));
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg(Mode.chat, 'Sonot'), seg(Mode.code, 'Code'), seg(Mode.buds, 'Buds')]),
    );
  }
}
