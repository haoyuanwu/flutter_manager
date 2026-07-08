import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'pub_environment_service.dart';

class FvmService {
  FvmService(this._environment);

  final PubEnvironmentService _environment;
  String? _executable;

  Future<String?> detect() async {
    // 1. 优先验证上一次检测到的路径（持久化缓存），命中则跳过全量扫描
    final cached = _environment.cachedFvmExecutable;
    if (cached != null) {
      final version = await _tryExecutable(cached);
      if (version != null) {
        _executable = cached;
        return version;
      }
      // 缓存失效（文件被移动/删除），清除并回退到全量扫描
      await _environment.setCachedFvmExecutable(null);
    }

    // 2. 全量扫描所有候选路径
    for (final candidate in _candidates()) {
      final version = await _tryExecutable(candidate);
      if (version != null) {
        _executable = candidate;
        // 持久化，下次启动直接用
        await _environment.setCachedFvmExecutable(candidate);
        return version;
      }
    }
    _executable = null;
    return null;
  }

  /// 尝试运行指定路径的 FVM，成功返回版本号，失败返回 null。
  Future<String?> _tryExecutable(String candidate) async {
    try {
      final result = await Process.run(
        candidate,
        const ['--version'],
        environment: _environment.processEnvironment,
        includeParentEnvironment: false,
      );
      if (result.exitCode == 0) {
        return _extractVersion(result.stdout);
      }
    } on ProcessException {
      // 文件不存在或无法执行，继续尝试下一个
    }
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
          final version = _extractVersion(result.stdout);
          await _environment.setCustomFvmExecutable(candidate);
          await _environment.setCachedFvmExecutable(candidate);
          _executable = candidate;
          return version ?? "";
        }
        failure = _decodeOutput(result.stderr);
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

  /// 从 `fvm --version` 的输出中提取纯版本号。
  ///
  /// fvm 在 stdout 中除了版本号，还可能夹杂多种提示：
  /// - `FVM Legacy environment variables detected: ...` 警告（fvm 4.x 在检测
  ///   到遗留 `FVM_HOME` 时通过 `logger.important()` 写到 stdout，且 ANSI 边框
  ///   + 图标会占据多行）；
  /// - `· Consider using FVM_CACHE_PATH` 等跟随提示；
  /// - 在 Windows 中文系统下，`·` (U+00B7) 还会因 GBK 解码出现乱码。
  ///
  /// 解析策略：
  /// 1. 优先匹配 `^\d+(\.\d+){0,3}([-+][\w.-]+)?$` 这样的版本号行；
  /// 2. 找不到再回退到首条非空、非警告/装饰行的内容。
  ///
  /// `result.stdout` 在 `Process.run` 中类型为 `dynamic`：桌面平台返回
  /// 已解码的 `String`、Web 平台返回 `String`、部分场景下也可能是 `List<int>`。
  /// 为兼容两种类型，按运行时实际类型分支处理。
  String? _extractVersion(Object? stdout) {
    final raw = _decodeOutput(stdout);
    if (raw.trim().isEmpty) return null;

    final lines = raw.split(RegExp(r'\r?\n'));

    // 1) 优先匹配形如 "3.2.1"、"3.2.1-1.0.pre" 的纯版本号行
    final versionRegex = RegExp(r'^\d+(?:\.\d+){0,3}(?:[-+][\w.\-]+)?$');
    for (final line in lines) {
      final stripped = _stripAnsi(line).trim();
      if (versionRegex.hasMatch(stripped)) return stripped;
    }

    // 2) 回退：找第一条既非空、又不像 fvm 警告/装饰框的内容
    final isNoise = RegExp(
      r'(legacy\s+environment|consider\s+using|deprecated|warning|notice|'
      r'^[│╭╰├┤┌└─]+$)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final stripped = _stripAnsi(line).trim();
      if (stripped.isEmpty) continue;
      if (isNoise.hasMatch(stripped)) continue;
      return stripped;
    }

    // 3) 实在找不到版本号，至少返回首行非空内容（不再让用户看到装饰框）
    return lines
        .map((line) => _stripAnsi(line).trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  /// 去掉 ANSI 控制序列（含颜色码与 fvm 用的方框字符中的 ESC 序列）。
  String _stripAnsi(String input) {
    return input.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
  }

  /// 兼容 `String`（已解码）和 `List<int>`（原始字节）两种 stdout 形式，
  /// 返回解码后的字符串。后者用 UTF-8 解码以避免 Windows 中文系统下 GBK 乱码。
  String _decodeOutput(Object? output) {
    if (output == null) return '';
    if (output is String) return output;
    if (output is List<int>) {
      return utf8.decode(output, allowMalformed: true);
    }
    return output.toString();
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

  Future<int> cacheSizeBytes() async {
    var total = 0;
    for (final directory in await _installedFlutterCacheDirectories()) {
      total += await _entitySize(directory);
    }
    return total;
  }

  Future<int> clearInstalledFlutterCache() async {
    var removedBytes = 0;
    for (final directory in await _installedFlutterCacheDirectories()) {
      removedBytes += await _entitySize(directory);
      await directory.delete(recursive: true);
    }
    return removedBytes;
  }

  Future<List<Directory>> _installedFlutterCacheDirectories() async {
    final directories = <Directory>[];
    for (final sdk in await listInstalled()) {
      if (sdk.directory.isEmpty) continue;
      final cache = Directory(
        '${sdk.directory}${Platform.pathSeparator}bin${Platform.pathSeparator}cache',
      );
      if (await cache.exists()) directories.add(cache);
    }
    return directories;
  }

  Future<int> _entitySize(FileSystemEntity entity) async {
    final stat = await entity.stat();
    if (stat.type == FileSystemEntityType.file) return stat.size;
    if (stat.type != FileSystemEntityType.directory) return 0;

    var total = 0;
    await for (final child in Directory(entity.path).list(followLinks: false)) {
      total += await _entitySize(child);
    }
    return total;
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
    final executableName = Platform.isWindows ? 'fvm.bat' : 'fvm';
    final separator = Platform.pathSeparator;
    final all = <String>[];

    // 1. 用户手动指定的 FVM 可执行文件（最高优先级）
    if (_environment.customFvmExecutable case final custom?) {
      all.add(custom);
    }

    // 2. 从 executableSearchPaths 构建（包含系统 PATH、Pub Cache bin 等）
    for (final directory in _environment.executableSearchPaths) {
      all.add('$directory$separator$executableName');
    }

    // 3. 平台特定的 FVM 常见安装路径（补充兜底，可能与上面重复，下方去重）
    for (final directory in _wellKnownFvmDirectories()) {
      all.add('$directory$separator$executableName');
    }

    // 去重后按优先级顺序 yield（Windows 路径不区分大小写）
    final seen = <String>{};
    for (final candidate in all) {
      final key = Platform.isWindows ? candidate.toLowerCase() : candidate;
      if (seen.add(key)) yield candidate;
    }
  }

  /// 返回当前平台下 FVM 的常见安装目录（区分 Windows / macOS）。
  ///
  /// - **Windows**: Pub Cache 位于 `%LOCALAPPDATA%\Pub\Cache`（或
  ///   `%USERPROFILE%\AppData\Local\Pub\Cache`），即
  ///   `C:\Users\<用户名>\AppData\Local\Pub\Cache\bin`；
  ///   FVM 全局目录位于 `%USERPROFILE%\fvm\default\bin`。
  /// - **macOS**: Pub Cache 位于 `~/.pub-cache/bin`；
  ///   FVM 全局目录位于 `~/fvm/default/bin`、`~/.fvm/default/bin`；
  ///   Homebrew 路径 `/opt/homebrew/bin`、`/usr/local/bin`。
  List<String> _wellKnownFvmDirectories() {
    final separator = Platform.pathSeparator;
    final paths = <String>[];

    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      // Pub Cache bin（dart pub global activate fvm 的默认安装位置）
      // 优先级: PUB_CACHE > LOCALAPPDATA\Pub\Cache > USERPROFILE\AppData\Local\Pub\Cache
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (localAppData != null ? '$localAppData\\Pub\\Cache' : null) ??
          (home != null ? '$home\\AppData\\Local\\Pub\\Cache' : null);
      if (pubCache != null) paths.add('$pubCache${separator}bin');
      // FVM 全局 Flutter 符号链接目录
      if (home != null) {
        paths.add('$home\\fvm\\default\\bin');
        paths.add('$home\\.fvm\\default\\bin');
      }
    } else {
      // macOS / Linux
      final home = Platform.environment['HOME'];
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (home != null ? '$home/.pub-cache' : null);
      if (pubCache != null) paths.add('$pubCache${separator}bin');
      if (home != null) {
        paths.add('$home/fvm/default/bin');
        paths.add('$home/.fvm/default/bin');
      }
      if (Platform.isMacOS) {
        paths.add('/opt/homebrew/bin');
        paths.add('/usr/local/bin');
      }
    }

    return paths;
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
