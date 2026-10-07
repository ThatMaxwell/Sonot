import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/theme.dart';
import 'bloom.dart';
import 'markdown.dart';

/// One turn. Yours sits right in a tinted glass bubble; Sonot's reads as
/// plain text on the page, with code fences in hairline glass boxes.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message, required this.palette, required this.mode, required this.waiting});
  final ChatMessage message;
  final Palette palette;
  final Mode mode;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    if (message.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 14, left: 56),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: p.userGlass,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(8),
                ),
                side: BorderSide(color: p.edge.withValues(alpha: p.edge.a * .7), width: .7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: SelectableText(
                message.text,
                style: sans(16, c: mode == Mode.code ? p.text : C.white, w: FontWeight.w400),
              ),
            ),
          ),
        ),
      );
    }

    if (waiting) {
      return Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 4),
        child: Align(alignment: Alignment.centerLeft, child: SpinningMark(size: 22, color: p.accent)),
      );
    }

    final color = message.error ? const Color(0xFFE5484D) : p.text;
    return Padding(
      padding: const EdgeInsets.only(top: 18, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final part in _split(message.text))
            part.code
                ? _CodeBlock(code: part.text, lang: part.lang, palette: p)
                : message.error
                ? SelectableText(part.text, style: sans(16, c: color, w: FontWeight.w400, h: 1.55))
                : SelectableText.rich(markdownSpan(part.text, base: sans(16, c: color, w: FontWeight.w400, h: 1.55), palette: p)),
        ],
      ),
    );
  }
}

class _Part {
  _Part(this.text, {this.code = false, this.lang = ''});
  final String text;
  final bool code;
  final String lang;
}

/// Splits a reply on ``` fences. An unclosed fence (still streaming) counts
/// as code so it renders as a block right away.
List<_Part> _split(String s) {
  final parts = <_Part>[];
  final fence = RegExp(r'^```(\S*)\s*$', multiLine: true);
  var pos = 0;
  var inCode = false;
  var lang = '';
  for (final m in fence.allMatches(s)) {
    final chunk = s.substring(pos, m.start);
    if (inCode) {
      parts.add(_Part(chunk.replaceFirst(RegExp(r'\n$'), ''), code: true, lang: lang));
    } else if (chunk.trim().isNotEmpty) {
      parts.add(_Part(chunk.trim()));
    }
    inCode = !inCode;
    lang = m.group(1) ?? '';
    pos = m.end + (m.end < s.length && s[m.end] == '\n' ? 1 : 0);
  }
  final rest = s.substring(pos.clamp(0, s.length));
  if (inCode) {
    parts.add(_Part(rest, code: true, lang: lang));
  } else if (rest.trim().isNotEmpty) {
    parts.add(_Part(rest.trim()));
  }
  return parts;
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.lang, required this.palette});
  final String code;
  final String lang;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.text.withValues(alpha: .045),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.edge, width: .7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
              child: Row(
                children: [
                  Text(lang.isEmpty ? 'code' : lang, style: mono(12, c: p.textSoft)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.copy_rounded, color: p.textSoft),
                    onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SelectableText(code, style: mono(13.5, c: p.text)),
            ),
          ],
        ),
      ),
    );
  }
}
