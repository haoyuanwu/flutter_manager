import 'dart:convert';
import 'dart:io';

import 'fvm_service.dart';

class FlutterCommandService {
  FlutterCommandService(this._fvmService);

  final FvmService _fvmService;
  Process? _activeProcess;

  bool get isRunning => _activeProcess != null;

  Future<int> run({
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) async {
    // 确保旧进程已停止
    if (_activeProcess != null) {
      stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final process = await _fvmService.startFlutterCommand(
      projectPath: projectPath,
      arguments: arguments,
    );
    _activeProcess = process;
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
      _activeProcess = null;
    }
  }

  Future<int> runExternal({
    required String executable,
    required String workingDirectory,
    required List<String> arguments,
    List<String>? displayArguments,
    required void Function(String output) onOutput,
  }) async {
    if (_activeProcess != null) {
      stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
    _activeProcess = process;
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
      _activeProcess = null;
    }
  }

  Future<void> stop() async {
    final process = _activeProcess;
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

  Future<void> hotReload() => _sendRuntimeCommand('r');

  Future<void> hotRestart() => _sendRuntimeCommand('R');

  Future<void> _sendRuntimeCommand(String command) async {
    final process = _activeProcess;
    if (process == null) throw Exception('Flutter Run 当前未运行');
    process.stdin.writeln(command);
    await process.stdin.flush();
  }
}
