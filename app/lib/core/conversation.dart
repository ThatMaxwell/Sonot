import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// One running conversation: the messages, the reply being streamed, and
/// send / stop. Shared by the main chat and Bud chats.
class Conversation extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  StreamSubscription<String>? _reply;
  ChatMessage? streaming;

  bool get busy => _reply != null;

  /// Sends [text] and streams the reply. [build] turns the history into a
  /// request; [filter] can rewrite each chunk (Buds strip hidden tags here)
  /// and [onDone] runs when the reply ends, successfully or not.
  void send(
    String text, {
    required ChatProvider provider,
    required ChatRequest Function(List<ChatMessage> history) build,
    String Function(String chunk)? filter,
    void Function(ChatMessage reply)? onDone,
    void Function(ApiException e)? onError,
  }) {
    if (busy || text.trim().isEmpty) return;
    // Failed turns stay on screen but aren't sent back to the model.
    final history = [...messages.where((m) => !m.error), ChatMessage('user', text.trim())];
    final reply = ChatMessage('assistant', '');
    messages
      ..add(history.last)
      ..add(reply);
    streaming = reply;
    notifyListeners();

    _reply = provider.chat(build(history)).listen(
      (chunk) {
        reply.text += filter == null ? chunk : filter(chunk);
        notifyListeners();
      },
      onError: (Object e) {
        reply.error = true;
        if (reply.text.isEmpty) reply.text = e.toString();
        if (e is ApiException) onError?.call(e);
        notifyListeners();
      },
      // The stream always closes after an error, so this runs either way.
      onDone: () {
        _finish();
        onDone?.call(reply);
      },
    );
  }

  void stop() {
    if (!busy) return;
    _reply?.cancel();
    final s = streaming;
    if (s != null && s.text.isEmpty) messages.remove(s);
    _finish();
  }

  void clear() {
    stop();
    messages.clear();
    notifyListeners();
  }

  void _finish() {
    _reply = null;
    streaming = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _reply?.cancel();
    super.dispose();
  }
}
