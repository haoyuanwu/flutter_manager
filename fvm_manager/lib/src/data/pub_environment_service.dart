import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

class MirrorOption {
  const MirrorOption({
    required this.id,
    required this.name,
    this.pubUrl,
    this.storageUrl,
  });
  final String id;
  final String name;
  final String? pubUrl;
  final String? storageUrl;
}

class PubEnvironmentService {
  PubEnvironmentService({File? settingsFile})
    : _customSettingsFile = settingsFile;

  final File? _customSettingsFile;

  // 缓存从 source 获取的 PATH
  String? _cachedPath;

  static const mirrors = [
    MirrorOption(id: 'official', name: '官方默认'),
    MirrorOption(
      id: 'flutter-io',
      name: 'Flutter CN',
      pubUrl: 'https://pub.flutter-io.cn',
      storageUrl: 'https://storage.flutter-io.cn',
    ),
    MirrorOption(
      id: 'tuna',
      name: '清华 TUNA',
      pubUrl: 'https://pub.tuna.tsinghua.edu.cn',
      storageUrl: 'https://mirrors.tuna.tsinghua.edu.cn/flutter',
    ),
    MirrorOption(
      id: 'sjtug',
      name: '上海交大 SJTUG',
      pubUrl: 'https://mirror.sjtug.sjtu.edu.cn',
      storageUrl: 'https://mirror.sjtug.sjtu.edu.cn',
    ),
    MirrorOption(
      id: 'nju',
      name: '南京大学 NJU',
      pubUrl: 'https://mirrors.nju.edu.cn/dart-pub',
      storageUrl: 'https://mirrors.nju.edu.cn/flutter',
    ),
  ];

  String _mirrorId = 'official';
  String? _ignoredFvmVersion;
  String? _ignoredFlutterVersion;
  String? _customFvmExecutable;
  String? _cachedFvmExecutable;
  bool _autoOpenConsoleWindow = true;
  bool _showMainWindowConsole = false;
  bool _showConsoleQuickCommands = true;
  bool _buildOpensConsoleWindow = false;
  bool _mcpServerEnabled = false;
  int _mcpServerPort = 17891;
  String _mcpServerToken = '';
  String _globalPgyerApiKey = '';
  String _globalFirApiToken = '';
  String _innoCompilerPath = '';

  String get mirrorId => _mirrorId;
  bool get useDomesticMirror => _mirrorId != 'official';
  MirrorOption get currentMirror =>
      mirrors.firstWhere((m) => m.id == _mirrorId, orElse: () => mirrors.first);
  String? get ignoredFvmVersion => _ignoredFvmVersion;
  String? get ignoredFlutterVersion => _ignoredFlutterVersion;
  String? get customFvmExecutable => _customFvmExecutable;
  String? get cachedFvmExecutable => _cachedFvmExecutable;
  bool get autoOpenConsoleWindow => _autoOpenConsoleWindow;
  bool get showMainWindowConsole => _showMainWindowConsole;
  bool get showConsoleQuickCommands => _showConsoleQuickCommands;
  bool get buildOpensConsoleWindow => _buildOpensConsoleWindow;
  bool get mcpServerEnabled => _mcpServerEnabled;
  int get mcpServerPort => _mcpServerPort;
  String get mcpServerToken => _mcpServerToken;
  String get globalPgyerApiKey => _globalPgyerApiKey;
  String get globalFirApiToken => _globalFirApiToken;
  String get innoCompilerPath => _innoCompilerPath;

  String get flutterStorageBaseUrl {
    final mirror = currentMirror;
    return mirror.storageUrl ?? 'https://storage.googleapis.com';
  }

  Map<String, String> get processEnvironment {
    final environment = Map<String, String>.from(Platform.environment);
    // 优先使用缓存的 PATH（从 source 获取的）
    environment['PATH'] =
        _cachedPath ??
        executableSearchPaths.join(Platform.isWindows ? ';' : ':');
    final mirror = currentMirror;
    if (mirror.pubUrl != null) {
      environment['PUB_HOSTED_URL'] = mirror.pubUrl!;
    }
    if (mirror.storageUrl != null) {
      environment['FLUTTER_STORAGE_BASE_URL'] = mirror.storageUrl!;
    }
    return environment;
  }

  /// 为从 Finder 启动的 GUI 应用补齐常见命令行工具目录。
  ///
  /// Finder 不会读取用户 shell 的启动文件，因此它提供的 PATH 通常不含
  /// Homebrew、Pub Cache，以及 FVM 全局 Flutter 中的 Dart。
  List<String> get executableSearchPaths {
    final separator = Platform.isWindows ? ';' : ':';
    final paths = <String>{};
    void add(String? path) {
      if (path != null && path.trim().isNotEmpty) paths.add(path.trim());
    }

    if (_customFvmExecutable != null) {
      add(File(_customFvmExecutable!).parent.path);
    }
    for (final path in (Platform.environment['PATH'] ?? '').split(separator)) {
      add(path);
    }
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final pubCache =
        Platform.environment['PUB_CACHE'] ??
        (home == null
            ? null
            : Platform.isWindows
            ? '$home\\AppData\\Local\\Pub\\Cache'
            : '$home/.pub-cache');
    if (pubCache != null) add('$pubCache${Platform.pathSeparator}bin');

    if (home != null) {
      if (Platform.isWindows) {
        add('$home\\fvm\\bin');
        add('$home\\fvm\\default\\bin');
        add('$home\\.fvm\\default\\bin');
      } else {
        add('$home/fvm/bin');
        add('$home/fvm/default/bin');
        add('$home/.fvm/default/bin');
      }
    }
    if (Platform.isMacOS) {
      add('/opt/homebrew/bin');
      add('/opt/homebrew/sbin');
      add('/usr/local/bin');
      add('/usr/local/sbin');
    }
    return paths.toList(growable: false);
  }

  Future<void> load() async {
    final file = _settingsFile;
    if (!await file.exists()) {
      _mcpServerToken = _generateToken();
      await _persist();
      return;
    }
    try {
      final data = jsonDecode(await file.readAsString());
      final settings = (data as Map).cast<String, dynamic>();
      // 兼容旧版 bool 字段
      final legacyDomestic = settings['useDomesticMirror'] as bool?;
      final storedId = settings['mirrorId'] as String?;
      if (storedId != null) {
        _mirrorId = storedId;
      } else if (legacyDomestic == true) {
        _mirrorId = 'flutter-io';
      } else {
        _mirrorId = 'official';
      }
      _ignoredFvmVersion = settings['ignoredFvmVersion'] as String?;
      _ignoredFlutterVersion = settings['ignoredFlutterVersion'] as String?;
      _customFvmExecutable = settings['customFvmExecutable'] as String?;
      _cachedFvmExecutable = settings['cachedFvmExecutable'] as String?;
      _autoOpenConsoleWindow =
          settings['autoOpenConsoleWindow'] as bool? ?? true;
      _showMainWindowConsole =
          settings['showMainWindowConsole'] as bool? ?? false;
      _showConsoleQuickCommands =
          settings['showConsoleQuickCommands'] as bool? ?? true;
      _buildOpensConsoleWindow =
          settings['buildOpensConsoleWindow'] as bool? ?? false;
      _mcpServerEnabled = settings['mcpServerEnabled'] as bool? ?? false;
      _mcpServerPort = settings['mcpServerPort'] as int? ?? 17891;
      _mcpServerToken = settings['mcpServerToken'] as String? ?? '';
      _globalPgyerApiKey = settings['globalPgyerApiKey'] as String? ?? '';
      _globalFirApiToken = settings['globalFirApiToken'] as String? ?? '';
      _innoCompilerPath = settings['innoCompilerPath'] as String? ?? '';
    } on Object {
      _mirrorId = 'official';
    }
    if (_mcpServerToken.isEmpty) {
      _mcpServerToken = _generateToken();
      await _persist();
    }

    // 加载时执行 source 获取最新的环境变量
    await _sourceShellProfile();
  }

  /// 执行 shell 配置文件的 source 命令，获取最新的环境变量。
  Future<void> _sourceShellProfile() async {
    if (!Platform.isMacOS && !Platform.isLinux) return;

    final home = Platform.environment['HOME'];
    if (home == null) return;

    final shell = Platform.environment['SHELL'] ?? '';
    final configFile = shell.contains('zsh')
        ? '$home/.zshrc'
        : '$home/.bash_profile';

    final file = File(configFile);
    if (await file.exists()) {
      await _sourceConfig(configFile);
    }
  }

  Future<void> setMirror(String mirrorId) async {
    final mirror = mirrors.firstWhere(
      (m) => m.id == mirrorId,
      orElse: () => mirrors.first,
    );
    await _updateSystemEnvironment(mirror);
    _mirrorId = mirrorId;
    await _persist();
  }

  /// 兼容旧接口
  Future<void> setDomesticMirror(bool enabled) =>
      setMirror(enabled ? 'flutter-io' : 'official');

  Future<void> ignoreFvmVersion(String version) async {
    _ignoredFvmVersion = version;
    await _persist();
  }

  Future<void> ignoreFlutterVersion(String version) async {
    _ignoredFlutterVersion = version;
    await _persist();
  }

  Future<void> setCustomFvmExecutable(String executable) async {
    _customFvmExecutable = executable;
    await _persist();
  }

  Future<void> setCachedFvmExecutable(String? executable) async {
    _cachedFvmExecutable = executable;
    await _persist();
  }

  Future<void> setAutoOpenConsoleWindow(bool enabled) async {
    _autoOpenConsoleWindow = enabled;
    await _persist();
  }

  Future<void> setShowMainWindowConsole(bool enabled) async {
    _showMainWindowConsole = enabled;
    await _persist();
  }

  Future<void> setShowConsoleQuickCommands(bool enabled) async {
    _showConsoleQuickCommands = enabled;
    await _persist();
  }

  Future<void> setBuildOpensConsoleWindow(bool enabled) async {
    _buildOpensConsoleWindow = enabled;
    await _persist();
  }

  Future<void> setMcpServerEnabled(bool enabled) async {
    _mcpServerEnabled = enabled;
    await _persist();
  }

  Future<void> setMcpServerPort(int port) async {
    _mcpServerPort = port;
    await _persist();
  }

  Future<void> resetMcpServerToken() async {
    _mcpServerToken = _generateToken();
    await _persist();
  }

  Future<void> setGlobalPgyerApiKey(String apiKey) async {
    _globalPgyerApiKey = apiKey;
    await _persist();
  }

  Future<void> setGlobalFirApiToken(String apiToken) async {
    _globalFirApiToken = apiToken;
    await _persist();
  }

  Future<void> setInnoCompilerPath(String path) async {
    _innoCompilerPath = path.trim();
    await _persist();
  }

  /// 测试镜像源连通性，返回延迟毫秒数，失败返回 -1。
  Future<int> testMirror(String mirrorId) async {
    final mirror = mirrors.firstWhere(
      (m) => m.id == mirrorId,
      orElse: () => mirrors.first,
    );
    final url = mirror.pubUrl ?? 'https://pub.dev';
    try {
      final stopwatch = Stopwatch()..start();
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain<void>();
      stopwatch.stop();
      client.close();
      return response.statusCode == 200 ||
              response.statusCode == 301 ||
              response.statusCode == 302
          ? stopwatch.elapsedMilliseconds
          : -1;
    } on Object {
      return -1;
    }
  }

  Future<void> _persist() async {
    final file = _settingsFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'mirrorId': _mirrorId,
        'useDomesticMirror': useDomesticMirror, // 兼容旧版
        'ignoredFvmVersion': _ignoredFvmVersion,
        'ignoredFlutterVersion': _ignoredFlutterVersion,
        'customFvmExecutable': _customFvmExecutable,
        'cachedFvmExecutable': _cachedFvmExecutable,
        'autoOpenConsoleWindow': _autoOpenConsoleWindow,
        'showMainWindowConsole': _showMainWindowConsole,
        'showConsoleQuickCommands': _showConsoleQuickCommands,
        'buildOpensConsoleWindow': _buildOpensConsoleWindow,
        'mcpServerEnabled': _mcpServerEnabled,
        'mcpServerPort': _mcpServerPort,
        'mcpServerToken': _mcpServerToken,
        'globalPgyerApiKey': _globalPgyerApiKey,
        'globalFirApiToken': _globalFirApiToken,
        'innoCompilerPath': _innoCompilerPath,
      }),
      flush: true,
    );
  }

  String _generateToken() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String rewriteStorageUrl(String url) {
    final mirror = currentMirror;
    if (mirror.storageUrl == null) return url;
    return url.replaceFirst(
      'https://storage.googleapis.com',
      mirror.storageUrl!,
    );
  }

  /// 获取当前系统 PATH 环境变量的路径列表。
  ///
  /// 优先从 shell 配置文件（~/.zshrc、~/.bash_profile 等）中解析，
  /// 如果解析失败则使用 launchctl（macOS）或注册表（Windows）获取。
  Future<List<String>> getSystemPath() async {
    if (Platform.isMacOS || Platform.isLinux) {
      // 尝试从 shell 配置文件中解析 PATH
      final paths = await _parsePathFromShellProfile();
      if (paths.isNotEmpty) return paths;

      // 回退到 launchctl
      if (Platform.isMacOS) {
        final result = await Process.run('launchctl', ['getenv', 'PATH']);
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) {
          return path.split(':').where((p) => p.isNotEmpty).toList();
        }
      }

      // 回退到进程环境变量
      return (Platform.environment['PATH'] ?? '')
          .split(':')
          .where((p) => p.isNotEmpty)
          .toList();
    }

    if (Platform.isWindows) {
      final result = await Process.run('reg', [
        'query',
        r'HKCU\Environment',
        '/v',
        'Path',
      ], runInShell: true);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('Path')) {
            final parts = line.trim().split(RegExp(r'\s{2,}'));
            if (parts.length >= 3) {
              return parts
                  .sublist(2)
                  .join('  ')
                  .trim()
                  .split(';')
                  .where((p) => p.isNotEmpty)
                  .toList();
            }
          }
        }
      }
      // 回退到进程环境变量
      return (Platform.environment['PATH'] ?? '')
          .split(';')
          .where((p) => p.isNotEmpty)
          .toList();
    }

    return [];
  }

  /// 从 shell 配置文件中解析 PATH 设置。
  Future<List<String>> _parsePathFromShellProfile() async {
    final home = Platform.environment['HOME'];
    if (home == null) return [];

    // 按优先级检查常见的 shell 配置文件
    final configFiles = [
      '$home/.zshrc',
      '$home/.zshenv',
      '$home/.bash_profile',
      '$home/.bashrc',
      '$home/.profile',
    ];

    for (final configPath in configFiles) {
      final file = File(configPath);
      if (!await file.exists()) continue;

      try {
        final content = await file.readAsString();
        final paths = _extractPathsFromShellContent(content);
        if (paths.isNotEmpty) return paths;
      } catch (_) {
        // 忽略读取错误，继续尝试下一个文件
      }
    }

    return [];
  }

  /// 从 shell 配置文件内容中提取 PATH 相关的路径。
  List<String> _extractPathsFromShellContent(String content) {
    final paths = <String>[];
    final home = Platform.environment['HOME'] ?? '';

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      // 跳过注释
      if (trimmed.startsWith('#')) continue;

      // 匹配 export PATH="..." 或 PATH="..." 格式
      final pathMatch = RegExp(
        r'''(?:export\s+)?PATH\s*=\s*["']?([^"'\n]+)["']?''',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (pathMatch != null) {
        var pathValue = pathMatch.group(1) ?? '';
        // 展开 $HOME 和 ~
        pathValue = pathValue
            .replaceAll('\$HOME', home)
            .replaceAll('~', home)
            .replaceAll('\$PATH', '')
            .replaceAll(':\$PATH', '')
            .replaceAll('\$PATH:', '');

        // 分割并过滤空路径
        final segments = pathValue
            .split(':')
            .where((p) => p.trim().isNotEmpty)
            .map((p) => p.trim())
            .toList();

        paths.addAll(segments);
      }
    }

    return paths;
  }

  /// 将指定的 Flutter bin 目录设置到系统 PATH 环境变量。
  ///
  /// [fvmCachePath] FVM 缓存路径，如 /Users/why/fvm
  /// [flutterBinPath] Flutter bin 目录的完整路径或相对于 FVM 缓存的路径
  /// [type] 设置类型：'default'、'version'、'custom'
  ///
  /// macOS 写入 ~/.zshrc 并执行 source，Windows 使用 setx。
  Future<void> setSystemFlutterPath({
    required String fvmCachePath,
    required String flutterBinPath,
    required String type,
  }) async {
    if (Platform.isMacOS || Platform.isLinux) {
      final configFile = await _writeToShellProfile(
        fvmCachePath: fvmCachePath,
        flutterBinPath: flutterBinPath,
        type: type,
      );

      // 执行 source 让配置立即生效
      if (configFile != null) {
        await _sourceConfig(configFile);
      }
      return;
    }

    if (Platform.isWindows) {
      // Windows 使用 setx 设置用户环境变量
      final result = await Process.run('reg', [
        'query',
        r'HKCU\Environment',
        '/v',
        'Path',
      ], runInShell: true);
      String currentPath = '';
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.trim().startsWith('Path')) {
            final parts = line.trim().split(RegExp(r'\s{2,}'));
            if (parts.length >= 3) {
              currentPath = parts.sublist(2).join('  ').trim();
            }
          }
        }
      }

      final separator = ';';
      final paths = currentPath
          .split(separator)
          .where((p) => p.isNotEmpty)
          .toList();

      // 移除旧的 FVM/Flutter 相关路径
      paths.removeWhere(
        (p) =>
            p.contains('fvm') ||
            p.contains('FVM') ||
            (p.contains('flutter') && !p.contains('pub')),
      );

      // 添加新路径
      paths.insert(0, flutterBinPath);
      final newPath = paths.join(separator);
      final setResult = await Process.run('setx', [
        'Path',
        newPath,
      ], runInShell: true);
      if (setResult.exitCode != 0) {
        throw Exception('设置系统 PATH 失败：${setResult.stderr}');
      }
    }
  }

  /// 执行 source 命令让配置文件立即生效。
  Future<void> _sourceConfig(String configFile) async {
    try {
      // 使用 bash -c source 来执行，这样可以获取新的环境变量
      final result = await Process.run('bash', [
        '-c',
        'source "$configFile" && env',
      ]).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        // 解析新的环境变量
        final env = result.stdout.toString();
        for (final line in env.split('\n')) {
          if (line.startsWith('PATH=')) {
            final newPath = line.substring(5);
            // 更新缓存的 PATH
            _cachedPath = newPath;
            // 更新 launchctl 环境变量（影响新打开的终端和应用）
            if (Platform.isMacOS) {
              await Process.run('launchctl', [
                'setenv',
                'PATH',
                newPath,
              ]).timeout(const Duration(seconds: 1));
            }
            break;
          }
        }
      }
    } catch (_) {
      // source 失败不影响主流程
    }
  }

  /// 将 Flutter 配置写入 shell 配置文件（~/.zshrc 或 ~/.bash_profile）。
  ///
  /// 返回写入的配置文件路径。
  Future<String?> _writeToShellProfile({
    required String fvmCachePath,
    required String flutterBinPath,
    required String type,
  }) async {
    final home = Platform.environment['HOME'];
    if (home == null) return null;

    final shell = Platform.environment['SHELL'] ?? '';
    final configFile = shell.contains('zsh')
        ? '$home/.zshrc'
        : '$home/.bash_profile';

    final file = File(configFile);
    if (!await file.exists()) {
      // 如果文件不存在，创建新文件
      await file.writeAsString(
        _buildNewConfigContent(
          fvmCachePath: fvmCachePath,
          flutterBinPath: flutterBinPath,
          type: type,
        ),
      );
      return configFile;
    }

    var content = await file.readAsString();

    // 删除所有旧的 FVM/Flutter 相关配置
    content = _removeOldFlutterConfig(content);

    // 构建新的配置
    final newConfig = _buildNewConfigContent(
      fvmCachePath: fvmCachePath,
      flutterBinPath: flutterBinPath,
      type: type,
    );

    // 追加新配置（保留原有内容）
    await file.writeAsString('${content.trimRight()}\n\n$newConfig');

    return configFile;
  }

  /// 删除内容中所有旧的 FVM/Flutter 相关配置。
  String _removeOldFlutterConfig(String content) {
    final lines = content.split('\n');
    final filteredLines = <String>[];
    var skipNextEmpty = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // 检测是否是需要删除的行
      final shouldRemove = _isFlutterConfigLine(trimmed);

      if (shouldRemove) {
        skipNextEmpty = true;
        continue;
      }

      // 删除配置块后的空行
      if (skipNextEmpty && trimmed.isEmpty) {
        skipNextEmpty = false;
        continue;
      }

      skipNextEmpty = false;
      filteredLines.add(line);
    }

    return filteredLines.join('\n');
  }

  /// 判断是否是需要删除的 FVM/Flutter 配置行。
  bool _isFlutterConfigLine(String line) {
    final lower = line.toLowerCase().trim();

    // 匹配 Flutter Manager 添加的注释
    if (lower.startsWith('#') && lower.contains('flutter manager')) {
      return true;
    }

    // 跳过其他注释
    if (lower.startsWith('#')) return false;

    // 匹配 FVM_CACHE_PATH 变量定义
    if (RegExp(r'^export\s+FVM_CACHE_PATH\s*=').hasMatch(line)) {
      return true;
    }

    // 匹配包含 fvm/flutter 的 PATH 配置
    if (RegExp(r'^export\s+PATH\s*=', caseSensitive: false).hasMatch(line) ||
        RegExp(r'^PATH\s*=', caseSensitive: false).hasMatch(line)) {
      // 检查是否包含 fvm 路径
      if (lower.contains('fvm')) {
        return true;
      }
      // 检查是否包含 flutter 路径（排除 pub-cache）
      // 匹配模式：/flutter、/flutter/bin、flutter_sdk 等
      if (RegExp(r'[/\\]flutter([/\\]bin)?[:"]').hasMatch(lower) ||
          RegExp(r'flutter[_-]?sdk').hasMatch(lower) ||
          (lower.contains('flutter') &&
              !lower.contains('pub-cache') &&
              !lower.contains('pub_cache'))) {
        return true;
      }
    }

    return false;
  }

  /// 构建新的配置内容。
  String _buildNewConfigContent({
    required String fvmCachePath,
    required String flutterBinPath,
    required String type,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final timeStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 添加注释头
    buffer.writeln('# Flutter Manager 添加 ($timeStr)');

    // FVM 缓存路径变量
    buffer.writeln('export FVM_CACHE_PATH="$fvmCachePath"');

    // 根据类型设置 PATH
    switch (type) {
      case 'default':
        buffer.writeln(
          'export PATH="\$FVM_CACHE_PATH/default/bin:\$HOME/.pub-cache/bin:\$PATH"',
        );
        break;
      case 'version':
        // flutterBinPath 是版本号
        buffer.writeln(
          'export PATH="\$FVM_CACHE_PATH/$flutterBinPath/bin:\$HOME/.pub-cache/bin:\$PATH"',
        );
        break;
      case 'custom':
        // flutterBinPath 是自定义路径
        buffer.writeln(
          'export PATH="$flutterBinPath:\$HOME/.pub-cache/bin:\$PATH"',
        );
        break;
    }

    return buffer.toString();
  }

  Future<void> _updateSystemEnvironment(MirrorOption mirror) async {
    if (Platform.isMacOS) {
      for (final entry in {
        'PUB_HOSTED_URL': mirror.pubUrl,
        'FLUTTER_STORAGE_BASE_URL': mirror.storageUrl,
      }.entries) {
        if (entry.value != null) {
          final result = await Process.run('launchctl', [
            'setenv',
            entry.key,
            entry.value!,
          ]);
          if (result.exitCode != 0) {
            throw Exception('更新 ${entry.key} 失败：${result.stderr}');
          }
        } else {
          await Process.run('launchctl', ['unsetenv', entry.key]);
        }
      }
      return;
    }

    if (Platform.isWindows) {
      for (final entry in {
        'PUB_HOSTED_URL': mirror.pubUrl,
        'FLUTTER_STORAGE_BASE_URL': mirror.storageUrl,
      }.entries) {
        if (entry.value != null) {
          final result = await Process.run('setx', [
            entry.key,
            entry.value!,
          ], runInShell: true);
          if (result.exitCode != 0) {
            throw Exception('更新 ${entry.key} 失败：${result.stderr}');
          }
        } else {
          await Process.run('reg', [
            'delete',
            r'HKCU\Environment',
            '/v',
            entry.key,
            '/f',
          ], runInShell: true);
        }
      }
    }
  }

  File get _settingsFile {
    if (_customSettingsFile case final file?) return file;
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null) throw Exception('无法确定用户目录');
    return File(
      '$home${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}settings.json',
    );
  }
}
