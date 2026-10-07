import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../code/github.dart';
import '../code/notify.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/glass.dart';
import '../widgets/model_picker.dart';

/// Everything you can set, on one glass page: account, models, the cloud
/// computer (your own cua.ai key), GitHub, Code permissions, notifications,
/// appearance and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.github, required this.palette, required this.onSignOut});
  final Settings settings;
  final GitHub github;
  final Palette palette;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings get st => widget.settings;
  Palette get p => widget.palette;

  late final _server = TextEditingController(text: st.server);
  late final _token = TextEditingController(text: st.token);
  // cua.ai Fleet credentials: "client_id:client_secret", or a Fleet token.
  late final _cuaId = TextEditingController(text: st.cuaApiKey.split(':').first);
  late final _cuaSecret = TextEditingController(text: st.cuaApiKey.contains(':') ? st.cuaApiKey.substring(st.cuaApiKey.indexOf(':') + 1) : '');
  final _pat = TextEditingController();
  bool _showCua = false;

  // Test connection.
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  // GitHub sign-in.
  DeviceCode? _code;
  String? _ghError;
  bool _ghBusy = false;
  bool _closed = false;

  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((i) {
          if (mounted) setState(() => _version = '${i.version} (${i.buildNumber})');
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _closed = true;
    _save();
    for (final c in [_server, _token, _cuaId, _cuaSecret, _pat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    st
      ..server = _server.text
      ..token = _token.text
      ..cuaApiKey = _cuaSecret.text.trim().isEmpty ? _cuaId.text.trim() : '${_cuaId.text.trim()}:${_cuaSecret.text.trim()}';
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _test() async {
    _save();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    var base = st.server.trim();
    String result;
    var ok = false;
    if (base.isEmpty) {
      result = 'Add your Sonot server address first. Cloud computers run through it.';
    } else {
      if (!base.startsWith('http')) base = 'http://$base';
      try {
        final res = await http
            .get(
              Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}/health'),
              headers: {if (st.token.isNotEmpty) 'authorization': 'Bearer ${st.token}', if (st.cuaApiKey.isNotEmpty) 'x-cua-api-key': st.cuaApiKey},
            )
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) {
          result = 'The server answered ${res.statusCode}. Check the address and app token.';
        } else {
          final j = jsonDecode(res.body);
          final cloud = j is Map ? j['cloud'] : null;
          ok = true;
          if (cloud == true || (cloud == null && st.cuaApiKey.isNotEmpty)) {
            result = 'Connected. Cloud computers are ready.';
          } else if (cloud == false) {
            ok = st.cuaApiKey.isNotEmpty;
            result = st.cuaApiKey.isEmpty
                ? 'Connected, but the server has no cua.ai keys. Add yours above.'
                : 'Connected. The server will use your cua.ai keys.';
          } else {
            result = 'Connected to your Sonot server.';
          }
        }
      } catch (e) {
        result = "Couldn't reach $base. Is the server running?";
      }
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result;
      _testOk = ok;
    });
  }

  Future<void> _ghSignIn() async {
    setState(() {
      _ghBusy = true;
      _ghError = null;
    });
    try {
      final code = await widget.github.startSignIn();
      setState(() => _code = code);
      await Clipboard.setData(ClipboardData(text: code.userCode));
      await launchUrl(Uri.parse(code.verifyUrl), mode: LaunchMode.externalApplication);
      await widget.github.finishSignIn(code, cancelled: () => _closed);
    } catch (e) {
      _ghError = '$e'.replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() {
      _ghBusy = false;
      _code = null;
    });
  }

  Future<void> _ghToken() async {
    if (_pat.text.trim().isEmpty) return;
    setState(() => _ghBusy = true);
    try {
      await widget.github.useToken(_pat.text);
      _pat.clear();
      _ghError = null;
    } catch (e) {
      _ghError = '$e'.replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _ghBusy = false);
  }

  void _pick(Mode m) {
    final (tier, effort) = st.modelFor(m);
    showModelPicker(context: context, palette: p, tier: tier, effort: effort, onChanged: (t, e) => setState(() => st.setModelFor(m, t, e)));
  }

  void _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  // ---- Page ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Backdrop(base: p.bg, blobs: p.blobs),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, pad.top + 84, 16, pad.bottom + 32),
                children: [_account(), _models(), _cloud(), _github(), _permissions(), _notifications(), _appearance(), _about()],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: pad.top + 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Glass(
                  radius: 30,
                  fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .55)),
                  edge: p.edge,
                  padding: const EdgeInsets.fromLTRB(4, 4, 18, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: Icon(Icons.arrow_back_rounded, color: p.text),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Settings',
                        style: sans(18, c: p.text, w: FontWeight.w700, ls: -.01),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Sections -----------------------------------------------------------

  Widget _account() {
    final puter = st.provider == 'puter';
    final name = st.puterUser.isEmpty ? 'you' : st.puterUser;
    return _Section(
      title: 'Account',
      palette: p,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent),
              child: Text(
                puter ? name.characters.first.toUpperCase() : 'S',
                style: sans(19, c: p.onAccent, w: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    puter ? name : 'Your own Sonot server',
                    style: sans(16.5, c: p.text, w: FontWeight.w600),
                  ),
                  Text(
                    puter ? 'Signed in with Puter. Your Puter account covers your AI usage.' : 'Chats go through the server below.',
                    style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _Pill(
            label: puter ? 'Sign out' : 'Switch to Puter',
            palette: p,
            onTap: () {
              Navigator.of(context).pop();
              widget.onSignOut();
            },
          ),
        ),
      ],
    );
  }

  Widget _models() {
    Widget row(Mode m, String label, String note) {
      final (tier, effort) = st.modelFor(m);
      return _Row(
        palette: p,
        title: label,
        subtitle: note,
        trailing: ModelChip(tier: tier, effort: effort, palette: p, onTap: () => _pick(m)),
      );
    }

    return _Section(
      title: 'Models and effort',
      palette: p,
      children: [
        row(Mode.chat, 'Sonot', 'Everyday chat'),
        row(Mode.code, 'Sonot Code', 'The coding agent'),
        row(Mode.buds, 'New Buds', 'Each Bud can switch in its own chat'),
      ],
    );
  }

  Widget _cloud() => _Section(
    title: 'Cloud computer',
    palette: p,
    children: [
      Text(
        "Buds, and Code's cloud browser, work on a cua.ai cloud computer through your Sonot server. "
        'Add your cua.ai client ID and secret (from the cua.ai dashboard) and the computers run on your account.',
        style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
      ),
      const SizedBox(height: 14),
      _Field(controller: _cuaId, label: 'cua.ai client ID (or a Fleet token)', palette: p, mono: true),
      const SizedBox(height: 10),
      _Field(
        controller: _cuaSecret,
        label: 'cua.ai client secret',
        palette: p,
        obscure: !_showCua,
        mono: true,
        suffix: IconButton(
          tooltip: _showCua ? 'Hide' : 'Show',
          icon: Icon(_showCua ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: p.textSoft, size: 20),
          onPressed: () => setState(() => _showCua = !_showCua),
        ),
      ),
      const SizedBox(height: 10),
      _Field(controller: _server, label: 'Sonot server address', hint: 'https://sonot.example.com', palette: p, mono: true),
      const SizedBox(height: 10),
      _Field(controller: _token, label: 'App token (if your server has one)', palette: p, obscure: true, mono: true),
      const SizedBox(height: 12),
      Row(
        children: [
          _Pill(label: _testing ? 'Testing…' : 'Test connection', palette: p, filled: true, onTap: _testing ? null : _test),
          const SizedBox(width: 10),
          _Pill(label: 'Get cua.ai keys', palette: p, onTap: () => _open('https://cua.ai')),
        ],
      ),
      if (_testResult != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Icon(
                _testOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: _testOk ? const Color(0xFF3FB27F) : const Color(0xFFE5484D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _testResult!,
                  style: sans(13.5, c: p.text, w: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Text(
        'Your keys stay in this device\'s secure keychain and are only sent to your Sonot server.',
        style: sans(12.5, c: p.textSoft.withValues(alpha: .85), w: FontWeight.w400),
      ),
    ],
  );

  Widget _github() {
    final signedIn = widget.github.signedIn;
    return _Section(
      title: 'GitHub',
      palette: p,
      children: [
        if (signedIn)
          _Row(
            palette: p,
            title: st.githubUser.isEmpty ? 'Signed in' : st.githubUser,
            subtitle: 'Sonot Code can read and change your repos.',
            trailing: _Pill(label: 'Sign out', palette: p, onTap: () => setState(widget.github.signOut)),
          )
        else ...[
          Text(
            'Sign in so Sonot Code can work in your repos, issues and pull requests.',
            style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
          ),
          const SizedBox(height: 12),
          if (GitHub.canSignIn) ...[
            _Pill(label: _ghBusy && _code != null ? 'Waiting for GitHub…' : 'Sign in with GitHub', palette: p, filled: true, onTap: _ghBusy ? null : _ghSignIn),
            if (_code != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Enter ',
                        style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
                      ),
                      TextSpan(
                        text: _code!.userCode,
                        style: mono(14, c: p.text, w: FontWeight.w500),
                      ),
                      TextSpan(
                        text: ' on github.com (it\'s copied).',
                        style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _Field(controller: _pat, label: 'Or paste a personal access token', palette: p, obscure: true, mono: true),
              ),
              const SizedBox(width: 8),
              _Pill(label: 'Use', palette: p, onTap: _ghBusy ? null : _ghToken),
            ],
          ),
        ],
        if (_ghError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_ghError!, style: sans(13, c: const Color(0xFFE5484D))),
          ),
      ],
    );
  }

  Widget _permissions() {
    final rules = st.alwaysAllow.where((r) => r != 'all').toList();
    final all = st.alwaysAllow.contains('all');
    return _Section(
      title: 'Code permissions',
      palette: p,
      children: [
        _Toggle(
          palette: p,
          title: 'Allow everything',
          subtitle: 'Sonot Code stops asking before commands, file changes, the browser and GitHub.',
          value: all,
          onChanged: (v) => setState(() => st.alwaysAllow = v ? [...rules, 'all'] : rules),
        ),
        const SizedBox(height: 6),
        if (rules.isEmpty)
          Text(
            'Nothing always allowed yet. When Sonot Code asks, pick "Always allow" and it shows up here.',
            style: sans(13.5, c: p.textSoft, w: FontWeight.w400),
          )
        else
          for (final r in rules)
            _Row(
              palette: p,
              title: ruleText(r),
              mono: r.startsWith('cmd'),
              trailing: IconButton(
                tooltip: 'Stop allowing',
                icon: Icon(Icons.close_rounded, color: p.textSoft, size: 20),
                onPressed: () => setState(() => st.alwaysAllow = st.alwaysAllow.where((x) => x != r).toList()),
              ),
            ),
      ],
    );
  }

  Widget _notifications() => _Section(
    title: 'Notifications',
    palette: p,
    children: [
      _Toggle(
        palette: p,
        title: 'Notifications',
        subtitle: 'When Sonot Code finishes or needs you.',
        value: st.notifications,
        onChanged: (v) => setState(() => st.notifications = v),
      ),
      _Toggle(
        palette: p,
        title: 'Urgent alerts',
        subtitle: 'Let "needs you" alerts break through Do Not Disturb.',
        value: st.urgentAlerts,
        onChanged: st.notifications ? (v) => setState(() => st.urgentAlerts = v) : null,
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: _Pill(
          label: 'Send a test',
          palette: p,
          onTap: () async {
            final ok = await Notifier.instance.show('Sonot', 'Notifications work.');
            if (!ok && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(st.notifications ? 'This device didn\'t show it. Check its notification settings.' : 'Notifications are off.'),
                ),
              );
            }
          },
        ),
      ),
    ],
  );

  Widget _appearance() {
    const sizes = {'Small': .9, 'Default': 1.0, 'Large': 1.15, 'Larger': 1.3};
    return _Section(
      title: 'Appearance',
      palette: p,
      children: [
        Text(
          'Text size',
          style: sans(15, c: p.text, w: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in sizes.entries)
              _Pill(label: e.key, palette: p, filled: (st.textScale - e.value).abs() < .01, onTap: () => setState(() => st.textScale = e.value)),
          ],
        ),
        const SizedBox(height: 10),
        _Toggle(palette: p, title: 'Glass blur', subtitle: 'Turn off if things feel slow.', value: st.blur, onChanged: (v) => setState(() => st.blur = v)),
        _Toggle(
          palette: p,
          title: 'Animations',
          subtitle: 'The Anthem on Max burst and other playful bits.',
          value: st.motion,
          onChanged: (v) => setState(() => st.motion = v),
        ),
      ],
    );
  }

  Widget _about() => _Section(
    title: 'About',
    palette: p,
    children: [
      _Row(
        palette: p,
        title: 'Sonot',
        subtitle: 'Made by ThatMaxwell',
        trailing: Text(_version, style: mono(13, c: p.textSoft)),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Pill(label: 'Releases', palette: p, onTap: () => _open('https://github.com/ThatMaxwell/Sonot/releases')),
          _Pill(label: 'Source', palette: p, onTap: () => _open('https://github.com/ThatMaxwell/Sonot')),
          _Pill(
            label: 'Licenses',
            palette: p,
            onTap: () => showLicensePage(context: context, applicationName: 'Sonot', applicationVersion: _version),
          ),
        ],
      ),
    ],
  );
}

/// How an "Always allow" rule reads.
String ruleText(String r) => switch (r) {
  'all' => 'Everything',
  'write' => 'File changes',
  'browser' => 'The browser',
  'node' => 'Node.js scripts',
  'github' => 'GitHub changes',
  _ when r.startsWith('cmd:') => '${r.substring(4)} commands',
  _ when r.startsWith('cmd=') => r.substring(4),
  _ => r,
};

// ---- Pieces ----------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.palette, required this.children});
  final String title;
  final Palette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Text(
            title.toUpperCase(),
            style: mono(11.5, c: palette.textSoft, w: FontWeight.w500),
          ),
        ),
        Glass(
          radius: 26,
          fill: palette.glass,
          edge: palette.edge,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.palette, required this.title, this.subtitle, this.trailing, this.mono = false});
  final Palette palette;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mono ? monoStyle(14, c: palette.text) : sans(15, c: palette.text, w: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: sans(13, c: palette.textSoft, w: FontWeight.w400),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    ),
  );
}

TextStyle monoStyle(double size, {required Color c}) => mono(size, c: c, w: FontWeight.w500, h: 1.35);

class _Toggle extends StatelessWidget {
  const _Toggle({required this.palette, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final Palette palette;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onChanged == null ? .5 : 1,
    child: _Row(
      palette: palette,
      title: title,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: palette.accent,
        activeThumbColor: Colors.white,
        inactiveTrackColor: palette.text.withValues(alpha: .12),
        inactiveThumbColor: palette.textSoft,
        trackOutlineColor: WidgetStatePropertyAll(palette.edge),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.palette, required this.onTap, this.filled = false});
  final String label;
  final Palette palette;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Opacity(
      opacity: onTap == null ? .55 : 1,
      child: Material(
        color: filled ? p.accent : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: filled ? Colors.transparent : p.textSoft.withValues(alpha: .4), width: .7)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: sans(14, c: filled ? p.onAccent : p.text, w: FontWeight.w600, h: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.palette, this.hint, this.obscure = false, this.mono = false, this.suffix});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final Palette palette;
  final bool obscure;
  final bool mono;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      style: mono ? monoStyle(14, c: p.text) : sans(15, c: p.text, w: FontWeight.w400),
      cursorColor: p.accent,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: sans(14, c: p.textSoft.withValues(alpha: .7), w: FontWeight.w400),
        labelStyle: sans(14, c: p.textSoft),
        isDense: true,
        filled: true,
        fillColor: p.text.withValues(alpha: .05),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.edge, width: .7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.accent),
        ),
      ),
    );
  }
}
