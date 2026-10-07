import 'package:flutter_test/flutter_test.dart';
import 'package:sonot_app/buds/bud_avatar.dart';
import 'package:sonot_app/buds/buds.dart';
import 'package:sonot_app/core/models.dart';

void main() {
  test('memory tags are pulled out of the text, even when split across chunks', () {
    final notes = <String>[];
    final f = MemoryTagFilter(notes.add);
    final out = f.add('Sure thing! [[remem') + f.add('ber:Carrot likes dark mode]] Done.') + f.close();
    expect(out, 'Sure thing!  Done.');
    expect(notes, ['Carrot likes dark mode']);
  });

  test('emotion and memory filters chain cleanly', () {
    final emotions = <BudEmotion>[];
    final notes = <String>[];
    final e = EmotionTagFilter(emotions.add);
    final m = MemoryTagFilter(notes.add);
    final out = m.add(e.add('[[emo:happy]]Hi! [[remember:Runs on Sundays]]')) + m.add(e.close()) + m.close();
    expect(out, 'Hi! ');
    expect(emotions, [BudEmotion.happy]);
    expect(notes, ['Runs on Sundays']);
  });

  test('the persona carries the job, the vibe and every memory note', () {
    final bud = starterBuds().first..memory.add(MemoryNote('Has a dog named Toast'));
    expect(bud.persona, contains(bud.job));
    expect(bud.persona, contains(bud.vibe));
    expect(bud.persona, contains('- Has a dog named Toast'));
  });

  test('Buds survive a save and load', () {
    final bud = starterBuds()[2]..memory.add(MemoryNote('Prefers TypeScript'));
    final back = Bud.fromJson(bud.toJson());
    expect(back.name, 'Byte');
    expect(back.shape, BudShape.square);
    expect(back.color, bud.color);
    expect(back.memory.single.text, 'Prefers TypeScript');
  });

  test('face and memory tags never leak, however the stream splits them', () {
    const reply = '[[emo:happy]]Hey there! Good to see you.\n\n[[emo:curious]]What should we dig into? '
        '[[remember:Likes tracking prices]][[ emo: Excited ]]Let\'s go.';
    // Every possible split point, including a lone "[" at a chunk's end.
    for (var cut = 0; cut <= reply.length; cut++) {
      final faces = <BudEmotion>[];
      final notes = <String>[];
      final e = EmotionTagFilter(faces.add);
      final m = MemoryTagFilter(notes.add);
      final out = m.add(e.add(reply.substring(0, cut))) + m.add(e.add(reply.substring(cut))) + m.add(e.close()) + m.close();
      expect(out, "Hey there! Good to see you.\n\nWhat should we dig into? Let's go.", reason: 'split at $cut');
      expect(faces, [BudEmotion.happy, BudEmotion.curious, BudEmotion.excited], reason: 'split at $cut');
      expect(notes, ['Likes tracking prices'], reason: 'split at $cut');
    }
  });

  test('tags split into single characters are still stripped', () {
    const reply = 'Hi [[emo:curious]]there [x] ok[';
    final faces = <BudEmotion>[];
    final e = EmotionTagFilter(faces.add);
    final out = reply.split('').map(e.add).join() + e.close();
    expect(out, 'Hi there [x] ok[');
    expect(faces, [BudEmotion.curious]);
  });

  test('each Bud keeps its own model, defaulting to Anthem', () {
    final bud = starterBuds().first;
    expect(bud.tier.id, 'anthem');
    expect(bud.effort, Effort.balanced);
    bud
      ..tier = tierById('chord')
      ..effort = Effort.deep;
    final back = Bud.fromJson(bud.toJson());
    expect(back.tier.id, 'chord');
    expect(back.effort, Effort.deep);
    // Buds saved before models were per Bud load as Anthem.
    final old = bud.toJson()..remove('tier')..remove('effort');
    expect(Bud.fromJson(old).tier.id, 'anthem');
  });
}
