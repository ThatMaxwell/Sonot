import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonot_app/core/api.dart';
import 'package:sonot_app/core/models.dart';
import 'package:sonot_app/core/theme.dart';

/// A stand-in for api.puter.com/drivers/call that parses bodies the way
/// Puter's Express setup does: JSON content types, or the exact header
/// `text/plain;actually=json`. Anything else leaves the body empty.
Future<HttpServer> _fakePuter() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final raw = await utf8.decoder.bind(req).join();
    final ct = req.headers.value('content-type') ?? '';
    final parsed = req.headers.contentType?.mimeType == 'application/json' || ct == 'text/plain;actually=json';
    final body = parsed ? jsonDecode(raw) as Map : const {};
    if (body['interface'] != 'puter-chat-completion') {
      req.response
        ..statusCode = 400
        ..write(jsonEncode({'error': 'Missing or invalid `interface`', 'message': 'Missing or invalid `interface`'}));
      return req.response.close();
    }
    final args = body['args'] as Map;
    req.response.headers.contentType = ContentType('application', 'x-ndjson');
    for (final t in ['Hey', ' there', ' (${args['model']})']) {
      req.response.writeln(jsonEncode({'type': 'text', 'text': t}));
    }
    await req.response.close();
  });
  return server;
}

void main() {
  test('Puter chat request is parsed and streams text back', () async {
    final server = await _fakePuter();
    addTearDown(server.close);
    final provider = PuterProvider('tok', api: 'http://127.0.0.1:${server.port}');
    final tier = tierById('tone');
    final out = await provider
        .chat(ChatRequest(history: [ChatMessage('user', 'hey bro')], mode: Mode.chat, tier: tier, effort: tier.defaultEffort))
        .join();
    expect(out, 'Hey there (${tier.model})');
  });
}
