import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One event from a browser task (see assets/helpers/sonot_browser.py).
typedef BrowserEvent = Map<String, dynamic>;

/// Sonot Code's browser, built on browser-use.
///
/// On Windows and Linux it runs the Python helper on this computer through
/// uv (downloaded on first use, so nothing needs installing by hand); the
/// browser is Chrome, Edge or Chromium with a Sonot profile of its own. On
/// Android, or when you pick "cloud", the Sonot server runs the same helper
/// against a cua.ai cloud computer.
class BrowserRunner {
  BrowserRunner({required this.cloudServer, required this.cloudToken});

  /// The Sonot server for cloud browsing.
  final String Function() cloudServer;
  final String Function() cloudToken;

  Process? _helper;
  Future<void>? _starting;
  final _tasks = <String, StreamController<BrowserEvent>>{};
  final _stderr = <String>[];
  int _next = 1;

  static bool get canRunLocally => Platform.isWindows || Platform.isLinux;

  /// Runs [task] and streams step, status, done and error events. Cancel the
  /// subscription to stop the task.
  Stream<BrowserEvent> run({
    required String task,
    required String puterToken,
    required String model,
    String? startUrl,
    int maxSteps = 40,
    bool cloud = false,
  }) {
    final req = {
      'type': 'task',
      'id': 'b${_next++}',
      'task': task,
      'token': puterToken,
      'model': model,
      'start_url': ?startUrl,
      'max_steps': maxSteps,
    };
    return cloud || !canRunLocally ? _cloud(req) : _local(req);
  }

  // ---- On this computer -----------------------------------------------

  Stream<BrowserEvent> _local(Map<String, dynamic> req) {
    final id = req['id'] as String;
    late final StreamController<BrowserEvent> out;
    out = StreamController<BrowserEvent>(
      onListen: () async {
        try {
          if (_helper == null) {
            out.add({'type': 'status', 'text': 'Getting the browser ready (the first time takes a minute)'});
          }
          await (_starting ??= _startHelper());
          _tasks[id] = out;
          _helper!.stdin.writeln(jsonEncode(req));
        } catch (e) {
          out
            ..add({'type': 'error', 'message': '$e'})
            ..close();
        }
      },
      onCancel: () {
        if (_tasks.remove(id) != null) _helper?.stdin.writeln(jsonEncode({'type': 'cancel', 'id': id}));
      },
    );
    return out.stream;
  }

  Future<void> _startHelper() async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}browser');
      await dir.create(recursive: true);
      final script = File('${dir.path}${Platform.pathSeparator}sonot_browser.py');
      await script.writeAsString(await rootBundle.loadString('assets/helpers/sonot_browser.py'));
      final uv = await _uv(dir);
      final p = await Process.start(
        uv,
        ['run', '--quiet', '--python', '3.12', script.path],
        workingDirectory: dir.path,
        environment: {
          'SONOT_BROWSER_PROFILE': '${dir.path}${Platform.pathSeparator}profile',
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUNBUFFERED': '1',
        },
      );
      _helper = p;
      final ready = Completer<void>();
      p.stdout.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((line) {
        BrowserEvent ev;
        try {
          ev = (jsonDecode(line) as Map).cast<String, dynamic>();
        } catch (_) {
          return;
        }
        if (ev['type'] == 'ready') {
          if (!ready.isCompleted) ready.complete();
          return;
        }
        final t = _tasks[ev['id']];
        if (t == null) return;
        t.add(ev);
        if (ev['type'] == 'done' || ev['type'] == 'error') {
          _tasks.remove(ev['id']);
          t.close();
        }
      });
      p.stderr.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((l) {
        _stderr.add(l);
        if (_stderr.length > 40) _stderr.removeAt(0);
      });
      unawaited(
        p.exitCode.then((code) {
          final why = 'The browser helper stopped (exit $code). ${_stderr.reversed.take(6).toList().reversed.join('\n')}';
          if (!ready.isCompleted) ready.completeError(why);
          for (final t in _tasks.values) {
            t
              ..add({'type': 'error', 'message': why})
              ..close();
          }
          _tasks.clear();
          _helper = null;
          _starting = null;
        }),
      );
      // First run downloads Python and browser-use.
      await ready.future.timeout(const Duration(minutes: 10));
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  /// uv on PATH, or a copy we downloaded into [dir].
  Future<String> _uv(Directory dir) async {
    final exe = Platform.isWindows ? 'uv.exe' : 'uv';
    try {
      final r = await Process.run(exe, ['--version']);
      if (r.exitCode == 0) return exe;
    } on ProcessException {
      // Not installed; fetch it below.
    }
    final local = File('${dir.path}${Platform.pathSeparator}$exe');
    if (local.existsSync()) return local.path;

    final arch = (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) ? 'aarch64' : 'x86_64';
    final name = Platform.isWindows ? 'uv-$arch-pc-windows-msvc.zip' : 'uv-$arch-unknown-linux-gnu.tar.gz';
    final res = await http.get(Uri.parse('https://github.com/astral-sh/uv/releases/latest/download/$name'));
    if (res.statusCode != 200) throw Exception("Couldn't download uv (${res.statusCode}).");
    final archive = File('${dir.path}${Platform.pathSeparator}$name');
    await archive.writeAsBytes(res.bodyBytes);
    final unpack = Directory('${dir.path}${Platform.pathSeparator}uv-unpack');
    await unpack.create(recursive: true);
    final r = Platform.isWindows
        ? await Process.run('powershell.exe', [
            '-NoProfile',
            '-Command',
            'Expand-Archive -Force -LiteralPath "${archive.path}" -DestinationPath "${unpack.path}"',
          ])
        : await Process.run('tar', ['xzf', archive.path, '-C', unpack.path]);
    if (r.exitCode != 0) throw Exception("Couldn't unpack uv: ${r.stderr}");
    final found = unpack.listSync(recursive: true).whereType<File>().firstWhere(
      (f) => f.path.endsWith('${Platform.pathSeparator}$exe'),
      orElse: () => throw Exception('uv was not in the download.'),
    );
    await found.copy(local.path);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', local.path]);
    await unpack.delete(recursive: true);
    await archive.delete();
    return local.path;
  }

  /// Closes the browser window (the helper keeps running).
  void closeBrowser() => _helper?.stdin.writeln(jsonEncode({'type': 'close'}));

  void dispose() {
    _helper?.kill();
    _helper = null;
  }

  // ---- On a cua.ai cloud computer, through the Sonot server -------------

  Stream<BrowserEvent> _cloud(Map<String, dynamic> req) {
    final client = http.Client();
    late final StreamController<BrowserEvent> out;
    out = StreamController<BrowserEvent>(
      onListen: () async {
        try {
          var base = cloudServer().trim();
          if (base.isEmpty) {
            throw Exception(
              Platform.isAndroid
                  ? 'Browsing from a phone runs on a cloud computer through a Sonot server, and none is set up. Add one under Use my own server.'
                  : 'No Sonot server is set for cloud browsing.',
            );
          }
          if (!base.startsWith('http')) base = 'http://$base';
          base = base.replaceFirst(RegExp(r'/$'), '');
          final token = cloudToken();
          final res = await client.send(
            http.Request('POST', Uri.parse('$base/v1/browser'))
              ..headers.addAll({'content-type': 'application/json', if (token.isNotEmpty) 'authorization': 'Bearer $token'})
              ..body = jsonEncode(req),
          );
          if (res.statusCode != 200) {
            throw Exception('The Sonot server answered ${res.statusCode}: ${await res.stream.bytesToString()}');
          }
          out.add({'type': 'status', 'text': 'Starting a cloud computer'});
          await for (final line in res.stream.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter())) {
            if (!line.startsWith('data:')) continue;
            final ev = (jsonDecode(line.substring(5).trim()) as Map).cast<String, dynamic>();
            out.add(ev);
            if (ev['type'] == 'done' || ev['type'] == 'error') break;
          }
        } catch (e) {
          if (!out.isClosed) out.add({'type': 'error', 'message': '$e'.replaceFirst('Exception: ', '')});
        } finally {
          client.close();
          if (!out.isClosed) await out.close();
        }
      },
      onCancel: client.close,
    );
    return out.stream;
  }
}
