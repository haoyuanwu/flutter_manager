import 'dart:async';
import 'dart:io';

import '../domain/models.dart';
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
    void Function(List<DiagnosticItem> items)? onItemAdded,
  }) async {
    final startedAt = DateTime.now();
    final items = <DiagnosticItem>[];

    void addItem(DiagnosticItem item) {
      items.add(item);
      onItemAdded?.call(items);
    }

    await _checkFvm(items, addItem);
    await _checkFlutter(items, state, addItem);
    await _checkMirror(items, state, addItem);
    _checkDevices(items, state, addItem);
    await _checkFlutterDoctor(items, state, addItem);
    await _checkMcp(items, state, addItem);

    return EnvironmentDiagnosticReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      items: items,
    );
  }

  Future<void> _checkFvm(
    List<DiagnosticItem> items,
    void Function(DiagnosticItem) addItem,
  ) async {
    final result = await _runCommand('fvm', const ['--version']);
    if (result.exitCode == 0) {
      addItem(
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
      addItem(
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

  Future<void> _checkFlutter(
    List<DiagnosticItem> items,
    FvmState state,
    void Function(DiagnosticItem) addItem,
  ) async {
    if (!state.fvmInstalled) {
      addItem(
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
      addItem(
        const DiagnosticItem(
          level: EnvironmentDiagnosticLevel.error,
          category: 'Flutter',
          title: '尚未安装 Flutter SDK',
          detail: 'FVM 当前没有可供项目使用的 Flutter 版本。',
          suggestion: '安装推荐的 Stable 版本，或在 Flutter 版本页面选择其他版本。',
        ),
      );
    } else {
      addItem(
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
      addItem(
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
      addItem(
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

  Future<void> _checkMirror(
    List<DiagnosticItem> items,
    FvmState state,
    void Function(DiagnosticItem) addItem,
  ) async {
    final latency = await _environment.testMirror(state.mirrorId);
    final mirror = _environment.currentMirror;
    if (latency >= 0) {
      addItem(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: '网络',
          title: '${mirror.name} 连通',
          detail: '延迟 ${latency}ms',
        ),
      );
    } else {
      addItem(
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

  void _checkDevices(
    List<DiagnosticItem> items,
    FvmState state,
    void Function(DiagnosticItem) addItem,
  ) {
    if (state.devicesLoading) {
      addItem(
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
      addItem(
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
    addItem(
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

  Future<void> _checkFlutterDoctor(
    List<DiagnosticItem> items,
    FvmState state,
    void Function(DiagnosticItem) addItem,
  ) async {
    if (!state.fvmInstalled || state.installed.isEmpty) {
      return;
    }

    // 使用全局版本或第一个已安装版本
    InstalledSdk? sdk;
    if (state.globalVersion case final globalVersion?) {
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
      addItem(
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

    if (sections.isEmpty) {
      addItem(
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

    for (final section in sections) {
      final help = _doctorHelp(section);
      addItem(
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

  Future<void> _checkMcp(
    List<DiagnosticItem> items,
    FvmState state,
    void Function(DiagnosticItem) addItem,
  ) async {
    if (!state.mcpServerEnabled) {
      addItem(
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
      addItem(
        DiagnosticItem(
          level: EnvironmentDiagnosticLevel.ok,
          category: 'MCP',
          title: 'MCP 本地端口可连接',
          detail: '127.0.0.1:${state.mcpServerPort}',
        ),
      );
    } on Object {
      addItem(
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
