/* ==========================================================================
   Sonot site config — edit this file to change downloads and intro behaviour.
   ========================================================================== */
window.SONOT_CONFIG = {
  version: 'v1.0 — preview',

  /* Download links. Leave as '' while they are placeholders: the buttons
     will show a friendly "coming soon" toast instead of going anywhere. */
  downloads: {
    mac: '',      // e.g. 'https://github.com/ThatMaxwell/Sonot/releases/latest/download/Sonot.dmg'
    win: '',      // e.g. '.../Sonot-Setup.exe'
    linux: '',    // e.g. '.../Sonot.AppImage'
    ios: '',      // App Store URL
    android: ''   // Google Play URL
  },

  requirements: {
    mac: 'macOS 12 or later',
    win: 'Windows 10 or later',
    linux: 'Ubuntu 20.04+, Fedora 36+',
    ios: 'iOS 16 or later',
    android: 'Android 10 or later'
  },

  /* Launch film: 'first-visit' plays it once per browser, 'always' plays it on
     every visit, 'never' only plays it from the "Watch the film" button.
     Add ?film to the URL to force it. */
  film: 'first-visit'
};
