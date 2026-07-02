import 'dart:convert';
import 'dart:io';

import 'fvm_service.dart';

class ProjectCommandLogBuffer {
  ProjectCommandLogBuffer({this.maxLength = 120000});

  final int maxLength;
  final Map<String, String> _logs = {};

  String logFor(String projectPath) => _logs[projectPath] ?? '';

  String append(String projectPath, String output) {
    var log = logFor(projectPath) + output;
    if (log.length > maxLength) log = log.substring(log.length - maxLength);
    _logs[projectPath] = log;
    return log;
  }

  void clear(String projectPath) => _logs[projectPath] = '';

  void remove(String projectPath) => _logs.remove(projectPath);
}

class FlutterCommandService {
  FlutterCommandService(this._fvmService);

  final FvmService _fvmService;
  final Map<String, Process> _activeProcesses = {};

  bool isRunning(String taskId) => _activeProcesses.containsKey(taskId);

  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await _fvmService.startFlutterCommand(
      projectPath: projectPath,
      arguments: arguments,
    );
    _activeProcesses[taskId] = process;
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
    try {
      return await process.exitCode;
    } finally {
      if (identical(_activeProcesses[taskId], process)) {
        _activeProcesses.remove(taskId);
      }
    }
  }

  Future<int> runDart({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await _fvmService.startDartCommand(
      projectPath: projectPath,
      arguments: arguments,
    );
    _activeProcesses[taskId] = process;
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
    try {
      return await process.exitCode;
    } finally {
      if (identical(_activeProcesses[taskId], process)) {
        _activeProcesses.remove(taskId);
      }
    }
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
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
    _activeProcesses[taskId] = process;
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
    try {
      return await process.exitCode;
    } finally {
      if (identical(_activeProcesses[taskId], process)) {
        _activeProcesses.remove(taskId);
      }
    }
  }

  Future<void> stop(String taskId) async {
    final process = _activeProcesses[taskId];
    if (process == null) return;
    if (Platform.isWindows) {
      await Process.run('taskkill', [
        '/PID',
        '${process.pid}',
        '/T',
        '/F',
      ], runInShell: true);
    } else {
      process.kill(ProcessSignal.sigterm);
    }
  }

  Future<void> hotReload(String taskId) => _sendRuntimeCommand(taskId, 'r');

  Future<void> hotRestart(String taskId) => _sendRuntimeCommand(taskId, 'R');

  Future<void> _sendRuntimeCommand(String taskId, String command) async {
    final process = _activeProcesses[taskId];
    if (process == null) throw Exception('Flutter Run 当前未运行');
    process.stdin.writeln(command);
    await process.stdin.flush();
  }
}
