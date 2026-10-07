import 'package:flutter_test/flutter_test.dart';
import 'package:sonot_app/buds/bud_avatar.dart';
import 'package:sonot_app/buds/buds.dart';

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
}
