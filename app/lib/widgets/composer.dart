import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/theme.dart';
import 'glass.dart';
import 'message.dart';

/// The glass input bar: text, an optional chip, and send / stop.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focus,
    required this.palette,
    required this.hint,
    required this.busy,
    required this.onSend,
    required this.onStop,
    this.monoInput = false,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final Palette palette;
  final String hint;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool monoInput;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, pad.bottom + 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Glass(
            radius: 28,
            fill: p.glass,
            edge: p.edge,
            padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: CallbackShortcuts(
                      // Desktop: Enter sends, Shift+Enter adds a line.
                      bindings: {const SingleActivator(LogicalKeyboardKey.enter): onSend},
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: monoInput ? mono(15, c: p.text) : sans(16, c: p.text, w: FontWeight.w400),
                        cursorColor: p.accent,
                        decoration: InputDecoration.collapsed(
                          hintText: hint,
                          hintStyle: sans(16, c: p.textSoft, w: FontWeight.w400),
                        ),
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                const SizedBox(width: 6),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty && !busy;
                    final lit = canSend || busy;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lit ? p.accent : p.textSoft.withValues(alpha: .18),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy ? onStop : (canSend ? onSend : null),
                          child: Icon(
                            busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                            size: 22,
                            color: lit ? p.onAccent : p.textSoft,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrolling list of messages, padded to clear the bar and composer.
class ThreadView extends StatelessWidget {
  const ThreadView({
    super.key,
    required this.messages,
    required this.streaming,
    required this.palette,
    required this.mode,
    required this.controller,
    this.top = 84,
    this.waiting,
  });

  final List<ChatMessage> messages;
  final ChatMessage? streaming;
  final Palette palette;
  final Mode mode;
  final ScrollController controller;
  final double top;

  /// Shown instead of the spinning mark while a reply hasn't started.
  final Widget? waiting;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView.builder(
          controller: controller,
          padding: EdgeInsets.fromLTRB(18, pad.top + top, 18, pad.bottom + 120),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final m = messages[i];
            return MessageView(
              key: ObjectKey(m),
              message: m,
              palette: palette,
              mode: mode,
              waiting: identical(m, streaming) && m.text.isEmpty && m.steps.isEmpty,
              waitingWidget: waiting,
            );
          },
        ),
      ),
    );
  }
}

/// Keeps a list pinned to the bottom while text streams in.
void scrollToEnd(ScrollController c) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!c.hasClients) return;
    c.animateTo(c.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  });
}
