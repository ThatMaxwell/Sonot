import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonot_app/core/theme.dart';
import 'package:sonot_app/widgets/markdown.dart';

String plain(TextSpan s) => s.toPlainText();

void main() {
  const base = TextStyle(fontSize: 16);

  test('bold, italic and inline code drop their markers', () {
    final span = markdownSpan('a **b** *c* `d`', base: base, palette: Palette.chat);
    expect(plain(span), 'a b c  d ');
  });

  test('bullets and numbers get markers, headings lose hashes', () {
    final span = markdownSpan('# Title\n- one\n2. two', base: base, palette: Palette.chat);
    expect(plain(span), 'Title\n•  one\n2.  two');
  });

  test('bold text is bold', () {
    final span = markdownSpan('**x**', base: base, palette: Palette.chat);
    final bold = span.children!.whereType<TextSpan>().firstWhere((s) => s.text == 'x');
    expect(bold.style!.fontWeight, FontWeight.w700);
  });
}
