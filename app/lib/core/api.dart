import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../code/step.dart';
import 'models.dart';
import 'theme.dart';

class ChatMessage {
  ChatMessage(this.role, this.text);
  final String role; // 'user' | 'assistant'
  String text;
  bool error = false;

  /// Sonot Code: the tool calls made while writing this reply.
  final List<ToolStep> steps = [];

  Map<String, String> toJson() => {'role': role, 'content': text};
}

class ApiException implements Exception {
  ApiException(this.message, {this.signedOut = false});
  final String message;

  /// The provider rejected our credentials; the app should ask to sign in again.
  final bool signedOut;

  @override
  String toString() => message;
}

/// One request: the conversation plus the knobs from the composer.
class ChatRequest {
  ChatRequest({required this.history, required this.mode, required this.tier, required this.effort, this.system});
  final List<ChatMessage> history;

  /// Overrides the mode's system prompt (Buds bring their own persona).
  final String? system;
  final Mode mode;
  final Tier tier;
  final Effort effort;
}

/// Where replies come from. Both stream plain text chunks; cancel the
/// subscription to stop generating.
abstract class ChatProvider {
  Stream<String> chat(ChatRequest req);
}

const systemPrompts = {
  Mode.chat:
      'You are Sonot, a friendly and sharp AI assistant made by ThatMaxwell. '
      'Answer clearly and get to the point. Use Markdown when it helps (lists, code blocks), '
      'and plain prose for casual chat.',
  Mode.code:
      'You are Sonot Code, the coding side of Sonot, made by ThatMaxwell. '
      'You are a senior engineer pairing with the user. Be precise and direct. Prefer working code over discussion: '
      'give complete, runnable snippets in fenced code blocks with a language tag, then a short note on anything non-obvious. '
      'Ask a clarifying question only when the task truly cannot proceed without it.',
  // Buds always send their own persona; this is only a fallback.
  Mode.buds: 'You are a Sonot Bud, a friendly AI helper made by ThatMaxwell.',
};

/// Runs [send] and turns its line stream into a text stream with uniform
/// error handling. [onLine] returns text to emit, or throws.
Stream<String> _lineStream(
  Future<http.StreamedResponse> Function(http.Client) send,
  String? Function(String line) onLine,
  String Function(int status, String body) describeHttpError,
) {
  final client = http.Client();
  late final StreamController<String> out;
  out = StreamController<String>(
    onListen: () async {
      try {
        final res = await send(client);
        if (res.statusCode != 200) {
          final body = await res.stream.bytesToString();
          throw ApiException(describeHttpError(res.statusCode, body), signedOut: res.statusCode == 401);
        }
        await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (out.isClosed) break;
          if (line.trim().isEmpty) continue;
          final text = onLine(line);
          if (text != null && text.isNotEmpty) out.add(text);
        }
      } on ApiException catch (e) {
        if (!out.isClosed) out.addError(e);
      } catch (e) {
        if (!out.isClosed) out.addError(ApiException("Couldn't reach Sonot. Check your connection."));
      } finally {
        client.close();
        if (!out.isClosed) await out.close();
      }
    },
    onCancel: client.close,
  );
  return out.stream;
}

String _errorFrom(String body, String fallback) {
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

/// Puter's user-pays AI (the same API puter.js calls): each user signs in
/// with their own Puter account, which covers their usage. No keys in the app.
class PuterProvider implements ChatProvider {
  PuterProvider(this.token, {this.api = 'https://api.puter.com'});
  final String token;
  final String api;

  @override
  Stream<String> chat(ChatRequest req) => _lineStream(
    (client) => client.send(
      http.Request('POST', Uri.parse('$api/drivers/call'))
        // Plain JSON: Puter only reads `text/plain;actually=json` when the
        // header matches exactly, and Dart appends `; charset=utf-8` to it.
        ..headers.addAll({'content-type': 'application/json', 'authorization': 'Bearer $token'})
        ..body = jsonEncode({
          'interface': 'puter-chat-completion',
          'driver': 'ai-chat',
          'method': 'complete',
          'args': {
            'model': req.tier.model,
            'stream': true,
            'reasoning_effort': req.effort.puter,
            'messages': [
              {'role': 'system', 'content': req.system ?? systemPrompts[req.mode]},
              for (final m in req.history) m.toJson(),
            ],
          },
          'auth_token': token,
        }),
    ),
    (line) {
      final j = jsonDecode(line);
      if (j is! Map) return null;
      if (j['type'] == 'error' || j['success'] == false || j['error'] != null) {
        throw ApiException(_errorFrom(line, 'Puter returned an error.'));
      }
      return j['type'] == 'text' ? j['text'] as String? : null;
    },
    (status, body) => switch (status) {
      401 => 'Your Puter sign-in expired. Sign in again.',
      402 => 'Your Puter AI allowance is used up for now.',
      _ => _errorFrom(body, 'Puter answered $status.'),
    },
  );

  /// The signed-in user's name, also a cheap check that the token works.
  Future<String> whoami() async {
    final res = await http
        .get(Uri.parse('$api/whoami'), headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) throw ApiException('That Puter sign-in did not work.', signedOut: true);
    if (res.statusCode != 200) throw ApiException('Puter answered ${res.statusCode}.');
    return ((jsonDecode(res.body) as Map)['username'] as String?) ?? 'you';
  }
}

/// Your own Sonot server (see /server in the repo), which holds an
/// Anthropic API key.
class ServerProvider implements ChatProvider {
  ServerProvider({required this.server, required this.token});
  final String server;
  final String token;

  Uri _uri(String path) {
    var base = server.trim();
    if (base.isEmpty) throw ApiException('No server set. Add one in settings.');
    if (!base.startsWith('http')) base = 'http://$base';
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return Uri.parse('$base$path');
  }

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (token.isNotEmpty) 'authorization': 'Bearer $token',
  };

  Future<void> ping() async {
    final res = await http.get(_uri('/health')).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw ApiException('Server answered ${res.statusCode}.');
  }

  @override
  Stream<String> chat(ChatRequest req) {
    var event = '';
    return _lineStream(
      (client) => client.send(
        http.Request('POST', _uri('/v1/chat'))
          ..headers.addAll(_headers)
          ..body = jsonEncode({
            'mode': req.mode.name,
            'model': req.tier.model,
            'effort': req.effort.puter,
            if (req.system != null) 'system': req.system,
            'messages': [for (final m in req.history) m.toJson()],
          }),
      ),
      (line) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
          return null;
        }
        if (!line.startsWith('data:')) return null;
        final data = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
        if (event == 'error') throw ApiException(data['message'] as String);
        return event == 'delta' ? data['text'] as String : null;
      },
      (status, body) => _errorFrom(body, 'Server answered $status.'),
    );
  }
}
