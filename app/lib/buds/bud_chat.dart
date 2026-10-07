import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/conversation.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/composer.dart';
import '../widgets/glass.dart';
import '../widgets/model_picker.dart';
import 'bud_avatar.dart';
import 'buds.dart';

/// Conversations with each Bud, kept while the app is open.
final _convos = <String, Conversation>{};

/// Chat with one Bud: a live face in the header, hidden emotion tags that
/// move it, and notes it keeps that you can see and edit.
class BudChat extends StatefulWidget {
  const BudChat({super.key, required this.bud, required this.store, required this.settings});
  final Bud bud;
  final BudStore store;
  final Settings settings;

  @override
  State<BudChat> createState() => _BudChatState();
}

class _BudChatState extends State<BudChat> {
  late final Conversation _convo = _convos.putIfAbsent(widget.bud.id, Conversation.new);
  final _face = BudFaceController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _typing = false;

  Bud get bud => widget.bud;

  @override
  void initState() {
    super.initState();
    _convo.addListener(_onConvo);
    _input.addListener(() {
      final typing = _input.text.trim().isNotEmpty;
      if (typing != _typing) setState(() => _typing = typing);
    });
  }

  void _onConvo() {
    if (!mounted) return;
    setState(() {});
    scrollToEnd(_scroll);
  }

  @override
  void dispose() {
    _convo.removeListener(_onConvo);
    _face.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || _convo.busy) return;
    _input.clear();
    _face.emotion = BudEmotion.thinking;
    var tagged = false;
    final emotions = EmotionTagFilter((e) {
      tagged = true;
      _face.emotion = e;
    });
    final notes = MemoryTagFilter(_remember);
    final (tier, effort) = (bud.tier, bud.effort);
    _convo.send(
      text,
      provider: widget.settings.chatProvider,
      build: (history) => ChatRequest(history: history, mode: Mode.buds, tier: tier, effort: effort, system: bud.persona),
      filter: (chunk) {
        if (!tagged && _face.emotion == BudEmotion.thinking) _face.emotion = BudEmotion.neutral;
        return notes.add(emotions.add(chunk));
      },
      onDone: (reply) {
        // Flush anything held back while waiting for a tag to finish.
        final rest = notes.add(emotions.close()) + notes.close();
        reply.text = (reply.text + rest).trimRight();
        if (reply.error) {
          _face.emotion = BudEmotion.sad;
        } else if (!tagged) {
          _face.emotion = BudEmotion.happy;
        }
        if (mounted) setState(() {});
      },
    );
  }

  void _remember(String text) {
    final note = MemoryNote(text);
    bud.memory.add(note);
    widget.store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          content: Text('${bud.name} will remember this'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              bud.memory.remove(note);
              widget.store.save();
              setState(() {});
            },
          ),
        ),
      );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const p = Palette.chat;
    final pad = MediaQuery.paddingOf(context);
    final empty = _convo.messages.isEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: p.bg,
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned.fill(
                child: Backdrop(
                  base: p.bg,
                  // The Bud's own colour tints the room.
                  blobs: [bud.color.withValues(alpha: .35), p.blobs[1], bud.color.withValues(alpha: .18), p.blobs[3]],
                ),
              ),
              // An empty chat shows the Bud big in the middle, saying hi.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: empty && !_typing ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BudAvatar(shape: bud.shape, color: bud.color, size: 160, controller: _face),
                          const SizedBox(height: 20),
                          Text("Hi, I'm ${bud.name}.", style: sans(26, c: p.text, w: FontWeight.w700, ls: -.02)),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(bud.job, textAlign: TextAlign.center, style: sans(15, c: p.textSoft, w: FontWeight.w400)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ThreadView(
                  messages: _convo.messages,
                  streaming: _convo.streaming,
                  palette: p,
                  mode: Mode.buds,
                  controller: _scroll,
                  top: 92,
                  // Waiting is the Bud's face thinking up in the header.
                  waiting: const SizedBox(height: 22),
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: _header(p, pad, empty)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Composer(
                  controller: _input,
                  focus: _focus,
                  palette: p,
                  hint: 'Message ${bud.name}',
                  busy: _convo.busy,
                  onSend: _send,
                  onStop: _convo.stop,
                  trailing: ModelChip(tier: bud.tier, effort: bud.effort, palette: p, onTap: () => _pickModel(p)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Palette p, EdgeInsets pad, bool empty) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, pad.top + 10, 14, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Glass(
            radius: 30,
            fill: p.glass,
            edge: p.edge,
            padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back_rounded, color: p.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: empty && !_typing
                      ? const SizedBox(width: 0, height: 44)
                      : BudAvatar(shape: bud.shape, color: bud.color, size: 44, controller: _face),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bud.name, style: sans(16.5, c: p.text, w: FontWeight.w700)),
                      Text(
                        _convo.busy ? 'thinking…' : bud.tier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(12.5, c: p.textSoft, w: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                _Chip(
                  label: bud.memory.isEmpty ? 'Memory' : 'Remembers ${bud.memory.length}',
                  palette: p,
                  onTap: () => _openMemory(p),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: Icon(Icons.more_horiz_rounded, color: p.text),
                  color: C.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (v) {
                    if (v == 'clear') _convo.clear();
                    if (v == 'delete') _delete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'clear', child: Text('New conversation', style: sans(15))),
                    PopupMenuItem(value: 'delete', child: Text('Delete ${bud.name}', style: sans(15, c: const Color(0xFFE5484D)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickModel(Palette p) => showModelPicker(
    context: context,
    palette: p,
    tier: bud.tier,
    effort: bud.effort,
    onChanged: (t, e) {
      setState(() {
        bud.tier = t;
        bud.effort = e;
      });
      widget.store.save();
    },
  );

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${bud.name}?', style: sans(19, w: FontWeight.w700)),
        content: Text('${bud.name} and everything it remembers will be gone from this device.', style: sans(15, w: FontWeight.w400)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFE5484D)))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    _convos.remove(bud.id)?.dispose();
    widget.store.remove(bud);
    Navigator.of(context).pop();
  }

  Future<void> _openMemory(Palette p) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .25),
      builder: (ctx) => _MemorySheet(bud: bud, store: widget.store, palette: p),
    );
    if (mounted) setState(() {});
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.palette, required this.onTap});
  final String label;
  final Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    shape: StadiumBorder(side: BorderSide(color: palette.textSoft.withValues(alpha: .35), width: .7)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: sans(13, c: palette.text, w: FontWeight.w600, h: 1)),
      ),
    ),
  );
}

/// Everything a Bud remembers, one note at a time: add, edit, delete.
class _MemorySheet extends StatefulWidget {
  const _MemorySheet({required this.bud, required this.store, required this.palette});
  final Bud bud;
  final BudStore store;
  final Palette palette;

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _save() {
    widget.store.save();
    setState(() {});
  }

  Future<void> _edit(MemoryNote n) async {
    final c = TextEditingController(text: n.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit note', style: sans(18, w: FontWeight.w700)),
        content: TextField(controller: c, autofocus: true, maxLines: 4, minLines: 1, style: sans(15, w: FontWeight.w400)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.trim().isEmpty) return;
    n.text = text.trim();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final bud = widget.bud;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: h * .8),
          child: Glass(
            radius: 30,
            blur: 30,
            fill: Color.alphaBlend(p.glass, p.bg.withValues(alpha: .7)),
            edge: p.edge,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BudAvatar(shape: bud.shape, color: bud.color, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text('What ${bud.name} remembers', style: sans(19, c: p.text, w: FontWeight.w700, ls: -.02))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'This is everything. Edit or delete any note, and ${bud.name} works from the new list.',
                  style: sans(14, c: p.textSoft, w: FontWeight.w400),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: bud.memory.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text('Nothing yet.', style: sans(15, c: p.textSoft), textAlign: TextAlign.center),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final n in bud.memory.reversed)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                                decoration: ShapeDecoration(
                                  color: p.text.withValues(alpha: .04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: p.edge, width: .7),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(n.text, style: sans(15, c: p.text, w: FontWeight.w400))),
                                    IconButton(
                                      tooltip: 'Edit',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Icons.edit_outlined, size: 18, color: p.textSoft),
                                      onPressed: () => _edit(n),
                                    ),
                                    IconButton(
                                      tooltip: 'Forget',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Icons.close_rounded, size: 18, color: p.textSoft),
                                      onPressed: () {
                                        bud.memory.remove(n);
                                        _save();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _add,
                  style: sans(15, c: p.text, w: FontWeight.w400),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    bud.memory.add(MemoryNote(v.trim()));
                    _add.clear();
                    _save();
                  },
                  decoration: InputDecoration(
                    hintText: 'Add something for ${bud.name} to remember',
                    hintStyle: sans(14.5, c: p.textSoft, w: FontWeight.w400),
                    filled: true,
                    fillColor: p.text.withValues(alpha: .04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.edge, width: .7)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
