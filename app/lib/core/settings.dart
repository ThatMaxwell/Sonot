import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// Build-time defaults for the optional self-hosted server:
///   flutter build apk --dart-define=SONOT_SERVER=https://sonot.example.com
const defaultServer = String.fromEnvironment('SONOT_SERVER');
const defaultToken = String.fromEnvironment('SONOT_APP_TOKEN');

/// What the app remembers between launches. Secrets (your cua.ai key) live
/// in the system keychain through flutter_secure_storage; the rest in
/// shared preferences. Listeners hear about appearance changes.
class Settings extends ChangeNotifier {
  Settings._(this._prefs, this._secrets);
  final SharedPreferences _prefs;
  final Map<String, String> _secrets;

  static const _secure = FlutterSecureStorage();
  static const _secretKeys = ['cua.key'];

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final secrets = <String, String>{};
    for (final k in _secretKeys) {
      try {
        final v = await _secure.read(key: k);
        if (v != null) secrets[k] = v;
      } catch (e) {
        debugPrint('Secure storage unavailable: $e');
      }
    }
    return Settings._(prefs, secrets);
  }

  void _setSecret(String key, String value) {
    final v = value.trim();
    if (v.isEmpty) {
      _secrets.remove(key);
      _secure.delete(key: key).catchError((Object e) => debugPrint('$e'));
    } else {
      _secrets[key] = v;
      _secure.write(key: key, value: v).catchError((Object e) => debugPrint('$e'));
    }
  }

  /// Your own cua.ai API key for cloud computers (Buds, and Code's cloud
  /// browser). Sent to your Sonot server as `X-Cua-Api-Key`.
  String get cuaApiKey => _secrets['cua.key'] ?? '';
  set cuaApiKey(String v) => _setSecret('cua.key', v);

  /// Notifications: on at all, and whether urgent ones may break through.
  bool get notifications => _prefs.getBool('notify.on') ?? true;
  set notifications(bool v) => _prefs.setBool('notify.on', v);
  bool get urgentAlerts => _prefs.getBool('notify.urgent') ?? true;
  set urgentAlerts(bool v) => _prefs.setBool('notify.urgent', v);

  /// Appearance: text size, glass blur, and the playful animations.
  double get textScale => _prefs.getDouble('ui.textScale') ?? 1.0;
  set textScale(double v) {
    _prefs.setDouble('ui.textScale', v);
    notifyListeners();
  }

  bool get blur => _prefs.getBool('ui.blur') ?? true;
  set blur(bool v) {
    _prefs.setBool('ui.blur', v);
    notifyListeners();
  }

  bool get motion => _prefs.getBool('ui.motion') ?? true;
  set motion(bool v) {
    _prefs.setBool('ui.motion', v);
    notifyListeners();
  }

  /// 'puter' (default: each user signs in with Puter) or 'server'.
  String get provider => _prefs.getString('provider') ?? 'puter';
  set provider(String v) => _prefs.setString('provider', v);

  String get puterToken => _prefs.getString('puterToken') ?? '';
  set puterToken(String v) => _prefs.setString('puterToken', v);

  String get puterUser => _prefs.getString('puterUser') ?? '';
  set puterUser(String v) => _prefs.setString('puterUser', v);

  String get server => _prefs.getString('server') ?? defaultServer;
  set server(String v) => _prefs.setString('server', v.trim());

  String get token => _prefs.getString('token') ?? defaultToken;
  set token(String v) => _prefs.setString('token', v.trim());

  /// The model and effort picked for a mode. Chat starts on Tone; Code and
  /// Buds start on Anthem (Buds at Balanced, so chatting stays snappy).
  (Tier, Effort) modelFor(Mode m) {
    final tier = tierById(_prefs.getString('${m.name}.tier') ?? (m == Mode.chat ? 'tone' : 'anthem'));
    final fallback = m == Mode.buds ? Effort.balanced : tier.defaultEffort;
    return (tier, tier.clamp(Effort.byName(_prefs.getString('${m.name}.effort')) ?? fallback));
  }

  void setModelFor(Mode m, Tier t, Effort e) {
    _prefs.setString('${m.name}.tier', t.id);
    _prefs.setString('${m.name}.effort', e.name);
  }

  /// Sonot Code: the folder the agent works in. Empty means the app's own
  /// documents folder.
  String get workspace => _prefs.getString('code.workspace') ?? '';
  set workspace(String v) => _prefs.setString('code.workspace', v.trim());

  /// Sonot Code: things you said "Always allow" to (see code/permissions.dart).
  List<String> get alwaysAllow => _prefs.getStringList('code.allow') ?? const [];
  set alwaysAllow(List<String> v) => _prefs.setStringList('code.allow', v);

  /// Sonot Code: 'local' runs the browser on this computer, 'cloud' on a
  /// cua.ai cloud computer through the Sonot server. Phones are always cloud.
  String get browserWhere => _prefs.getString('code.browser') ?? 'local';
  set browserWhere(String v) => _prefs.setString('code.browser', v);

  /// Sonot Code: GitHub sign-in (a GitHub App user token) and who it is.
  String get githubToken => _prefs.getString('github.token') ?? '';
  set githubToken(String v) => _prefs.setString('github.token', v);
  String get githubRefresh => _prefs.getString('github.refresh') ?? '';
  set githubRefresh(String v) => _prefs.setString('github.refresh', v);
  int get githubExpires => _prefs.getInt('github.expires') ?? 0;
  set githubExpires(int v) => _prefs.setInt('github.expires', v);
  String get githubUser => _prefs.getString('github.user') ?? '';
  set githubUser(String v) => _prefs.setString('github.user', v);

  /// A random id for this install, so its cloud computers are its own.
  String get installId {
    var id = _prefs.getString('installId');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(10, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[r.nextInt(32)]).join();
      _prefs.setString('installId', id);
    }
    return id;
  }

  bool get signedIn => provider == 'puter' ? puterToken.isNotEmpty : server.isNotEmpty;

  ChatProvider get chatProvider =>
      provider == 'puter' ? PuterProvider(puterToken) : ServerProvider(server: server, token: token);

  Future<void> signOut() async {
    await _prefs.remove('puterToken');
    await _prefs.remove('puterUser');
    await _prefs.remove('provider');
  }
}
