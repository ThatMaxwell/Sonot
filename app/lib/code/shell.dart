import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs commands and processes on this machine for Sonot Code.
///
/// Windows uses PowerShell, Linux bash (or sh), Android the app's own sh
/// (which can only see the app's folders).
class Shell {
  Shell({required this.workspace});

  /// Where commands start unless the agent passes `cwd`.
  String Function() workspace;

  final Map<String, ManagedProcess> processes = {};
  int _next = 1;

  /// Keeps this much of each process's output.
  static const keepBytes = 256 * 1024;

  /// Hands this much of an output back to the model.
  static const returnChars = 16000;

  static (String, List<String>) shellFor(String command) {
    if (Platform.isWindows) {
      // UTF-8 out, so non-English output survives the trip.
      return (
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', '[Console]::OutputEncoding=[Text.Encoding]::UTF8; $command'],
      );
    }
    if (Platform.isAndroid) return ('/system/bin/sh', ['-c', command]);
    final bash = File('/bin/bash').existsSync() ? '/bin/bash' : '/bin/sh';
    // setsid gives the command its own process group, so stopping it also
    // stops whatever it started.
    if (File('/usr/bin/setsid').existsSync()) return ('/usr/bin/setsid', [bash, '-lc', command]);
    return (bash, ['-lc', command]);
  }

  String _cwd(String? cwd) {
    final base = workspace();
    if (cwd == null || cwd.trim().isEmpty) return base;
    final c = cwd.trim();
    final abs = Platform.isWindows ? RegExp(r'^([a-zA-Z]:|\\\\)').hasMatch(c) : c.startsWith('/');
    return abs ? c : '$base${Platform.pathSeparator}$c';
  }

  Future<ManagedProcess> _start(String command, String? cwd, {Map<String, String>? env}) async {
    final dir = _cwd(cwd);
    if (!Directory(dir).existsSync()) throw ShellException('Folder not found: $dir');
    final (exe, args) = shellFor(command);
    final p = await Process.start(exe, args, workingDirectory: dir, environment: env, runInShell: false);
    final mp = ManagedProcess('p${_next++}', command, dir, p);
    processes[mp.id] = mp;
    return mp;
  }

  /// Runs [command] to the end (or [timeout]) and returns its output.
  /// [onOutput] gets the output as it arrives, for the step card.
  Future<CommandResult> run(
    String command, {
    String? cwd,
    Duration timeout = const Duration(minutes: 2),
    void Function(String text)? onOutput,
    Map<String, String>? env,
  }) async {
    final mp = await _start(command, cwd, env: env);
    final sub = mp.changes.listen((_) => onOutput?.call(mp.output));
    final code = await mp.exitCode.timeout(timeout, onTimeout: () async {
      await mp.kill();
      mp.timedOut = true;
      return -1;
    });
    await mp.drained;
    await sub.cancel();
    processes.remove(mp.id);
    return CommandResult(code, mp.output, timedOut: mp.timedOut);
  }

  /// Starts [command] in the background and returns at once.
  Future<ManagedProcess> start(String command, {String? cwd, Map<String, String>? env}) async =>
      (await _start(command, cwd, env: env))..background = true;

  /// Stops commands that are running in the foreground (when you press stop).
  Future<void> killForeground() async {
    for (final p in processes.values.where((p) => !p.background && p.running).toList()) {
      await p.kill();
    }
  }

  Future<void> killAll() async {
    for (final p in processes.values.toList()) {
      if (p.running) await p.kill();
    }
  }

  /// Trims [text] to the last [returnChars] characters for the model.
  static String tail(String text, [int max = returnChars]) {
    if (text.length <= max) return text;
    return '[… ${text.length - max} earlier characters cut …]\n${text.substring(text.length - max)}';
  }
}

class ShellException implements Exception {
  ShellException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CommandResult {
  CommandResult(this.exitCode, this.output, {this.timedOut = false});
  final int exitCode;
  final String output;
  final bool timedOut;

  /// What the model reads.
  String forModel(Duration timeout) {
    final head = timedOut ? 'Timed out after ${timeout.inSeconds}s and was stopped.' : 'Exit code $exitCode.';
    final body = output.trim().isEmpty ? '(no output)' : Shell.tail(output);
    return '$head\n$body';
  }
}

/// A process Sonot Code started, with its output so far.
class ManagedProcess {
  ManagedProcess(this.id, this.command, this.cwd, this.process) {
    final done = <Future<void>>[];
    for (final s in [process.stdout, process.stderr]) {
      final c = Completer<void>();
      done.add(c.future);
      s.transform(const Utf8Decoder(allowMalformed: true)).listen(_add, onDone: c.complete, onError: (_) => c.complete());
    }
    drained = Future.wait(done);
    exitCode = process.exitCode.then((c) {
      code = c;
      _changes.add(null);
      return c;
    });
  }

  final String id;
  final String command;
  final String cwd;
  final Process process;
  final DateTime started = DateTime.now();
  late final Future<int> exitCode;
  late final Future<void> drained;
  int? code;
  bool timedOut = false;
  bool background = false;

  final _buf = StringBuffer();
  int _readTo = 0;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  bool get running => code == null;
  String get output => _buf.toString();

  void _add(String s) {
    _buf.write(s);
    if (_buf.length > Shell.keepBytes) {
      final keep = _buf.toString().substring(_buf.length - Shell.keepBytes ~/ 2);
      _readTo = (_readTo - (_buf.length - keep.length)).clamp(0, keep.length);
      _buf
        ..clear()
        ..write(keep);
    }
    _changes.add(null);
  }

  /// Output since the last call (what's new for the model).
  String takeNew() {
    final all = output;
    final fresh = all.substring(_readTo.clamp(0, all.length));
    _readTo = all.length;
    return fresh;
  }

  Future<void> kill() async {
    if (!running) return;
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/T', '/F', '/PID', '${process.pid}']);
    } else if (!Platform.isAndroid && File('/usr/bin/setsid').existsSync()) {
      // The whole group setsid made.
      await Process.run('kill', ['-TERM', '--', '-${process.pid}']);
    } else {
      process.kill();
    }
    await exitCode.timeout(const Duration(seconds: 3), onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
  }

  String describe() {
    final state = running ? 'running' : 'exited with $code';
    return '$id  $state  since ${started.toIso8601String().substring(11, 19)}  $command';
  }
}
