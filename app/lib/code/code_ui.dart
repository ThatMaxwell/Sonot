import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/glass.dart';
import 'browser.dart';
import 'github.dart';
import 'notify.dart';
import 'permissions.dart';
import 'step.dart';

/// A tool call inside a Code reply: a hairline glass row that opens to show
/// what came back.
class StepCard extends StatefulWidget {
  const StepCard({super.key, required this.step, required this.palette});
  final ToolStep step;
  final Palette palette;

  @override
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  bool? _open;

  static IconData iconFor(String name) => switch (name) {
    'run_command' || 'process_output' || 'process_kill' || 'process_list' => Icons.terminal_rounded,
    'run_node' => Icons.javascript_rounded,
    'read_file' || 'list_dir' || 'search' => Icons.description_outlined,
    'write_file' || 'edit_file' => Icons.edit_note_rounded,
    'browser' => Icons.public_rounded,
    'notify' => Icons.notifications_active_outlined,
    _ when name.startsWith('github_') => Icons.merge_type_rounded,
    _ => Icons.build_circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.step;
    // Live steps (browser, long commands) stay open until they finish.
    final open = _open ?? (s.status == StepStatus.running && (s.name == 'browser' || s.output.isNotEmpty));
    final (Color tint, Widget badge) = switch (s.status) {
      StepStatus.running => (p.accent, SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: p.accent))),
      StepStatus.asking => (const Color(0xFFF5A524), const Icon(Icons.front_hand_rounded, size: 14, color: Color(0xFFF5A524))),
      StepStatus.done => (p.textSoft, Icon(Icons.check_rounded, size: 15, color: p.textSoft)),
      StepStatus.failed => (const Color(0xFFE5484D), const Icon(Icons.close_rounded, size: 15, color: Color(0xFFE5484D))),
      StepStatus.denied => (p.textSoft, Icon(Icons.block_rounded, size: 14, color: p.textSoft)),
    };
    final hasBody = s.output.trim().isNotEmpty || s.image != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.text.withValues(alpha: .035),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.edge, width: .7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: hasBody ? () => setState(() => _open = !open) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                child: Row(
                  children: [
                    Icon(iconFor(s.name), size: 16, color: tint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: open ? 4 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono(12.5, c: s.status == StepStatus.denied ? p.textSoft : p.text, h: 1.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    badge,
                    if (hasBody) Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: p.textSoft),
                  ],
                ),
              ),
            ),
            if (open && hasBody)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.image != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(s.image!, gaplessPlayback: true, fit: BoxFit.contain, height: 260),
                        ),
                      ),
                    if (s.output.trim().isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: SingleChildScrollView(
                          reverse: s.status == StepStatus.running,
                          child: SelectableText(s.output.trimRight(), style: mono(12, c: p.textSoft, h: 1.45)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _sheet(BuildContext ctx, Palette p, Widget child) => Padding(
  padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 12),
  child: Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Glass(
        radius: 28,
        blur: 30,
        fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .85)),
        edge: p.edge,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: child,
      ),
    ),
  ),
);

/// "Sonot Code wants to …" with Allow once, Always allow and Deny.
/// Returns null when dismissed from outside ([close]).
Future<Approval> showApproval(BuildContext context, Palette p, Ask ask, {required void Function(VoidCallback close) onOpen}) async {
  HapticFeedback.mediumImpact();
  final r = await showModalBottomSheet<Approval>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (ctx) {
      onOpen(() => Navigator.of(ctx).maybePop(Approval.deny));
      return _sheet(
        ctx,
        p,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sonot Code wants to', style: sans(13.5, c: p.textSoft)),
            const SizedBox(height: 2),
            Text(ask.title.toLowerCase(), style: sans(20, c: p.text, w: FontWeight.w700, ls: -.02)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: p.text.withValues(alpha: .05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.edge, width: .7)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(ask.detail, style: mono(13, c: p.text)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx, Approval.once),
              child: Text('Allow once', style: sans(15, c: p.onAccent, w: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, Approval.always),
                    child: Text(ask.ruleLabel, textAlign: TextAlign.center, style: sans(14, c: p.accent, w: FontWeight.w600)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, Approval.deny),
                    child: Text('Deny', style: sans(14, c: p.textSoft, w: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return r ?? Approval.deny;
}

/// Code settings: the workspace folder, where the browser runs, GitHub, and
/// what you've always allowed.
Future<void> showCodeSettings(BuildContext context, Palette p, Settings settings, GitHub github) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  barrierColor: Colors.black.withValues(alpha: .25),
  builder: (ctx) => _sheet(ctx, p, _CodeSettings(palette: p, settings: settings, github: github)),
);

class _CodeSettings extends StatefulWidget {
  const _CodeSettings({required this.palette, required this.settings, required this.github});
  final Palette palette;
  final Settings settings;
  final GitHub github;

  @override
  State<_CodeSettings> createState() => _CodeSettingsState();
}

class _CodeSettingsState extends State<_CodeSettings> {
  late final _workspace = TextEditingController(text: widget.settings.workspace);
  final _pat = TextEditingController();
  DeviceCode? _code;
  String? _ghError;
  bool _ghBusy = false;
  bool _closed = false;

  Settings get st => widget.settings;
  Palette get p => widget.palette;

  @override
  void dispose() {
    _closed = true;
    st.workspace = _workspace.text;
    _workspace.dispose();
    _pat.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final dir = await getDirectoryPath(initialDirectory: _workspace.text.isEmpty ? null : _workspace.text);
    if (dir != null) setState(() => _workspace.text = dir);
  }

  Future<void> _signIn() async {
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

  Future<void> _useToken() async {
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

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(s, style: sans(13, c: p.textSoft, w: FontWeight.w600)),
  );

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: mono(13, c: p.textSoft),
    isDense: true,
    filled: true,
    fillColor: p.text.withValues(alpha: .05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.edge, width: .7)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent)),
  );

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label, style: sans(13.5, c: on ? p.onAccent : p.text, w: FontWeight.w600)),
      selected: on,
      showCheckmark: false,
      selectedColor: p.accent,
      backgroundColor: p.text.withValues(alpha: .05),
      side: BorderSide(color: p.edge, width: .7),
      shape: const StadiumBorder(),
      onSelected: (_) => onTap(),
    ),
  );

  String _ruleText(String r) => switch (r) {
    'all' => 'Everything (no questions)',
    'write' => 'File changes',
    'browser' => 'The browser',
    'node' => 'Node.js scripts',
    'github' => 'GitHub changes',
    _ when r.startsWith('cmd:') => '${r.substring(4)} commands',
    _ when r.startsWith('cmd=') => r.substring(4),
    _ => r,
  };

  @override
  Widget build(BuildContext context) {
    final rules = st.alwaysAllow;
    final everything = rules.contains('all');
    final desktop = Platform.isWindows || Platform.isLinux;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sonot Code', style: sans(20, c: p.text, w: FontWeight.w700, ls: -.02)),
            const SizedBox(height: 4),
            Text(
              'The agent runs commands, Node.js, files and a browser on this ${desktop ? 'computer' : 'phone'}. It asks before anything that changes things.',
              style: sans(14, c: p.textSoft, w: FontWeight.w400),
            ),
            _label('Workspace folder'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _workspace,
                    style: mono(13, c: p.text),
                    cursorColor: p.accent,
                    decoration: _field(desktop ? r'C:\Users\you\projects\app' : 'Sonot Code folder'),
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 8),
                  GlassIconButton(icon: Icons.folder_open_rounded, tooltip: 'Choose', onTap: _pickFolder, color: p.text, fill: p.glass, edge: p.edge),
                ],
              ],
            ),
            _label('Browser runs on'),
            Row(
              children: [
                if (BrowserRunner.canRunLocally)
                  _chip('This computer', st.browserWhere != 'cloud', () => setState(() => st.browserWhere = 'local')),
                _chip('Cloud computer', st.browserWhere == 'cloud' || !BrowserRunner.canRunLocally, () => setState(() => st.browserWhere = 'cloud')),
              ],
            ),
            if (!BrowserRunner.canRunLocally || st.browserWhere == 'cloud')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Cloud browsing runs on a cua.ai computer through your Sonot server.', style: sans(12.5, c: p.textSoft, w: FontWeight.w400)),
              ),
            _label('GitHub'),
            if (widget.github.signedIn)
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Signed in as ${st.githubUser}', style: sans(14.5, c: p.text))),
                  TextButton(
                    onPressed: () => setState(widget.github.signOut),
                    child: Text('Sign out', style: sans(14, c: p.textSoft, w: FontWeight.w600)),
                  ),
                ],
              )
            else ...[
              if (_code != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      style: sans(14, c: p.textSoft, w: FontWeight.w400),
                      children: [
                        const TextSpan(text: 'Enter '),
                        TextSpan(text: _code!.userCode, style: mono(15, c: p.text, w: FontWeight.w500)),
                        TextSpan(text: ' at ${_code!.verifyUrl} (copied). Waiting for GitHub…'),
                      ],
                    ),
                  ),
                ),
              if (GitHub.canSignIn)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: p.text, foregroundColor: p.bg, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: _ghBusy ? null : _signIn,
                  icon: const Icon(Icons.merge_type_rounded, size: 18),
                  label: Text(_ghBusy ? 'Waiting for GitHub…' : 'Sign in with GitHub', style: sans(14.5, c: p.bg, w: FontWeight.w600)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pat,
                        obscureText: true,
                        style: mono(13, c: p.text),
                        cursorColor: p.accent,
                        decoration: _field(GitHub.canSignIn ? 'or paste a token' : 'Paste a GitHub token'),
                      ),
                    ),
                    TextButton(onPressed: _ghBusy ? null : _useToken, child: Text('Use', style: sans(14, c: p.accent, w: FontWeight.w600))),
                  ],
                ),
              ),
            ],
            if (_ghError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_ghError!, style: sans(13, c: const Color(0xFFE5484D), w: FontWeight.w400)),
              ),
            _label('Always allowed'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeTrackColor: p.accent,
              title: Text('Never ask (full access)', style: sans(14.5, c: p.text)),
              subtitle: Text('Runs every command without asking. Only for machines you trust it with.', style: sans(12.5, c: p.textSoft, w: FontWeight.w400)),
              value: everything,
              onChanged: (v) => setState(() => st.alwaysAllow = v ? [...rules, 'all'] : rules.where((r) => r != 'all').toList()),
            ),
            for (final r in rules.where((r) => r != 'all'))
              Row(
                children: [
                  Expanded(child: Text(_ruleText(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(13, c: p.text))),
                  IconButton(
                    tooltip: 'Ask again',
                    icon: Icon(Icons.close_rounded, size: 18, color: p.textSoft),
                    onPressed: () => setState(() => st.alwaysAllow = rules.where((x) => x != r).toList()),
                  ),
                ],
              ),
            if (rules.where((r) => r != 'all').isEmpty) Text('Nothing yet.', style: sans(13.5, c: p.textSoft, w: FontWeight.w400)),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Notifier.instance.show('Sonot Code', 'Notifications work.', urgent: true),
                  icon: Icon(Icons.notifications_active_outlined, size: 18, color: p.textSoft),
                  label: Text('Test notification', style: sans(14, c: p.textSoft, w: FontWeight.w600)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done', style: sans(15, c: p.accent, w: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
