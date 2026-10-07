/// ==========================================================================
/// Sonot site config — edit this file to change downloads and intro behaviour,
/// then rebuild (see README).
/// ==========================================================================
class SonotConfig {
  /// Download links. Leave '' while they are placeholders: the buttons then
  /// show a friendly "coming soon" message instead of going anywhere.
  static const downloads = <String, String>{
    'win': '', // e.g. 'https://github.com/ThatMaxwell/Sonot/releases/latest/download/Sonot-Setup.exe'
    'linux': '', // e.g. '.../Sonot.AppImage'
    'android': '', // Google Play URL
  };

  /// Launch film: 'first-visit' plays it once per browser, 'always' on every
  /// visit, 'never' only from the "Watch the film" button.
  /// URL flags: ?film forces it, ?nofilm skips it, ?reset forgets everything.
  static const film = 'first-visit';

  static const github = 'https://github.com/ThatMaxwell';
}

const osNames = {'win': 'Windows', 'linux': 'Linux', 'android': 'Android'};
