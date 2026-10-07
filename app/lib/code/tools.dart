import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/settings.dart';
import 'browser.dart';
import 'files.dart';
import 'github.dart';
import 'notify.dart';
import 'permissions.dart';
import 'shell.dart';
import 'step.dart';

Map<String, dynamic> _fn(String name, String description, Map<String, dynamic> props, [List<String> required = const []]) => {
  'type': 'function',
  'function': {
    'name': name,
    'description': description,
    'parameters': {'type': 'object', 'properties': props, 'required': required},
  },
};

const _str = {'type': 'string'};
Map<String, dynamic> _s(String d) => {'type': 'string', 'description': d};
Map<String, dynamic> _i(String d) => {'type': 'integer', 'description': d};
Map<String, dynamic> _b(String d) => {'type': 'boolean', 'description': d};

/// Everything Sonot Code can do on your machine, and the gate in front of it.
class Toolbox {
  Toolbox({required this.settings, required this.permissions, required this.browser, required this.github})
    : shell = Shell(workspace: () => ''),
      files = Files(workspace: () => '') {
    shell.workspace = () => workspaceDir;
    files.workspace = () => workspaceDir;
  }

  final Settings settings;
  final Permissions permissions;
  final BrowserRunner browser;
  final GitHub github;
  final Shell shell;
  final Files files;

  /// Set by the agent: the Puter model browser tasks use.
  String browserModel = 'claude-sonnet-5-5';

  String _fallbackDir = '';
  String get workspaceDir => settings.workspace.isNotEmpty ? settings.workspace : _fallbackDir;

  List<McpTool> _github = const [];

  Future<void> prepare() async {
    if (settings.workspace.isEmpty && _fallbackDir.isEmpty) {
      final docs = await getApplicationDocumentsDirectory();
      final d = Directory('${docs.path}${Platform.pathSeparator}Sonot Code');
      await d.create(recursive: true);
      _fallbackDir = d.path;
    }
    _github = const [];
    if (github.signedIn) {
      try {
        _github = (await github.mcp()).tools;
      } catch (_) {
        // GitHub tools are a bonus; the rest still works (and `gh` gets the token).
      }
    }
  }

  String get platformNote {
    final os = Platform.isWindows ? 'Windows (commands run in PowerShell)' : Platform.isAndroid ? 'Android (commands run in the app sandbox with a basic sh)' : 'Linux (commands run in bash)';
    final gh = github.signedIn
        ? 'GitHub: signed in as ${settings.githubUser}; github_* tools act as them, and GH_TOKEN is set for git/gh commands.'
        : 'GitHub: not signed in (they can sign in under Code settings).';
    return 'Machine: $os. Workspace: $workspaceDir. $gh';
  }

  List<Map<String, dynamic>> get schemas => [
    _fn(
      'run_command',
      'Run a shell command on the user\'s machine and get its output. The user approves commands. '
          'Use background=true for servers, watchers and anything long-running, then read it with process_output.',
      {
        'command': _s('The command line.'),
        'cwd': _s('Folder to run in, relative to the workspace or absolute. Default: the workspace.'),
        'timeout_seconds': _i('Stop the command after this long (default 120, max 1800). Ignored for background.'),
        'background': _b('Start it and return at once with a process id.'),
      },
      ['command'],
    ),
    _fn('process_output', 'New output from a background process since the last read, and whether it is still running.', {'id': _str}, ['id']),
    _fn('process_kill', 'Stop a background process (and what it started).', {'id': _str}, ['id']),
    _fn('process_list', 'List the background processes this chat started.', {}),
    _fn(
      'run_node',
      'Run a Node.js script on the user\'s machine (ES module, top-level await works). Good for quick computations, '
          'scripting, JSON wrangling, or using npm packages already in the workspace. Prints what the script logs.',
      {
        'code': _s('The JavaScript source.'),
        'args': {'type': 'array', 'items': _str, 'description': 'Command-line arguments (process.argv.slice(2)).'},
        'timeout_seconds': _i('Default 120.'),
      },
      ['code'],
    ),
    _fn('read_file', 'Read a text file, with line numbers.', {
      'path': _s('Relative to the workspace, or absolute.'),
      'offset': _i('First line to read (1-based).'),
      'limit': _i('How many lines (default 2000).'),
    }, ['path']),
    _fn('write_file', 'Create or overwrite a file with the full content given.', {'path': _str, 'content': _str}, ['path', 'content']),
    _fn('edit_file', 'Replace an exact piece of text in a file. old_text must match exactly and be unique unless replace_all.', {
      'path': _str,
      'old_text': _str,
      'new_text': _str,
      'replace_all': {'type': 'boolean'},
    }, ['path', 'old_text', 'new_text']),
    _fn('list_dir', 'List a folder (skips .git, node_modules, build…).', {'path': _str, 'depth': _i('Default 2.')}),
    _fn('search', 'Search file contents with a regular expression.', {
      'pattern': _str,
      'path': _s('Folder to search. Default: the workspace.'),
      'glob': _s('Only files whose name matches, e.g. *.dart'),
    }, ['pattern']),
    _fn(
      'browser',
      'Use a real web browser to do a task: open sites, click, type, fill forms, read pages, sign-in flows the user has done before. '
          'A browser agent (browser-use) does the clicking and reports back. Give it one clear goal with all the details it needs. '
          'It keeps the same browser between calls, so you can continue where it left off.',
      {
        'task': _s('What to do and what to report back.'),
        'start_url': _s('Where to start (optional).'),
        'max_steps': _i('Most browser steps to take (default 40).'),
      },
      ['task'],
    ),
    _fn(
      'notify',
      'Send the user a system notification, e.g. when a long task finishes or you need them. urgent=true forces it through '
          '(breaks through Do Not Disturb on Windows, full-screen alert on Android). Use urgent only when it truly matters.',
      {'title': _str, 'body': _str, 'urgent': {'type': 'boolean'}},
      ['title', 'body'],
    ),
    for (final t in _github) _fn('github_${t.name}', t.description, t.schema),
  ];

  Map<String, String> get _env => {
    if (github.signedIn) ...{'GH_TOKEN': settings.githubToken, 'GITHUB_TOKEN': settings.githubToken},
  };

  /// Runs [step]. Returns what the model reads; keeps [step] up to date and
  /// calls [changed] whenever the card should redraw.
  Future<String> run(ToolStep step, void Function() changed, {String puterToken = ''}) async {
    final a = step.args;
    String s(String k) => (a[k] ?? '').toString();
    int n(String k, int def) => (a[k] is num) ? (a[k] as num).toInt() : int.tryParse(s(k)) ?? def;

    Future<bool> ask(Ask q) async {
      if (permissions.allowed(q.rule)) return true;
      step.status = StepStatus.asking;
      changed();
      final ok = await permissions.check(q);
      step.status = ok ? StepStatus.running : StepStatus.denied;
      changed();
      return ok;
    }

    const denied = 'The user declined this. Ask them how they want to proceed, or try another way.';

    switch (step.name) {
      case 'run_command':
        final cmd = s('command');
        final (rule, label) = Permissions.commandRule(cmd);
        if (!await ask(Ask(title: 'Run a command', detail: cmd, rule: rule, ruleLabel: label))) return denied;
        if (a['background'] == true) {
          final p = await shell.start(cmd, cwd: s('cwd'), env: _env);
          p.changes.listen((_) {
            step.output = Shell.tail(p.output, 4000);
            changed();
          });
          await Future<void>.delayed(const Duration(seconds: 2));
          final first = p.takeNew();
          return 'Started ${p.id} (${p.running ? 'running' : 'exited with ${p.code}'}).\n${first.isEmpty ? '(no output yet)' : Shell.tail(first)}';
        }
        final timeout = Duration(seconds: n('timeout_seconds', 120).clamp(1, 1800));
        final r = await shell.run(
          cmd,
          cwd: s('cwd'),
          timeout: timeout,
          env: _env,
          onOutput: (o) {
            step.output = Shell.tail(o, 4000);
            changed();
          },
        );
        if (r.exitCode != 0) step.status = StepStatus.failed;
        return r.forModel(timeout);

      case 'process_output':
        final p = shell.processes[s('id')];
        if (p == null) return 'No process ${s('id')}. Running: ${shell.processes.keys.join(', ')}';
        final fresh = p.takeNew();
        step.output = Shell.tail(fresh, 4000);
        return '${p.running ? 'Still running.' : 'Exited with ${p.code}.'}\n${fresh.isEmpty ? '(no new output)' : Shell.tail(fresh)}';

      case 'process_kill':
        final p = shell.processes[s('id')];
        if (p == null) return 'No process ${s('id')}.';
        await p.kill();
        return 'Stopped ${p.id}.';

      case 'process_list':
        return shell.processes.isEmpty ? 'No background processes.' : shell.processes.values.map((p) => p.describe()).join('\n');

      case 'run_node':
        if (!await ask(Ask(title: 'Run a Node.js script', detail: s('code'), rule: 'node', ruleLabel: 'Always allow Node.js scripts'))) {
          return denied;
        }
        final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}sonot-node');
        await dir.create(recursive: true);
        final file = File('${dir.path}${Platform.pathSeparator}script-${DateTime.now().microsecondsSinceEpoch}.mjs');
        await file.writeAsString(s('code'));
        final args = [for (final x in (a['args'] as List? ?? const [])) _quote('$x')].join(' ');
        final timeout = Duration(seconds: n('timeout_seconds', 120).clamp(1, 1800));
        try {
          final r = await shell.run(
            'node ${_quote(file.path)} $args',
            timeout: timeout,
            env: _env,
            onOutput: (o) {
              step.output = Shell.tail(o, 4000);
              changed();
            },
          );
          if (r.exitCode != 0) step.status = StepStatus.failed;
          final missing = r.exitCode != 0 && RegExp(r'not recognized|not found|No such file', caseSensitive: false).hasMatch(r.output) && !r.output.contains('Error:');
          return missing
              ? 'Node.js is not installed. You can install it with ${Platform.isWindows ? '`winget install OpenJS.NodeJS.LTS`' : 'the system package manager'} (ask the user first).'
              : r.forModel(timeout);
        } finally {
          unawaited(file.delete().catchError((_) => file));
        }

      case 'read_file':
        final out = await files.read(s('path'), offset: n('offset', 1), limit: n('limit', 2000));
        step.output = _peek(out);
        return out;

      case 'write_file':
        final path = files.resolve(s('path'));
        final lines = const LineSplitter().convert(s('content')).length;
        if (!await ask(Ask(title: 'Write a file', detail: '$path  ($lines lines)', rule: 'write', ruleLabel: 'Always allow file changes'))) {
          return denied;
        }
        return step.output = await files.write(s('path'), s('content'));

      case 'edit_file':
        final path = files.resolve(s('path'));
        if (!await ask(Ask(title: 'Edit a file', detail: '$path\n− ${_peek(s('old_text'), 6)}\n+ ${_peek(s('new_text'), 6)}', rule: 'write', ruleLabel: 'Always allow file changes'))) {
          return denied;
        }
        return step.output = await files.edit(s('path'), s('old_text'), s('new_text'), all: a['replace_all'] == true);

      case 'list_dir':
        final out = await files.list(s('path'), depth: n('depth', 2).clamp(1, 6));
        step.output = _peek(out);
        return out;

      case 'search':
        final out = await files.search(s('pattern'), path: s('path'), glob: s('glob'));
        step.output = _peek(out);
        return out;

      case 'browser':
        if (!await ask(Ask(title: 'Use the browser', detail: s('task'), rule: 'browser', ruleLabel: 'Always allow the browser'))) return denied;
        return _browse(step, changed, puterToken);

      case 'notify':
        final ok = await Notifier.instance.show(s('title'), s('body'), urgent: a['urgent'] == true);
        return ok ? 'Notification shown.' : 'This device could not show a notification.';

      default:
        if (step.name.startsWith('github_')) return _githubTool(step, changed, ask);
        return 'Unknown tool ${step.name}.';
    }
  }

  Future<String> _browse(ToolStep step, void Function() changed, String puterToken) async {
    final a = step.args;
    final log = <String>[];
    String? result;
    final done = Completer<String>();
    final sub = browser
        .run(
          task: '${a['task']}',
          startUrl: (a['start_url'] as String?)?.trim().isEmpty ?? true ? null : a['start_url'] as String,
          maxSteps: (a['max_steps'] is num) ? (a['max_steps'] as num).toInt() : 40,
          puterToken: puterToken,
          model: browserModel,
          cloud: settings.browserWhere == 'cloud',
        )
        .listen(
          (ev) {
            switch (ev['type']) {
              case 'status':
                log.add('… ${ev['text']}');
              case 'step':
                final goal = '${ev['goal'] ?? ''}'.trim();
                log.add('${ev['n']}. ${goal.isEmpty ? (ev['actions'] as List?)?.join(', ') ?? '' : goal}  ${ev['url'] ?? ''}');
                final shot = ev['screenshot'];
                if (shot is String && shot.isNotEmpty) step.image = base64Decode(shot);
              case 'done':
                result = '${ev['ok'] == true ? 'Done' : 'Finished without success'} after ${ev['steps']} steps.\n'
                    'Result: ${ev['result']}\nPages: ${(ev['urls'] as List?)?.join(', ') ?? ''}'
                    '${(ev['errors'] as List?)?.isNotEmpty ?? false ? '\nErrors: ${(ev['errors'] as List).join(' | ')}' : ''}';
                if (ev['ok'] != true) step.status = StepStatus.failed;
              case 'error':
                step.status = StepStatus.failed;
                result = 'The browser failed: ${ev['message']}';
            }
            step.output = log.length > 14 ? log.sublist(log.length - 14).join('\n') : log.join('\n');
            changed();
          },
          onDone: () => done.complete(result ?? 'The browser stopped without a result.'),
          onError: (Object e) => done.complete('The browser failed: $e'),
        );
    try {
      return await done.future;
    } finally {
      await sub.cancel();
    }
  }

  Future<String> _githubTool(ToolStep step, void Function() changed, Future<bool> Function(Ask) ask) async {
    final name = step.name.substring('github_'.length);
    final tool = _github.where((t) => t.name == name).firstOrNull;
    if (tool == null) return 'GitHub tool $name is not available. Is the user signed in to GitHub?';
    if (!tool.readOnly &&
        !await ask(Ask(title: 'Change something on GitHub', detail: '$name  ${_peek(jsonEncode(step.args), 8)}', rule: 'github', ruleLabel: 'Always allow GitHub changes'))) {
      return 'The user declined this. Ask them how they want to proceed.';
    }
    final (text, isError) = await (await github.mcp()).call(name, step.args);
    if (isError) step.status = StepStatus.failed;
    step.output = _peek(text);
    return Shell.tail(text, 40000);
  }

  static String _quote(String s) => Platform.isWindows ? "'${s.replaceAll("'", "''")}'" : "'${s.replaceAll("'", r"'\''")}'";

  static String _peek(String s, [int lines = 12]) {
    final l = const LineSplitter().convert(s);
    return l.length <= lines ? s : '${l.take(lines).join('\n')}\n…';
  }
}
