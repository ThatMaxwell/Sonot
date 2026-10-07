import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonot_app/code/agent.dart';
import 'package:sonot_app/code/browser.dart';
import 'package:sonot_app/code/files.dart';
import 'package:sonot_app/code/github.dart';
import 'package:sonot_app/code/permissions.dart';
import 'package:sonot_app/code/shell.dart';
import 'package:sonot_app/code/step.dart';
import 'package:sonot_app/code/tools.dart';
import 'package:sonot_app/core/api.dart';
import 'package:sonot_app/core/models.dart';
import 'package:sonot_app/core/settings.dart';
import 'package:sonot_app/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding fakes all HTTP; these tests talk to a local fake Puter.
  HttpOverrides.global = null;
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('sonot_code_');
  });
  tearDown(() => tmp.delete(recursive: true));

  group('permissions', () {
    test('"always" remembers the program, or the whole line when it chains', () {
      expect(Permissions.commandRule('npm test --watch').$1, 'cmd:npm');
      expect(Permissions.commandRule(r'C:\tools\Git.EXE status').$1, 'cmd:git');
      expect(Permissions.commandRule('npm i && rm -rf /').$1, 'cmd=npm i && rm -rf /');
      expect(Permissions.commandRule('cat a | sh').$1, startsWith('cmd='));
    });

    test('asks once, then remembers Always allow', () async {
      final settings = await Settings.load();
      final perms = Permissions(settings);
      var asked = 0;
      perms.onAsk = (_) async {
        asked++;
        return Approval.always;
      };
      final ask = Ask(title: 'Run', detail: 'npm test', rule: 'cmd:npm', ruleLabel: '');
      expect(await perms.check(ask), isTrue);
      expect(await perms.check(ask), isTrue);
      expect(asked, 1);
      perms.onAsk = (_) async => Approval.deny;
      expect(await perms.check(Ask(title: 'Run', detail: 'rm x', rule: 'cmd:rm', ruleLabel: '')), isFalse);
    });
  });

  group('shell', skip: Platform.isWindows ? 'bash tests' : null, () {
    test('runs a command and returns its output and exit code', () async {
      final sh = Shell(workspace: () => tmp.path);
      final r = await sh.run('echo hello; echo oops >&2; exit 3');
      expect(r.exitCode, 3);
      expect(r.output, contains('hello'));
      expect(r.output, contains('oops'));
    });

    test('times out and stops the command', () async {
      final sh = Shell(workspace: () => tmp.path);
      final r = await sh.run('sleep 30', timeout: const Duration(milliseconds: 300));
      expect(r.timedOut, isTrue);
    });

    test('background processes report new output and can be killed', () async {
      final sh = Shell(workspace: () => tmp.path);
      final p = await sh.start('for i in 1 2 3; do echo tick \$i; sleep 0.1; done; sleep 30');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(p.takeNew(), contains('tick 3'));
      expect(p.takeNew(), isEmpty);
      await p.kill();
      expect(p.running, isFalse);
    });
  });

  group('files', () {
    test('write, read with line numbers, edit and search', () async {
      final f = Files(workspace: () => tmp.path);
      await f.write('src/a.txt', 'one\ntwo\nthree\n');
      expect(await f.read('src/a.txt'), contains('    2  two'));
      await f.edit('src/a.txt', 'two', 'TWO');
      expect(File('${tmp.path}/src/a.txt').readAsStringSync(), 'one\nTWO\nthree\n');
      expect(() => f.edit('src/a.txt', 'missing', 'x'), throwsFormatException);
      expect(await f.search('TW.'), contains('a.txt:2:TWO'));
      expect(await f.list(''), contains('a.txt'));
    });
  });

  test('the agent runs tool calls and sends results back until it answers', skip: Platform.isWindows ? 'bash' : null, () async {
    final requests = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      final args = body['args'] as Map<String, dynamic>;
      requests.add(args);
      req.response.headers.contentType = ContentType('application', 'x-ndjson');
      if (requests.length == 1) {
        req.response
          ..writeln(jsonEncode({'type': 'text', 'text': 'Running it.'}))
          ..writeln(jsonEncode({'type': 'reasoning_detail', 'detail': {'type': 'thinking', 'thinking': 'hm', 'signature': 'sig'}}))
          ..writeln(jsonEncode({'type': 'tool_use', 'id': 'call_1', 'name': 'run_command', 'input': {'command': 'echo from-tool'}, 'text': ''}));
      } else {
        req.response.writeln(jsonEncode({'type': 'text', 'text': 'It printed from-tool.'}));
      }
      await req.response.close();
    });

    final settings = await Settings.load();
    settings.workspace = tmp.path;
    final perms = Permissions(settings)..onAsk = (_) async => Approval.once;
    final agent = CodeAgent(
      Toolbox(
        settings: settings,
        permissions: perms,
        browser: BrowserRunner(cloudServer: () => '', cloudToken: () => ''),
        github: GitHub(settings),
      ),
    );
    final tier = tierById('anthem');
    final done = Completer<ChatMessage>();
    agent.send(
      'say hi from the shell',
      provider: PuterProvider('tok', api: 'http://127.0.0.1:${server.port}'),
      build: (h) => ChatRequest(history: h, mode: Mode.code, tier: tier, effort: tier.defaultEffort),
      onDone: done.complete,
    );
    final reply = await done.future.timeout(const Duration(seconds: 20));

    expect(reply.error, isFalse, reason: reply.text);
    expect(reply.text, 'Running it.\n\nIt printed from-tool.');
    expect(reply.steps.single.status, StepStatus.done);
    expect(reply.steps.single.at, 'Running it.'.length);
    expect(requests, hasLength(2));
    expect((requests.first['tools'] as List).map((t) => t['function']['name']), containsAll(['run_command', 'browser', 'run_node', 'notify']));
    final wire = (requests[1]['messages'] as List).cast<Map>();
    final assistant = wire[2];
    expect(assistant['role'], 'assistant');
    expect((assistant['content'] as List).last, {'type': 'tool_use', 'id': 'call_1', 'name': 'run_command', 'input': {'command': 'echo from-tool'}});
    expect(assistant['reasoning_details'], [{'type': 'thinking', 'thinking': 'hm', 'signature': 'sig'}]);
    expect(wire[3]['role'], 'tool');
    expect(wire[3]['tool_call_id'], 'call_1');
    expect(wire[3]['content'], contains('from-tool'));
  });

  test('a Bud drives its own cloud computer and sees the screenshot', () async {
    final requests = <Map<String, dynamic>>[];
    final actions = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      if (req.uri.path == '/v1/computer') {
        actions.add(body);
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'ok': true, 'text': 'Screen is 1280x800.', 'screenshot': base64Encode([1, 2, 3])}));
        return req.response.close();
      }
      requests.add(body['args'] as Map<String, dynamic>);
      req.response.headers.contentType = ContentType('application', 'x-ndjson');
      if (requests.length == 1) {
        req.response.writeln(jsonEncode({'type': 'tool_use', 'id': 't1', 'name': 'computer', 'input': {'action': 'screenshot'}}));
      } else {
        req.response.writeln(jsonEncode({'type': 'text', 'text': 'I see my desktop [[emo:happy]]'}));
      }
      await req.response.close();
    });

    final settings = await Settings.load();
    settings.workspace = tmp.path;
    settings.server = '127.0.0.1:${server.port}';
    final tools = Toolbox(
      settings: settings,
      permissions: Permissions(settings),
      browser: BrowserRunner(cloudServer: () => settings.server, cloudToken: () => ''),
      github: GitHub(settings),
    );
    final agent = CodeAgent(tools, system: (r) => 'persona', only: const {'browser', 'computer', 'notify'}, computer: tools.computerName('bud-pip'));
    final tier = tierById('anthem');
    final done = Completer<ChatMessage>();
    agent.send(
      'open ur computer',
      provider: PuterProvider('tok', api: 'http://127.0.0.1:${server.port}'),
      build: (h) => ChatRequest(history: h, mode: Mode.buds, tier: tier, effort: tier.defaultEffort),
      filter: (c) => c.replaceAll(RegExp(r'\s*\[\[emo:\w+\]\]'), ''),
      onDone: done.complete,
    );
    final reply = await done.future.timeout(const Duration(seconds: 20));

    expect(reply.error, isFalse, reason: reply.text);
    expect(reply.text, 'I see my desktop');
    expect(actions.single['action'], 'screenshot');
    expect(actions.single['computer'], startsWith('bud-pip-'));
    expect((requests.first['tools'] as List).map((t) => t['function']['name']), unorderedEquals(['browser', 'computer', 'notify']));
    expect((requests.first['messages'] as List).first['content'], 'persona');
    final wire = (requests[1]['messages'] as List).cast<Map>();
    expect(wire[3]['role'], 'tool');
    expect(wire[4]['role'], 'user');
    expect((wire[4]['content'] as List).last['image_url']['url'], 'data:image/jpeg;base64,${base64Encode([1, 2, 3])}');
    expect(reply.steps.single.image, isNotNull);
  });
}
