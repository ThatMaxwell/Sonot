import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Just enough Markdown for chat replies: headings, bullet and numbered
/// lists, quotes, **bold**, *italic* and `inline code`. Code fences are
/// handled by the message view. Returns one span so the whole block stays
/// selectable.
TextSpan markdownSpan(String text, {required TextStyle base, required Palette palette}) {
  final lines = text.split('\n');
  final out = <InlineSpan>[];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var style = base;
    String? bullet;

    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    final bulletM = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
    final numM = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$').firstMatch(line);
    final quote = RegExp(r'^>\s?(.*)$').firstMatch(line);

    if (heading != null) {
      final level = heading.group(1)!.length;
      style = base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (base.fontSize ?? 16) * (level == 1 ? 1.35 : level == 2 ? 1.2 : 1.06),
        letterSpacing: -.2,
      );
      line = heading.group(2)!;
    } else if (bulletM != null) {
      final depth = bulletM.group(1)!.length ~/ 2;
      bullet = '${'    ' * depth}•  ';
      line = bulletM.group(2)!;
    } else if (numM != null) {
      final depth = numM.group(1)!.length ~/ 2;
      bullet = '${'    ' * depth}${numM.group(2)}.  ';
      line = numM.group(3)!;
    } else if (RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line)) {
      out.add(TextSpan(text: '────────', style: base.copyWith(color: palette.textSoft.withValues(alpha: .5))));
      if (i < lines.length - 1) out.add(const TextSpan(text: '\n'));
      continue;
    } else if (quote != null) {
      style = base.copyWith(color: palette.textSoft, fontStyle: FontStyle.italic);
      bullet = '▏ ';
      line = quote.group(1)!;
    }

    if (bullet != null) out.add(TextSpan(text: bullet, style: base.copyWith(color: palette.accent, fontWeight: FontWeight.w600)));
    out.addAll(_inline(line, style, palette));
    if (i < lines.length - 1) out.add(TextSpan(text: '\n', style: base));
  }
  return TextSpan(style: base, children: out);
}

final _inlinePattern = RegExp(r'(`[^`\n]+`)|(\*\*[^*\n]+\*\*)|(__[^_\n]+__)|(\*[^*\s][^*\n]*\*)|(_[^_\s][^_\n]*_)');

List<InlineSpan> _inline(String s, TextStyle style, Palette p) {
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in _inlinePattern.allMatches(s)) {
    if (m.start > pos) spans.add(TextSpan(text: s.substring(pos, m.start), style: style));
    final t = m.group(0)!;
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: ' ${t.substring(1, t.length - 1)} ',
          style: mono((style.fontSize ?? 16) * .88, c: p.text).copyWith(backgroundColor: p.text.withValues(alpha: .07)),
        ),
      );
    } else if (m.group(2) != null || m.group(3) != null) {
      spans.add(TextSpan(text: t.substring(2, t.length - 2), style: style.copyWith(fontWeight: FontWeight.w700)));
    } else {
      spans.add(TextSpan(text: t.substring(1, t.length - 1), style: style.copyWith(fontStyle: FontStyle.italic)));
    }
    pos = m.end;
  }
  if (pos < s.length) spans.add(TextSpan(text: s.substring(pos), style: style));
  return spans;
}
