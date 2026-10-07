import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'theme.dart';

/// Build-time defaults for the optional self-hosted server:
///   flutter build apk --dart-define=SONOT_SERVER=https://sonot.example.com
const defaultServer = String.fromEnvironment('SONOT_SERVER');
const defaultToken = String.fromEnvironment('SONOT_APP_TOKEN');

/// What the app remembers between launches.
class Settings {
  Settings._(this._prefs);
  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

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

  bool get signedIn => provider == 'puter' ? puterToken.isNotEmpty : server.isNotEmpty;

  ChatProvider get chatProvider =>
      provider == 'puter' ? PuterProvider(puterToken) : ServerProvider(server: server, token: token);

  Future<void> signOut() async {
    await _prefs.remove('puterToken');
    await _prefs.remove('puterUser');
    await _prefs.remove('provider');
  }
}
