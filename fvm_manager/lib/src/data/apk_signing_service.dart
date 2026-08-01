import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'process_runner.dart';

/// Metadata extracted from a single APK.
class ApkInfo {
  const ApkInfo({
    required this.path,
    required this.name,
    this.channel = '未知',
    this.gdtChannel = '',
    this.versionName = '',
    this.versionCode = '',
    this.outputName = '',
  });

  final String path;
  final String name;
  final String channel;
  final String gdtChannel;
  final String versionName;
  final String versionCode;
  final String outputName;

  ApkInfo copyWith({String? outputName}) => ApkInfo(
    path: path,
    name: name,
    channel: channel,
    gdtChannel: gdtChannel,
    versionName: versionName,
    versionCode: versionCode,
    outputName: outputName ?? this.outputName,
  );
}

/// A signing task result.
class SignedApkInfo {
  const SignedApkInfo({
    required this.originalPath,
    required this.outputPath,
    required this.outputName,
    this.channel = '未知',
    this.gdtChannel = '',
    this.versionName = '',
    this.versionCode = '',
    this.success = true,
    this.errorMessage,
  });

  final String originalPath;
  final String outputPath;
  final String outputName;
  final String channel;
  final String gdtChannel;
  final String versionName;
  final String versionCode;
  final bool success;
  final String? errorMessage;
}

/// Persisted signing configuration.
class ApkSigningConfig {
  const ApkSigningConfig({
    this.jksPath = '',
    this.password = '',
    this.keyAlias = '',
    this.outputDirectory = '',
    this.outputNamePrefix = '',
    this.outputNameSuffix = '_signed',
    this.keyAliasHistory = const [],
    this.passwordHistory = const [],
  });

  final String jksPath;
  final String password;
  final String keyAlias;
  final String outputDirectory;
  final String outputNamePrefix;
  final String outputNameSuffix;
  final List<String> keyAliasHistory;
  final List<String> passwordHistory;

  ApkSigningConfig copyWith({
    String? jksPath,
    String? password,
    String? keyAlias,
    String? outputDirectory,
    String? outputNamePrefix,
    String? outputNameSuffix,
    List<String>? keyAliasHistory,
    List<String>? passwordHistory,
  }) => ApkSigningConfig(
    jksPath: jksPath ?? this.jksPath,
    password: password ?? this.password,
    keyAlias: keyAlias ?? this.keyAlias,
    outputDirectory: outputDirectory ?? this.outputDirectory,
    outputNamePrefix: outputNamePrefix ?? this.outputNamePrefix,
    outputNameSuffix: outputNameSuffix ?? this.outputNameSuffix,
    keyAliasHistory: keyAliasHistory ?? this.keyAliasHistory,
    passwordHistory: passwordHistory ?? this.passwordHistory,
  );

  factory ApkSigningConfig.fromMap(Map<String, dynamic> map) =>
      ApkSigningConfig(
        jksPath: map['jksPath'] as String? ?? '',
        password: map['password'] as String? ?? '',
        keyAlias: map['keyAlias'] as String? ?? '',
        outputDirectory: map['outputDirectory'] as String? ?? '',
        outputNamePrefix: map['outputNamePrefix'] as String? ?? '',
        outputNameSuffix: map['outputNameSuffix'] as String? ?? '_signed',
        keyAliasHistory:
            (map['keyAliasHistory'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        passwordHistory:
            (map['passwordHistory'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  Map<String, dynamic> toMap() => {
    'jksPath': jksPath,
    'password': password,
    'keyAlias': keyAlias,
    'outputDirectory': outputDirectory,
    'outputNamePrefix': outputNamePrefix,
    'outputNameSuffix': outputNameSuffix,
    'keyAliasHistory': keyAliasHistory,
    'passwordHistory': passwordHistory,
  };
}

class ApkSigningService {
  ApkSigningService(this._processRunner);

  final ProcessRunner _processRunner;

  String get defaultOutputDirectory {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null || home.isEmpty) return Directory.current.path;
    final desktop = Directory('$home${Platform.pathSeparator}Desktop');
    final base = desktop.existsSync() ? desktop.path : home;
    return '$base${Platform.pathSeparator}signed_apks';
  }

  File get _configFile {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null) throw Exception('无法确定用户目录');
    return File(
      '$home${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}'
      'apk_signing_config.json',
    );
  }

  // ---- Config persistence ----

  Future<ApkSigningConfig> loadConfig() async {
    final file = _configFile;
    if (!await file.exists()) return const ApkSigningConfig();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return ApkSigningConfig.fromMap(decoded);
      }
    } on Object {
      // ignore
    }
    return const ApkSigningConfig();
  }

  Future<void> saveConfig(ApkSigningConfig config) async {
    final file = _configFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toMap()), flush: true);
  }

  // ---- Android SDK tool discovery ----

  Future<String?> findAndroidSdkPath() async {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final candidates = <String?>[
      Platform.environment['ANDROID_SDK_ROOT'],
      Platform.environment['ANDROID_HOME'],
      if (home != null && Platform.isMacOS) '$home/Library/Android/sdk',
      if (home != null && Platform.isWindows)
        '$home\\AppData\\Local\\Android\\Sdk',
    ];
    for (final path in candidates) {
      if (path == null || path.trim().isEmpty) continue;
      if (Directory(path).existsSync()) return path;
    }
    return null;
  }

  /// Returns the path to the latest `apksigner` in build-tools, or null.
  Future<String?> findApkSigner() async {
    final sdk = await findAndroidSdkPath();
    if (sdk == null) return null;
    return _findToolInBuildTools(sdk, 'apksigner');
  }

  /// Returns the path to the latest `aapt` in build-tools, or null.
  Future<String?> findAapt() async {
    final sdk = await findAndroidSdkPath();
    if (sdk == null) return null;
    return _findToolInBuildTools(sdk, 'aapt');
  }

  String? _findToolInBuildTools(String sdkPath, String toolName) {
    final buildToolsDir = Directory(
      '$sdkPath${Platform.pathSeparator}build-tools',
    );
    if (!buildToolsDir.existsSync()) return null;
    final versions =
        buildToolsDir
            .listSync()
            .whereType<Directory>()
            .map((d) => d.path.split(Platform.pathSeparator).last)
            .toList()
          ..sort(_compareVersions);
    for (final version in versions.reversed) {
      final toolPath =
          '${buildToolsDir.path}${Platform.pathSeparator}$version'
          '${Platform.pathSeparator}$toolName';
      if (Platform.isWindows) {
        for (final extension in const ['.exe', '.bat', '.cmd']) {
          final file = File('$toolPath$extension');
          if (file.existsSync()) return file.path;
        }
      } else {
        final file = File(toolPath);
        if (file.existsSync()) return toolPath;
      }
    }
    return null;
  }

  int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    final len = pa.length < pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = pa[i] ?? 0;
      final vb = pb[i] ?? 0;
      if (va != vb) return va.compareTo(vb);
    }
    return pa.length.compareTo(pb.length);
  }

  // ---- APK metadata extraction ----

  /// Extracts channel and version info from [apkPath] using `aapt`.
  Future<ApkInfo> extractApkInfo(String apkPath) async {
    final normalizedPath = _normalizePath(apkPath);
    final name = _fileName(normalizedPath);

    // Check if file exists
    if (!File(normalizedPath).existsSync()) {
      return ApkInfo(
        path: normalizedPath,
        name: name,
        channel: '文件不存在',
      );
    }

    final aaptPath = await findAapt();
    if (aaptPath == null) {
      return ApkInfo(path: normalizedPath, name: name);
    }

    String channel = '未知';
    String gdtChannel = '';
    String versionName = '';
    String versionCode = '';

    try {
      final xmlResult = await _processRunner.run(
        executable: aaptPath,
        arguments: ['dump', 'xmltree', normalizedPath, 'AndroidManifest.xml'],
        taskId: 'apk-info:xml:$normalizedPath',
        timeout: const Duration(seconds: 20),
      );
      if (xmlResult.exitCode == 0) {
        final xmlOut = xmlResult.stdout;
        channel = _extractMetaValue(xmlOut, 'CHANNEL_NAME') ?? '未知';
        gdtChannel = _extractMetaValue(xmlOut, 'gdt_action_channel_id') ?? '';
      }
    } on Object {
      // ignore
    }

    try {
      final badgingResult = await _processRunner.run(
        executable: aaptPath,
        arguments: ['dump', 'badging', normalizedPath],
        taskId: 'apk-info:badging:$normalizedPath',
        timeout: const Duration(seconds: 20),
      );
      if (badgingResult.exitCode == 0) {
        final badging = badgingResult.stdout;
        final firstLine = badging.split('\n').first;
        final vnMatch = RegExp(r"versionName='([^']*)'").firstMatch(firstLine);
        if (vnMatch != null) versionName = vnMatch.group(1)!;
        final vcMatch = RegExp(r"versionCode='([^']*)'").firstMatch(firstLine);
        if (vcMatch != null) versionCode = vcMatch.group(1)!;
      }
    } on Object {
      // ignore
    }

    return ApkInfo(
      path: normalizedPath,
      name: name,
      channel: channel,
      gdtChannel: gdtChannel,
      versionName: versionName,
      versionCode: versionCode,
    );
  }

  String? _extractMetaValue(String xmlOutput, String metaName) {
    final lines = xmlOutput.split('\n');
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      // 找到包含 metaName 的 android:name 行
      if (line.contains('android:name') && line.contains(metaName)) {
        // 检查同一行是否有 android:value
        if (line.contains('android:value')) {
          final rawMatch = RegExp(
            r'android:value.*?Raw:\s*"([^"]*)"',
          ).firstMatch(line);
          if (rawMatch != null) return rawMatch.group(1);
        }
        // 检查下一行是否有 android:value
        final nextLine = lines[i + 1];
        if (nextLine.contains('android:value')) {
          final rawMatch = RegExp(r'Raw:\s*"([^"]*)"').firstMatch(nextLine);
          if (rawMatch != null) return rawMatch.group(1);
        }
      }
    }
    return null;
  }

  // ---- File selection helpers ----

  Future<String?> pickJksFile() async {
    final result = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'JKS 密钥库', extensions: ['jks', 'keystore']),
      ],
      confirmButtonText: '选择密钥库',
    );
    return result != null ? _normalizePath(result.path) : null;
  }

  Future<List<String>> pickLocalApks() async {
    final result = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(label: 'APK 文件', extensions: ['apk']),
      ],
      confirmButtonText: '选择 APK 文件',
    );
    return result.map((f) => _normalizePath(f.path)).toList();
  }

  String _normalizePath(String path) {
    // Handle file:// URIs
    if (path.startsWith('file://')) {
      final uri = Uri.parse(path);
      path = uri.toFilePath();
    }
    // Normalize path separators for the current platform
    if (Platform.isWindows) {
      path = path.replaceAll('/', '\\');
    }
    return path;
  }

  Future<String?> pickOutputDirectory() async {
    final result = await getDirectoryPath(confirmButtonText: '选择输出目录');
    return result;
  }

  // ---- Signing ----

  /// Signs a single APK. Returns the [SignedApkInfo] with result.
  Future<SignedApkInfo> signApk({
    required String apkPath,
    required String jksPath,
    required String password,
    required String keyAlias,
    required String outputDir,
    String? customBaseName,
    String outputNamePrefix = '',
    String outputNameSuffix = '_signed',
  }) async {
    final normalizedApkPath = _normalizePath(apkPath);

    // Check if source APK exists
    if (!File(normalizedApkPath).existsSync()) {
      return SignedApkInfo(
        originalPath: normalizedApkPath,
        outputPath: '',
        outputName: '',
        success: false,
        errorMessage: 'APK 文件不存在: $normalizedApkPath',
      );
    }

    final apksigner = await findApkSigner();
    if (apksigner == null) {
      return SignedApkInfo(
        originalPath: normalizedApkPath,
        outputPath: '',
        outputName: '',
        success: false,
        errorMessage: '未找到 apksigner，请确认 Android SDK build-tools 已安装',
      );
    }

    final name = _fileName(normalizedApkPath);
    final dotIdx = name.lastIndexOf('.');
    final baseName = dotIdx > 0 ? name.substring(0, dotIdx) : name;
    final outputName = _signedOutputName(
      baseName,
      customBaseName: customBaseName,
      prefix: outputNamePrefix,
      suffix: outputNameSuffix,
    );
    final outputPath = '$outputDir${Platform.pathSeparator}$outputName';

    // Copy APK to output path first, then sign in-place.
    try {
      await Directory(outputDir).create(recursive: true);
      await File(normalizedApkPath).copy(outputPath);
    } on Object catch (e) {
      return SignedApkInfo(
        originalPath: normalizedApkPath,
        outputPath: '',
        outputName: outputName,
        success: false,
        errorMessage: '复制文件失败: $e',
      );
    }

    try {
      final result = await _processRunner.run(
        executable: apksigner,
        arguments: [
          'sign',
          '--ks',
          jksPath,
          '--ks-key-alias',
          keyAlias,
          '--ks-pass',
          'env:FVM_MANAGER_APK_SIGNING_PASSWORD',
          '--key-pass',
          'env:FVM_MANAGER_APK_SIGNING_PASSWORD',
          outputPath,
        ],
        taskId: 'apk-sign:$outputPath',
        environment: {'FVM_MANAGER_APK_SIGNING_PASSWORD': password},
        runInShell: Platform.isWindows,
        timeout: const Duration(minutes: 5),
      );
      if (result.exitCode != 0) {
        // Clean up failed output.
        try {
          await File(outputPath).delete();
        } on Object {
          // ignore
        }
        final stderr = result.stderr;
        final stdout = result.stdout;
        return SignedApkInfo(
          originalPath: normalizedApkPath,
          outputPath: '',
          outputName: outputName,
          success: false,
          errorMessage: '签名失败: ${stderr.isNotEmpty ? stderr : stdout}',
        );
      }

      final verifyResult = await _processRunner.run(
        executable: apksigner,
        arguments: ['verify', '--print-certs', outputPath],
        taskId: 'apk-verify:$outputPath',
        runInShell: Platform.isWindows,
        timeout: const Duration(minutes: 2),
      );
      if (verifyResult.exitCode != 0) {
        try {
          await File(outputPath).delete();
        } on Object {
          // ignore
        }
        return SignedApkInfo(
          originalPath: normalizedApkPath,
          outputPath: '',
          outputName: outputName,
          success: false,
          errorMessage: '签名校验失败: ${verifyResult.bestMessage}',
        );
      }
    } on Object catch (e) {
      try {
        await File(outputPath).delete();
      } on Object {
        // ignore
      }
      return SignedApkInfo(
        originalPath: normalizedApkPath,
        outputPath: '',
        outputName: outputName,
        success: false,
        errorMessage: '执行签名失败: $e',
      );
    }

    // Extract metadata from signed APK.
    final info = await extractApkInfo(outputPath);
    return SignedApkInfo(
      originalPath: normalizedApkPath,
      outputPath: outputPath,
      outputName: outputName,
      channel: info.channel,
      gdtChannel: info.gdtChannel,
      versionName: info.versionName,
      versionCode: info.versionCode,
      success: true,
    );
  }

  String _fileName(String path) =>
      path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

  String _signedOutputName(
    String baseName, {
    String? customBaseName,
    required String prefix,
    required String suffix,
  }) {
    final overrideName = customBaseName?.trim().replaceFirst(
      RegExp(r'\.apk$', caseSensitive: false),
      '',
    );
    final effectiveBaseName = overrideName == null || overrideName.isEmpty
        ? baseName
        : overrideName;
    final rawName = '${prefix.trim()}$effectiveBaseName${suffix.trim()}'
        .replaceFirst(RegExp(r'\.apk$', caseSensitive: false), '');
    final safeName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
    return '${safeName.isEmpty ? '${baseName}_signed' : safeName}.apk';
  }
}
