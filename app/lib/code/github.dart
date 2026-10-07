import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/settings.dart';

/// The Sonot GitHub App's client id. Device flow needs no secret, so this is
/// safe to ship:  --dart-define=SONOT_GITHUB_CLIENT_ID=Iv23li...
const githubClientId = String.fromEnvironment('SONOT_GITHUB_CLIENT_ID');

/// GitHub's hosted MCP server: repos, issues, pull requests, Actions, code
/// search and more, as tools.
const githubMcpUrl = 'https://api.githubcopilot.com/mcp/';

/// What GitHub shows while you approve the sign-in.
class DeviceCode {
  DeviceCode(this.userCode, this.verifyUrl, this.deviceCode, this.interval, this.expires);
  final String userCode;
  final String verifyUrl;
  final String deviceCode;
  final int interval;
  final DateTime expires;
}

/// Sign in with GitHub (device flow) and talk to GitHub's MCP server.
class GitHub {
  GitHub(this.settings);
  final Settings settings;

  bool get signedIn => settings.githubToken.isNotEmpty;
  static bool get canSignIn => githubClientId.isNotEmpty;

  Future<DeviceCode> startSignIn() async {
    final res = await http.post(
      Uri.parse('https://github.com/login/device/code'),
      headers: {'accept': 'application/json'},
      body: {'client_id': githubClientId},
    );
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['device_code'] == null) throw Exception(j['error_description'] ?? 'GitHub said no (${res.statusCode}).');
    return DeviceCode(
      j['user_code'] as String,
      j['verification_uri'] as String,
      j['device_code'] as String,
      (j['interval'] as num?)?.toInt() ?? 5,
      DateTime.now().add(Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 900)),
    );
  }

  /// Waits until you approve the code on github.com. Returns your login.
  Future<String> finishSignIn(DeviceCode code, {bool Function()? cancelled}) async {
    var wait = code.interval;
    while (DateTime.now().isBefore(code.expires)) {
      await Future<void>.delayed(Duration(seconds: wait));
      if (cancelled?.call() ?? false) throw Exception('Cancelled.');
      final j = await _token({'device_code': code.deviceCode, 'grant_type': 'urn:ietf:params:oauth:grant-type:device_code'});
      switch (j['error']) {
        case null:
          _save(j);
          return await whoami();
        case 'authorization_pending':
          continue;
        case 'slow_down':
          wait += 5;
          continue;
        default:
          throw Exception(j['error_description'] ?? j['error']);
      }
    }
    throw Exception('The code expired. Try again.');
  }

  /// Use a personal access token instead of the app.
  Future<String> useToken(String token) async {
    settings
      ..githubToken = token.trim()
      ..githubRefresh = ''
      ..githubExpires = 0;
    return whoami();
  }

  Future<Map<String, dynamic>> _token(Map<String, String> body) async {
    final res = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {'accept': 'application/json'},
      body: {'client_id': githubClientId, ...body},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _save(Map<String, dynamic> j) {
    settings.githubToken = j['access_token'] as String;
    settings.githubRefresh = (j['refresh_token'] as String?) ?? '';
    final secs = (j['expires_in'] as num?)?.toInt();
    settings.githubExpires = secs == null ? 0 : DateTime.now().add(Duration(seconds: secs - 120)).millisecondsSinceEpoch;
  }

  /// A token that's good right now (refreshed when the app's tokens expire).
  Future<String> token() async {
    final exp = settings.githubExpires;
    if (exp != 0 && DateTime.now().millisecondsSinceEpoch > exp && settings.githubRefresh.isNotEmpty) {
      final j = await _token({'grant_type': 'refresh_token', 'refresh_token': settings.githubRefresh});
      if (j['access_token'] != null) _save(j);
    }
    return settings.githubToken;
  }

  Future<String> whoami() async {
    final res = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {'authorization': 'Bearer ${await token()}', 'accept': 'application/vnd.github+json'},
    );
    if (res.statusCode != 200) {
      signOut();
      throw Exception('GitHub did not accept that sign-in (${res.statusCode}).');
    }
    final login = (jsonDecode(res.body) as Map)['login'] as String;
    settings.githubUser = login;
    return login;
  }

  void signOut() {
    settings
      ..githubToken = ''
      ..githubRefresh = ''
      ..githubExpires = 0
      ..githubUser = '';
    _mcp = null;
  }

  McpClient? _mcp;

  /// GitHub's MCP server, connected with your sign-in.
  Future<McpClient> mcp() async {
    final t = await token();
    if (_mcp != null && _mcp!.bearer == t) return _mcp!;
    final c = McpClient(Uri.parse(githubMcpUrl), bearer: t);
    await c.connect();
    return _mcp = c;
  }
}

/// A tool an MCP server offers.
class McpTool {
  McpTool(this.name, this.description, this.schema, {required this.readOnly});
  final String name;
  final String description;
  final Map<String, dynamic> schema;
  final bool readOnly;
}

/// A small MCP client for the Streamable HTTP transport (JSON-RPC over POST,
/// answers as JSON or as a server-sent event stream).
class McpClient {
  McpClient(this.url, {required this.bearer});
  final Uri url;
  final String bearer;
  String? _session;
  int _id = 1;
  List<McpTool> tools = const [];

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'accept': 'application/json, text/event-stream',
    'authorization': 'Bearer $bearer',
    'mcp-session-id': ?_session,
  };

  Future<void> connect() async {
    await _rpc('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'Sonot Code', 'version': '0.1'},
    });
    await http.post(url, headers: _headers, body: jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
    final all = <McpTool>[];
    String? cursor;
    do {
      final r = await _rpc('tools/list', {'cursor': ?cursor});
      for (final t in (r['tools'] as List? ?? const [])) {
        final m = (t as Map).cast<String, dynamic>();
        final ann = (m['annotations'] as Map?) ?? const {};
        all.add(
          McpTool(
            m['name'] as String,
            (m['description'] as String?) ?? '',
            ((m['inputSchema'] as Map?) ?? {'type': 'object', 'properties': <String, dynamic>{}}).cast<String, dynamic>(),
            readOnly: ann['readOnlyHint'] == true,
          ),
        );
      }
      cursor = r['nextCursor'] as String?;
    } while (cursor != null);
    tools = all;
  }

  /// Calls a tool and returns its text.
  Future<(String text, bool isError)> call(String name, Map<String, dynamic> args) async {
    final r = await _rpc('tools/call', {'name': name, 'arguments': args});
    final parts = <String>[];
    for (final c in (r['content'] as List? ?? const [])) {
      final m = c as Map;
      if (m['type'] == 'text') {
        parts.add(m['text'] as String);
      } else if (m['type'] == 'resource') {
        parts.add(((m['resource'] as Map?)?['text'] as String?) ?? '');
      }
    }
    return (parts.join('\n'), r['isError'] == true);
  }

  Future<Map<String, dynamic>> _rpc(String method, Map<String, dynamic> params) async {
    final id = _id++;
    final res = await http
        .post(url, headers: _headers, body: jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}))
        .timeout(const Duration(minutes: 2));
    final sid = res.headers['mcp-session-id'];
    if (sid != null) _session = sid;
    if (res.statusCode == 401) throw Exception('GitHub sign-in expired. Sign in again in Code settings.');
    if (res.statusCode >= 400) throw Exception('GitHub MCP answered ${res.statusCode}: ${res.body}');
    final type = res.headers['content-type'] ?? '';
    Map<String, dynamic>? msg;
    if (type.contains('text/event-stream')) {
      for (final line in const LineSplitter().convert(utf8.decode(res.bodyBytes))) {
        if (!line.startsWith('data:')) continue;
        final j = jsonDecode(line.substring(5).trim());
        if (j is Map && j['id'] == id) msg = j.cast<String, dynamic>();
      }
    } else {
      msg = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
    }
    if (msg == null) throw Exception('GitHub MCP sent no answer to $method.');
    final err = msg['error'];
    if (err is Map) throw Exception('GitHub MCP: ${err['message']}');
    return ((msg['result'] as Map?) ?? const {}).cast<String, dynamic>();
  }
}
