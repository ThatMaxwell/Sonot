/// ==========================================================================
/// Sonot site config — edit this file to change downloads and intro behaviour,
/// then rebuild (see README).
/// ==========================================================================
class SonotConfig {
  /// Download links. Leave '' while they are placeholders: the buttons then
  /// show a friendly "coming soon" message instead of going anywhere.
  static const downloads = <String, String>{
    'mac': '', // e.g. 'https://github.com/ThatMaxwell/Sonot/releases/latest/download/Sonot.dmg'
    'win': '', // e.g. '.../Sonot-Setup.exe'
    'linux': '', // e.g. '.../Sonot.AppImage'
    'ios': '', // App Store URL
    'android': '', // Google Play URL
  };

  /// Launch film: 'first-visit' plays it once per browser, 'always' on every
  /// visit, 'never' only from the "Watch the film" button.
  /// URL flags: ?film forces it, ?nofilm skips it, ?reset forgets everything.
  static const film = 'first-visit';

  static const github = 'https://github.com/ThatMaxwell';
}

const osNames = {'mac': 'macOS', 'win': 'Windows', 'linux': 'Linux', 'ios': 'iPhone', 'android': 'Android'};
