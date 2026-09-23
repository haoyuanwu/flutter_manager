import 'dart:convert';
import 'dart:io';

import 'fvm_service.dart';
import 'process_runner.dart';

/// 按控制台标签（会话/任务 ID）隔离日志，避免不同命令互相干扰。
class ProjectCommandLogBuffer {
  ProjectCommandLogBuffer({this.maxLength = 120000});

  final int maxLength;
  final Map<String, String> _logs = {};

  String logFor(String tabId) => _logs[tabId] ?? '';

  String append(String tabId, String output) {
    var log = logFor(tabId) + output;
    if (log.length > maxLength) log = log.substring(log.length - maxLength);
    _logs[tabId] = log;
    return log;
  }

  void clear(String tabId) => _logs[tabId] = '';

  void remove(String tabId) => _logs.remove(tabId);

  /// 合并某项目下全部标签日志（MCP 兼容用）。
  String logForProject(
    String projectPath,
    Iterable<String> tabIds,
  ) {
    final buffer = StringBuffer();
    for (final id in tabIds) {
      final log = logFor(id);
      if (log.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln('\n${'─' * 48}\n');
      buffer.write(log);
    }
    return buffer.toString();
  }
}

class FlutterCommandService {
  FlutterCommandService(this._fvmService, this._processRunner);

  final FvmService _fvmService;
  final ProcessRunner _processRunner;

  bool isRunning(String taskId) => _processRunner.isRunning(taskId);

  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await _processRunner.startManaged(
      taskId: taskId,
      starter: () => _fvmService.startFlutterCommand(
        projectPath: projectPath,
        arguments: arguments,
      ),
    );
    onOutput(
      r'$ flutter '
      '${arguments.join(' ')}\n\n',
    );
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    return process.exitCode;
  }

  Future<int> runDart({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await _processRunner.startManaged(
      taskId: taskId,
      starter: () => _fvmService.startDartCommand(
        projectPath: projectPath,
        arguments: arguments,
      ),
    );
    onOutput(
      r'$ dart '
      '${arguments.join(' ')}\n\n',
    );
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    return process.exitCode;
  }

  Future<int> runExternal({
    required String taskId,
    required String executable,
    required String workingDirectory,
    required List<String> arguments,
    List<String>? displayArguments,
    required void Function(String output) onOutput,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await _processRunner.start(
      taskId: taskId,
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
    onOutput(
      r'$ '
      '$executable ${(displayArguments ?? arguments).join(' ')}\n\n',
    );
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    return process.exitCode;
  }

  Future<void> stop(String taskId, {bool gracefulFlutterRun = false}) async {
    await _processRunner.stop(
      taskId,
      gracefulStop: gracefulFlutterRun ? _quitFlutterRun : null,
    );
  }

  Future<bool> _quitFlutterRun(Process process) async {
    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
      await process.exitCode.timeout(const Duration(seconds: 5));
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> hotReload(String taskId) => _sendRuntimeCommand(taskId, 'r');

  Future<void> hotRestart(String taskId) => _sendRuntimeCommand(taskId, 'R');

  Future<void> _sendRuntimeCommand(String taskId, String command) async {
    final process = _processRunner.processFor(taskId);
    if (process == null) throw Exception('Flutter Run 当前未运行');
    process.stdin.writeln(command);
    await process.stdin.flush();
  }
}
