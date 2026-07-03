import 'dart:convert';
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
  bool _autoOpenConsoleWindow = true;
  bool _showMainWindowConsole = false;
  bool _showConsoleQuickCommands = true;
  bool _buildOpensConsoleWindow = false;
  String _globalPgyerApiKey = '';
  String _globalFirApiToken = '';

  String get mirrorId => _mirrorId;
  bool get useDomesticMirror => _mirrorId != 'official';
  MirrorOption get currentMirror =>
      mirrors.firstWhere((m) => m.id == _mirrorId, orElse: () => mirrors.first);
  String? get ignoredFvmVersion => _ignoredFvmVersion;
  String? get ignoredFlutterVersion => _ignoredFlutterVersion;
  String? get customFvmExecutable => _customFvmExecutable;
  bool get autoOpenConsoleWindow => _autoOpenConsoleWindow;
  bool get showMainWindowConsole => _showMainWindowConsole;
  bool get showConsoleQuickCommands => _showConsoleQuickCommands;
  bool get buildOpensConsoleWindow => _buildOpensConsoleWindow;
  String get globalPgyerApiKey => _globalPgyerApiKey;
  String get globalFirApiToken => _globalFirApiToken;

  String get flutterStorageBaseUrl {
    final mirror = currentMirror;
    return mirror.storageUrl ?? 'https://storage.googleapis.com';
  }

  Map<String, String> get processEnvironment {
    final environment = Map<String, String>.from(Platform.environment);
    environment['PATH'] = executableSearchPaths.join(
      Platform.isWindows ? ';' : ':',
    );
    final mirror = currentMirror;
    if (mirror.pubUrl != null) {
      environment['PUB_HOSTED_URL'] = mirror.pubUrl!;
    } else {
      environment.remove('PUB_HOSTED_URL');
    }
    if (mirror.storageUrl != null) {
      environment['FLUTTER_STORAGE_BASE_URL'] = mirror.storageUrl!;
    } else {
      environment.remove('FLUTTER_STORAGE_BASE_URL');
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
        add('$home\\fvm\\default\\bin');
        add('$home\\.fvm\\default\\bin');
      } else {
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
    if (!await file.exists()) return;
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
      _autoOpenConsoleWindow =
          settings['autoOpenConsoleWindow'] as bool? ?? true;
      _showMainWindowConsole =
          settings['showMainWindowConsole'] as bool? ?? false;
      _showConsoleQuickCommands =
          settings['showConsoleQuickCommands'] as bool? ?? true;
      _buildOpensConsoleWindow =
          settings['buildOpensConsoleWindow'] as bool? ?? false;
      _globalPgyerApiKey =
          settings['globalPgyerApiKey'] as String? ?? '';
      _globalFirApiToken =
          settings['globalFirApiToken'] as String? ?? '';
    } on Object {
      _mirrorId = 'official';
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

  Future<void> setGlobalPgyerApiKey(String apiKey) async {
    _globalPgyerApiKey = apiKey;
    await _persist();
  }

  Future<void> setGlobalFirApiToken(String apiToken) async {
    _globalFirApiToken = apiToken;
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
        'autoOpenConsoleWindow': _autoOpenConsoleWindow,
        'showMainWindowConsole': _showMainWindowConsole,
        'showConsoleQuickCommands': _showConsoleQuickCommands,
        'buildOpensConsoleWindow': _buildOpensConsoleWindow,
        'globalPgyerApiKey': _globalPgyerApiKey,
        'globalFirApiToken': _globalFirApiToken,
      }),
      flush: true,
    );
  }

  String rewriteStorageUrl(String url) {
    final mirror = currentMirror;
    if (mirror.storageUrl == null) return url;
    return url.replaceFirst(
      'https://storage.googleapis.com',
      mirror.storageUrl!,
    );
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
