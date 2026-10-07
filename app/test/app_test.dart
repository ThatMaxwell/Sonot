import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonot_app/core/settings.dart';
import 'package:sonot_app/main.dart';
import 'package:sonot_app/widgets/bloom.dart';

Future<Settings> _settings(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return Settings.load();
}

void main() {
  testWidgets('first launch shows the setup screen', (tester) async {
    await tester.pumpWidget(SonotApp(settings: await _settings({})));
    expect(find.text('Continue with Puter'), findsOneWidget);
    expect(find.text('Use my own server'), findsOneWidget);
  });

  testWidgets('Use my own server asks for an address', (tester) async {
    await tester.pumpWidget(SonotApp(settings: await _settings({})));
    await tester.tap(find.text('Use my own server'));
    await tester.pumpAndSettle();
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('the Sonot mark shows on an empty chat and hides while typing', (tester) async {
    await tester.pumpWidget(SonotApp(settings: await _settings({'puterToken': 'test-token'})));
    await tester.pumpAndSettle();
    final mark = find.ancestor(of: find.byType(SonotMark), matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(mark).opacity, 1);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(mark).opacity, 0);
  });

  testWidgets('switching to Code changes the hint', (tester) async {
    await tester.pumpWidget(SonotApp(settings: await _settings({'puterToken': 'test-token'})));
    await tester.pumpAndSettle();
    expect(find.text('Ask Sonot anything'), findsOneWidget);
    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the code task…'), findsOneWidget);
  });
}

