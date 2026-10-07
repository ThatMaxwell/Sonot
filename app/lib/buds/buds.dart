import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bud_avatar.dart';

/// A note a Bud keeps about you. Every one is visible, editable and
/// deletable: nothing is remembered behind your back.
class MemoryNote {
  MemoryNote(this.text, {DateTime? at, String? id})
    : at = at ?? DateTime.now(),
      id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  String text;
  final DateTime at;

  Map<String, Object> toJson() => {'id': id, 'text': text, 'at': at.toIso8601String()};
  static MemoryNote fromJson(Map<String, dynamic> j) =>
      MemoryNote(j['text'] as String, at: DateTime.tryParse(j['at'] as String? ?? ''), id: j['id'] as String?);
}

/// A Bud: a named helper with a face, a job and a vibe.
class Bud {
  Bud({
    required this.id,
    required this.name,
    required this.shape,
    required this.color,
    required this.job,
    required this.vibe,
    List<MemoryNote>? memory,
  }) : memory = memory ?? [];

  final String id;
  String name;
  BudShape shape;
  Color color;
  String job;
  String vibe;
  final List<MemoryNote> memory;

  /// The persona the model runs with. Built from the job and vibe, plus the
  /// visible memory and the rules every Bud follows.
  String get persona {
    final notes = memory.isEmpty ? '(nothing yet)' : memory.map((n) => '- ${n.text}').join('\n');
    return '''You are $name, a Sonot Bud: a friendly AI helper made by ThatMaxwell.
Your job: $job
Your vibe: $vibe

Talk like yourself: warm, short and clear. Get things done for the user rather than chatting about them.

What you remember about the user (they can see and edit this list):
$notes

When the user tells you something worth remembering for later (a preference, a plan, a fact about their life or work), add [[remember:SHORT NOTE]] at the very end of your reply, written in third person, at most once per reply. Don't remember secrets, passwords or anything they ask you to forget. Never mention these tags.

While you reply, you may set your face with [[emo:NAME]] at any point. NAME is one of: neutral happy excited curious thinking focused surprised sad sleepy wink confused shy serious. Use at most one tag per sentence. Never mention the tags.

Ground rules: you are an AI, and you say so if asked. No romance or flirting. If the user mentions self-harm or being in danger, be kind, encourage them to reach out to someone they trust, and point them to local emergency services or a crisis line (in the US, call or text 988).''';
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'shape': shape.name,
    'color': color.toARGB32(),
    'job': job,
    'vibe': vibe,
    'memory': [for (final n in memory) n.toJson()],
  };

  static Bud fromJson(Map<String, dynamic> j) => Bud(
    id: j['id'] as String,
    name: j['name'] as String,
    shape: BudShape.values.firstWhere((s) => s.name == j['shape'], orElse: () => BudShape.circle),
    color: Color(j['color'] as int),
    job: j['job'] as String,
    vibe: j['vibe'] as String,
    memory: [for (final n in (j['memory'] as List? ?? [])) MemoryNote.fromJson(n as Map<String, dynamic>)],
  );
}

/// The colours a Bud can be: the four starters plus a few more.
const budColors = [
  Color(0xFFF6B73C),
  Color(0xFFFF7A59),
  Color(0xFF2F6BFF),
  Color(0xFF5FBF7A),
  Color(0xFFB57BFF),
  Color(0xFFFF6FAE),
  Color(0xFF2EC4C4),
  Color(0xFF8A94AD),
];

List<Bud> starterBuds() => [
  Bud(
    id: 'pip',
    name: 'Pip',
    shape: BudShape.circle,
    color: const Color(0xFFF6B73C),
    job: 'Your day: plans, reminders and a daily brief.',
    vibe: 'Sunny and organised, a little playful.',
  ),
  Bud(
    id: 'scout',
    name: 'Scout',
    shape: BudShape.triangle,
    color: const Color(0xFFFF7A59),
    job: 'Research anything and keep watching it.',
    vibe: 'Curious and thorough. Cites what it finds.',
  ),
  Bud(
    id: 'byte',
    name: 'Byte',
    shape: BudShape.square,
    color: const Color(0xFF2F6BFF),
    job: 'Keep your repos healthy and help with code.',
    vibe: 'Calm, precise engineer. Shows code, skips fluff.',
  ),
  Bud(
    id: 'moss',
    name: 'Moss',
    shape: BudShape.capsule,
    color: const Color(0xFF5FBF7A),
    job: 'Wind down: journaling, reflection and calm chat.',
    vibe: 'Gentle and unhurried. Asks good questions.',
  ),
];

/// Keeps the Buds on this device.
class BudStore extends ChangeNotifier {
  BudStore._(this._prefs, this.buds);
  final SharedPreferences _prefs;
  final List<Bud> buds;

  static Future<BudStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('buds');
    List<Bud> buds;
    try {
      buds = raw == null ? starterBuds() : [for (final j in jsonDecode(raw) as List) Bud.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      buds = starterBuds();
    }
    return BudStore._(prefs, buds);
  }

  void save() {
    _prefs.setString('buds', jsonEncode([for (final b in buds) b.toJson()]));
    notifyListeners();
  }

  void add(Bud b) {
    buds.add(b);
    save();
  }

  void remove(Bud b) {
    buds.remove(b);
    save();
  }
}

/// Pulls hidden `[[remember:...]]` notes out of a reply as it streams.
class MemoryTagFilter {
  MemoryTagFilter(this.onNote);
  final void Function(String note) onNote;
  String _buf = '';
  static final _tag = RegExp(r'\[\[\s*remember\s*:([^\]\n]{1,300})\]\]');

  String add(String chunk) {
    _buf += chunk;
    final out = StringBuffer();
    while (true) {
      final m = _tag.firstMatch(_buf);
      if (m == null) break;
      out.write(_buf.substring(0, m.start));
      onNote(m.group(1)!.trim());
      _buf = _buf.substring(m.end);
    }
    // Hold back a possible tag that hasn't finished arriving.
    final hold = EmotionTagFilter.holdFrom(_buf, 320);
    out.write(_buf.substring(0, hold));
    _buf = _buf.substring(hold);
    return out.toString();
  }

  String close() {
    final rest = _buf.replaceAllMapped(_tag, (m) {
      onNote(m.group(1)!.trim());
      return '';
    });
    _buf = '';
    return rest;
  }
}
