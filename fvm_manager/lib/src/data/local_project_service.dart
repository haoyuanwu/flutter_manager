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

  Future<bool> clearBuildDirectory(String projectPath) async {
    await validate(projectPath);
    final buildDirectory = Directory(
      '$projectPath${Platform.pathSeparator}build',
    );
    if (!await buildDirectory.exists()) return false;
    await buildDirectory.delete(recursive: true);
    return true;
  }

  /// 在系统文件管理器中显示并选中文件。
  Future<void> revealFile(String filePath) async {
    late final ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', ['-R', filePath]);
    } else if (Platform.isWindows) {
      result = await Process.run('explorer.exe', ['/select,', filePath]);
    } else {
      result = await Process.run('xdg-open', [File(filePath).parent.path]);
    }
    if (result.exitCode != 0) {
      throw Exception('无法打开文件所在目录：${result.stderr}');
    }
  }

  Future<void> openInAndroidStudio(String projectPath) async {
    await _openAndroidStudio(projectPath);
  }

  Future<void> openAndroidModuleInAndroidStudio(String projectPath) async {
    final androidDirectory = Directory(
      '$projectPath${Platform.pathSeparator}android',
    );
    if (!await androidDirectory.exists()) {
      throw Exception('该项目不存在 Android 工程目录');
    }
    await _openAndroidStudio(androidDirectory.path);
  }

  Future<void> openWindowsProjectInVisualStudio(String projectPath) async {
    if (!Platform.isWindows) {
      throw Exception('Visual Studio 原生工程仅支持在 Windows 系统打开');
    }
    final windowsDirectory = Directory(
      '$projectPath${Platform.pathSeparator}windows',
    );
    if (!await windowsDirectory.exists()) {
      throw Exception('该项目不存在 Windows 工程目录');
    }
    final result = await Process.run('cmd.exe', [
      '/c',
      'start',
      '',
      'devenv.exe',
      windowsDirectory.path,
    ], runInShell: true);
    if (result.exitCode != 0) {
      throw Exception('无法打开 Visual Studio，请确认已安装');
    }
  }

  Future<void> openIosProjectInXcode(String projectPath) async {
    await _openAppleProjectInXcode(projectPath, 'ios', 'iOS');
  }

  Future<void> openMacosProjectInXcode(String projectPath) async {
    await _openAppleProjectInXcode(projectPath, 'macos', 'macOS');
  }

  Future<void> _openAppleProjectInXcode(
    String projectPath,
    String platformDirectory,
    String platformLabel,
  ) async {
    if (!Platform.isMacOS) {
      throw Exception('Xcode 仅支持 macOS');
    }
    final appleDirectory = Directory(
      '$projectPath${Platform.pathSeparator}$platformDirectory',
    );
    if (!await appleDirectory.exists()) {
      throw Exception('该项目不存在 $platformLabel 工程目录');
    }

    final entries = await appleDirectory.list().toList();
    final workspaces =
        entries
            .whereType<Directory>()
            .where((entry) => entry.path.endsWith('.xcworkspace'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final projects =
        entries
            .whereType<Directory>()
            .where((entry) => entry.path.endsWith('.xcodeproj'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final target = workspaces.firstOrNull ?? projects.firstOrNull;
    if (target == null) {
      throw Exception('$platformLabel 目录中未找到 .xcworkspace 或 .xcodeproj');
    }

    final result = await Process.run('open', ['-a', 'Xcode', target.path]);
    if (result.exitCode != 0) {
      throw Exception('无法打开 Xcode，请确认已安装：${result.stderr}');
    }
  }

  Future<void> openInVSCode(String projectPath) async {
    if (await _tryStart('code', [projectPath])) return;
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final programFiles = Platform.environment['ProgramFiles'];
      final candidates = [
        if (localAppData != null)
          '$localAppData${Platform.pathSeparator}Programs${Platform.pathSeparator}'
              'Microsoft VS Code${Platform.pathSeparator}Code.exe',
        if (programFiles != null)
          '$programFiles${Platform.pathSeparator}Microsoft VS Code'
              '${Platform.pathSeparator}Code.exe',
      ];
      for (final candidate in candidates) {
        if (await File(candidate).exists() &&
            await _tryStart(candidate, [projectPath])) {
          return;
        }
      }
    }
    throw Exception('无法打开 VS Code，请确认已安装且 `code` 命令可用');
  }

  Future<void> _openAndroidStudio(String path) async {
    if (Platform.isMacOS &&
        await _tryStart('open', ['-a', 'Android Studio', path])) {
      return;
    }
    if (await _tryStart('studio', [path]) ||
        await _tryStart('studio64', [path])) {
      return;
    }
    if (Platform.isWindows) {
      final programFiles = Platform.environment['ProgramFiles'];
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final candidates = [
        if (programFiles != null)
          '$programFiles${Platform.pathSeparator}Android${Platform.pathSeparator}'
              'Android Studio${Platform.pathSeparator}bin${Platform.pathSeparator}studio64.exe',
        if (programFilesX86 != null)
          '$programFilesX86${Platform.pathSeparator}Android${Platform.pathSeparator}'
              'Android Studio${Platform.pathSeparator}bin${Platform.pathSeparator}studio64.exe',
        if (localAppData != null)
          '$localAppData${Platform.pathSeparator}Programs${Platform.pathSeparator}'
              'Android Studio${Platform.pathSeparator}bin${Platform.pathSeparator}studio64.exe',
      ];
      for (final candidate in candidates) {
        if (await File(candidate).exists() &&
            await _tryStart(candidate, [path])) {
          return;
        }
      }
    }
    throw Exception('无法打开 Android Studio，请确认已安装');
  }

  Future<bool> _tryStart(String executable, List<String> arguments) async {
    try {
      await Process.start(
        executable,
        arguments,
        runInShell: Platform.isWindows,
      );
      return true;
    } on ProcessException {
      return false;
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

  Future<String> packageWindowsInnoSetup({
    required String projectPath,
    required String appNameHint,
    required void Function(String output) onOutput,
  }) async {
    if (!Platform.isWindows) {
      throw Exception('Inno Setup 打包仅支持 Windows');
    }
    final separator = Platform.pathSeparator;
    final releaseDirectory = Directory(
      '$projectPath${separator}build${separator}windows${separator}x64'
      '${separator}runner${separator}Release',
    );
    if (!await releaseDirectory.exists()) {
      throw Exception('Windows Release 目录不存在，请先完成 Windows 构建');
    }
    final mainExe = await _findWindowsMainExe(releaseDirectory, appNameHint);
    final pubspec = await _readPubspec(projectPath);
    final appName = _safeInnoValue(
      pubspec['name']?.toString().trim().isNotEmpty == true
          ? pubspec['name'].toString().trim()
          : appNameHint,
    );
    final version = _safeInnoValue(
      (pubspec['version']?.toString().split('+').first.trim().isNotEmpty == true
              ? pubspec['version'].toString().split('+').first.trim()
              : '1.0.0')
          .replaceAll(RegExp(r'[^0-9A-Za-z_.-]'), '.'),
    );
    final outputDirectory = Directory(
      '$projectPath${separator}build${separator}windows${separator}installer',
    );
    await outputDirectory.create(recursive: true);
    final scriptFile = File('${outputDirectory.path}${separator}installer.iss');
    final outputBaseName = '${_safeFileName(appName)}-$version-setup';
    await scriptFile.writeAsString(
      _windowsInnoScript(
        appName: appName,
        appVersion: version,
        releaseDirectory: releaseDirectory.path,
        mainExeName: mainExe.uri.pathSegments.last,
        outputDirectory: outputDirectory.path,
        outputBaseName: outputBaseName,
        setupIconPath: await _windowsAppIconPath(projectPath),
      ),
    );
    final iscc = await _findInnoCompiler();
    if (iscc == null) {
      throw Exception(
        '未找到 Inno Setup 编译器 ISCC.exe。请安装 Inno Setup 6，'
        '或将 ISCC.exe 添加到 PATH 后重试。',
      );
    }
    onOutput('\n[Inno Setup] $iscc\n');
    onOutput('[Inno Setup] ${scriptFile.path}\n');
    final process = await Process.start(iscc, [
      scriptFile.path,
    ], runInShell: true);
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(onOutput);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('Inno Setup 打包失败（退出码 $exitCode）');
    }
    final installerPath =
        '${outputDirectory.path}$separator$outputBaseName.exe';
    if (!await File(installerPath).exists()) {
      throw Exception('Inno Setup 已结束，但未找到安装包：$installerPath');
    }
    return installerPath;
  }

  Future<File> _findWindowsMainExe(
    Directory releaseDirectory,
    String appNameHint,
  ) async {
    final files =
        await releaseDirectory
              .list(followLinks: false)
              .where((entity) => entity is File && entity.path.endsWith('.exe'))
              .cast<File>()
              .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw Exception('Windows Release 目录中未找到主程序 .exe');
    }
    final normalizedHint = _normalizeName(appNameHint);
    return files.firstWhere(
      (file) => _normalizeName(
        file.uri.pathSegments.last.replaceAll(
          RegExp(r'\.exe$', caseSensitive: false),
          '',
        ),
      ).contains(normalizedHint),
      orElse: () => files.first,
    );
  }

  Future<String?> _findInnoCompiler() async {
    final candidates = <String>[
      r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
      r'C:\Program Files\Inno Setup 6\ISCC.exe',
      r'C:\Program Files (x86)\Inno Setup 5\ISCC.exe',
      r'C:\Program Files\Inno Setup 5\ISCC.exe',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    try {
      final result = await Process.run('where', ['ISCC.exe'], runInShell: true);
      if (result.exitCode == 0) {
        final found = result.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        if (found.isNotEmpty && await File(found).exists()) return found;
      }
    } on ProcessException {
      // Fall through to not found.
    }
    return null;
  }

  Future<YamlMap> _readPubspec(String projectPath) async {
    final pubspecFile = File(
      '$projectPath${Platform.pathSeparator}pubspec.yaml',
    );
    return loadYaml(await pubspecFile.readAsString()) as YamlMap;
  }

  String _windowsInnoScript({
    required String appName,
    required String appVersion,
    required String releaseDirectory,
    required String mainExeName,
    required String outputDirectory,
    required String outputBaseName,
    String? setupIconPath,
  }) {
    final escapedRelease = _innoPath(releaseDirectory);
    final escapedOutput = _innoPath(outputDirectory);
    final escapedExe = _safeInnoValue(mainExeName);
    final setupIconLine = setupIconPath == null
        ? ''
        : 'SetupIconFile=${_innoPath(setupIconPath)}';
    return '''
#define MyAppName "$appName"
#define MyAppVersion "$appVersion"
#define MyAppExeName "$escapedExe"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppName}
DefaultDirName={autopf}\\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=$escapedOutput
OutputBaseFilename=$outputBaseName
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
$setupIconLine

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$escapedRelease\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
''';
  }

  String _safeInnoValue(String value) => value.replaceAll('"', r'\"');

  String _innoPath(String value) => _safeInnoValue(value);

  String _safeFileName(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-').trim();

  String _normalizeName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<String?> _windowsAppIconPath(String projectPath) async {
    final icon = File(
      '$projectPath${Platform.pathSeparator}windows${Platform.pathSeparator}'
      'runner${Platform.pathSeparator}resources${Platform.pathSeparator}'
      'app_icon.ico',
    );
    return await icon.exists() ? icon.path : null;
  }

  /// 将 macOS .app 打包成 .dmg
  Future<String> packageMacosDmg(String projectPath, String appName) async {
    final separator = Platform.pathSeparator;
    final app = await findMacosReleaseApp(projectPath, appName);
    final appPath = app.path;
    final bundleName = app.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final productName = bundleName.substring(0, bundleName.length - 4);
    final dmgPath =
        '$projectPath${separator}build$separator${productName.replaceAll(' ', '')}.dmg';
    // 删除旧的 dmg
    final oldDmg = File(dmgPath);
    if (oldDmg.existsSync()) await oldDmg.delete();

    // 使用临时目录组织标准的拖拽安装布局：应用 + Applications 快捷方式。
    final stagingDirectory = await Directory.systemTemp.createTemp(
      'flutter_manager_dmg_',
    );
    try {
      final stagedAppPath = '${stagingDirectory.path}$separator$bundleName';
      final copyResult = await Process.run('ditto', [appPath, stagedAppPath]);
      if (copyResult.exitCode != 0) {
        throw Exception('准备 DMG 应用文件失败：${copyResult.stderr}');
      }
      await Link(
        '${stagingDirectory.path}${separator}Applications',
      ).create('/Applications');

      final result = await Process.run('hdiutil', [
        'create',
        '-volname',
        productName,
        '-srcfolder',
        stagingDirectory.path,
        '-ov',
        '-format',
        'UDZO',
        dmgPath,
      ]);
      if (result.exitCode != 0) {
        throw Exception('打包 DMG 失败：${result.stderr}');
      }
    } finally {
      try {
        await stagingDirectory.delete(recursive: true);
      } on FileSystemException {
        // 临时目录清理失败不应覆盖实际的打包结果或错误。
      }
    }
    return dmgPath;
  }

  /// 查找 Flutter/Xcode 实际生成的 macOS Release 应用。
  ///
  /// pubspec 的 `name` 是 Dart 包名（例如 `demo_app`），不一定等于
  /// Xcode 的 `PRODUCT_NAME`（例如 `Demo App`），因此不能直接拼接文件名。
  Future<Directory> findMacosReleaseApp(
    String projectPath,
    String appNameHint,
  ) async {
    final separator = Platform.pathSeparator;
    final releaseDirectory = Directory(
      '$projectPath${separator}build${separator}macos${separator}Build'
      '${separator}Products${separator}Release',
    );
    if (!await releaseDirectory.exists()) {
      throw Exception('未找到 macOS Release 构建目录，请先完成 macOS Release 构建');
    }

    final generatedNameFile = File(
      '$projectPath${separator}macos${separator}Flutter${separator}ephemeral'
      '$separator.app_filename',
    );
    if (await generatedNameFile.exists()) {
      final generatedName = (await generatedNameFile.readAsString()).trim();
      if (generatedName.isNotEmpty &&
          !generatedName.contains('/') &&
          !generatedName.contains('\\')) {
        final generatedApp = Directory(
          '${releaseDirectory.path}$separator$generatedName',
        );
        if (await generatedApp.exists()) return generatedApp;
      }
    }

    final apps = await releaseDirectory
        .list(followLinks: false)
        .where((entity) => entity is Directory && entity.path.endsWith('.app'))
        .cast<Directory>()
        .toList();
    final normalizedHint = _normalizeAppName(appNameHint);
    final matchingApps = apps.where((app) {
      final name = app.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      return _normalizeAppName(name.substring(0, name.length - 4)) ==
          normalizedHint;
    }).toList();
    if (matchingApps.length == 1) return matchingApps.single;
    if (apps.length == 1) return apps.single;

    final found = apps
        .map(
          (app) =>
              app.uri.pathSegments.where((segment) => segment.isNotEmpty).last,
        )
        .join('、');
    throw Exception(
      found.isEmpty
          ? 'Release 目录中未找到 .app，请先完成 macOS Release 构建'
          : 'Release 目录中存在多个 .app，无法确定要打包哪一个：$found',
    );
  }

  String _normalizeAppName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

  /// 更新 Flutter 项目的打包版本，并同步 Android 中写死的版本字面量。
  Future<bool> updateProjectVersion(
    String path, {
    required String version,
    required String buildNo,
  }) async {
    final normalizedVersion = version.trim();
    final normalizedBuildNo = buildNo.trim();
    if (!RegExp(
      r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
    ).hasMatch(normalizedVersion)) {
      throw Exception('Version 格式无效，请输入类似 1.2.3 或 1.2.3-beta.1');
    }
    if (!RegExp(r'^\d+$').hasMatch(normalizedBuildNo) ||
        int.parse(normalizedBuildNo) < 1) {
      throw Exception('Build No 必须是大于 0 的整数');
    }

    final separator = Platform.pathSeparator;
    final pubspecFile = File('$path${separator}pubspec.yaml');
    if (!await pubspecFile.exists()) throw Exception('未找到项目 pubspec.yaml');
    final pubspecSource = await pubspecFile.readAsString();
    final versionLine = RegExp(r'^version\s*:\s*.*$', multiLine: true);
    if (!versionLine.hasMatch(pubspecSource)) {
      throw Exception('pubspec.yaml 中未找到 version 配置');
    }
    final updatedPubspec = pubspecSource.replaceFirst(
      versionLine,
      'version: $normalizedVersion+$normalizedBuildNo',
    );

    File? androidFile;
    String? updatedAndroidSource;
    var androidSynchronized = false;
    for (final candidate in [
      '$path${separator}android${separator}app${separator}build.gradle',
      '$path${separator}android${separator}app${separator}build.gradle.kts',
    ]) {
      final file = File(candidate);
      if (!await file.exists()) continue;
      final source = await file.readAsString();
      var updated = source.replaceFirstMapped(
        RegExp(
          r'''^(\s*versionName\s*(?:=\s*)?)["'][^"']*["'](\s*(?://.*)?)$''',
          multiLine: true,
        ),
        (match) => '${match.group(1)}"$normalizedVersion"${match.group(2)}',
      );
      updated = updated.replaceFirstMapped(
        RegExp(
          r'^(\s*versionCode\s*(?:=\s*)?)\d+(\s*(?://.*)?)$',
          multiLine: true,
        ),
        (match) => '${match.group(1)}$normalizedBuildNo${match.group(2)}',
      );
      androidFile = file;
      updatedAndroidSource = updated;
      androidSynchronized = updated != source;
      break;
    }

    await pubspecFile.writeAsString(updatedPubspec, flush: true);
    if (androidFile != null && androidSynchronized) {
      await androidFile.writeAsString(updatedAndroidSource!, flush: true);
    }
    return androidSynchronized;
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
