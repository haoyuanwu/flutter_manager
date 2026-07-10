import 'dart:async';
import 'dart:io';

import '../domain/models.dart';
import '../domain/project_models.dart';
import 'pub_environment_service.dart';

enum EnvironmentDiagnosticLevel { ok, warning, error, info }

class DiagnosticItem {
  const DiagnosticItem({
    required this.level,
    required this.category,
    required this.title,
    required this.detail,
    this.suggestion,
    this.documentationUrl,
    this.documentationLabel,
  });

  final EnvironmentDiagnosticLevel level;
  final String category;
  final String title;
  final String detail;
  final String? suggestion;
  final String? documentationUrl;
  final String? documentationLabel;
}

class EnvironmentDiagnosticReport {
  const EnvironmentDiagnosticReport({
    required this.startedAt,
    required this.finishedAt,
    required this.items,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final List<DiagnosticItem> items;

  int count(EnvironmentDiagnosticLevel level) =>
      items.where((item) => item.level == level).length;
}

class EnvironmentDiagnosticsService {
  const EnvironmentDiagnosticsService(this._environment);

  final PubEnvironmentService _environment;

  Future<EnvironmentDiagnosticReport> run({
    required FvmState state,
    FlutterProject? selectedProject,
  }) async {
    final startedAt = DateTime.now();
    final items = <DiagnosticItem>[];

    await _checkFvm(items);
    await _checkFlutter(items, state);
    await _checkMirror(items, state);
    _checkProject(items, state, selectedProject);
    _checkDevices(items, state);
    await _checkPlatformTools(items, state, selectedProject);
    await _checkFlutterDoctor(items, state, selectedProject);
    await _checkMcp(items, state);

    return EnvironmentDiagnosticReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      items: items,
    );
  }

  Future<void> _checkFvm(List<DiagnosticItem> items) async {
    final result = await _runCommand('fvm', const ['--version']);
    if (result.exitCode == 0) {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: 'FVM',
          title: 'FVM 可用',
          detail: result.output.trim().isEmpty
              ? 'fvm --version 执行成功'
              : result.output.trim(),
        ),
      );
    } else {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: 'FVM',
          title: '未检测到 FVM',
          detail: result.output.trim().isEmpty ? result.error : result.output,
          suggestion: '请在概览中安装 FVM，或选择本地 FVM 目录。',
        ),
      );
    }
  }

  Future<void> _checkFlutter(List<DiagnosticItem> items, FvmState state) async {
    if (!state.fvmInstalled) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: 'Flutter',
          title: '等待 FVM 环境',
          detail: '安装 FVM 后才能检查和管理 Flutter SDK。',
        ),
      );
      return;
    }
    if (state.installed.isEmpty) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: 'Flutter',
          title: '尚未安装 Flutter SDK',
          detail: 'FVM 当前没有可供项目使用的 Flutter 版本。',
          suggestion: '安装推荐的 Stable 版本，或在 Flutter 版本页面选择其他版本。',
        ),
      );
    } else {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: 'Flutter',
          title: '已安装 ${state.installed.length} 个 Flutter SDK',
          detail: state.installed
              .map((sdk) => sdk.flutterVersion)
              .toSet()
              .join('、'),
        ),
      );
    }

    final result = await _runCommand('flutter', const ['--version']);
    if (result.exitCode == 0) {
      final firstLine = result.output.split('\n').firstOrNull?.trim();
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: 'Flutter',
          title: 'Flutter 命令可用',
          detail: firstLine?.isNotEmpty == true
              ? firstLine!
              : 'flutter --version 执行成功',
        ),
      );
    } else {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: 'Flutter',
          title: '未配置系统全局 Flutter',
          detail: result.output.trim().isEmpty ? result.error : result.output,
          suggestion: '项目通过 FVM 运行时不受影响；如需在终端直接使用 flutter，可设置全局版本。',
        ),
      );
    }
  }

  Future<void> _checkMirror(List<DiagnosticItem> items, FvmState state) async {
    final latency = await _environment.testMirror(state.mirrorId);
    final mirror = _environment.currentMirror;
    if (latency >= 0) {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: '网络',
          title: '${mirror.name} 连通',
          detail: '延迟 ${latency}ms',
        ),
      );
    } else {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: '网络',
          title: '${mirror.name} 无法访问',
          detail: '当前 pub 镜像连通性测试失败。',
          suggestion:
              'Windows 下如果 pub.dev TLS 报错，建议切换 Flutter CN、清华或南京大学镜像，并检查系统时间/代理/证书。',
        ),
      );
    }
  }

  void _checkProject(
    List<DiagnosticItem> items,
    FvmState state,
    FlutterProject? project,
  ) {
    if (project == null) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '项目',
          title: '未选择项目',
          detail: '选择项目后可检查平台目录、Flavor 和构建产物。',
        ),
      );
      return;
    }

    final pubspec = File(
      '${project.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (!project.pathExists || !pubspec.existsSync()) {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: '项目',
          title: '项目目录不可用',
          detail: project.path,
          suggestion: '请重新定位项目目录，或删除失效项目记录。',
        ),
      );
      return;
    }

    final platforms = <String>[
      if (project.hasAndroid) 'Android',
      if (project.hasIos) 'iOS',
      if (project.hasMacos) 'macOS',
      if (project.hasWindows) 'Windows',
    ];
    items.add(
      DiagnosticItem(
        level: EnvironmentDiagnosticLevel.ok,
        category: '项目',
        title: '项目目录正常',
        detail: platforms.isEmpty ? '未检测到平台目录' : '平台：${platforms.join('、')}',
      ),
    );

    final requiredVersion = project.fvmVersion?.trim();
    if (requiredVersion == null || requiredVersion.isEmpty) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.warning,
          category: '项目',
          title: '项目未指定 FVM 版本',
          detail: '项目将使用 FVM 全局 Flutter 版本。',
          suggestion: '建议为项目设置明确的 Flutter 版本，保证不同环境构建结果一致。',
        ),
      );
    } else {
      final installed = state.installed.any(
        (sdk) =>
            sdk.name == requiredVersion ||
            sdk.flutterVersion == requiredVersion,
      );
      items.add(
        DiagnosticItem(
          level: installed
              ? EnvironmentDiagnosticLevel.ok
              : EnvironmentDiagnosticLevel.error,
          category: '项目',
          title: installed ? '项目 Flutter 版本已就绪' : '缺少项目所需 Flutter 版本',
          detail: 'Flutter $requiredVersion',
          suggestion: installed
              ? null
              : '请安装 Flutter $requiredVersion 后再运行或构建项目。',
        ),
      );
    }

    if (state.selectedAndroidFlavors.isNotEmpty &&
        project.androidFlavors.isNotEmpty) {
      final invalid = state.selectedAndroidFlavors
          .where((flavor) => !project.androidFlavors.contains(flavor))
          .toList();
      items.add(
        DiagnosticItem(
          level: invalid.isEmpty
              ? EnvironmentDiagnosticLevel.ok
              : EnvironmentDiagnosticLevel.error,
          category: '项目',
          title: invalid.isEmpty ? 'Android Flavor 有效' : 'Android Flavor 不存在',
          detail: invalid.isEmpty
              ? state.selectedAndroidFlavors.join('、')
              : '无效：${invalid.join('、')}；可用：${project.androidFlavors.join('、')}',
          suggestion: invalid.isEmpty ? null : '请在项目详情中重新选择有效渠道。',
        ),
      );
    }

    final output = _buildOutputDirectory(
      project.path,
      state.projectBuildTarget,
    );
    items.add(
      DiagnosticItem(
        level: output.existsSync()
            ? EnvironmentDiagnosticLevel.ok
            : EnvironmentDiagnosticLevel.info,
        category: '构建产物',
        title: output.existsSync() ? '构建产物目录存在' : '构建产物目录尚不存在',
        detail: output.path,
        suggestion: output.existsSync()
            ? null
            : '完成一次 ${state.projectBuildTarget.name} 构建后会生成该目录。',
      ),
    );
  }

  void _checkDevices(List<DiagnosticItem> items, FvmState state) {
    if (state.devicesLoading) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '设备',
          title: '设备监听中',
          detail: '正在等待 Flutter device daemon 返回设备列表。',
        ),
      );
      return;
    }
    if (state.devices.isEmpty) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.warning,
          category: '设备',
          title: '暂无设备',
          detail: '当前未检测到可运行设备。',
          suggestion: '连接 Android/iOS 设备，或打开模拟器后刷新设备。',
        ),
      );
      return;
    }
    items.add(
      DiagnosticItem(
        level: EnvironmentDiagnosticLevel.ok,
        category: '设备',
        title: '检测到 ${state.devices.length} 个设备',
        detail: state.devices
            .map(
              (device) => '${device['name'] ?? device['id']} (${device['id']})',
            )
            .join('、'),
      ),
    );
  }

  Future<void> _checkPlatformTools(
    List<DiagnosticItem> items,
    FvmState state,
    FlutterProject? project,
  ) async {
    if (project == null) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '工具链',
          title: '未检查平台工具链',
          detail: '选择项目后，将只检查该项目实际包含的平台。',
        ),
      );
      return;
    }

    var checked = false;
    if (project.hasAndroid) {
      checked = true;
      await _checkAndroidTools(items);
    }
    if (Platform.isWindows && project.hasWindows) {
      checked = true;
      await _checkWindowsTools(
        items,
        requireInstaller:
            state.projectBuildTarget == ProjectBuildTarget.windows,
      );
    }
    if (Platform.isMacOS && (project.hasIos || project.hasMacos)) {
      checked = true;
      await _checkMacosTools(items);
    }

    if (Platform.isWindows && (project.hasIos || project.hasMacos)) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '平台兼容性',
          title: 'Windows 不能构建 iOS/macOS',
          detail: 'iOS 和 macOS 产物需要在 macOS 上使用 Xcode 构建。',
        ),
      );
    } else if (Platform.isMacOS && project.hasWindows) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '平台兼容性',
          title: 'macOS 不能构建 Windows',
          detail: 'Windows 桌面产物需要在 Windows 上使用 Visual Studio 构建。',
        ),
      );
    }

    if (!checked) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: '工具链',
          title: '当前系统无需额外检查',
          detail: '项目未包含当前系统可构建的原生桌面平台。',
        ),
      );
    }
  }

  Future<void> _checkAndroidTools(List<DiagnosticItem> items) async {
    final separator = Platform.pathSeparator;
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final sdkCandidates = <String?>[
      Platform.environment['ANDROID_SDK_ROOT'],
      Platform.environment['ANDROID_HOME'],
      if (home != null && Platform.isMacOS) '$home/Library/Android/sdk',
      if (home != null && Platform.isWindows)
        '$home\\AppData\\Local\\Android\\Sdk',
    ];
    final sdkPath = sdkCandidates
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .map((path) => Directory(path))
        .where((directory) => directory.existsSync())
        .firstOrNull
        ?.path;
    items.add(
      DiagnosticItem(
        level: sdkPath == null
            ? EnvironmentDiagnosticLevel.error
            : EnvironmentDiagnosticLevel.ok,
        category: 'Android',
        title: sdkPath == null ? '未检测到 Android SDK' : 'Android SDK 可用',
        detail: sdkPath ?? 'ANDROID_SDK_ROOT/ANDROID_HOME 未配置，且常见目录中未找到 SDK',
        suggestion: sdkPath == null
            ? '请通过 Android Studio 安装 Android SDK，并确认 SDK 路径。'
            : null,
        documentationUrl: sdkPath == null
            ? 'https://developer.android.com/studio'
            : null,
        documentationLabel: '下载 Android Studio',
      ),
    );

    final adbName = Platform.isWindows ? 'adb.exe' : 'adb';
    final bundledAdb = sdkPath == null
        ? null
        : '$sdkPath${separator}platform-tools$separator$adbName';
    final adb = bundledAdb != null && File(bundledAdb).existsSync()
        ? bundledAdb
        : await _findOnPath(adbName);
    final adbResult = adb == null
        ? null
        : await _runCommand(adb, const ['version']);
    items.add(
      DiagnosticItem(
        level: adbResult?.exitCode == 0
            ? EnvironmentDiagnosticLevel.ok
            : EnvironmentDiagnosticLevel.error,
        category: 'Android',
        title: adbResult?.exitCode == 0 ? 'ADB 可用' : 'ADB 不可用',
        detail: adbResult?.exitCode == 0
            ? _firstOutputLine(adbResult!)
            : adbResult?.error ?? 'Android SDK platform-tools 中未找到 adb',
        suggestion: adbResult?.exitCode == 0
            ? null
            : '请在 Android Studio SDK Manager 中安装 Android SDK Platform-Tools。',
        documentationUrl: adbResult?.exitCode == 0
            ? null
            : 'https://developer.android.com/tools/releases/platform-tools',
        documentationLabel: '查看 Platform-Tools',
      ),
    );

    final javaCandidates = <String>[
      if (Platform.environment['JAVA_HOME'] case final javaHome?)
        '$javaHome${separator}bin$separator${Platform.isWindows ? 'java.exe' : 'java'}',
      if (Platform.isMacOS)
        '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java',
      if (Platform.isWindows)
        r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
    ];
    final java =
        javaCandidates.where((path) => File(path).existsSync()).firstOrNull ??
        await _findOnPath(Platform.isWindows ? 'java.exe' : 'java');
    final javaResult = java == null
        ? null
        : await _runCommand(java, const ['-version']);
    items.add(
      DiagnosticItem(
        level: javaResult?.exitCode == 0
            ? EnvironmentDiagnosticLevel.ok
            : EnvironmentDiagnosticLevel.error,
        category: 'Android',
        title: javaResult?.exitCode == 0 ? 'Java/JDK 可用' : '未检测到 Java/JDK',
        detail: javaResult?.exitCode == 0
            ? _firstOutputLine(javaResult!)
            : javaResult?.error ??
                  'JAVA_HOME、PATH 和 Android Studio JBR 中均未找到 java',
        suggestion: javaResult?.exitCode == 0
            ? null
            : '安装 Android Studio 通常会附带 JDK；也可安装独立 JDK 并配置 JAVA_HOME。',
        documentationUrl: javaResult?.exitCode == 0
            ? null
            : 'https://developer.android.com/studio',
        documentationLabel: '下载 Android Studio',
      ),
    );
  }

  Future<void> _checkWindowsTools(
    List<DiagnosticItem> items, {
    required bool requireInstaller,
  }) async {
    final iscc = await _findWindowsExecutable('ISCC.exe', [
      _environment.innoCompilerPath,
      r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
      r'C:\Program Files\Inno Setup 6\ISCC.exe',
    ]);
    if (requireInstaller || iscc != null) {
      items.add(
        DiagnosticItem(
          level: iscc == null
              ? EnvironmentDiagnosticLevel.warning
              : EnvironmentDiagnosticLevel.ok,
          category: 'Windows',
          title: iscc == null ? '未检测到 Inno Setup' : 'Inno Setup 可用',
          detail: iscc ?? 'ISCC.exe 不在常见路径或 PATH 中',
          suggestion: iscc == null
              ? '如需生成 setup.exe，请安装 Inno Setup 6 或在打包时手动选择 ISCC.exe。'
              : null,
          documentationUrl: iscc == null
              ? 'https://jrsoftware.org/isdl.php'
              : null,
          documentationLabel: '下载 Inno Setup',
        ),
      );
    }

    final devenv = await _findVisualStudio();
    items.add(
      DiagnosticItem(
        level: devenv == null
            ? EnvironmentDiagnosticLevel.warning
            : EnvironmentDiagnosticLevel.ok,
        category: 'Windows',
        title: devenv == null ? '未检测到 Visual Studio' : 'Visual Studio 可用',
        detail: devenv ?? 'devenv.exe 不在 PATH 中',
        suggestion: devenv == null
            ? 'Windows 桌面构建需要安装 Visual Studio Desktop development with C++。'
            : null,
        documentationUrl: devenv == null
            ? 'https://visualstudio.microsoft.com/downloads/'
            : null,
        documentationLabel: '下载 Visual Studio',
      ),
    );
  }

  Future<void> _checkMacosTools(List<DiagnosticItem> items) async {
    final xcode = await _runCommand('xcode-select', const ['-p']);
    items.add(
      DiagnosticItem(
        level: xcode.exitCode == 0
            ? EnvironmentDiagnosticLevel.ok
            : EnvironmentDiagnosticLevel.warning,
        category: 'macOS',
        title: xcode.exitCode == 0 ? 'Xcode 命令行工具可用' : '未检测到 Xcode 命令行工具',
        detail: xcode.exitCode == 0 ? xcode.output.trim() : xcode.error,
        suggestion: xcode.exitCode == 0
            ? null
            : '如需构建 iOS/macOS，请安装 Xcode 并运行 xcode-select。',
        documentationUrl: xcode.exitCode == 0
            ? null
            : 'https://developer.apple.com/support/xcode/',
        documentationLabel: '下载 Xcode',
      ),
    );

    final pods = await _runCommand('pod', const ['--version']);
    items.add(
      DiagnosticItem(
        level: pods.exitCode == 0
            ? EnvironmentDiagnosticLevel.ok
            : EnvironmentDiagnosticLevel.warning,
        category: 'macOS',
        title: pods.exitCode == 0 ? 'CocoaPods 可用' : '未检测到 CocoaPods',
        detail: pods.exitCode == 0 ? pods.output.trim() : pods.error,
        suggestion: pods.exitCode == 0
            ? null
            : '新版 Flutter 默认使用 Swift Package Manager；旧项目或部分插件仍可能需要 CocoaPods。',
        documentationUrl: pods.exitCode == 0
            ? null
            : 'https://guides.cocoapods.org/using/getting-started.html',
        documentationLabel: '查看安装说明',
      ),
    );
  }

  Future<void> _checkFlutterDoctor(
    List<DiagnosticItem> items,
    FvmState state,
    FlutterProject? project,
  ) async {
    if (!state.fvmInstalled || state.installed.isEmpty || project == null) {
      return;
    }

    final requiredVersion = project.fvmVersion?.trim();
    InstalledSdk? sdk;
    if (requiredVersion != null && requiredVersion.isNotEmpty) {
      sdk = state.installed
          .where(
            (item) =>
                item.name == requiredVersion ||
                item.flutterVersion == requiredVersion,
          )
          .firstOrNull;
      if (sdk == null) return;
    } else if (state.globalVersion case final globalVersion?) {
      sdk = state.installed
          .where(
            (item) =>
                item.name == globalVersion ||
                item.flutterVersion == globalVersion,
          )
          .firstOrNull;
    }
    sdk ??= state.installed.first;

    final executable =
        '${sdk.directory}${Platform.pathSeparator}bin${Platform.pathSeparator}'
        '${Platform.isWindows ? 'flutter.bat' : 'flutter'}';
    if (!File(executable).existsSync()) {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: 'Flutter Doctor',
          title: 'Flutter SDK 文件不完整',
          detail: '未找到 $executable',
          suggestion: '请删除并重新安装 Flutter ${sdk.flutterVersion}。',
        ),
      );
      return;
    }

    final result = await _runLongCommand(executable, const [
      'doctor',
      '-v',
    ], timeout: const Duration(seconds: 90));
    final sections = _parseDoctorSections(result.output);
    final relevant = sections
        .where((section) => _isRelevantDoctorSection(section.title, project))
        .toList();
    if (relevant.isEmpty) {
      items.add(
        DiagnosticItem(
          level: result.exitCode == 0
              ? EnvironmentDiagnosticLevel.ok
              : EnvironmentDiagnosticLevel.warning,
          category: 'Flutter Doctor',
          title: result.exitCode == 0
              ? 'Flutter Doctor 检查完成'
              : 'Flutter Doctor 未返回可解析结果',
          detail: _truncateDiagnosticDetail(
            result.output.trim().isNotEmpty ? result.output : result.error,
          ),
          suggestion: result.exitCode == 0
              ? null
              : '可在控制台手动运行 flutter doctor -v 查看完整输出。',
        ),
      );
      return;
    }

    for (final section in relevant) {
      final help = _doctorHelp(section);
      items.add(
        DiagnosticItem(
          level: switch (section.marker) {
            '✓' => EnvironmentDiagnosticLevel.ok,
            '!' => EnvironmentDiagnosticLevel.warning,
            _ => EnvironmentDiagnosticLevel.error,
          },
          category: 'Flutter Doctor',
          title: section.title,
          detail: _truncateDiagnosticDetail(section.detail),
          suggestion: help.suggestion,
          documentationUrl: help.url,
          documentationLabel: help.label,
        ),
      );
    }
  }

  List<_DoctorSection> _parseDoctorSections(String output) {
    final sections = <_DoctorSection>[];
    final markerPattern = RegExp(r'^\[([✓!✗Xx])\]\s*(.+)$');
    String? marker;
    String? title;
    var detail = <String>[];

    void flush() {
      if (marker == null || title == null) return;
      sections.add(
        _DoctorSection(
          marker: marker,
          title: title,
          detail: detail.map((line) => line.trim()).join('\n').trim(),
        ),
      );
    }

    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trimLeft();
      final match = markerPattern.firstMatch(line);
      if (match != null) {
        flush();
        marker = match.group(1);
        title = match.group(2)?.trim();
        detail = <String>[];
      } else if (marker != null && line.trim().isNotEmpty) {
        detail.add(line);
      }
    }
    flush();
    return sections;
  }

  bool _isRelevantDoctorSection(String title, FlutterProject project) {
    final normalized = title.toLowerCase();
    if (normalized.startsWith('flutter')) return true;
    if (normalized.contains('android')) return project.hasAndroid;
    if (normalized.contains('xcode')) return project.hasIos || project.hasMacos;
    if (normalized.contains('visual studio')) {
      return Platform.isWindows && project.hasWindows;
    }
    if (normalized.contains('connected device')) return true;
    if (normalized.contains('network resources')) return true;
    return false;
  }

  ({String? suggestion, String? url, String? label}) _doctorHelp(
    _DoctorSection section,
  ) {
    if (section.marker == '✓') {
      return (suggestion: null, url: null, label: null);
    }
    final content = '${section.title}\n${section.detail}'.toLowerCase();
    if (content.contains('license')) {
      return (
        suggestion:
            '请在终端运行 flutter doctor --android-licenses，阅读并接受必需的 Android SDK 许可。',
        url: 'https://docs.flutter.dev/platform-integration/android/setup',
        label: '查看 Android 配置说明',
      );
    }
    if (content.contains('android')) {
      return (
        suggestion: '请在 Android Studio SDK Manager 中安装 Doctor 列出的 SDK 和命令行组件。',
        url: 'https://docs.flutter.dev/platform-integration/android/setup',
        label: '查看 Android 配置说明',
      );
    }
    if (content.contains('xcode')) {
      return (
        suggestion: '请根据 Doctor 提示安装/启动 Xcode，并完成许可协议与命令行工具配置。',
        url: 'https://developer.apple.com/support/xcode/',
        label: '查看 Xcode 说明',
      );
    }
    if (content.contains('visual studio')) {
      return (
        suggestion:
            '请安装 Visual Studio，并勾选 Desktop development with C++ 工作负载及 Doctor 列出的组件。',
        url: 'https://visualstudio.microsoft.com/downloads/',
        label: '下载 Visual Studio',
      );
    }
    return (
      suggestion: '请按 Flutter Doctor 的输出完成所列配置后重新诊断。',
      url: 'https://docs.flutter.dev/install/troubleshoot',
      label: '查看 Flutter 排错文档',
    );
  }

  String _truncateDiagnosticDetail(String detail) {
    final normalized = detail.trim();
    if (normalized.isEmpty) return '未返回详细信息';
    const limit = 1400;
    return normalized.length <= limit
        ? normalized
        : '${normalized.substring(0, limit)}\n……';
  }

  Future<void> _checkMcp(List<DiagnosticItem> items, FvmState state) async {
    if (!state.mcpServerEnabled) {
      items.add(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.info,
          category: 'MCP',
          title: 'MCP 服务未启用',
          detail: '仅当需要让 AI 工具控制 App 时才需要启用。',
        ),
      );
      return;
    }
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        state.mcpServerPort,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: 'MCP',
          title: 'MCP 本地端口可连接',
          detail: '127.0.0.1:${state.mcpServerPort}',
        ),
      );
    } on Object {
      items.add(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: 'MCP',
          title: 'MCP 本地端口不可连接',
          detail: '127.0.0.1:${state.mcpServerPort}',
          suggestion: '请关闭并重新启用 MCP 控制接口，或换一个未被占用的端口。',
        ),
      );
    }
  }

  Directory _buildOutputDirectory(
    String projectPath,
    ProjectBuildTarget target,
  ) {
    final separator = Platform.pathSeparator;
    return switch (target) {
      ProjectBuildTarget.apk => Directory(
        '$projectPath${separator}build${separator}app${separator}outputs'
        '${separator}flutter-apk',
      ),
      ProjectBuildTarget.appbundle => Directory(
        '$projectPath${separator}build${separator}app${separator}outputs'
        '${separator}flutter-aab',
      ),
      ProjectBuildTarget.ios => Directory(
        '$projectPath${separator}build${separator}ios',
      ),
      ProjectBuildTarget.macos => Directory(
        '$projectPath${separator}build${separator}macos${separator}Build'
        '${separator}Products${separator}Release',
      ),
      ProjectBuildTarget.windows => Directory(
        '$projectPath${separator}build${separator}windows${separator}x64'
        '${separator}runner${separator}Release',
      ),
    };
  }

  Future<String?> _findWindowsExecutable(
    String executable,
    List<String> candidates,
  ) async {
    for (final candidate in candidates.where(
      (path) => path.trim().isNotEmpty,
    )) {
      if (await File(candidate).exists()) return candidate;
    }
    final result = await _runCommand('where', [
      executable,
    ], timeout: const Duration(seconds: 2));
    if (result.exitCode != 0) return null;
    return result.output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  Future<String?> _findVisualStudio() async {
    final direct = await _findWindowsExecutable('devenv.exe', const <String>[]);
    if (direct != null) return direct;
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
    if (programFilesX86 == null) return null;
    final vswhere = File(
      '$programFilesX86\\Microsoft Visual Studio\\Installer\\vswhere.exe',
    );
    if (!await vswhere.exists()) return null;
    final result = await _runCommand(vswhere.path, const [
      '-latest',
      '-products',
      '*',
      '-requires',
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
      '-property',
      'installationPath',
    ]);
    if (result.exitCode != 0 || result.output.trim().isEmpty) return null;
    return result.output.trim();
  }

  Future<String?> _findOnPath(String executable) async {
    final finder = Platform.isWindows ? 'where' : 'which';
    final result = await _runCommand(finder, [
      executable,
    ], timeout: const Duration(seconds: 2));
    if (result.exitCode != 0) return null;
    return result.output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  String _firstOutputLine(_CommandResult result) {
    final combined = result.output.trim().isNotEmpty
        ? result.output
        : result.error;
    return combined
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '命令执行成功');
  }

  Future<_CommandResult> _runLongCommand(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) async {
    try {
      final process = await Process.start(
        executable,
        arguments,
        environment: _environment.processEnvironment,
        includeParentEnvironment: false,
        runInShell: Platform.isWindows,
      );
      final outputFuture = process.stdout
          .transform(const SystemEncoding().decoder)
          .join();
      final errorFuture = process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      try {
        final exitCode = await process.exitCode.timeout(timeout);
        return _CommandResult(
          exitCode: exitCode,
          output: await outputFuture,
          error: await errorFuture,
        );
      } on TimeoutException {
        process.kill();
        return _CommandResult(
          exitCode: -1,
          output: await outputFuture,
          error: '命令执行超过 ${timeout.inSeconds} 秒，已终止',
        );
      }
    } on ProcessException catch (error) {
      return _CommandResult(exitCode: -1, output: '', error: error.message);
    } on Object catch (error) {
      return _CommandResult(exitCode: -1, output: '', error: '$error');
    }
  }

  Future<_CommandResult> _runCommand(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        environment: _environment.processEnvironment,
        includeParentEnvironment: false,
        runInShell: Platform.isWindows,
      ).timeout(timeout);
      return _CommandResult(
        exitCode: result.exitCode,
        output: _decode(result.stdout),
        error: _decode(result.stderr),
      );
    } on TimeoutException {
      return const _CommandResult(exitCode: -1, output: '', error: '命令执行超时');
    } on ProcessException catch (error) {
      return _CommandResult(exitCode: -1, output: '', error: error.message);
    } on Object catch (error) {
      return _CommandResult(exitCode: -1, output: '', error: '$error');
    }
  }

  String _decode(Object value) {
    if (value is List<int>) return String.fromCharCodes(value);
    return value.toString();
  }
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.output,
    required this.error,
  });

  final int exitCode;
  final String output;
  final String error;
}

class _DoctorSection {
  const _DoctorSection({
    required this.marker,
    required this.title,
    required this.detail,
  });

  final String marker;
  final String title;
  final String detail;
}
