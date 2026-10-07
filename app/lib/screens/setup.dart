import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/puter_auth.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/glass.dart';

enum _Step { start, waiting, server }

/// First-run screen: night navy, one wordmark, glass pills.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.settings, required this.onDone});
  final Settings settings;
  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _auth = PuterAuth();
  late final _server = TextEditingController(text: widget.settings.server);
  late final _token = TextEditingController(text: widget.settings.token);
  _Step _step = _Step.start;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _auth.cancel();
    _server.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _puter() async {
    setState(() {
      _step = _Step.waiting;
      _error = null;
    });
    try {
      final token = await _auth.signIn();
      await _usePuterToken(token);
    } catch (e) {
      if (!mounted || _step != _Step.waiting) return;
      setState(() {
        _step = _Step.start;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _usePuterToken(String token) async {
    final user = await PuterProvider(token).whoami();
    widget.settings
      ..provider = 'puter'
      ..puterToken = token
      ..puterUser = user;
    widget.onDone();
  }

  void _cancelWaiting() {
    _auth.cancel();
    setState(() => _step = _Step.start);
  }

  Future<void> _connectServer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ServerProvider(server: _server.text, token: _token.text).ping();
      widget.settings
        ..provider = 'server'
        ..server = _server.text
        ..token = _token.text;
      widget.onDone();
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : "Couldn't reach that server.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: .5);
    return Scaffold(
      backgroundColor: C.night,
      resizeToAvoidBottomInset: true,
      body: BackdropGroup(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Backdrop(
                base: C.night,
                blobs: [Color(0x332B4BFF), Color(0x1F6EA2FF), Color(0x293A2FBF), Color(0x1A1C2546)],
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        const _Wordmark(),
                        const Spacer(flex: 2),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: switch (_step) {
                              _Step.start => _start(),
                              _Step.waiting => _waiting(),
                              _Step.server => _serverForm(),
                            },
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_error!, style: sans(14, c: const Color(0xFFFF9C9C)), textAlign: TextAlign.center),
                          ),
                        const Spacer(flex: 5),
                        Text.rich(
                          TextSpan(
                            style: sans(13, c: Colors.white.withValues(alpha: .42), w: FontWeight.w400),
                            children: [
                              const TextSpan(text: 'Sonot runs on '),
                              TextSpan(text: 'Puter', style: sans(13, c: soft.withValues(alpha: .85))),
                              const TextSpan(text: '. Your account covers your own AI usage.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _start() => Column(
    key: const ValueKey('start'),
    children: [
      _Pill(label: 'Continue with Puter', light: true, onTap: _puter, leading: const _PuterGlyph()),
      const _OrDivider(),
      _Pill(label: 'Use my own server', light: false, onTap: () => setState(() => _step = _Step.server)),
    ],
  );

  Widget _waiting() => Column(
    key: const ValueKey('waiting'),
    children: [
      _Pill(
        label: 'Finish signing in in your browser',
        light: false,
        onTap: null,
        leading: const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TextLink('Open again', _puter),
          const SizedBox(width: 24),
          _TextLink('Cancel', _cancelWaiting),
        ],
      ),
    ],
  );

  Widget _serverForm() => Column(
    key: const ValueKey('server'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Field(controller: _server, hint: 'Server address, e.g. 192.168.1.20:8787', autofocus: true),
      const SizedBox(height: 12),
      _Field(controller: _token, hint: 'App token (optional)', obscure: true),
      const SizedBox(height: 20),
      _Pill(label: _busy ? 'Connecting…' : 'Connect', light: true, onTap: _busy ? null : _connectServer),
      const SizedBox(height: 10),
      _TextLink('Back', () => setState(() {
        _step = _Step.start;
        _error = null;
      })),
    ],
  );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'sonot ', style: sans(64, w: FontWeight.w700, c: Colors.white, ls: -.035, h: 1)),
          TextSpan(text: 'chat', style: serif(64, c: Colors.white.withValues(alpha: .45), h: 1)),
        ],
      ),
    ),
  );
}

/// A tall pill. Light is the solid main action; dark is glass with a
/// hairline edge.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.light, required this.onTap, this.leading});
  final String label;
  final bool light;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final fg = light ? C.ink : Colors.white;
    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Flexible(
                child: Text(label, style: sans(17, c: fg, w: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: light
          ? Glass(radius: 29, fill: const Color(0xF2F2F3F7), edge: Colors.white, child: content)
          : Glass(radius: 29, fill: const Color(0x12FFFFFF), edge: const Color(0x2EFFFFFF), child: content),
    );
  }
}

class _PuterGlyph extends StatelessWidget {
  const _PuterGlyph();
  @override
  Widget build(BuildContext context) => const Icon(Icons.cloud_rounded, size: 22, color: C.blue);
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: .7, color: Colors.white.withValues(alpha: .12)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or', style: sans(15, c: Colors.white.withValues(alpha: .5))),
          ),
          line,
        ],
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Text(label, style: sans(14.5, c: Colors.white.withValues(alpha: .6))),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.obscure = false, this.autofocus = false});
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 29,
    fill: const Color(0x12FFFFFF),
    edge: const Color(0x2EFFFFFF),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      autocorrect: false,
      style: sans(16, c: Colors.white),
      cursorColor: C.blueSoft,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: sans(15, c: Colors.white.withValues(alpha: .35)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: InputBorder.none,
      ),
    ),
  );
}
