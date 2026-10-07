import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonot_app/buds/bud_avatar.dart';
import 'package:sonot_app/buds/buds.dart';
import 'package:sonot_app/core/settings.dart';
import 'package:sonot_app/main.dart';
import 'package:sonot_app/widgets/bloom.dart';

Future<SonotApp> _app(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SonotApp(settings: await Settings.load(), buds: await BudStore.load());
}

void main() {
  testWidgets('first launch shows the setup screen', (tester) async {
    await tester.pumpWidget(await _app({}));
    expect(find.text('Continue with Puter'), findsOneWidget);
    expect(find.text('Use my own server'), findsOneWidget);
  });

  testWidgets('Use my own server asks for an address', (tester) async {
    await tester.pumpWidget(await _app({}));
    await tester.tap(find.text('Use my own server'));
    await tester.pumpAndSettle();
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('the Sonot mark shows on an empty chat and hides while typing', (tester) async {
    await tester.pumpWidget(await _app({'puterToken': 'test-token'}));
    await tester.pumpAndSettle();
    final mark = find.ancestor(of: find.byType(SonotMark), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(mark).opacity, 1);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(mark).opacity, 0);
  });

  testWidgets('switching to Code changes the hint', (tester) async {
    await tester.pumpWidget(await _app({'puterToken': 'test-token'}));
    await tester.pumpAndSettle();
    expect(find.text('Ask Sonot anything'), findsOneWidget);
    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the code task…'), findsOneWidget);
  });

  testWidgets('the Buds tab shows the starter Buds', (tester) async {
    await tester.pumpWidget(await _app({'puterToken': 'test-token'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buds'));
    await tester.pump(const Duration(milliseconds: 600));
    for (final name in ['Pip', 'Scout', 'Byte', 'Moss']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byType(BudAvatar), findsWidgets);
    expect(find.text('New Bud'), findsOneWidget);
  });
}
