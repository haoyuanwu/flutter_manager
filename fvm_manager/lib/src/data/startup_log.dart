import 'dart:convert';
import 'dart:io';

class StartupLog {
  static void write(String event, [Map<String, Object?> values = const {}]) {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return;
    try {
      final home =
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
      if (home == null) return;
      final file = File('$home/.fvm_manager/logs/startup.jsonl');
      file.parent.createSync(recursive: true);
      if (file.existsSync() && file.lengthSync() > 1024 * 1024) {
        file.renameSync('${file.path}.previous');
      }
      file.writeAsStringSync(
        '${jsonEncode({'time': DateTime.now().toIso8601String(), 'pid': pid, 'event': event, ...values})}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // 日志失败不能影响启动。
    }
  }
}
