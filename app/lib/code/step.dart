import 'dart:typed_data';

/// Where a tool step is in its life.
enum StepStatus { asking, running, done, failed, denied }

/// One tool call inside a Sonot Code reply: what the agent asked for, whether
/// you allowed it, and what came back. Shown as a card in the reply.
class ToolStep {
  ToolStep({required this.id, required this.name, required this.args, required this.at});

  final String id;
  final String name;
  final Map<String, dynamic> args;

  /// How much of the reply's text existed when this step started, so text
  /// and steps render in the order they happened.
  final int at;

  StepStatus status = StepStatus.running;

  /// What the tool printed or returned, as shown on the card (trimmed).
  String output = '';

  /// A picture to show on the card (a browser screenshot).
  Uint8List? image;

  /// A one-line label, e.g. "Run  npm test".
  String get title => describeStep(name, args);
}

/// A human label for a tool call.
String describeStep(String name, Map<String, dynamic> a) {
  String s(String k) => (a[k] ?? '').toString();
  final on = s('node').isEmpty ? '' : ' on ${s('node')}';
  return switch (name) {
    'run_command' => '${a['background'] == true ? 'Start' : 'Run'}$on  ${s('command')}',
    'process_output' => 'Read output of ${s('id')}',
    'process_kill' => 'Stop ${s('id')}',
    'process_list' => 'List running processes',
    'read_file' => 'Read ${s('path')}',
    'write_file' => 'Write ${s('path')}',
    'edit_file' => 'Edit ${s('path')}',
    'list_dir' => 'List ${s('path').isEmpty ? 'workspace' : s('path')}',
    'search' => 'Search for ${s('pattern')}',
    'browser' => 'Browse$on  ${s('task')}',
    'notify' => 'Notify$on  ${s('title')}',
    'nodes' => 'List devices',
    _ => name,
  };
}
