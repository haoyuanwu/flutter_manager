import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'pub_environment_service.dart';

class FvmService {
  FvmService(this._environment, {this.onProgress});

  final PubEnvironmentService _environment;

  /// 修复/安装过程中的进度回调（可选）。
  final void Function(String message)? onProgress;
  String? _executable;

  /// 当前已解析到的 FVM 可执行文件完整路径（detect/useLocalDirectory 成功后可用）。
  String? get executablePath => _executable;

  String? _env(String name) {
    if (!Platform.isWindows) return Platform.environment[name];
    final lower = name.toLowerCase();
    for (final entry in Platform.environment.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  Future<String?> detect({bool allowRepair = true}) async {
    // 0. 用户手动指定的路径优先：重装后首次选择必须立刻生效，不能被
    //    缓存探测失败清掉。
    final custom = _environment.customFvmExecutable;
    if (custom != null && await File(custom).exists()) {
      final version = await _tryExecutable(custom);
      if (version != null) {
        _executable = custom;
        await _environment.setCachedFvmExecutable(custom);
        return version;
      }
    }

    // 1. 优先验证上一次检测到的路径（持久化缓存），命中则跳过全量扫描
    final cached = _environment.cachedFvmExecutable;
    if (cached != null) {
      final version = await _tryExecutable(cached);
      if (version != null) {
        _executable = cached;
        return version;
      }
      // 仅当文件确实不存在时才丢缓存；能运行但版本解析失败时保留路径。
      if (!await File(cached).exists()) {
        await _environment.setCachedFvmExecutable(null);
      }
    }

    // 2. 全量扫描所有候选路径
    for (final candidate in _candidates()) {
      // macos
      if (Platform.isMacOS) {
        try {
          final result = await Process.run(
            candidate,
            const ['--version'],
            environment: _environment.processEnvironment,
            includeParentEnvironment: false,
          ).timeout(const Duration(seconds: 2));
          if (result.exitCode == 0) {
            _executable = candidate;
            return result.stdout.toString().trim();
          }
        } on ProcessException {
          // Try the next well-known location.
        } on TimeoutException {
          // Try the next well-known location.
        }
      } else if (Platform.isWindows) {
        final version = await _tryExecutable(candidate);
        if (version != null) {
          _executable = candidate;
          // 持久化，下次启动直接用
          await _environment.setCachedFvmExecutable(candidate);
          return version;
        }
      }
    }

    // 3. 安装包/重装后常见问题：fvm.bat 被清掉，但 Pub 里仍有 fvm 包和 dart。
    //    自动执行 dart pub global activate fvm 重建可执行文件。
    if (allowRepair && Platform.isWindows) {
      final repaired = await _repairPubGlobalFvm();
      if (repaired) return detect(allowRepair: false);
    }

    _executable = null;
    return null;
  }

  /// 尝试通过 `dart pub global activate fvm` 重建丢失的 fvm 可执行文件。
  Future<bool> _repairPubGlobalFvm() async {
    final dart = _findExecutable('dart');
    if (dart == null) return false;
    try {
      onProgress?.call('检测到 FVM 可执行文件缺失，正在通过 dart pub global 修复…');
      final result = await Process.run(
        dart,
        const ['pub', 'global', 'activate', 'fvm'],
        environment: _environment.processEnvironment,
        includeParentEnvironment: true,
        runInShell: Platform.isWindows,
      ).timeout(const Duration(seconds: 120));
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  /// Windows 上 FVM 可能以 .exe / .bat / .cmd 或无扩展名安装。
  List<String> get _fvmExecutableNames => Platform.isWindows
      ? const ['fvm.exe', 'fvm.bat', 'fvm.cmd', 'fvm']
      : const ['fvm'];

  /// 尝试运行指定路径的 FVM，成功返回版本号，失败返回 null。
  Future<String?> _tryExecutable(String candidate) async {
    for (final inherit in const [false, true]) {
      try {
        final result = await Process.run(
          candidate,
          const ['--version'],
          environment: _environment.processEnvironment,
          // 打包安装后的 GUI 环境可能缺 COMSPEC/PATHEXT/PATH；
          // 先用合并环境，失败再继承父进程作兜底。
          includeParentEnvironment: inherit,
          runInShell: Platform.isWindows,
        );
        if (result.exitCode == 0) {
          // 能跑通就视为可用。版本号解析失败时返回空串而不是 null，
          // 避免 detect() 误判失败并清掉用户刚选择的路径。
          return _extractVersion(result.stdout) ?? '';
        }
      } on ProcessException {
        // 文件不存在或无法执行，继续尝试下一个
      }
    }
    return null;
  }

  Future<({int exitCode, String output, String error})> _runVersionProbe(
    String candidate,
  ) async {
    for (final inherit in const [false, true]) {
      try {
        final result = await Process.run(
          candidate,
          const ['--version'],
          environment: _environment.processEnvironment,
          includeParentEnvironment: inherit,
          runInShell: Platform.isWindows,
        );
        if (result.exitCode == 0) {
          return (
            exitCode: result.exitCode,
            output: _decodeOutput(result.stdout),
            error: _decodeOutput(result.stderr),
          );
        }
        final output = _decodeOutput(result.stdout).trim();
        final error = _decodeOutput(result.stderr).trim();
        if (output.isNotEmpty || error.isNotEmpty) {
          return (exitCode: result.exitCode, output: output, error: error);
        }
      } on ProcessException catch (e) {
        return (exitCode: -1, output: '', error: e.message);
      }
    }
    return (exitCode: -1, output: '', error: '无法执行 $candidate');
  }

  Future<String> useLocalDirectory(String directoryPath) async {
    final separator = Platform.pathSeparator;
    final normalized = directoryPath.replaceAll(RegExp(r'[\\/]$'), '');
    final candidates = <String>[];
    // 允许直接选中可执行文件本身。
    if (File(normalized).existsSync()) {
      candidates.add(normalized);
    }
    // 常见层级：
    //   <dir>/fvm.bat          （Pub\\Cache\\bin）
    //   <dir>/bin/fvm.bat      （Pub\\Cache）
    //   <dir>/../bin/fvm.bat   （误选了 versions 等相邻目录时的兜底）
    final parent = File(normalized).parent.path;
    for (final name in _fvmExecutableNames) {
      candidates.addAll([
        '$normalized$separator$name',
        '$normalized${separator}bin$separator$name',
        '$parent${separator}bin$separator$name',
        '$parent$separator$name',
      ]);
    }
    String? failure;
    var foundAny = false;
    String? lastCandidate;
    for (final candidate in candidates) {
      if (!await File(candidate).exists()) continue;
      foundAny = true;
      lastCandidate = candidate;
      final probe = await _runVersionProbe(candidate);
      if (probe.exitCode == 0) {
        final version = _extractVersion(probe.output) ?? '';
        await _environment.setCustomFvmExecutable(candidate);
        await _environment.setCachedFvmExecutable(candidate);
        _executable = candidate;
        return version;
      }
      failure = probe.error.isNotEmpty ? probe.error : probe.output;
    }

    // 选到的是 FVM 缓存 / Flutter SDK 目录，而不是 fvm 程序本身。
    final looksLikeCache =
        Directory('$normalized${separator}versions').existsSync() ||
        Directory('$normalized${separator}default').existsSync() ||
        File('$normalized${separator}flutter.version').existsSync() ||
        File('$normalized${separator}version').existsSync();
    final names = _fvmExecutableNames.join(' / ');
    final example =
        '示例：C:\\Users\\<用户名>\\AppData\\Local\\Pub\\Cache\\bin'
        '（或其上级 Pub\\Cache，也可直接选中 fvm.bat）。'
        '不要选择 D:\\fvm 这类 Flutter SDK 缓存目录。';
    if (!foundAny && looksLikeCache) {
      throw Exception(
        '所选目录是 FVM/Flutter SDK 缓存，不是 FVM 程序目录。\n'
        '请改为选择 fvm.exe / fvm.bat 所在位置，通常是 '
        '%LOCALAPPDATA%\\Pub\\Cache\\bin。\n$example',
      );
    }
    throw Exception(
      failure?.isNotEmpty == true
          ? '所选路径中的 FVM 无法运行（$lastCandidate）：$failure\n$example'
          : foundAny
          ? '所选路径中的 FVM 无法运行，请确认 $names 可执行\n$example'
          : '所选路径中未找到 $names。\n'
                '可选择：可执行文件所在目录、其上级目录（会自动找 bin\\）、'
                '或直接选中 fvm.exe/fvm.bat。\n$example',
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
    if (dartExecutable != null) {
      await _runInstaller(
        dartExecutable,
        const ['pub', 'global', 'activate', 'fvm'],
        onOutput: onOutput,
        failureMessage: 'FVM$operation失败',
      );
    } else if (Platform.isMacOS || Platform.isLinux) {
      await _installStandalone(onOutput);
    } else if (Platform.isWindows) {
      final chocolatey = _findExecutable('choco');
      if (chocolatey == null) {
        throw Exception(
          '未检测到 Dart 或 Chocolatey，无法自动安装 FVM。'
          '请先安装 Chocolatey，或选择已安装的本地 FVM 目录。',
        );
      }
      await _runInstaller(
        chocolatey,
        const ['install', 'fvm', '-y'],
        onOutput: onOutput,
        failureMessage: 'Chocolatey 安装 FVM 失败',
      );
    } else {
      throw Exception('当前系统暂不支持自动安装 FVM');
    }

    _executable = null;
    await _environment.setCachedFvmExecutable(null);
    if (await detect() == null) {
      throw Exception('FVM 已完成$operation，但当前应用仍无法找到它。请选择 FVM 安装目录。');
    }
  }

  Future<void> _installStandalone(void Function(String) onOutput) async {
    final curl = _findExecutable('curl');
    final bash = _findExecutable('bash');
    if (curl == null || bash == null) {
      throw Exception('自动安装 FVM 需要 curl 和 bash，但当前系统未检测齐全');
    }

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'flutter-manager-fvm-',
    );
    final script = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}install.sh',
    );
    try {
      onOutput('正在下载 FVM 官方安装程序…');
      await _runInstaller(
        curl,
        ['-fsSL', 'https://fvm.app/install.sh', '-o', script.path],
        onOutput: onOutput,
        failureMessage: '下载 FVM 安装程序失败',
      );
      onOutput('正在安装 FVM…');
      await _runInstaller(
        bash,
        [script.path],
        onOutput: onOutput,
        failureMessage: 'FVM 安装失败',
      );
    } finally {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _runInstaller(
    String executable,
    List<String> arguments, {
    required void Function(String) onOutput,
    required String failureMessage,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      runInShell: Platform.isWindows,
      environment: _environment.processEnvironment,
      includeParentEnvironment: false,
    );
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    final code = await process.exitCode;
    if (code != 0) throw Exception('$failureMessage（退出码 $code）');
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

  /// Resolve without invoking Flutter itself: `flutter --version` also waits
  /// for the startup lock. Refuse unknown wrappers rather than unlock another SDK.
  Future<String> projectFlutterSdkPath(String projectPath) async {
    if (_usesFvm(projectPath) &&
        (_executable != null || await detect(allowRepair: false) != null)) {
      final config = File('$projectPath/.fvmrc');
      final legacy = File('$projectPath/.fvm/fvm_config.json');
      final data =
          jsonDecode(
                await (await config.exists() ? config : legacy).readAsString(),
              )
              as Map;
      final version = (data['flutter'] ?? data['flutterSdkVersion']) as String?;
      final sdks = await listInstalled();
      final sdk = sdks.where((sdk) => sdk.name == version).firstOrNull;
      if (sdk == null || sdk.directory.isEmpty) {
        throw Exception('无法确定项目的 FVM SDK（$version），请先检查项目版本配置');
      }
      return _validatedFlutterSdk(Directory(sdk.directory));
    }
    final executable = _findExecutable('flutter');
    if (executable == null) throw Exception('未检测到当前项目使用的 Flutter SDK');
    final resolved = await File(executable).resolveSymbolicLinks();
    return _validatedFlutterSdk(File(resolved).parent.parent);
  }

  Future<String> _validatedFlutterSdk(Directory directory) async {
    final resolved = await directory.resolveSymbolicLinks();
    if (!await File('$resolved/packages/flutter_tools/pubspec.yaml').exists()) {
      throw Exception('无法从启动脚本确定 Flutter SDK，请检查 Flutter 路径：$resolved');
    }
    return resolved;
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
      // 打包安装后优先用合并环境；失败场景由 detect 的 inherit 兜底覆盖。
      includeParentEnvironment: true,
      runInShell: Platform.isWindows,
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
    final separator = Platform.pathSeparator;
    final all = <String>[];

    // 1. 用户手动指定的 FVM 可执行文件（最高优先级）
    if (_environment.customFvmExecutable case final custom?) {
      all.add(custom);
    }

    // 2. 从 executableSearchPaths 构建（包含系统 PATH、Pub Cache bin 等）
    for (final directory in _environment.executableSearchPaths) {
      for (final name in _fvmExecutableNames) {
        all.add('$directory$separator$name');
      }
    }

    // 3. 平台特定的 FVM 常见安装路径（补充兜底，可能与上面重复，下方去重）
    for (final directory in _wellKnownFvmDirectories()) {
      for (final name in _fvmExecutableNames) {
        all.add('$directory$separator$name');
      }
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
      final home = _env('USERPROFILE');
      final localAppData = _env('LOCALAPPDATA');
      // Pub Cache bin（dart pub global activate fvm 的默认安装位置）
      // 优先级: PUB_CACHE > LOCALAPPDATA\Pub\Cache > USERPROFILE\AppData\Local\Pub\Cache
      final pubCache =
          _env('PUB_CACHE') ??
          (localAppData != null ? '$localAppData\\Pub\\Cache' : null) ??
          (home != null ? '$home\\AppData\\Local\\Pub\\Cache' : null);
      if (pubCache != null) paths.add('$pubCache${separator}bin');
      // FVM 全局 Flutter 符号链接目录
      if (home != null) {
        paths.add('$home\\fvm\\bin');
        paths.add('$home\\fvm\\default\\bin');
        paths.add('$home\\.fvm\\default\\bin');
        paths.add('$home\\AppData\\Local\\fvm\\bin');
        paths.add('$home\\scoop\\shims');
      }
      final fvmCache = _env('FVM_CACHE_PATH') ?? _env('FVM_HOME');
      if (fvmCache != null && fvmCache.trim().isNotEmpty) {
        final cache = fvmCache.trim().replaceAll(RegExp(r'[\\/]$'), '');
        paths.add('$cache${separator}bin');
        paths.add('$cache${separator}default${separator}bin');
      }
      final programData = _env('ProgramData');
      if (programData != null) paths.add('$programData\\chocolatey\\bin');
    } else {
      // macOS / Linux
      final home = _env('HOME');
      final pubCache =
          _env('PUB_CACHE') ?? (home != null ? '$home/.pub-cache' : null);
      if (pubCache != null) paths.add('$pubCache${separator}bin');
      if (home != null) {
        paths.add('$home/fvm/bin');
        paths.add('$home/fvm/default/bin');
        paths.add('$home/.fvm/default/bin');
      }
      final fvmCache = _env('FVM_CACHE_PATH') ?? _env('FVM_HOME');
      if (fvmCache != null && fvmCache.trim().isNotEmpty) {
        final cache = fvmCache.trim().replaceAll(RegExp(r'[\\/]$'), '');
        paths.add('$cache${separator}bin');
        paths.add('$cache${separator}default${separator}bin');
      }
      if (Platform.isMacOS) {
        paths.add('/opt/homebrew/bin');
        paths.add('/usr/local/bin');
      }
    }

    return paths;
  }

  String? _findExecutable(String name) {
    final executableNames = Platform.isWindows
        ? ['$name.exe', '$name.bat', '$name.cmd', name]
        : [name];
    for (final directory in _environment.executableSearchPaths) {
      for (final executableName in executableNames) {
        final candidate = '$directory${Platform.pathSeparator}$executableName';
        if (File(candidate).existsSync()) return candidate;
      }
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
