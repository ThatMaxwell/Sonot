import 'package:flutter/widgets.dart';

import 'settings.dart';

/// Hands the appearance settings (glass blur, animations) down the tree, so
/// widgets that read them rebuild when they change.
class UiPrefs extends InheritedNotifier<Settings> {
  const UiPrefs({super.key, required Settings settings, required super.child}) : super(notifier: settings);

  static Settings? _of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiPrefs>()?.notifier;

  /// Whether glass panels blur what's behind them.
  static bool blur(BuildContext context) => _of(context)?.blur ?? true;

  /// Whether playful animations (like the Anthem on Max burst) play.
  static bool motion(BuildContext context) => _of(context)?.motion ?? true;
}
