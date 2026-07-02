import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'pub_environment_service.dart';

class FvmService {
  FvmService(this._environment);

  final PubEnvironmentService _environment;
  String? _executable;

  Future<String?> detect() async {
    for (final candidate in _candidates()) {
      try {
        final result = await Process.run(
          candidate,
          const ['--version'],
          environment: _environment.processEnvironment,
          includeParentEnvironment: false,
        );
        if (result.exitCode == 0) {
          _executable = candidate;
          return result.stdout.toString().trim();
        }
      } on ProcessException {
        // Try the next well-known location.
      }
    }
    _executable = null;
    return null;
  }

  Future<String> useLocalDirectory(String directoryPath) async {
    final executableName = Platform.isWindows ? 'fvm.bat' : 'fvm';
    final separator = Platform.pathSeparator;
    final candidates = <String>[
      '$directoryPath$separator$executableName',
      '$directoryPath${separator}bin$separator$executableName',
    ];
    String? failure;
    for (final candidate in candidates) {
      if (!await File(candidate).exists()) continue;
      try {
        final result = await Process.run(
          candidate,
          const ['--version'],
          environment: _environment.processEnvironment,
          includeParentEnvironment: false,
        );
        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          await _environment.setCustomFvmExecutable(candidate);
          _executable = candidate;
          return version;
        }
        failure = result.stderr.toString().trim();
      } on ProcessException catch (error) {
        failure = error.message;
      }
    }
    throw Exception(
      failure?.isNotEmpty == true
          ? '所选目录中的 FVM 无法运行：$failure'
          : '所选目录中未找到 $executableName，请选择包含该文件的目录或其上级目录',
    );
  }

  Future<void> install({required void Function(String) onOutput}) async {
    await _activate(operation: '安装', onOutput: onOutput);
  }

  Future<void> update({required void Function(String) onOutput}) async {
    await _activate(operation: '更新', onOutput: onOutput);
  }

  Future<void> _activate({
    required String operation,
    required void Function(String) onOutput,
  }) async {
    final dartExecutable = _findExecutable('dart');
    if (dartExecutable == null) {
      throw Exception('未检测到 Dart，无法通过 Dart Pub 安装 FVM');
    }
    final process = await Process.start(
      dartExecutable,
      const ['pub', 'global', 'activate', 'fvm'],
      runInShell: Platform.isWindows,
      environment: _environment.processEnvironment,
      includeParentEnvironment: false,
    );
    process.stdout.transform(utf8.decoder).listen(onOutput);
    process.stderr.transform(utf8.decoder).listen(onOutput);
    final code = await process.exitCode;
    if (code != 0) throw Exception('FVM$operation失败（退出码 $code）');
    if (await detect() == null) {
      throw Exception('FVM 已完成$operation，但当前应用找不到它。请按环境配置说明添加 PATH。');
    }
  }

  Future<List<InstalledSdk>> listInstalled() async {
    final result = await _run(const [
      'api',
      'list',
      '--compress',
      '--skip-size-calculation',
    ]);
    final json = jsonDecode(result) as Map<String, dynamic>;
    return (json['versions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(InstalledSdk.fromMap)
        .toList();
  }

  Future<String> cachePath() async {
    final result = await _run(const ['api', 'context', '--compress']);
    final json = jsonDecode(result) as Map<String, dynamic>;
    final context = json['context'] as Map<String, dynamic>;
    return context['fvmDir'] as String;
  }

  Future<String?> globalVersion() async {
    final path = '${await cachePath()}${Platform.pathSeparator}default';
    try {
      final target = await Directory(path).resolveSymbolicLinks();
      return target.split(RegExp(r'[/\\]')).last;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> openFvmDirectory() async {
    await _openDirectory(await cachePath(), 'FVM');
  }

  Future<void> openGlobalFlutterDirectory() async {
    final separator = Platform.pathSeparator;
    await _openDirectory('${await cachePath()}${separator}default', 'Flutter');
  }

  Future<void> openFlutterDirectory(String path) async {
    await _openDirectory(path, 'Flutter');
  }

  Future<void> _openDirectory(String path, String label) async {
    if (!await Directory(path).exists()) {
      throw Exception('$label 目录不存在：$path');
    }
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : await Process.run('open', [path]);
    if (result.exitCode != 0) {
      throw Exception('无法打开 $label 目录：${result.stderr}');
    }
  }

  Future<void> setGlobal(String version) async {
    await _run(['global', version]);
  }

  Future<void> removeVersion(String version) async {
    await _run(['remove', version]);
  }

  Future<void> setProjectVersion({
    required String projectPath,
    required String version,
  }) async {
    await _run([
      'use',
      version,
      '--skip-pub-get',
    ], workingDirectory: projectPath);
  }

  /// 移除项目的 FVM 配置（删除 .fvmrc 和 .fvm 目录）
  Future<void> removeProjectVersion(String projectPath) async {
    final separator = Platform.pathSeparator;
    final fvmrc = File('$projectPath$separator.fvmrc');
    if (fvmrc.existsSync()) await fvmrc.delete();
    final fvmDir = Directory('$projectPath$separator.fvm');
    if (fvmDir.existsSync()) await fvmDir.delete(recursive: true);
  }

  Future<Process> startFlutterCommand({
    required String projectPath,
    required List<String> arguments,
  }) async {
    if (_usesFvm(projectPath) &&
        (_executable != null || await detect() != null)) {
      return Process.start(
        _executable!,
        ['flutter', ...arguments],
        workingDirectory: projectPath,
        environment: _environment.processEnvironment,
        includeParentEnvironment: false,
        runInShell: Platform.isWindows,
      );
    }
    final flutterExecutable = _findExecutable('flutter');
    if (flutterExecutable == null) {
      throw Exception('未检测到 Flutter，请先安装 Flutter 或配置 FVM 全局版本');
    }
    return Process.start(
      flutterExecutable,
      arguments,
      workingDirectory: projectPath,
      environment: _environment.processEnvironment,
      includeParentEnvironment: false,
      runInShell: Platform.isWindows,
    );
  }

  Future<Process> startDartCommand({
    required String projectPath,
    required List<String> arguments,
  }) async {
    if (_usesFvm(projectPath) &&
        (_executable != null || await detect() != null)) {
      return Process.start(
        _executable!,
        ['dart', ...arguments],
        workingDirectory: projectPath,
        environment: _environment.processEnvironment,
        includeParentEnvironment: false,
        runInShell: Platform.isWindows,
      );
    }
    final dartExecutable = _findExecutable('dart');
    if (dartExecutable == null) {
      throw Exception('未检测到 Dart，请先安装 Flutter 或配置 FVM 全局版本');
    }
    return Process.start(
      dartExecutable,
      arguments,
      workingDirectory: projectPath,
      environment: _environment.processEnvironment,
      includeParentEnvironment: false,
      runInShell: Platform.isWindows,
    );
  }

  Future<List<Map<String, String>>> listDevices(String projectPath) async {
    final process = await startFlutterCommand(
      projectPath: projectPath,
      arguments: const ['devices', '--machine'],
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw Exception(
        stderr.trim().isEmpty
            ? '获取 Flutter 设备失败（退出码 $exitCode）'
            : stderr.trim(),
      );
    }
    try {
      final list = jsonDecode(stdout) as List;
      return list.map((entry) {
        final device = (entry as Map).cast<String, dynamic>();
        return {
          'id': (device['id'] ?? device['name'] ?? '').toString(),
          'name': (device['name'] ?? '').toString(),
          'platform': (device['platform'] ?? '').toString(),
        };
      }).toList();
    } on Object {
      return const [];
    }
  }

  Future<String> _run(
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final executable =
        _executable ?? (await detect() != null ? _executable : null);
    if (executable == null) throw Exception('未检测到 FVM');
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: _environment.processEnvironment,
      includeParentEnvironment: false,
    );
    if (result.exitCode != 0) {
      throw Exception(
        result.stderr.toString().trim().isEmpty
            ? result.stdout.toString().trim()
            : result.stderr.toString().trim(),
      );
    }
    return result.stdout.toString();
  }

  Iterable<String> _candidates() sync* {
    if (_environment.customFvmExecutable case final custom?) yield custom;
    final executableName = Platform.isWindows ? 'fvm.bat' : 'fvm';
    for (final directory in _environment.executableSearchPaths) {
      yield '$directory${Platform.pathSeparator}$executableName';
    }
  }

  String? _findExecutable(String name) {
    final executableName = Platform.isWindows ? '$name.bat' : name;
    for (final directory in _environment.executableSearchPaths) {
      final candidate = '$directory${Platform.pathSeparator}$executableName';
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  bool _usesFvm(String projectPath) {
    final separator = Platform.pathSeparator;
    return File('$projectPath$separator.fvmrc').existsSync() ||
        File(
          '$projectPath$separator.fvm${separator}fvm_config.json',
        ).existsSync();
  }
}
