import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../domain/project_models.dart';

class LocalProjectService {
  Future<String?> chooseDirectory() async {
    try {
      return await getDirectoryPath(confirmButtonText: '选择项目');
    } on MissingPluginException {
      throw Exception('目录选择插件尚未加载，请彻底停止应用后重新运行（热重载无效）');
    }
  }

  Future<void> validate(String path) async {
    final separator = Platform.pathSeparator;
    if (!await File('$path${separator}pubspec.yaml').exists()) {
      throw Exception('所选目录不是 Flutter 项目：未找到 pubspec.yaml');
    }
  }

  Future<FlutterProject> inspectProject(String path) async {
    await validate(path);
    final separator = Platform.pathSeparator;
    final pubspecFile = File('$path${separator}pubspec.yaml');
    final pubspec = loadYaml(await pubspecFile.readAsString()) as YamlMap;
    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap || !dependencies.containsKey('flutter')) {
      throw Exception('所选目录不是 Flutter 项目：pubspec.yaml 中未声明 Flutter');
    }

    final android = Directory('$path${separator}android');
    final androidConfig = await _readAndroidConfig(path);
    final pubspecVersion = pubspec['version']?.toString() ?? '';
    final versionParts = pubspecVersion.split('+');
    return FlutterProject(
      name: pubspec['name']?.toString() ?? path.split(RegExp(r'[/\\]')).last,
      description: pubspec['description']?.toString(),
      path: path,
      lastOpened: DateTime.now(),
      fvmVersion: await currentVersion(path),
      hasAndroid: await android.exists(),
      hasIos: await Directory('$path${separator}ios').exists(),
      hasWindows: await Directory('$path${separator}windows').exists(),
      hasMacos: await Directory('$path${separator}macos').exists(),
      androidFlavors: androidConfig.flavors,
      androidBuildTypes: androidConfig.buildTypes,
      bugly: BuglyUploadConfig(
        bundleId: androidConfig.applicationId ?? '',
        version: androidConfig.versionName ?? versionParts.first,
        buildNo:
            androidConfig.versionCode ??
            (versionParts.length > 1 ? versionParts[1] : ''),
      ),
    );
  }

  Future<void> openApkOutput(String projectPath) async {
    final separator = Platform.pathSeparator;
    final output = Directory(
      '$projectPath${separator}build${separator}app${separator}outputs'
      '${separator}flutter-apk',
    );
    if (!await output.exists()) {
      throw Exception('APK 输出目录尚不存在，请先完成一次 APK 构建');
    }
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [output.path])
        : await Process.run('open', [output.path]);
    if (result.exitCode != 0) {
      throw Exception('无法打开 APK 输出目录：${result.stderr}');
    }
  }

  Future<void> openProjectFolder(String projectPath) async {
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [projectPath])
        : await Process.run('open', [projectPath]);
    if (result.exitCode != 0) {
      throw Exception('无法打开项目目录：${result.stderr}');
    }
  }

  Future<void> openInAndroidStudio(String projectPath) async {
    // macOS: Android Studio 通常通过 `open -a` 调用
    final result = await Process.run('open', [
      '-a',
      'Android Studio',
      projectPath,
    ]);
    if (result.exitCode != 0) {
      // 备选：尝试命令行工具
      final result2 = await Process.run('studio', [projectPath]);
      if (result2.exitCode != 0) {
        throw Exception('无法打开 Android Studio，请确认已安装');
      }
    }
  }

  Future<void> openInVSCode(String projectPath) async {
    final result = await Process.run('code', [projectPath]);
    if (result.exitCode != 0) {
      throw Exception('无法打开 VS Code，请确认已安装且 `code` 命令可用');
    }
  }

  /// 打开构建产物目录
  Future<void> openBuildOutput(String projectPath, String target) async {
    final separator = Platform.pathSeparator;
    String outputPath;
    switch (target) {
      case 'apk':
      case 'appbundle':
        outputPath =
            '$projectPath${separator}build${separator}app${separator}outputs'
            '$separator${target == 'apk' ? 'flutter-apk' : 'flutter-aab'}';
      case 'ios':
        outputPath = '$projectPath${separator}build${separator}ios';
      case 'macos':
        outputPath =
            '$projectPath${separator}build${separator}macos${separator}Build'
            '${separator}Products${separator}Release';
      case 'windows':
        outputPath =
            '$projectPath${separator}build${separator}windows${separator}x64'
            '${separator}runner${separator}Release';
      default:
        outputPath = '$projectPath${separator}build';
    }
    final dir = Directory(outputPath);
    if (!await dir.exists()) {
      throw Exception('构建产物目录不存在，请先完成一次构建');
    }
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [outputPath])
        : await Process.run('open', [outputPath]);
    if (result.exitCode != 0) {
      throw Exception('无法打开目录：${result.stderr}');
    }
  }

  /// 将 macOS .app 打包成 .dmg
  Future<String> packageMacosDmg(String projectPath, String appName) async {
    final separator = Platform.pathSeparator;
    final appPath =
        '$projectPath${separator}build${separator}macos${separator}Build'
        '${separator}Products${separator}Release$separator$appName.app';
    if (!Directory(appPath).existsSync()) {
      throw Exception('未找到 $appName.app，请先完成 macOS Release 构建');
    }
    final dmgPath =
        '$projectPath${separator}build$separator${appName.replaceAll(' ', '')}.dmg';
    // 删除旧的 dmg
    final oldDmg = File(dmgPath);
    if (oldDmg.existsSync()) await oldDmg.delete();
    final result = await Process.run('hdiutil', [
      'create',
      '-volname',
      appName,
      '-srcfolder',
      appPath,
      '-ov',
      '-format',
      'UDZO',
      dmgPath,
    ]);
    if (result.exitCode != 0) {
      throw Exception('打包 DMG 失败：${result.stderr}');
    }
    return dmgPath;
  }

  /// 获取可用的 Flutter 设备列表。
  Future<List<Map<String, String>>> listDevices(String projectPath) async {
    final result = await Process.run('fvm', [
      'flutter',
      'devices',
      '--machine',
    ], workingDirectory: projectPath);
    if (result.exitCode != 0) {
      // 回退到直接用 flutter
      final result2 = await Process.run('flutter', [
        'devices',
        '--machine',
      ], workingDirectory: projectPath);
      if (result2.exitCode != 0) return [];
      return _parseDevices(result2.stdout as String);
    }
    return _parseDevices(result.stdout as String);
  }

  List<Map<String, String>> _parseDevices(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return {
          'id': (m['id'] ?? m['name'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
          'platform': (m['platform'] ?? '').toString(),
        };
      }).toList();
    } on Object {
      return [];
    }
  }

  /// 从项目文件中读取当前的 Bundle ID、Version、Build No。
  /// Version / Build No 直接读 pubspec.yaml；Bundle ID 读 android build.gradle。
  Future<({String? bundleId, String? version, String? buildNo})>
  readProjectInfo(String path) async {
    final separator = Platform.pathSeparator;

    // 1. 从 pubspec.yaml 读取 version + buildNo
    String? version;
    String? buildNo;
    final pubspecFile = File('$path${separator}pubspec.yaml');
    if (await pubspecFile.exists()) {
      final pubspec = loadYaml(await pubspecFile.readAsString()) as YamlMap;
      final raw = pubspec['version'];
      if (raw != null) {
        final versionStr = raw.toString();
        final idx = versionStr.indexOf('+');
        if (idx >= 0) {
          version = versionStr.substring(0, idx);
          buildNo = versionStr.substring(idx + 1);
        } else {
          version = versionStr;
        }
      }
    }

    // 2. 从 android build.gradle 读取 applicationId（仅此一项需要从 gradle 读）
    String? bundleId;
    final androidDir = Directory('$path${separator}android');
    if (await androidDir.exists()) {
      final androidConfig = await _readAndroidConfig(path);
      bundleId = androidConfig.applicationId;
    }

    return (bundleId: bundleId, version: version, buildNo: buildNo);
  }

  Future<String?> chooseBuglyJar() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Java Archive', extensions: ['jar']),
        ],
        confirmButtonText: '选择 Bugly 符号上传工具',
      );
      return file?.path;
    } on MissingPluginException {
      throw Exception('文件选择插件尚未加载，请彻底停止应用后重新运行');
    }
  }

  Future<String?> currentVersion(String path) async {
    final separator = Platform.pathSeparator;
    final config = File('$path$separator.fvmrc');
    if (await config.exists()) {
      final json = await _readJson(config, '.fvmrc');
      return json['flutter'] as String?;
    }

    final legacy = File('$path$separator.fvm${separator}fvm_config.json');
    if (await legacy.exists()) {
      final json = await _readJson(legacy, '.fvm/fvm_config.json');
      return json['flutterSdkVersion'] as String?;
    }
    return null;
  }

  Future<Map<String, dynamic>> _readJson(File file, String name) async {
    try {
      final json = jsonDecode(await file.readAsString());
      return (json as Map).cast<String, dynamic>();
    } on Object {
      throw Exception('项目的 $name 格式无效');
    }
  }

  Future<
    ({
      List<String> flavors,
      List<String> buildTypes,
      String? applicationId,
      String? versionName,
      String? versionCode,
    })
  >
  _readAndroidConfig(String path) async {
    final separator = Platform.pathSeparator;
    final candidates = [
      '$path${separator}android${separator}app${separator}build.gradle',
      '$path${separator}android${separator}app${separator}build.gradle.kts',
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (!await file.exists()) continue;
      final source = await file.readAsString();
      final flavors = _parseGradleNames(source, 'productFlavors');
      final buildTypes = _parseGradleNames(source, 'buildTypes');
      return (
        flavors: flavors,
        buildTypes: buildTypes.isEmpty
            ? const ['debug', 'release']
            : buildTypes,
        applicationId: _parseGradleString(source, 'applicationId'),
        versionName: _parseGradleString(source, 'versionName'),
        versionCode: _parseGradleNumber(source, 'versionCode'),
      );
    }
    return (
      flavors: const <String>[],
      buildTypes: const ['debug', 'release'],
      applicationId: null,
      versionName: null,
      versionCode: null,
    );
  }

  String? _parseGradleString(String source, String key) {
    for (final line in source.split('\n')) {
      final m = RegExp(
        '''$key\\s*(?:=\\s*)?["']([^"']+)["']''',
      ).firstMatch(line);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _parseGradleNumber(String source, String key) {
    for (final line in source.split('\n')) {
      final m = RegExp('$key\\s*(?:=\\s*)?(\\d+)').firstMatch(line);
      if (m != null) return m.group(1);
    }
    return null;
  }

  List<String> _parseGradleNames(String source, String sectionName) {
    final section = RegExp('$sectionName\\s*\\{').firstMatch(source);
    if (section == null) return const [];
    final openBrace = source.indexOf('{', section.start);
    var depth = 1;
    var cursor = openBrace + 1;
    while (cursor < source.length && depth > 0) {
      if (source[cursor] == '{') depth++;
      if (source[cursor] == '}') depth--;
      cursor++;
    }
    if (depth != 0) return const [];
    final body = source.substring(openBrace + 1, cursor - 1);
    final names = <String>{};
    var lineDepth = 0;
    for (final rawLine in body.split('\n')) {
      final line = rawLine.trim();
      if (lineDepth == 0) {
        final created = RegExp(
          r'''(?:create|maybeCreate|getByName)\s*\(\s*["']([^"']+)''',
        ).firstMatch(line);
        final block = RegExp(r'^([A-Za-z_][\w-]*)\s*\{').firstMatch(line);
        final name = created?.group(1) ?? block?.group(1);
        if (name != null && name != 'all' && name != 'configureEach') {
          names.add(name);
        }
      }
      lineDepth += '{'.allMatches(line).length;
      lineDepth -= '}'.allMatches(line).length;
    }
    return names.toList();
  }
}
