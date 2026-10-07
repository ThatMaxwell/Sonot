import 'package:flutter/widgets.dart';

import '../core/settings.dart';
import 'notify.dart';

/// What you answered when Sonot Code asked to do something.
enum Approval { once, always, deny }

/// One thing the agent wants to do that needs your OK.
class Ask {
  Ask({required this.title, required this.detail, required this.rule, required this.ruleLabel});

  /// e.g. "Run a command".
  final String title;

  /// The exact command, file or task.
  final String detail;

  /// What "Always allow" remembers, e.g. `cmd:npm` or `write`.
  final String rule;

  /// How "Always allow" reads on the button, e.g. "Always allow npm".
  final String ruleLabel;
}

/// Asks before the agent touches your machine, and remembers "Always allow".
///
/// Rules: `cmd:<program>` for commands that start with that program,
/// `cmd=<exact command>` for compound commands (pipes, `&&` …), `node`,
/// `write` for file changes, `browser`, `github` for GitHub changes.
class Permissions {
  Permissions(this.settings);
  final Settings settings;

  /// Set by the UI: shows the question and returns your answer.
  Future<Approval> Function(Ask ask)? onAsk;

  /// Set by the UI while a question is open: dismisses it (when you press stop).
  void Function()? cancelAsk;

  bool allowed(String rule) {
    final rules = settings.alwaysAllow;
    return rules.contains('all') || rules.contains(rule);
  }

  /// True when the agent may go ahead.
  Future<bool> check(Ask ask) async {
    if (allowed(ask.rule)) return true;
    final ui = onAsk;
    if (ui == null) return false;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      Notifier.instance.show('Sonot Code needs you', '${ask.title}: ${ask.detail.split('\n').first}', urgent: true);
    }
    final a = await ui(ask);
    if (a == Approval.always) settings.alwaysAllow = {...settings.alwaysAllow, ask.rule}.toList();
    return a != Approval.deny;
  }

  void forget(String rule) => settings.alwaysAllow = settings.alwaysAllow.where((r) => r != rule).toList();

  /// The rule "Always allow" saves for [command]: the program for a simple
  /// command, the whole line when it chains several.
  static (String rule, String label) commandRule(String command) {
    final c = command.trim();
    if (RegExp(r'&&|\|\||[|;`<>]|\$\(|\n').hasMatch(c)) return ('cmd=$c', 'Always allow this exact command');
    final first = c.split(RegExp(r'\s+')).first;
    var prog = first.replaceAll('"', '').replaceAll("'", '').split(RegExp(r'[\\/]')).last.toLowerCase();
    prog = prog.replaceFirst(RegExp(r'\.(exe|cmd|bat|ps1)$'), '');
    return ('cmd:$prog', 'Always allow $prog');
  }
}
