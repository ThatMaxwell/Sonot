import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/conversation.dart';
import 'notify.dart';
import 'step.dart';
import 'tools.dart';

const _agentPrompt = '''
You are Sonot Code, the coding agent in the Sonot app, made by ThatMaxwell. You work on the user's own machine through tools:
shell commands and background processes, Node.js scripts, files, a real web browser (browser-use), your own cloud computer
(a Linux desktop you see through screenshots and drive with mouse and keyboard), notifications and, when they've signed in, GitHub.

How to work:
- Act, don't describe. Look before you change things: list, read and search first, then edit, then run the build or tests to check.
- Prefer edit_file for small changes and write_file for new files. Keep changes focused on what was asked.
- Long-running things (dev servers, watchers) go in the background; read them with process_output and stop them when done.
- The user approves commands, file changes and browsing. If they decline, don't retry the same thing; ask or find another way.
- Use the browser for anything that needs a website: research, docs, web apps, forms, checking a page you built.
- When a task takes a while, send a notification at the end. Use urgent only when something truly needs them now.
- Finish with a short summary of what you did and anything they should know. Use Markdown, and fenced code blocks with a language tag.''';

/// Sonot Code's agent: one conversation where the model can call tools.
///
/// Runs the tool loop against Puter's chat API (the same `drivers/call`
/// endpoint the chat uses, with `tools`): stream a turn, run the tool calls
/// it asked for, send the results back, repeat until it answers. Your own
/// Sonot server doesn't do tools yet, so Code there is plain chat.
class CodeAgent extends Conversation {
  CodeAgent(this.toolbox, {this.system, this.only, this.computer});
  final Toolbox toolbox;

  /// The system prompt; Sonot Code's own when null. Buds bring their persona.
  final String Function(ChatRequest req)? system;

  /// The tools this agent may use; all of them when null.
  final Set<String>? only;

  /// The cloud computer this agent owns (each Bud has its own).
  final String? computer;

  /// Screenshots kept in the model's view; older ones are dropped to save room.
  static const keepScreens = 3;

  /// What the model sees, including tool calls and results.
  final List<Map<String, dynamic>> _wire = [];
  bool _running = false;
  bool _cancelled = false;
  http.Client? _client;
  final Set<String> _pending = {};

  static const maxTurns = 80;

  @override
  bool get busy => _running || super.busy;

  @override
  void send(
    String text, {
    required ChatProvider provider,
    required ChatRequest Function(List<ChatMessage> history) build,
    String Function(String chunk)? filter,
    void Function(ChatMessage reply)? onDone,
    void Function(ApiException e)? onError,
  }) {
    if (provider is! PuterProvider) {
      super.send(text, provider: provider, build: build, filter: filter, onDone: onDone, onError: onError);
      return;
    }
    if (busy || text.trim().isEmpty) return;
    final user = ChatMessage('user', text.trim());
    final reply = ChatMessage('assistant', '');
    final req = build([...messages.where((m) => !m.error), user]);
    messages
      ..add(user)
      ..add(reply);
    streaming = reply;
    _running = true;
    _cancelled = false;
    _wire.add({'role': 'user', 'content': user.text});
    notifyListeners();
    _loop(reply, provider, req, filter).then((_) {
      onDone?.call(reply);
    }, onError: (Object e) {
      reply.error = true;
      final msg = e is ApiException ? e.message : '$e';
      reply.text = reply.text.isEmpty ? msg : '${reply.text}\n\n$msg';
      if (e is ApiException) onError?.call(e);
    }).whenComplete(() {
      _running = false;
      streaming = null;
      _closePending('Stopped by the user.');
      notifyListeners();
      final done = !reply.error && !_cancelled;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed && !_cancelled) {
        Notifier.instance.show(done ? 'Sonot Code is done' : 'Sonot Code stopped', _firstLine(reply.text));
      }
    });
  }

  Future<void> _loop(ChatMessage reply, PuterProvider puter, ChatRequest req, String Function(String)? filter) async {
    await toolbox.prepare();
    toolbox.browserModel = req.tier.id == 'anthem' || req.tier.id == 'chord' ? 'claude-sonnet-5-5' : req.tier.model;
    final system = this.system?.call(req) ?? '$_agentPrompt\n\n${toolbox.platformNote}';
    for (var turn = 0; turn < maxTurns && !_cancelled; turn++) {
      final turnText = StringBuffer();
      final uses = <Map<String, dynamic>>[];
      final reasoning = <Object>[];
      await _complete(puter, req, system, onText: (t) {
        if (turnText.isEmpty && reply.text.isNotEmpty && !reply.text.endsWith('\n')) reply.text += '\n\n';
        turnText.write(t);
        reply.text += filter == null ? t : filter(t);
        notifyListeners();
      }, onTool: uses.add, onReasoning: reasoning.add);
      if (_cancelled) return;
      if (turnText.isEmpty && uses.isEmpty) break;
      _wire.add({
        'role': 'assistant',
        'content': [
          if (turnText.isNotEmpty) {'type': 'text', 'text': turnText.toString()},
          for (final u in uses) {...u, 'type': 'tool_use'},
        ],
        if (reasoning.isNotEmpty) 'reasoning_details': reasoning,
      });
      if (uses.isEmpty) break;
      _pending.addAll(uses.map((u) => u['id'] as String));
      final screens = <ToolStep>[];
      for (final u in uses) {
        if (_cancelled) return;
        final input = u['input'];
        final step = ToolStep(
          id: u['id'] as String,
          name: u['name'] as String,
          args: input is Map ? input.cast<String, dynamic>() : (input is String && input.isNotEmpty ? (jsonDecode(input) as Map).cast<String, dynamic>() : {}),
          at: reply.text.length,
        );
        reply.steps.add(step);
        notifyListeners();
        String result;
        try {
          result = await toolbox.run(step, notifyListeners, puterToken: puter.token, computer: computer);
          if (step.status == StepStatus.running) step.status = StepStatus.done;
        } catch (e) {
          step.status = StepStatus.failed;
          step.output = '$e';
          result = 'Error: $e';
        }
        notifyListeners();
        if (_cancelled) return;
        _pending.remove(step.id);
        _wire.add({'role': 'tool', 'tool_call_id': step.id, 'content': result});
        if (step.modelImage != null) screens.add(step);
      }
      // Tool results are text-only on Puter, so screens follow as one user
      // message after all of this turn's results (they must come first).
      if (screens.isNotEmpty) {
        _wire.add({
          'role': 'user',
          'content': [
            for (final st in screens) ...[
              {'type': 'text', 'text': 'Screenshot after ${st.title}:'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,${st.modelImage}'},
              },
            ],
          ],
        });
        _dropOldScreens();
      }
    }
  }

  /// One streamed model turn.
  Future<void> _complete(
    PuterProvider puter,
    ChatRequest req,
    String system, {
    required void Function(String) onText,
    required void Function(Map<String, dynamic>) onTool,
    required void Function(Object) onReasoning,
  }) async {
    final client = _client = http.Client();
    try {
      final res = await client.send(
        http.Request('POST', Uri.parse('${puter.api}/drivers/call'))
          ..headers.addAll({'content-type': 'application/json', 'authorization': 'Bearer ${puter.token}'})
          ..body = jsonEncode({
            'interface': 'puter-chat-completion',
            'driver': 'ai-chat',
            'method': 'complete',
            'args': {
              'model': req.tier.model,
              'stream': true,
              'reasoning_effort': req.effort.puter,
              'tools': toolbox.schemasFor(only),
              'messages': [
                {'role': 'system', 'content': system},
                ..._wire,
              ],
            },
            'auth_token': puter.token,
          }),
      );
      if (res.statusCode != 200) {
        final body = await res.stream.bytesToString();
        throw ApiException(switch (res.statusCode) {
          401 => 'Your Puter sign-in expired. Sign in again.',
          402 => 'Your Puter AI allowance is used up for now.',
          _ => _errorText(body, 'Puter answered ${res.statusCode}.'),
        }, signedOut: res.statusCode == 401);
      }
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_cancelled) break;
        if (line.trim().isEmpty) continue;
        final j = jsonDecode(line);
        if (j is! Map) continue;
        if (j['type'] == 'error' || j['success'] == false || j['error'] != null) throw ApiException(_errorText(line, 'Puter returned an error.'));
        switch (j['type']) {
          case 'text':
            final t = j['text'];
            if (t is String && t.isNotEmpty) onText(t);
          case 'tool_use':
            onTool(Map<String, dynamic>.from(j)..remove('type')..remove('text'));
          case 'reasoning_detail':
            final d = j['detail'];
            if (d != null) onReasoning(d);
        }
      }
    } on http.ClientException {
      if (!_cancelled) throw ApiException("Couldn't reach Sonot. Check your connection.");
    } finally {
      client.close();
      _client = null;
    }
  }

  void _dropOldScreens() {
    var seen = 0;
    for (final m in _wire.reversed) {
      final c = m['content'];
      if (c is! List || !c.any((p) => p is Map && p['type'] == 'image_url')) continue;
      if (++seen > keepScreens) {
        m['content'] = [
          for (final p in c)
            if (p is Map && p['type'] == 'image_url') {'type': 'text', 'text': '(older screenshot removed)'} else p,
        ];
      }
    }
  }

  /// Every tool call needs a result before the next turn, even stopped ones.
  void _closePending(String why) {
    for (final id in _pending) {
      _wire.add({'role': 'tool', 'tool_call_id': id, 'content': why});
    }
    _pending.clear();
  }

  @override
  void stop() {
    if (!_running) return super.stop();
    _cancelled = true;
    _client?.close();
    toolbox.shell.killForeground();
    for (final m in messages) {
      for (final s in m.steps) {
        if (s.status == StepStatus.running || s.status == StepStatus.asking) s.status = StepStatus.failed;
      }
    }
    toolbox.permissions.cancelAsk?.call();
    notifyListeners();
  }

  @override
  void clear() {
    stop();
    _wire.clear();
    toolbox.shell.killAll();
    super.clear();
  }

  static String _firstLine(String s) {
    final l = s.trim().split('\n').firstWhere((x) => x.trim().isNotEmpty, orElse: () => 'Your task finished.');
    return l.length > 140 ? '${l.substring(0, 140)}…' : l;
  }

  static String _errorText(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        if (e is Map && e['message'] is String) return e['message'] as String;
        if (j['message'] is String) return j['message'] as String;
        if (e is String) return e;
      }
    } catch (_) {}
    return fallback;
  }
}
