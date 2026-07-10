import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  String get bestMessage {
    final err = stderr.trim();
    if (err.isNotEmpty) return err;
    return stdout.trim();
  }
}

class ProcessRunner {
  final Map<String, Process> _activeProcesses = {};

  bool isRunning(String taskId) => _activeProcesses.containsKey(taskId);

  Process? processFor(String taskId) => _activeProcesses[taskId];

  int? pidFor(String taskId) => _activeProcesses[taskId]?.pid;

  List<String> get activeTaskIds => _activeProcesses.keys.toList();

  Future<Process> start({
    required String taskId,
    required String executable,
    required List<String> arguments,
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) {
    return startManaged(
      taskId: taskId,
      starter: () => Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
      ),
    );
  }

  Future<Process> startManaged({
    required String taskId,
    required Future<Process> Function() starter,
  }) async {
    if (isRunning(taskId)) throw Exception('该任务已在运行');
    final process = await starter();
    _activeProcesses[taskId] = process;
    unawaited(
      process.exitCode.whenComplete(() {
        if (identical(_activeProcesses[taskId], process)) {
          _activeProcesses.remove(taskId);
        }
      }),
    );
    return process;
  }

  Future<ProcessRunResult> run({
    required String executable,
    required List<String> arguments,
    String? taskId,
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    final id =
        taskId ?? 'run:${DateTime.now().microsecondsSinceEpoch}:$executable';
    final process = await start(
      taskId: id,
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );
    final stdoutFuture = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    final stderrFuture = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();

    var timedOut = false;
    var exitCodeFuture = process.exitCode;
    if (timeout != null) {
      exitCodeFuture = exitCodeFuture.timeout(
        timeout,
        onTimeout: () async {
          timedOut = true;
          await stop(id);
          return -1;
        },
      );
    }

    final exitCode = await exitCodeFuture;
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    return ProcessRunResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: timedOut ? '${stderr.trim()}\n命令执行超时，已尝试停止。'.trim() : stderr,
      timedOut: timedOut,
    );
  }

  Future<void> stop(
    String taskId, {
    Future<bool> Function(Process process)? gracefulStop,
  }) async {
    final process = _activeProcesses[taskId];
    if (process == null) return;
    if (gracefulStop != null && await gracefulStop(process)) return;
    await _killProcessTree(process);
  }

  Future<void> stopAll() async {
    for (final taskId in activeTaskIds) {
      await stop(taskId);
    }
  }

  Future<void> _killProcessTree(Process process) async {
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
}
