import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Signs in to Puter the same way puter.js does from Node: open puter.com in
/// the browser with `action=authme`, and catch the token when Puter redirects
/// back to a one-shot server on this device's loopback address.
class PuterAuth {
  HttpServer? _server;

  Future<String> signIn({Duration timeout = const Duration(minutes: 5)}) async {
    await cancel();
    final server = _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = Uri.encodeComponent('http://localhost:${server.port}');
    final url = Uri.parse('https://puter.com/?action=authme&redirectURL=$redirect');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await cancel();
      throw Exception("Couldn't open the browser.");
    }
    try {
      await for (final req in server.timeout(timeout)) {
        final token = req.uri.queryParameters['token'];
        req.response.headers.contentType = ContentType.html;
        if (token == null || token.isEmpty) {
          // Browsers also ask for /favicon.ico and the like.
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          continue;
        }
        req.response.write(_donePage);
        await req.response.close();
        return token;
      }
      throw TimeoutException('Sign-in was not finished.');
    } on TimeoutException {
      throw Exception('Sign-in timed out. Try again.');
    } finally {
      await cancel();
    }
  }

  Future<void> cancel() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }
}

const _donePage = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Signed in to Sonot</title>
<style>
  html,body{height:100%;margin:0}
  body{display:flex;align-items:center;justify-content:center;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;
       background:linear-gradient(#0A1028,#1C2546);color:#fff;text-align:center}
  h1{font-weight:700;letter-spacing:-.02em;font-size:40px;margin:0 0 10px}
  h1 em{font-family:Georgia,serif;font-weight:400;color:rgba(255,255,255,.5)}
  p{color:rgba(255,255,255,.6);font-size:16px;margin:0}
</style></head>
<body><div><h1>sonot <em>is ready</em></h1><p>You're signed in. Head back to the Sonot app.</p></div></body></html>''';
