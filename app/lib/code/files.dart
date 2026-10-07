import 'dart:convert';
import 'dart:io';

/// File tools for Sonot Code, rooted at the workspace folder. Absolute paths
/// work too: it's your machine, and writes always ask first.
class Files {
  Files({required this.workspace});
  String Function() workspace;

  static const _skip = {'.git', 'node_modules', 'build', '.dart_tool', '.venv', 'venv', '__pycache__', '.gradle', '.idea', 'dist', 'target'};
  static const maxRead = 120 * 1024;

  String resolve(String path) {
    final p = path.trim();
    if (p.isEmpty || p == '.') return workspace();
    final abs = Platform.isWindows ? RegExp(r'^([a-zA-Z]:|\\\\)').hasMatch(p) : p.startsWith('/');
    if (abs) return p;
    if (p.startsWith('~')) return '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? ''}${p.substring(1)}';
    return '${workspace()}${Platform.pathSeparator}$p';
  }

  String _rel(String full) {
    final base = workspace();
    return full.startsWith(base) ? full.substring(base.length).replaceFirst(RegExp(r'^[\\/]'), '') : full;
  }

  /// Lines [offset]..[offset]+[limit] of a text file, numbered.
  Future<String> read(String path, {int offset = 1, int limit = 2000}) async {
    final f = File(resolve(path));
    if (!f.existsSync()) throw FileSystemException('No such file', f.path);
    final bytes = await f.readAsBytes();
    if (bytes.take(8000).contains(0)) return '(binary file, ${bytes.length} bytes)';
    final lines = const LineSplitter().convert(utf8.decode(bytes, allowMalformed: true));
    final start = (offset - 1).clamp(0, lines.length);
    final end = (start + limit).clamp(0, lines.length);
    final out = StringBuffer();
    for (var i = start; i < end; i++) {
      out.writeln('${'${i + 1}'.padLeft(5)}  ${lines[i]}');
      if (out.length > maxRead) {
        out.writeln('[… stopped at line ${i + 1} of ${lines.length}; read on with offset]');
        return out.toString();
      }
    }
    if (end < lines.length) out.writeln('[… ${lines.length - end} more lines; read on with offset=${end + 1}]');
    return out.isEmpty ? '(empty file)' : out.toString();
  }

  Future<String> write(String path, String content) async {
    final f = File(resolve(path));
    await f.parent.create(recursive: true);
    final existed = f.existsSync();
    await f.writeAsString(content);
    return '${existed ? 'Updated' : 'Created'} ${f.path} (${const LineSplitter().convert(content).length} lines).';
  }

  /// Replaces [oldText] with [newText]. [oldText] must appear exactly once
  /// unless [all] is set.
  Future<String> edit(String path, String oldText, String newText, {bool all = false}) async {
    final f = File(resolve(path));
    if (!f.existsSync()) throw FileSystemException('No such file', f.path);
    final s = await f.readAsString();
    final n = oldText.isEmpty ? 0 : oldText.allMatches(s).length;
    if (n == 0) throw const FormatException('old_text was not found in the file. Read the file and copy the text exactly.');
    if (n > 1 && !all) throw FormatException('old_text appears $n times. Add more surrounding lines so it is unique, or set all=true.');
    await f.writeAsString(all ? s.replaceAll(oldText, newText) : s.replaceFirst(oldText, newText));
    return 'Edited ${f.path} ($n change${n == 1 ? '' : 's'}).';
  }

  Future<String> list(String path, {int depth = 2}) async {
    final root = Directory(resolve(path));
    if (!root.existsSync()) throw FileSystemException('No such folder', root.path);
    final out = StringBuffer();
    var count = 0;
    Future<void> walk(Directory d, int level) async {
      final kids = await d.list(followLinks: false).toList()
        ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      for (final e in kids) {
        if (++count > 800) return;
        final name = e.path.split(RegExp(r'[\\/]')).last;
        final pad = '  ' * level;
        if (e is Directory) {
          out.writeln('$pad$name/');
          if (level + 1 < depth && !_skip.contains(name)) await walk(e, level + 1);
        } else if (e is File) {
          out.writeln('$pad$name  ${_size(e.lengthSync())}');
        }
      }
    }

    await walk(root, 0);
    if (count > 800) out.writeln('[… more entries; list a subfolder]');
    return out.isEmpty ? '(empty folder)' : '${root.path}\n$out';
  }

  /// Regex search across text files under [path]. Uses ripgrep when it's installed.
  Future<String> search(String pattern, {String path = '', String glob = ''}) async {
    final root = resolve(path);
    try {
      final r = await Process.run('rg', [
        '--line-number',
        '--no-heading',
        '--max-count',
        '20',
        '--max-columns',
        '300',
        if (glob.isNotEmpty) ...['--glob', glob],
        '-e',
        pattern,
        root,
      ]);
      if (r.exitCode <= 1) {
        final s = (r.stdout as String).trim();
        return s.isEmpty ? 'No matches.' : _cap(s.replaceAll('$root${Platform.pathSeparator}', ''));
      }
    } on ProcessException {
      // No ripgrep; search in Dart below.
    }
    final re = RegExp(pattern);
    final globRe = glob.isEmpty ? null : RegExp('^${RegExp.escape(glob).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$');
    final out = StringBuffer();
    var hits = 0;
    Future<void> walk(Directory d) async {
      await for (final e in d.list(followLinks: false)) {
        if (hits >= 300) return;
        final name = e.path.split(RegExp(r'[\\/]')).last;
        if (e is Directory) {
          if (!_skip.contains(name)) await walk(e);
        } else if (e is File) {
          if (globRe != null && !globRe.hasMatch(name)) continue;
          if (e.lengthSync() > 2 * 1024 * 1024) continue;
          final List<String> lines;
          try {
            lines = await e.readAsLines();
          } catch (_) {
            continue;
          }
          for (var i = 0; i < lines.length; i++) {
            if (re.hasMatch(lines[i])) {
              final l = lines[i].length > 300 ? '${lines[i].substring(0, 300)}…' : lines[i];
              out.writeln('${_rel(e.path)}:${i + 1}:$l');
              if (++hits >= 300) return;
            }
          }
        }
      }
    }

    await walk(Directory(root));
    return hits == 0 ? 'No matches.' : _cap(out.toString());
  }

  static String _cap(String s) => s.length > 20000 ? '${s.substring(0, 20000)}\n[… more matches; narrow the search]' : s;

  static String _size(int b) => b < 1024
      ? '${b}B'
      : b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(1)}K'
      : '${(b / 1024 / 1024).toStringAsFixed(1)}M';
}
