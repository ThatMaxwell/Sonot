import 'package:flutter/material.dart';

/// Sonot palette, shared with the launch site: white first, electric blue,
/// black for contrast moments.
class C {
  static const blue = Color(0xFF0B5CFF);
  static const blueDeep = Color(0xFF0029C9);
  static const blueSoft = Color(0xFF6EA2FF);
  static const sky = Color(0xFFDCE7FF);
  static const mist = Color(0xFFF3F6FF);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF07080D);
  static const ink2 = Color(0xFF2A2F3D);
  static const mute = Color(0xFF6B7390);
  static const line = Color(0xFFE5E9F4);

  // Setup screen: deep night navy.
  static const night = Color(0xFF0A1028);
  static const night2 = Color(0xFF1C2546);
}

class F {
  static const sans = 'InterTight';
  static const serif = 'InstrumentSerif';
  static const mono = 'JetBrainsMono';
}

/// The moods of the app. Chat and Buds are the site's white and blue; Code
/// is darker and more serious.
enum Mode { chat, code, buds }

/// Colours for one mode. Every screen reads from this instead of [C] so the
/// whole app can cross-fade between moods.
class Palette {
  const Palette({
    required this.bg,
    required this.blobs,
    required this.text,
    required this.textSoft,
    required this.accent,
    required this.onAccent,
    required this.glass,
    required this.edge,
    required this.userGlass,
    required this.watermark,
  });

  /// Backdrop base colour and the soft blobs behind the glass.
  final Color bg;
  final List<Color> blobs;
  final Color text, textSoft, accent, onAccent;

  /// Glass fill and its hairline edge.
  final Color glass, edge;

  /// Fill for the user's own bubbles.
  final Color userGlass;

  /// The big Sonot mark behind an empty chat.
  final Color watermark;

  static const chat = Palette(
    bg: Color(0xFFEDF2FF),
    blobs: [Color(0x660B5CFF), Color(0x806EA2FF), Color(0x99DCE7FF), Color(0x558FB4FF)],
    text: C.ink,
    textSoft: C.mute,
    accent: C.blue,
    onAccent: C.white,
    glass: Color(0x8CFFFFFF),
    edge: Color(0xE6FFFFFF),
    userGlass: Color(0xD90B5CFF),
    watermark: Color(0x330B5CFF),
  );

  static const code = Palette(
    bg: Color(0xFF05060B),
    blobs: [Color(0x590029C9), Color(0x333A2FBF), Color(0x400B5CFF), Color(0x1F6EA2FF)],
    text: Color(0xFFE8ECF7),
    textSoft: Color(0xFF7E87A6),
    accent: C.blueSoft,
    onAccent: C.ink,
    glass: Color(0x0FFFFFFF),
    edge: Color(0x24FFFFFF),
    userGlass: Color(0x1FFFFFFF),
    watermark: Color(0x1A6EA2FF),
  );

  static Palette of(Mode m) => m == Mode.code ? code : chat;

  static Palette lerp(Palette a, Palette b, double t) => Palette(
    bg: Color.lerp(a.bg, b.bg, t)!,
    blobs: [for (var i = 0; i < a.blobs.length; i++) Color.lerp(a.blobs[i], b.blobs[i], t)!],
    text: Color.lerp(a.text, b.text, t)!,
    textSoft: Color.lerp(a.textSoft, b.textSoft, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
    glass: Color.lerp(a.glass, b.glass, t)!,
    edge: Color.lerp(a.edge, b.edge, t)!,
    userGlass: Color.lerp(a.userGlass, b.userGlass, t)!,
    watermark: Color.lerp(a.watermark, b.watermark, t)!,
  );
}

TextStyle sans(double size, {FontWeight w = FontWeight.w500, Color c = C.ink, double ls = 0, double h = 1.35}) =>
    TextStyle(fontFamily: F.sans, fontSize: size, fontWeight: w, color: c, letterSpacing: size * ls, height: h);

TextStyle serif(double size, {Color c = C.ink, double h = 1.1}) =>
    TextStyle(fontFamily: F.serif, fontStyle: FontStyle.italic, fontSize: size, color: c, height: h, fontWeight: FontWeight.w400);

/// Mono with ligatures off, so code shows exactly what was typed (`<=`, not `≤`).
TextStyle mono(double size, {Color c = C.mute, FontWeight w = FontWeight.w400, double h = 1.5}) => TextStyle(
  fontFamily: F.mono,
  fontSize: size,
  color: c,
  fontWeight: w,
  height: h,
  fontFeatures: const [FontFeature.disable('calt'), FontFeature.disable('liga')],
);
