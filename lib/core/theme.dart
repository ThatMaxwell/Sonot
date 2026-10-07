import 'package:flutter/widgets.dart';

/// Sonot palette: white first, electric blue, black for contrast moments.
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
  static const green = Color(0xFF16C172);
}

class F {
  static const sans = 'InterTight';
  static const serif = 'InstrumentSerif';
  /// Round toy-like face. The word "buds" is always set in it, lowercase.
  static const toy = 'Fredoka';
  static const mono = 'JetBrainsMono';
}

TextStyle sans(double size, {FontWeight w = FontWeight.w500, Color c = C.ink, double ls = 0, double h = 1.25}) =>
    TextStyle(fontFamily: F.sans, fontSize: size, fontWeight: w, color: c, letterSpacing: size * ls, height: h);

TextStyle serif(double size, {Color c = C.ink, double h = 1.1}) =>
    TextStyle(fontFamily: F.serif, fontStyle: FontStyle.italic, fontSize: size, color: c, height: h, fontWeight: FontWeight.w400);

TextStyle mono(double size, {Color c = C.mute, FontWeight w = FontWeight.w500, double ls = .14}) =>
    TextStyle(fontFamily: F.mono, fontSize: size, color: c, fontWeight: w, letterSpacing: size * ls);

/// Headline helper: "Plain words *serif words*" — text inside asterisks
/// renders in the italic serif accent.
List<InlineSpan> accent(String text, TextStyle base, {Color? accentColor}) {
  final spans = <InlineSpan>[];
  final parts = text.split('*');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(
      TextSpan(
        text: parts[i],
        style: i.isOdd
            ? base.copyWith(fontFamily: F.serif, fontStyle: FontStyle.italic, fontWeight: FontWeight.w400, letterSpacing: 0, color: accentColor ?? C.blue)
            : base,
      ),
    );
  }
  return spans;
}

/// Responsive helpers
extension Vp on BuildContext {
  Size get vp => MediaQuery.sizeOf(this);
  double get vw => vp.width / 100;
  double get vh => vp.height / 100;
  bool get isMobile => vp.width < 760;
  bool get isNarrow => vp.width < 1000;
}

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double seg(double p, double a, double b) => clamp01((p - a) / (b - a));
double lerpD(double a, double b, double t) => a + (b - a) * t;
