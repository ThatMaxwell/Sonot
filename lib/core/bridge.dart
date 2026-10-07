import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/* ---------------- Audio (web/js/audio.js) ---------------- */
@JS('sonotAudio')
external _Audio? get _audio;

extension type _Audio._(JSObject _) implements JSObject {
  external bool unlock();
  external JSString state();
  external bool start(double from);
  external double time();
  external bool started();
  external void stop();
  external void pause();
  external void resume();
  external void setMuted(bool m);
  external bool muted();
  @JS('LENGTH')
  external double get length;
  @JS('BEAT')
  external double get beat;
}

class Audio {
  static bool get available => _audio != null;
  static bool unlock() => _audio?.unlock() ?? false;
  static String get state => _audio?.state().toDart ?? 'none';
  static bool get running => state == 'running';
  static bool start(double from) => _audio?.start(from) ?? false;

  /// Film time from the audio clock, or -1 when the song isn't playing.
  static double time() => _audio?.time() ?? -1;
  static bool get started => _audio?.started() ?? false;
  static void stop() => _audio?.stop();
  static void pause() => _audio?.pause();
  static void resume() => _audio?.resume();
  static void setMuted(bool m) => _audio?.setMuted(m);
  static bool get muted => _audio?.muted() ?? false;
  static double get length => _audio?.length ?? 50.32;
  static double get beat => _audio?.beat ?? 60 / 124;
}

/* ---------------- three.js (web/js/sonot3d.js) ---------------- */
@JS('sonot3d')
external _Three? get _three;

extension type _Three._(JSObject _) implements JSObject {
  external int mount(web.HTMLElement el, String kind);
  external void setProgress(int id, double p);
  external void dispose(int id);
}

final Set<String> _registered = {};

/// A three.js scene living inside Flutter. [progress] drives scroll-linked motion.
class ThreeView extends StatefulWidget {
  const ThreeView({super.key, required this.kind, this.progress});
  final String kind;
  final ValueListenable<double>? progress;
  @override
  State<ThreeView> createState() => _ThreeViewState();
}

class _ThreeViewState extends State<ThreeView> {
  static int _seq = 0;
  late final String viewType = 'sonot-3d-${widget.kind}-${_seq++}';
  int? id;

  @override
  void initState() {
    super.initState();
    if (!_registered.contains(viewType)) {
      _registered.add(viewType);
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.style
          ..width = '100%'
          ..height = '100%'
          ..pointerEvents = 'none';
        id = _three?.mount(div, widget.kind);
        return div;
      });
    }
    widget.progress?.addListener(_push);
  }

  void _push() {
    final i = id;
    if (i != null) _three?.setProgress(i, widget.progress!.value);
  }

  @override
  void dispose() {
    widget.progress?.removeListener(_push);
    final i = id;
    if (i != null) _three?.dispose(i);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: HtmlElementView(viewType: viewType));
}

/* ---------------- misc browser helpers ---------------- */
class Browser {
  static String? read(String k) {
    try {
      return web.window.localStorage.getItem(k);
    } catch (_) {
      return null;
    }
  }

  static void write(String k, String v) {
    try {
      web.window.localStorage.setItem(k, v);
    } catch (_) {}
  }

  static void clearSonot() {
    try {
      final ls = web.window.localStorage;
      final keys = <String>[];
      for (var i = 0; i < ls.length; i++) {
        final k = ls.key(i);
        if (k != null && k.startsWith('sonot.')) keys.add(k);
      }
      for (final k in keys) {
        ls.removeItem(k);
      }
    } catch (_) {}
  }

  static String get language => web.window.navigator.language;
  static bool get hidden => web.document.hidden;
  static void onVisibility(void Function(bool hidden) f) {
    web.document.addEventListener('visibilitychange', ((web.Event _) => f(web.document.hidden)).toJS);
  }

  static void open(String url) => web.window.open(url, '_blank');

  static String detectOS() {
    final ua = web.window.navigator.userAgent;
    final plat = web.window.navigator.platform;
    final touch = web.window.navigator.maxTouchPoints > 1;
    // Sonot ships for Windows, Linux and Android. Phones and tablets get
    // Android; every other computer gets Windows unless it runs Linux.
    if (RegExp('android|iPhone|iPad|iPod', caseSensitive: false).hasMatch(ua) || (plat.contains('Mac') && touch)) return 'android';
    if (plat.contains('Win') || ua.contains('Windows')) return 'win';
    if (RegExp('Linux|X11|CrOS').hasMatch(plat + ua)) return 'linux';
    return 'win';
  }

  static bool get reducedMotion => web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
