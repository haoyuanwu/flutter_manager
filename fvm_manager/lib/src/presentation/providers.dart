import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../data/flutter_release_service.dart';
import '../data/fvm_service.dart';
import '../data/flutter_command_service.dart';
import '../data/flutter_device_monitor.dart';
import '../data/environment_diagnostics_service.dart';
import '../data/distribution_service.dart';
import '../data/pgyer_service.dart';
import '../data/fir_service.dart';
import '../data/custom_command_parser.dart';
import '../data/build_history_repository.dart';
import '../data/local_project_service.dart';
import '../data/project_icon_service.dart';
import '../data/mcp_ai_setup_service.dart';
import '../data/project_repository.dart';
import '../data/pub_environment_service.dart';
import '../data/process_runner.dart';
import '../domain/models.dart';
import '../domain/build_history_models.dart';
import '../domain/project_models.dart';
import 'console_window_service.dart';
import 'mcp_control_server.dart';
import 'status_menu_service.dart';
import '../data/apk_signing_service.dart';
import '../data/apk_install_service.dart';
import '../data/build_directory_watcher.dart';
import '../data/signing_info_service.dart';

final dioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  ),
);

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

final pubEnvironmentServiceProvider = Provider<PubEnvironmentService>(
  (ref) => PubEnvironmentService(),
);

final processRunnerProvider = Provider<ProcessRunner>((ref) {
  final runner = ProcessRunner();
  ref.onDispose(() => unawaited(runner.stopAll()));
  return runner;
});

final fvmServiceProvider = Provider<FvmService>(
  (ref) => FvmService(
    ref.watch(pubEnvironmentServiceProvider),
    onProgress: (message) {
      // 延迟读取，避免 Provider 构造阶段循环依赖。
      Future.microtask(() {
        ref.read(fvmControllerProvider.notifier).showStatus(message);
      });
    },
  ),
);

final localProjectServiceProvider = Provider<LocalProjectService>(
  (ref) => LocalProjectService(),
);

final mcpAiSetupServiceProvider = Provider<McpAiSetupService>(
  (ref) => McpAiSetupService(),
);

final projectIconProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, projectPath) => ProjectIconService().findIcon(projectPath),
);

final distributionServiceProvider = Provider<DistributionService>(
  (ref) => DistributionService(),
);

final buildDirectoryWatcherProvider = Provider<BuildDirectoryWatcher>((ref) {
  final watcher = BuildDirectoryWatcher();
  ref.onDispose(() => watcher.dispose());
  return watcher;
});

final apkSigningServiceProvider = Provider<ApkSigningService>(
  (ref) => ApkSigningService(ref.watch(processRunnerProvider)),
);

final apkInstallServiceProvider = Provider<ApkInstallService>(
  (ref) => ApkInstallService(
    ref.watch(processRunnerProvider),
    ref.watch(pubEnvironmentServiceProvider),
  ),
);

final signingInfoServiceProvider = Provider<SigningInfoService>(
  (ref) => SigningInfoService(ref.watch(processRunnerProvider)),
);

final apkSigningControllerProvider =
    NotifierProvider<ApkSigningController, ApkSigningState>(
      ApkSigningController.new,
    );

class ApkSigningState {
  const ApkSigningState({
    this.unsignedApks = const [],
    this.signedApks = const [],
    this.signingInProgress = false,
    this.signingStatus = '',
  });

  final List<ApkInfo> unsignedApks;
  final List<SignedApkInfo> signedApks;
  final bool signingInProgress;
  final String signingStatus;

  ApkSigningState copyWith({
    List<ApkInfo>? unsignedApks,
    List<SignedApkInfo>? signedApks,
    bool? signingInProgress,
    String? signingStatus,
  }) => ApkSigningState(
    unsignedApks: unsignedApks ?? this.unsignedApks,
    signedApks: signedApks ?? this.signedApks,
    signingInProgress: signingInProgress ?? this.signingInProgress,
    signingStatus: signingStatus ?? this.signingStatus,
  );
}

class ApkSigningController extends Notifier<ApkSigningState> {
  @override
  ApkSigningState build() => const ApkSigningState();

  void addUnsignedApks(List<ApkInfo> apks) {
    final existing = state.unsignedApks.map((a) => a.path).toSet();
    final newApks = apks.where((a) => !existing.contains(a.path)).toList();
    state = state.copyWith(unsignedApks: [...state.unsignedApks, ...newApks]);
  }

  void updateApkOutputName(String path, String outputName) {
    state = state.copyWith(
      unsignedApks: state.unsignedApks.map((apk) {
        return apk.path == path ? apk.copyWith(outputName: outputName) : apk;
      }).toList(),
    );
  }

  void removeUnsignedApk(String path) {
    state = state.copyWith(
      unsignedApks: state.unsignedApks.where((a) => a.path != path).toList(),
    );
  }

  void clearUnsignedApks() {
    state = state.copyWith(unsignedApks: const []);
  }

  void clearSignedApks() {
    state = state.copyWith(signedApks: const [], signingStatus: '');
  }

  Future<void> signSelectedApks({
    required String jksPath,
    required String password,
    required String keyAlias,
    String? outputDir,
    String outputNamePrefix = '',
    String outputNameSuffix = '_signed',
    required List<String> selectedPaths,
  }) async {
    if (selectedPaths.isEmpty) return;

    final service = ref.read(apkSigningServiceProvider);
    final signingOutputDir = outputDir?.trim().isNotEmpty == true
        ? outputDir!.trim()
        : service.defaultOutputDirectory;

    final apksToSign = state.unsignedApks
        .where((a) => selectedPaths.contains(a.path))
        .toList();
    if (apksToSign.isEmpty) return;

    state = state.copyWith(
      signingInProgress: true,
      signingStatus: '正在签名...',
      signedApks: [...state.signedApks],
    );

    final results = <SignedApkInfo>[];
    final total = apksToSign.length;

    for (var i = 0; i < total; i++) {
      final apk = apksToSign[i];
      state = state.copyWith(
        signingStatus: '签名中 (${i + 1}/$total): ${apk.name}',
      );

      final result = await service.signApk(
        apkPath: apk.path,
        jksPath: jksPath,
        password: password,
        keyAlias: keyAlias,
        outputDir: signingOutputDir,
        customBaseName: apk.outputName.isEmpty ? null : apk.outputName,
        outputNamePrefix: outputNamePrefix,
        outputNameSuffix: outputNameSuffix,
      );
      results.add(result);
    }

    state = state.copyWith(
      signingInProgress: false,
      signingStatus:
          '签名完成: ${results.where((r) => r.success).length}/$total 成功',
      signedApks: [...state.signedApks, ...results],
    );
  }
}

final environmentDiagnosticsServiceProvider =
    Provider<EnvironmentDiagnosticsService>(
      (ref) => EnvironmentDiagnosticsService(
        ref.watch(pubEnvironmentServiceProvider),
        ref.watch(fvmServiceProvider),
      ),
    );

final pgyerServiceProvider = Provider<PgyerService>(
  (ref) => PgyerService(ref.watch(dioProvider)),
);

final firServiceProvider = Provider<FirService>(
  (ref) => FirService(ref.watch(dioProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(),
);

final buildHistoryRepositoryProvider = Provider<BuildHistoryRepository>(
  (ref) => BuildHistoryRepository(),
);

final flutterCommandServiceProvider = Provider<FlutterCommandService>(
  (ref) => FlutterCommandService(
    ref.watch(fvmServiceProvider),
    ref.watch(processRunnerProvider),
  ),
);

final flutterDeviceMonitorProvider = Provider<FlutterDeviceMonitor>((ref) {
  final monitor = FlutterDeviceMonitor(ref.watch(fvmServiceProvider));
  ref.onDispose(() => unawaited(monitor.dispose()));
  return monitor;
});

final customCommandParserProvider = Provider<CustomCommandParser>(
  (ref) => CustomCommandParser(),
);

final releaseServiceProvider = Provider<FlutterReleaseService>(
  (ref) => FlutterReleaseService(
    ref.watch(dioProvider),
    ref.watch(pubEnvironmentServiceProvider),
  ),
);

final fvmControllerProvider = NotifierProvider<FvmController, FvmState>(
  FvmController.new,
);

class FvmController extends Notifier<FvmState> {
  final ProjectCommandLogBuffer _commandLogs = ProjectCommandLogBuffer();
  final Map<String, ({String projectPath, String label})> _activeCommandTasks =
      {};
  final Set<String> _stoppingCommandTasks = {};
  final Set<String> _closedConsoleTabIds = {};
  final Set<String> _closingConsoleTabIds = {};
  final Map<String, String> _consoleModes = {};
  final Map<String, int> _mcpRuntimeCursors = {};
  final McpControlServer _mcpControlServer = McpControlServer();
  String? _mainBuildConsoleProjectPath;

  bool get selectedProjectCommandRunning =>
      activeTasksForSelectedProject.isNotEmpty;

  bool get selectedProjectBuildConsoleVisible =>
      state.buildConsoleVisible &&
      _mainBuildConsoleProjectPath == state.selectedManagedProjectPath;

  bool selectedTaskActive(String kind) {
    final path = state.selectedManagedProjectPath;
    return path != null && _activeCommandTasks.containsKey(_taskId(kind, path));
  }

  List<({String id, String label})> get activeTasksForSelectedProject {
    final path = state.selectedManagedProjectPath;
    if (path == null) return const [];
    return _activeCommandTasks.entries
        .where((entry) => entry.value.projectPath == path)
        .map((entry) => (id: entry.key, label: entry.value.label))
        .toList(growable: false);
  }

  List<({String id, String label})> _tasksForProject(String projectPath) =>
      _activeCommandTasks.entries
          .where((entry) => entry.value.projectPath == projectPath)
          .map((entry) => (id: entry.key, label: entry.value.label))
          .toList(growable: false);

  @override
  FvmState build() => const FvmState();

  Future<void> initialize() async {
    if (state.loading) return;
    await StatusMenuService.instance.initialize(
      _openConsoleWindow,
      onRunProjectAction: _runProjectActionFromConsole,
    );
    try {
      await ConsoleWindowService.instance.registerMainHandler((call) async {
        final arguments = call.arguments as Map<dynamic, dynamic>? ?? const {};
        switch (call.method) {
          case 'stopCommand':
            final taskId = arguments['taskId'] as String?;
            if (taskId != null) await stopProjectCommand(taskId);
            return;
          case 'clearCommandLog':
            final tabId =
                arguments['tabId'] as String? ??
                arguments['projectPath'] as String?;
            if (tabId != null) {
              _clearCommandLogFor(
                state.consoleTabs.any((tab) => tab.id == tabId)
                    ? tabId
                    : _tabIdForProjectFallback(tabId),
              );
            }
            return;
          case 'runProjectAction':
            final projectPath = arguments['projectPath'] as String?;
            final action = arguments['action'] as String?;
            if (projectPath != null && action != null) {
              await _runProjectActionFromConsole(projectPath, action);
            }
            return;
          case 'consoleReady':
            final projectPath = arguments['projectPath'] as String?;
            if (projectPath != null) {
              ConsoleWindowService.instance.markReady(projectPath);
            }
            return;
        }
      });
    } on MissingPluginException {
      // Widget tests do not load desktop window plugins.
    }
    state = state.copyWith(loading: true, errorMessage: null);
    final fvm = ref.read(fvmServiceProvider);
    try {
      final environment = ref.read(pubEnvironmentServiceProvider);
      await environment.load();
      try {
        await ref
            .read(buildHistoryRepositoryProvider)
            .recoverInterruptedSessions();
      } on Object {
        // 构建历史恢复失败不应阻断 App 初始化，原文件保留供后续恢复。
      }
      final projects = await ref.read(projectRepositoryProvider).load();
      state = state.copyWith(
        useDomesticMirror: environment.useDomesticMirror,
        mirrorId: environment.mirrorId,
        autoOpenConsoleWindow: environment.autoOpenConsoleWindow,
        showMainWindowConsole: environment.showMainWindowConsole,
        showConsoleQuickCommands: environment.showConsoleQuickCommands,
        buildOpensConsoleWindow: environment.buildOpensConsoleWindow,
        mcpServerEnabled: environment.mcpServerEnabled,
        mcpServerPort: environment.mcpServerPort,
        mcpServerToken: environment.mcpServerToken,
        managedProjects: projects,
        selectedManagedProjectPath:
            state.selectedManagedProjectPath ?? projects.firstOrNull?.path,
        projectBuildTarget: projects.firstOrNull == null
            ? state.projectBuildTarget
            : projects.first.lastBuildTarget,
        projectBuildMode:
            projects.firstOrNull?.lastBuildMode ?? state.projectBuildMode,
        selectedAndroidFlavors:
            projects.firstOrNull?.selectedFlavors ?? const [],
        cleanBeforeBuild: projects.firstOrNull?.cleanBeforeBuild ?? false,
        androidTargetPlatform:
            projects.firstOrNull?.androidTargetPlatform ?? 'android-arm64',
      );
      unawaited(_syncMcpControlServer());
      final version = await fvm.detect();
      state = state.copyWith(
        fvmInstalled: version != null,
        fvmVersion: version,
      );
      if (version != null) {
        unawaited(refreshInstalled());
      } else {
        unawaited(_startDeviceMonitoringAfterDelay());
      }
      unawaited(_refreshReleaseMetadata(showNotice: true));
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
      _publishStatusMenu();
    }
  }

  Future<void> _refreshReleaseMetadata({bool showNotice = false}) async {
    try {
      final results = await Future.wait<Object?>([
        ref.read(releaseServiceProvider).fetchReleases(),
        ref.read(releaseServiceProvider).fetchLatestFvmVersion(),
      ]);
      final releases = results[0] as List<FlutterRelease>;
      final latestStable = releases
          .where((release) => release.channel == ReleaseChannel.stable)
          .firstOrNull;
      state = state.copyWith(
        releases: releases,
        latestFvmVersion: results[1] as String?,
        latestFlutterVersion: latestStable?.version,
      );
      _syncUpdateState(showNotice: showNotice);
      _publishStatusMenu();
    } catch (_) {
      // 网络版本信息不应该阻塞首次启动；失败后用户刷新或下次启动再试。
    }
  }

  Future<void> refreshInstalled({
    bool includeCacheSize = false,
    bool startDeviceMonitoring = true,
  }) async {
    final fvm = ref.read(fvmServiceProvider);
    try {
      final futures = <Future<Object?>>[
        fvm.listInstalled(),
        fvm.globalVersion(),
        if (includeCacheSize) fvm.cacheSizeBytes(),
      ];
      final results = await Future.wait<Object?>(futures);
      final installed = [...results[0] as List<InstalledSdk>]
        ..sort(_compareInstalledSdks);
      state = state.copyWith(
        installed: installed,
        globalVersion: results[1] as String?,
        fvmCacheSizeBytes: includeCacheSize
            ? results[2] as int
            : state.fvmCacheSizeBytes,
        errorMessage: null,
      );
      _publishStatusMenu();
      if (startDeviceMonitoring) unawaited(_startDeviceMonitoringAfterDelay());
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> _startDeviceMonitoringAfterDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _startDeviceMonitoring();
  }

  void selectChannel(ReleaseChannel channel) {
    state = state.copyWith(selectedChannel: channel, releaseDisplayLimit: 30);
  }

  void loadMoreReleases() {
    state = state.copyWith(releaseDisplayLimit: state.releaseDisplayLimit + 30);
  }

  Future<void> installFvm() async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在安装 FVM…',
    );
    try {
      await ref
          .read(fvmServiceProvider)
          .install(
            onOutput: (message) =>
                state = state.copyWith(statusMessage: message.trim()),
          );
      final version = await ref.read(fvmServiceProvider).detect();
      if (version == null) throw Exception('FVM 安装完成，但仍无法检测到可执行文件');
      state = state.copyWith(
        fvmInstalled: true,
        fvmVersion: version,
        statusMessage: 'FVM 安装完成',
      );
      await refreshInstalled();
      _syncUpdateState();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> selectLocalFvmDirectory() async {
    try {
      final directory = await _pickLocalFvmPath();
      if (directory == null) return;
      state = state.copyWith(
        loading: true,
        errorMessage: null,
        statusMessage: '正在验证本地 FVM…',
      );
      final fvm = ref.read(fvmServiceProvider);
      final version = await fvm.useLocalDirectory(directory);
      // 同步可执行路径，保证本次会话立刻可用（不必重启）。
      final confirmed = await fvm.detect();
      final resolvedVersion = (confirmed?.trim().isNotEmpty ?? false)
          ? confirmed!.trim()
          : (version.trim().isEmpty ? '已配置' : version.trim());
      state = state.copyWith(
        fvmInstalled: true,
        fvmVersion: resolvedVersion,
        statusMessage: '已使用本地 FVM $resolvedVersion',
      );
      try {
        await refreshInstalled();
      } on Object catch (error) {
        // SDK 列表失败不影响“已识别 FVM”本身。
        state = state.copyWith(
          statusMessage: '已使用本地 FVM $resolvedVersion',
          errorMessage: _message(error),
        );
      }
      _syncUpdateState();
    } catch (error) {
      state = state.copyWith(
        errorMessage: _message(error),
        statusMessage: null,
      );
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 优先让用户直接选中 fvm 可执行文件，取消后再选目录。
  Future<String?> _pickLocalFvmPath() async {
    try {
      final file = await openFile(
        confirmButtonText: '选择 fvm 程序',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'FVM 可执行文件',
            extensions: ['exe', 'bat', 'cmd'],
          ),
          const XTypeGroup(label: '全部文件'),
        ],
      );
      if (file != null && file.path.isNotEmpty) return file.path;
    } on Object {
      // 某些平台不支持选文件时回退到目录选择。
    }
    return getDirectoryPath(confirmButtonText: '使用此目录');
  }

  Future<void> updateFvm() async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在更新 FVM…',
    );
    try {
      await ref
          .read(fvmServiceProvider)
          .update(
            onOutput: (message) =>
                state = state.copyWith(statusMessage: message.trim()),
          );
      final version = await ref.read(fvmServiceProvider).detect();
      state = state.copyWith(
        fvmInstalled: true,
        fvmVersion: version,
        statusMessage: 'FVM 已更新至 $version',
      );
      await refreshInstalled();
      _syncUpdateState();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> download(FlutterRelease release) async {
    if (!_ensureFvmReady('安装 Flutter ${release.version}')) return;
    state = state.copyWith(
      activeVersion: release.version,
      downloadProgress: 0,
      downloadReceivedBytes: 0,
      downloadTotalBytes: 0,
      downloadBytesPerSecond: 0,
      downloadPhase: '准备下载',
      errorMessage: null,
      statusMessage: '正在下载 Flutter ${release.version}',
    );
    try {
      final cache = await ref.read(fvmServiceProvider).cachePath();
      await ref
          .read(releaseServiceProvider)
          .downloadAndInstall(
            release: release,
            fvmCachePath: cache,
            onProgress: (progress, received, total, speed, phase) =>
                state = state.copyWith(
                  downloadProgress: progress,
                  downloadReceivedBytes: received,
                  downloadTotalBytes: total,
                  downloadBytesPerSecond: speed,
                  downloadPhase: phase,
                ),
          );
      state = state.copyWith(statusMessage: 'Flutter ${release.version} 安装完成');
      await refreshInstalled();
      _syncUpdateState();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(activeVersion: null, downloadProgress: 0);
    }
  }

  void cancelDownload() => ref.read(releaseServiceProvider).cancel();

  Future<void> installRequiredFlutterVersion([String? requestedVersion]) async {
    if (!_ensureFvmReady('安装 Flutter SDK') || state.activeVersion != null) {
      return;
    }
    final version = requestedVersion?.trim().isNotEmpty == true
        ? requestedVersion!.trim()
        : state.latestFlutterVersion;
    final stableReleases =
        state.releases
            .where((release) => release.channel == ReleaseChannel.stable)
            .toList()
          ..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    final release = version == null
        ? stableReleases.firstOrNull
        : state.releases.where((item) => item.version == version).firstOrNull;
    if (release == null) {
      state = state.copyWith(
        errorMessage: version == null
            ? '暂时无法获取推荐 Flutter 版本，请检查网络后重新诊断。'
            : '版本列表中未找到 Flutter $version，请刷新版本信息后重试。',
      );
      return;
    }

    await download(release);
    final installed = state.installed
        .where(
          (sdk) =>
              sdk.name == release.version ||
              sdk.flutterVersion == release.version,
        )
        .firstOrNull;
    if (installed != null && state.globalVersion == null) {
      await setGlobal(installed.name);
    }
  }

  Future<void> addManagedProject() async {
    try {
      final service = ref.read(localProjectServiceProvider);
      final path = await service.chooseDirectory();
      if (path == null) return;
      state = state.copyWith(
        loading: true,
        errorMessage: null,
        statusMessage: '正在读取 Flutter 项目信息…',
      );
      final inspected = await service.inspectProject(path);
      final project = inspected.copyWith(
        lastBuildTarget: _defaultBuildTarget(inspected),
      );
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, project);
      state = state.copyWith(
        managedProjects: projects,
        selectedManagedProjectPath: project.path,
        selectedAndroidFlavors: project.selectedFlavors,
        projectBuildTarget: project.lastBuildTarget,
        projectBuildMode: project.lastBuildMode,
        cleanBeforeBuild: project.cleanBeforeBuild,
        androidTargetPlatform: project.androidTargetPlatform,
        statusMessage: '已添加项目 ${project.displayName}',
      );
      _publishStatusMenu();
      unawaited(_startDeviceMonitoring());
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 通过拖放添加项目
  Future<void> addProjectByDragDrop(String path) async {
    try {
      // 检查是否已经是管理的项目
      final existing = state.managedProjects
          .where((project) => project.path == path)
          .firstOrNull;
      if (existing != null) {
        // 如果已存在，只选中它
        await selectManagedProject(path);
        state = state.copyWith(
          statusMessage: '项目 ${existing.displayName} 已存在，已切换到该项目',
        );
        return;
      }

      state = state.copyWith(
        loading: true,
        errorMessage: null,
        statusMessage: '正在读取拖放的项目信息…',
      );

      final service = ref.read(localProjectServiceProvider);
      final inspected = await service.inspectProject(path);
      final project = inspected.copyWith(
        lastBuildTarget: _defaultBuildTarget(inspected),
      );
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, project);
      state = state.copyWith(
        managedProjects: projects,
        selectedManagedProjectPath: project.path,
        selectedAndroidFlavors: project.selectedFlavors,
        projectBuildTarget: project.lastBuildTarget,
        projectBuildMode: project.lastBuildMode,
        cleanBeforeBuild: project.cleanBeforeBuild,
        androidTargetPlatform: project.androidTargetPlatform,
        statusMessage: '已添加项目 ${project.displayName}',
      );
      _publishStatusMenu();
      unawaited(_startDeviceMonitoring());
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> selectManagedProject(String path) async {
    final current = state.managedProjects
        .where((project) => project.path == path)
        .firstOrNull;
    if (current != null) {
      final updated = current.copyWith(lastOpened: DateTime.now());
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, updated);
      state = state.copyWith(
        managedProjects: projects,
        selectedManagedProjectPath: path,
        selectedAndroidFlavors: updated.selectedFlavors,
        projectBuildTarget: updated.lastBuildTarget,
        projectBuildMode: updated.lastBuildMode,
        cleanBeforeBuild: updated.cleanBeforeBuild,
        androidTargetPlatform: updated.androidTargetPlatform,
        selectedConsoleTabId: state.consoleTabs
            .where((tab) => tab.projectPath == path)
            .lastOrNull
            ?.id,
        commandLog: _commandLogs.logFor(
          state.consoleTabs
                  .where((tab) => tab.projectPath == path)
                  .lastOrNull
                  ?.id ??
              '',
        ),
        commandRunning: _hasActiveTasks(path),
        activeCommand: _activeLabels(path),
      );
      _publishStatusMenu();
    }
  }

  Future<void> refreshManagedProject() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    ref.invalidate(projectIconProvider(path));
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final inspected = await ref
          .read(localProjectServiceProvider)
          .inspectProject(path);
      final previous = state.managedProjects
          .where((item) => item.path == path)
          .firstOrNull;
      final project = previous == null
          ? inspected
          : inspected.copyWith(
              alias: previous.alias,
              bugly: previous.bugly,
              pgyer: previous.pgyer,
              fir: previous.fir,
              selectedFlavors: previous.selectedFlavors,
              lastBuildMode: previous.lastBuildMode,
              lastBuildTarget: previous.lastBuildTarget,
              cleanBeforeBuild: previous.cleanBeforeBuild,
              androidTargetPlatform: previous.androidTargetPlatform,
              useCustomCommands: previous.useCustomCommands,
              customCommandCode: previous.customCommandCode,
            );
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, project);
      state = state.copyWith(
        managedProjects: projects,
        selectedAndroidFlavors: state.selectedAndroidFlavors
            .where(project.androidFlavors.contains)
            .toList(),
        projectBuildTarget: project.lastBuildTarget,
        projectBuildMode: project.lastBuildMode,
        cleanBeforeBuild: project.cleanBeforeBuild,
        androidTargetPlatform: project.androidTargetPlatform,
        statusMessage: '项目信息已刷新',
      );
      _publishStatusMenu();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> removeManagedProject(String path) async {
    final projects = await ref
        .read(projectRepositoryProvider)
        .remove(state.managedProjects, path);
    state = state.copyWith(
      managedProjects: projects,
      selectedManagedProjectPath: projects.firstOrNull?.path,
      selectedAndroidFlavors: const [],
      projectBuildTarget: projects.firstOrNull == null
          ? state.projectBuildTarget
          : projects.first.lastBuildTarget,
      projectBuildMode:
          projects.firstOrNull?.lastBuildMode ?? state.projectBuildMode,
      cleanBeforeBuild: projects.firstOrNull?.cleanBeforeBuild ?? false,
      androidTargetPlatform:
          projects.firstOrNull?.androidTargetPlatform ?? 'android-arm64',
      statusMessage: '项目记录已移除（本地文件未删除）',
    );
    _publishStatusMenu();
  }

  Future<void> relocateManagedProject(FlutterProject missingProject) async {
    try {
      final service = ref.read(localProjectServiceProvider);
      final path = await service.chooseDirectory();
      if (path == null) return;
      final inspected = await service.inspectProject(path);
      final relocated = inspected.copyWith(
        alias: missingProject.alias,
        bugly: missingProject.bugly,
        pgyer: missingProject.pgyer,
        fir: missingProject.fir,
        selectedFlavors: missingProject.selectedFlavors,
        lastBuildMode: missingProject.lastBuildMode,
        lastBuildTarget: missingProject.lastBuildTarget,
        cleanBeforeBuild: missingProject.cleanBeforeBuild,
        androidTargetPlatform: missingProject.androidTargetPlatform,
        useCustomCommands: missingProject.useCustomCommands,
        customCommandCode: missingProject.customCommandCode,
        pathExists: true,
      );
      final projects = await ref
          .read(projectRepositoryProvider)
          .relocate(state.managedProjects, missingProject.path, relocated);
      state = state.copyWith(
        managedProjects: projects,
        selectedManagedProjectPath: relocated.path,
        selectedAndroidFlavors: relocated.selectedFlavors,
        projectBuildMode: relocated.lastBuildMode,
        projectBuildTarget: relocated.lastBuildTarget,
        cleanBeforeBuild: relocated.cleanBeforeBuild,
        androidTargetPlatform: relocated.androidTargetPlatform,
        statusMessage: '项目已重新定位到 ${relocated.path}',
      );
      _publishStatusMenu();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  void toggleAndroidFlavor(String flavor) {
    final selected = [...state.selectedAndroidFlavors];
    selected.contains(flavor) ? selected.remove(flavor) : selected.add(flavor);
    state = state.copyWith(selectedAndroidFlavors: selected);
    _updateSelectedProject(
      (project) => project.copyWith(selectedFlavors: selected),
    );
  }

  void selectProjectBuildMode(ProjectBuildMode mode) {
    state = state.copyWith(projectBuildMode: mode);
    _updateSelectedProject((project) => project.copyWith(lastBuildMode: mode));
  }

  void selectProjectBuildTarget(ProjectBuildTarget target) {
    state = state.copyWith(projectBuildTarget: target);
    _updateSelectedProject(
      (project) => project.copyWith(lastBuildTarget: target),
    );
  }

  void setCleanBeforeBuild(bool value) {
    state = state.copyWith(cleanBeforeBuild: value);
    _updateSelectedProject(
      (project) => project.copyWith(cleanBeforeBuild: value),
    );
  }

  void setAndroidTargetPlatform(String value) {
    state = state.copyWith(androidTargetPlatform: value);
    _updateSelectedProject(
      (project) => project.copyWith(androidTargetPlatform: value),
    );
  }

  void setUseCustomCommands(bool value) {
    _updateSelectedProject(
      (project) => project.copyWith(useCustomCommands: value),
    );
  }

  Future<void> saveCustomCommandCode(String code) async {
    _updateSelectedProject(
      (project) => project.copyWith(customCommandCode: code),
      persist: false,
    );
    await ref.read(projectRepositoryProvider).save(state.managedProjects);
    state = state.copyWith(statusMessage: '自定义构建工作流已保存');
  }

  void updateBuglyConfig(BuglyUploadConfig config) {
    _updateSelectedProject((project) => project.copyWith(bugly: config));
  }

  Future<void> chooseBuglyJar() async {
    try {
      final path = await ref.read(localProjectServiceProvider).chooseBuglyJar();
      if (path == null) return;
      final project = _selectedManagedProject;
      if (project != null) {
        updateBuglyConfig(project.bugly.copyWith(jarPath: path));
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  /// 从项目文件中重新读取 Bundle ID、Version、Build No，
  /// 覆盖 Bugly 配置中的对应字段（保留手动填写的 appId / appKey / jarPath）。
  Future<void> refreshBuglyFromProject() async {
    final project = _selectedManagedProject;
    if (project == null) return;
    try {
      final info = await ref
          .read(localProjectServiceProvider)
          .readProjectInfo(project.path);
      updateBuglyConfig(
        project.bugly.copyWith(
          bundleId: info.bundleId ?? project.bugly.bundleId,
          version: info.version ?? project.bugly.version,
          buildNo: info.buildNo ?? project.bugly.buildNo,
        ),
      );
      state = state.copyWith(
        statusMessage:
            '已从项目读取：'
            '${info.bundleId ?? "-"} / ${info.version ?? "-"} / ${info.buildNo ?? "-"}',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> updateProjectBuildVersion(String version, String buildNo) async {
    final project = _selectedManagedProject;
    if (project == null) return;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在更新项目版本…',
    );
    try {
      final androidSynchronized = await ref
          .read(localProjectServiceProvider)
          .updateProjectVersion(
            project.path,
            version: version,
            buildNo: buildNo,
          );
      final updated = project.copyWith(
        bugly: project.bugly.copyWith(
          version: version.trim(),
          buildNo: buildNo.trim(),
        ),
      );
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, updated);
      state = state.copyWith(
        managedProjects: projects,
        statusMessage:
            '版本已更新为 ${version.trim()}+${buildNo.trim()}'
            '${androidSynchronized ? '，已同步 Android Gradle' : ''}',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> saveBuglyConfig() async {
    final project = _selectedManagedProject;
    if (project == null) return;
    try {
      final projects = await ref
          .read(projectRepositoryProvider)
          .upsert(state.managedProjects, project);
      state = state.copyWith(
        managedProjects: projects,
        statusMessage: 'Bugly 上传配置已保存',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> projectClean() =>
      _runProjectCommand(const ['clean'], label: 'Flutter Clean');

  Future<void> clearProjectBuildDirectory() async {
    final project = _selectedManagedProject;
    if (project == null || !project.pathExists || selectedTaskActive('build')) {
      return;
    }
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在清理 ${project.displayName} 的 build 目录…',
    );
    try {
      final deleted = await ref
          .read(localProjectServiceProvider)
          .clearBuildDirectory(project.path);
      state = state.copyWith(
        statusMessage: deleted ? '已清理项目 build 目录' : '项目中没有 build 目录',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> projectPubGet() =>
      _runProjectCommand(const ['pub', 'get'], label: 'Pub Get');

  Future<void> openProjectDevTools() async {
    if (!_ensureFlutterReady('打开 DevTools')) return;
    final path = state.selectedManagedProjectPath;
    if (path == null || _selectedManagedProject?.pathExists != true) return;
    const label = 'DevTools';
    final taskId = 'devtools:${DateTime.now().microsecondsSinceEpoch}:$path';
    _startCommandTask(taskId, path, label);
    state = state.copyWith(statusMessage: '正在浏览器中打开 DevTools…');
    try {
      final vmUri = state.vmServiceUris?[path];
      final arguments = <String>[
        'devtools',
        '--launch-browser',
        '--port=0',
        ?vmUri,
      ];
      final code = await ref
          .read(flutterCommandServiceProvider)
          .runDart(
            taskId: taskId,
            projectPath: path,
            arguments: arguments,
            onOutput: (output) => _appendCommandLog(taskId, output),
          );
      if (code != 0 && !_stoppingCommandTasks.contains(taskId)) {
        throw Exception('$label 启动失败（退出码 $code）');
      }
      state = state.copyWith(statusMessage: '$label 已停止');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      _finishCommandTask(taskId);
    }
  }

  Future<void> runManagedProject() {
    final path = state.selectedManagedProjectPath;
    if (path != null) {
      _clearCommandLogFor(_taskId('run', path));
      final uris = Map<String, String>.from(state.vmServiceUris ?? const {});
      uris.remove(path);
      state = state.copyWith(vmServiceUris: uris);
    }
    final arguments = <String>['run'];
    final deviceId = state.selectedDeviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      arguments.addAll(['-d', deviceId]);
    }
    if (state.selectedAndroidFlavors.length == 1) {
      arguments.addAll(['--flavor', state.selectedAndroidFlavors.single]);
    }
    return _runProjectCommand(arguments, label: '运行项目', taskKind: 'run');
  }

  Future<void> hotReloadManagedProject() => _sendRuntimeCommand(reload: true);

  Future<void> hotRestartManagedProject() => _sendRuntimeCommand(reload: false);

  Future<void> rerunManagedProject() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    final taskId = _taskId('run', path);
    if (_consoleTabById(taskId) != null) selectConsoleTab(taskId);
    _clearCommandLogFor(taskId);
    if (_activeCommandTasks.containsKey(taskId)) {
      _appendCommandLog(taskId, '\n[正在结束当前进程并重新运行]\n');
      await ref.read(flutterCommandServiceProvider).stop(taskId);
      for (var attempt = 0; attempt < 50; attempt++) {
        if (!_activeCommandTasks.containsKey(taskId)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_activeCommandTasks.containsKey(taskId)) {
        state = state.copyWith(errorMessage: '当前运行进程未能及时结束，请稍后重试');
        return;
      }
    }
    state = state.copyWith(errorMessage: null, statusMessage: '正在重新运行项目…');
    await runManagedProject();
  }

  Future<void> _sendRuntimeCommand({required bool reload}) async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    final taskId = _taskId('run', path);
    if (!_activeCommandTasks.containsKey(taskId)) return;
    try {
      if (!reload) {
        if (_consoleTabById(taskId) != null) selectConsoleTab(taskId);
        _clearCommandLogFor(taskId);
      }
      final service = ref.read(flutterCommandServiceProvider);
      reload
          ? await service.hotReload(taskId)
          : await service.hotRestart(taskId);
      final action = reload ? '热重载' : '项目热重启';
      _appendCommandLog(taskId, '\n[$action 已触发]\n');
      state = state.copyWith(statusMessage: '$action 命令已发送');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> buildManagedProject() {
    final project = _selectedManagedProject;
    if (project == null) return Future.value();
    final target = state.projectBuildTarget.name;
    final isAndroid =
        state.projectBuildTarget == ProjectBuildTarget.apk ||
        state.projectBuildTarget == ProjectBuildTarget.appbundle;
    final flavors = isAndroid && state.selectedAndroidFlavors.isNotEmpty
        ? state.selectedAndroidFlavors.map<String?>((value) => value).toList()
        : <String?>[null];
    final commands = flavors.map((flavor) {
      final arguments = <String>[
        'build',
        target,
        '--${state.projectBuildMode.name}',
      ];
      if (flavor != null) arguments.addAll(['--flavor', flavor]);
      if (state.projectBuildTarget == ProjectBuildTarget.apk) {
        arguments.addAll(['--target-platform', state.androidTargetPlatform]);
      }
      return arguments;
    }).toList();
    if (project.bugly.enabled) {
      final validationError = _validateBuglyBuild(project, flavors);
      if (validationError != null) {
        state = state.copyWith(errorMessage: validationError);
        return Future.value();
      }
    }
    final prefixCount = state.cleanBeforeBuild ? 2 : 0;
    final workflow = <List<String>>[
      if (state.cleanBeforeBuild) ...[
        const ['clean'],
        const ['pub', 'get'],
      ],
      ...commands,
    ];
    return _runProjectCommands(
      workflow,
      label: flavors.length > 1 ? '批量构建 ${flavors.length} 个渠道' : '构建 $target',
      taskKind: 'build',
      afterEach: project.bugly.enabled
          ? (index) async {
              if (index >= prefixCount) {
                await _uploadBuglySymbols(
                  project,
                  flavors[index - prefixCount]!,
                );
              }
            }
          : null,
    );
  }

  Future<void> runCustomBuildWorkflow() async {
    if (!_ensureFlutterReady('运行自定义构建工作流')) return;
    final project = _selectedManagedProject;
    if (project == null ||
        !project.pathExists ||
        selectedTaskActive('workflow')) {
      return;
    }
    try {
      final commands = ref
          .read(customCommandParserProvider)
          .parse(
            project.customCommandCode,
            flavors: state.selectedAndroidFlavors,
            variables: {
              'version': project.bugly.version,
              'buildNo': project.bugly.buildNo,
              'bundleId': project.bugly.bundleId,
              'projectPath': project.path,
              'targetPlatform': state.androidTargetPlatform,
            },
          );
      await _runEditableCommands(project, commands);
    } on FormatException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  Future<void> _runEditableCommands(
    FlutterProject project,
    List<EditableCommand> commands,
  ) async {
    final taskId = _taskId('workflow', project.path);
    _startCommandTask(taskId, project.path, '自定义构建工作流');
    var stoppedByUser = false;
    try {
      for (var index = 0; index < commands.length; index++) {
        final command = commands[index];
        _updateCommandTaskLabel(
          taskId,
          '自定义工作流（${index + 1}/${commands.length}）',
        );
        final service = ref.read(flutterCommandServiceProvider);
        final code = command.executable == 'flutter'
            ? await service.run(
                taskId: taskId,
                projectPath: project.path,
                arguments: command.arguments,
                onOutput: (output) => _appendCommandLog(taskId, output),
              )
            : await service.runExternal(
                taskId: taskId,
                executable: command.executable,
                workingDirectory: project.path,
                arguments: command.arguments,
                displayArguments: _maskSensitiveArguments(command.arguments),
                onOutput: (output) => _appendCommandLog(taskId, output),
              );
        if (_stoppingCommandTasks.contains(taskId)) {
          stoppedByUser = true;
          state = state.copyWith(statusMessage: '自定义构建工作流已停止');
          break;
        }
        if (code != 0 && !_stoppingCommandTasks.contains(taskId)) {
          throw Exception('${command.executable} 执行失败（退出码 $code）');
        }
        _appendCommandLog(taskId, '\n${List.filled(72, '─').join()}\n\n');
      }
      if (!stoppedByUser) {
        state = state.copyWith(statusMessage: '自定义构建工作流完成');
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      _finishCommandTask(taskId);
    }
  }

  List<String> _maskSensitiveArguments(List<String> arguments) {
    final masked = [...arguments];
    final index = masked.indexOf('-appkey');
    if (index >= 0 && index + 1 < masked.length) masked[index + 1] = '********';
    return masked;
  }

  Future<void> _runProjectCommand(
    List<String> arguments, {
    required String label,
    String taskKind = 'operation',
  }) => _runProjectCommands([arguments], label: label, taskKind: taskKind);

  Future<void> _runProjectCommands(
    List<List<String>> commands, {
    required String label,
    String taskKind = 'operation',
    Future<void> Function(int index)? afterEach,
  }) async {
    if (!_ensureFlutterReady(label)) return;
    final path = state.selectedManagedProjectPath;
    if (path == null || _selectedManagedProject?.pathExists != true) {
      return;
    }
    final taskId = _taskId(taskKind, path);
    if (_activeCommandTasks.containsKey(taskId)) return;
    final buildSession = taskKind == 'build'
        ? BuildSession(
            id: 'build-${DateTime.now().microsecondsSinceEpoch}',
            projectPath: path,
            taskId: taskId,
            label: label,
            commands: commands
                .map((arguments) => 'fvm flutter ${arguments.join(' ')}')
                .toList(growable: false),
            target: state.projectBuildTarget.name,
            mode: state.projectBuildMode.name,
            flavors: [...state.selectedAndroidFlavors],
            startedAt: DateTime.now(),
            flutterVersion:
                _selectedManagedProject?.fvmVersion ?? state.globalVersion,
            status: BuildSessionStatus.running,
          )
        : null;
    if (buildSession != null) {
      try {
        await ref
            .read(buildHistoryRepositoryProvider)
            .startSession(buildSession);
      } catch (error) {
        _appendCommandLog(taskId, '\n[构建历史记录启动失败：${_message(error)}]\n');
      }
    }
    _startCommandTask(taskId, path, label);
    var stoppedByUser = false;
    var failed = false;
    int? lastExitCode;
    try {
      for (var index = 0; index < commands.length; index++) {
        _updateCommandTaskLabel(
          taskId,
          commands.length == 1
              ? label
              : '$label（${index + 1}/${commands.length}）',
        );
        final code = await ref
            .read(flutterCommandServiceProvider)
            .run(
              taskId: taskId,
              projectPath: path,
              arguments: commands[index],
              onOutput: (output) => _appendCommandLog(taskId, output),
            );
        lastExitCode = code;
        if (_stoppingCommandTasks.contains(taskId)) {
          stoppedByUser = true;
          state = state.copyWith(statusMessage: '$label 已停止');
          break;
        }
        if (code != 0 && !_stoppingCommandTasks.contains(taskId)) {
          throw Exception(_commandFailureMessage(label, path, code));
        }
        if (afterEach != null) await afterEach(index);
        if (index < commands.length - 1) {
          _appendCommandLog(taskId, '\n${List.filled(72, '─').join()}\n\n');
        }
      }
      if (!stoppedByUser) {
        state = state.copyWith(statusMessage: '$label 完成');
      }
    } catch (error) {
      failed = true;
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      if (buildSession != null) {
        await _completeBuildSession(
          buildSession,
          stoppedByUser: stoppedByUser,
          failed: failed,
          exitCode: lastExitCode,
        );
      }
      _finishCommandTask(taskId);
    }
  }

  Future<void> _completeBuildSession(
    BuildSession session, {
    required bool stoppedByUser,
    required bool failed,
    required int? exitCode,
  }) async {
    try {
      final status = stoppedByUser
          ? BuildSessionStatus.stopped
          : failed
          ? BuildSessionStatus.failed
          : BuildSessionStatus.success;
      final artifacts = status == BuildSessionStatus.success
          ? await ref
                .read(distributionServiceProvider)
                .scanArtifacts(session.projectPath)
          : const <DistributionArtifact>[];
      final earliestModified = session.startedAt.subtract(
        const Duration(seconds: 2),
      );
      final records = artifacts
          .where((artifact) => !artifact.modified.isBefore(earliestModified))
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => BuildArtifactRecord(
              id: '${session.id}-artifact-${entry.key}',
              buildSessionId: session.id,
              projectPath: session.projectPath,
              path: entry.value.path,
              name: entry.value.name,
              type: entry.value.type.name,
              platform: entry.value.platformLabel,
              size: entry.value.size,
              modified: entry.value.modified,
              source: 'build',
              fingerprint:
                  '${entry.value.path}|${entry.value.size}|'
                  '${entry.value.modified.millisecondsSinceEpoch}',
            ),
          )
          .toList(growable: false);
      await ref
          .read(buildHistoryRepositoryProvider)
          .completeSession(
            sessionId: session.id,
            status: status,
            finishedAt: DateTime.now(),
            exitCode: exitCode,
            artifacts: records,
          );
      if (status == BuildSessionStatus.success) {
        _appendCommandLog(
          session.taskId,
          '\n[已记录构建历史，关联 ${records.length} 个新产物]\n',
        );
      }
    } catch (error) {
      _appendCommandLog(session.taskId, '\n[保存构建历史失败：${_message(error)}]\n');
    }
  }

  bool _ensureFvmReady(String action) {
    if (state.fvmInstalled) return true;
    state = state.copyWith(
      errorMessage: '未检测到 FVM，$action 需要先安装或选择本地 FVM。请点击“环境诊断”完成配置。',
    );
    return false;
  }

  bool _ensureFlutterReady(String action) {
    if (!_ensureFvmReady(action)) return false;
    if (state.installed.isEmpty) {
      state = state.copyWith(
        errorMessage: '尚未安装 Flutter SDK，$action 无法执行。请点击“环境诊断”安装推荐版本。',
      );
      return false;
    }
    final requiredVersion = _selectedManagedProject?.fvmVersion?.trim();
    if (requiredVersion != null &&
        requiredVersion.isNotEmpty &&
        !state.installed.any(
          (sdk) =>
              sdk.name == requiredVersion ||
              sdk.flutterVersion == requiredVersion,
        )) {
      state = state.copyWith(
        errorMessage: '当前项目需要 Flutter $requiredVersion，但该版本尚未安装。请点击“环境诊断”完成安装。',
      );
      return false;
    }
    return true;
  }

  void _appendCommandLog(String tabId, String output) {
    if (_closedConsoleTabIds.contains(tabId)) return;
    _commandLogs.append(tabId, output);
    final tab = _consoleTabById(tabId);
    if (tab != null) _bumpMcpRuntimeCursor(tab.projectPath);
    // 主窗口只显示选中标签的内容，其它标签只写缓冲/独立窗口。
    if (state.selectedConsoleTabId == tabId) {
      state = state.copyWith(commandLog: _commandLogs.logFor(tabId));
    }
    final tail = _commandLogs.tailFor(tabId);
    if (tab != null) _parseVmServiceUri(tab.projectPath, tail);
    _syncConsoleWindow(tabId);
  }

  ConsoleTabInfo? _consoleTabById(String tabId) {
    for (final tab in state.consoleTabs) {
      if (tab.id == tabId) return tab;
    }
    return null;
  }

  String _tabIdForProjectFallback(String projectPath) {
    final selected = state.selectedConsoleTabId;
    final selectedTab = selected == null ? null : _consoleTabById(selected);
    if (selectedTab != null && selectedTab.projectPath == projectPath) {
      return selectedTab.id;
    }
    final tab = state.consoleTabs
        .where((item) => item.projectPath == projectPath)
        .lastOrNull;
    return tab?.id ?? _taskId('run', projectPath);
  }

  void selectConsoleTab(String tabId) {
    final tab = _consoleTabById(tabId);
    if (tab == null) return;
    final project = state.managedProjects
        .where((item) => item.path == tab.projectPath)
        .firstOrNull;
    final projectChanged =
        project != null && state.selectedManagedProjectPath != tab.projectPath;
    state = state.copyWith(
      selectedManagedProjectPath: projectChanged
          ? tab.projectPath
          : state.selectedManagedProjectPath,
      selectedAndroidFlavors: projectChanged
          ? project.selectedFlavors
          : state.selectedAndroidFlavors,
      projectBuildTarget: projectChanged
          ? project.lastBuildTarget
          : state.projectBuildTarget,
      projectBuildMode: projectChanged
          ? project.lastBuildMode
          : state.projectBuildMode,
      cleanBeforeBuild: projectChanged
          ? project.cleanBeforeBuild
          : state.cleanBeforeBuild,
      androidTargetPlatform: projectChanged
          ? project.androidTargetPlatform
          : state.androidTargetPlatform,
      commandRunning: projectChanged
          ? _hasActiveTasks(tab.projectPath)
          : state.commandRunning,
      activeCommand: projectChanged
          ? _activeLabels(tab.projectPath)
          : state.activeCommand,
      selectedConsoleTabId: tabId,
      commandLog: _commandLogs.logFor(tabId),
    );
    if (projectChanged) _publishStatusMenu();
  }

  Future<void> closeConsoleTab(String tabId) async {
    final tab = _consoleTabById(tabId);
    if (tab == null || !_closingConsoleTabIds.add(tabId)) return;
    try {
      if (tab.running) {
        await stopProjectCommand(tabId);
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
      return;
    } finally {
      _closingConsoleTabIds.remove(tabId);
    }
    if (_consoleTabById(tabId) == null) return;
    _closedConsoleTabIds.add(tabId);
    final removedIndex = state.consoleTabs.indexWhere(
      (item) => item.id == tabId,
    );
    final tabs = state.consoleTabs.where((item) => item.id != tabId).toList();
    _commandLogs.remove(tabId);
    unawaited(ConsoleWindowService.instance.close(tabId));
    final selected = state.selectedConsoleTabId;
    final nextSelected = selected == tabId && tabs.isNotEmpty
        ? tabs[removedIndex.clamp(0, tabs.length - 1)].id
        : null;
    state = state.copyWith(
      consoleTabs: tabs,
      selectedConsoleTabId: selected == tabId ? null : selected,
      commandLog: selected == tabId ? '' : state.commandLog,
    );
    if (nextSelected != null) selectConsoleTab(nextSelected);
  }

  Future<void> openConsoleTabWindow(String tabId) async {
    final tab = _consoleTabById(tabId);
    if (tab == null) return;
    try {
      await ConsoleWindowService.instance.openOrFocus(
        windowKey: tabId,
        projectPath: tab.projectPath,
        projectTitle: '${_projectTitle(tab.projectPath)} · ${tab.title}',
        commandLog: _commandLogs.logFor(tabId),
        tasks: _serializedTasks(tab.projectPath),
        showQuickCommands: state.showConsoleQuickCommands,
        consoleMode: _consoleMode(tab.projectPath),
        buildTarget: _projectBuildTarget(tab.projectPath),
      );
      _syncConsoleWindow(tabId);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  void _ensureConsoleTab({
    required String tabId,
    required String projectPath,
    required String title,
    required String kind,
  }) {
    _closedConsoleTabIds.remove(tabId);
    final existing = state.consoleTabs;
    final index = existing.indexWhere((item) => item.id == tabId);
    final tab = ConsoleTabInfo(
      id: tabId,
      projectPath: projectPath,
      title: title,
      kind: kind,
      running: true,
    );
    final tabs = [...existing];
    if (index >= 0) {
      tabs[index] = tab;
    } else {
      tabs.add(tab);
    }
    state = state.copyWith(consoleTabs: tabs, selectedConsoleTabId: tabId);
  }

  void _setConsoleTabRunning(String tabId, bool running) {
    final tabs = state.consoleTabs
        .map(
          (item) => item.id == tabId
              ? ConsoleTabInfo(
                  id: item.id,
                  projectPath: item.projectPath,
                  title: item.title,
                  kind: item.kind,
                  running: running,
                )
              : item,
        )
        .toList(growable: false);
    state = state.copyWith(consoleTabs: tabs);
  }

  String _commandFailureMessage(String label, String projectPath, int code) {
    final tail = _commandLogs
        .logFor(_tabIdForProjectFallback(projectPath))
        .toLowerCase();
    if (tail.contains('tls error') ||
        tail.contains('certificate') && tail.contains('pub.dev') ||
        tail.contains('failed to update packages') &&
            tail.contains('pub.dev')) {
      return '$label 失败（退出码 $code）：访问 pub.dev 出现 TLS/证书错误。'
          '请在“环境配置”里切换到国内镜像，或检查 Windows 证书、代理和系统时间后重试。';
    }
    return '$label 失败（退出码 $code）';
  }

  String _projectTitle(String projectPath) =>
      state.managedProjects
          .where((project) => project.path == projectPath)
          .firstOrNull
          ?.displayName ??
      '控制台';

  List<Map<String, String>> _serializedTasks(String projectPath) =>
      _tasksForProject(projectPath)
          .map((task) => {'id': task.id, 'label': task.label})
          .toList(growable: false);

  String _consoleMode(String projectPath) =>
      _consoleModes[projectPath] ?? 'run';

  String _projectBuildTarget(String projectPath) {
    if (state.selectedManagedProjectPath == projectPath) {
      return state.projectBuildTarget.name;
    }
    return state.managedProjects
            .where((project) => project.path == projectPath)
            .firstOrNull
            ?.lastBuildTarget
            .name ??
        ProjectBuildTarget.apk.name;
  }

  void _syncConsoleWindow(String tabId) {
    if (!ConsoleWindowService.instance.isTracking(tabId)) return;
    final tab = _consoleTabById(tabId);
    if (tab == null) return;
    unawaited(
      ConsoleWindowService.instance.sync(
        windowKey: tabId,
        projectPath: tab.projectPath,
        projectTitle: '${_projectTitle(tab.projectPath)} · ${tab.title}',
        commandLog: _commandLogs.logFor(tabId),
        tasks: _serializedTasks(tab.projectPath),
        showQuickCommands: state.showConsoleQuickCommands,
        consoleMode: _consoleMode(tab.projectPath),
        buildTarget: _projectBuildTarget(tab.projectPath),
      ),
    );
  }

  Future<void> _openConsoleWindow(String projectPath) async {
    await openConsoleTabWindow(_tabIdForProjectFallback(projectPath));
  }

  Future<void> openSelectedProjectConsole() async {
    final tabId = state.selectedConsoleTabId;
    if (tabId != null) {
      await openConsoleTabWindow(tabId);
      return;
    }
    final path = state.selectedManagedProjectPath;
    if (path != null) await _openConsoleWindow(path);
  }

  Future<void> _runProjectActionFromConsole(
    String projectPath,
    String action,
  ) async {
    if (state.selectedManagedProjectPath != projectPath) {
      await selectManagedProject(projectPath);
    }
    final Future<void>? command = switch (action) {
      'run' => runManagedProject(),
      'hotReload' => hotReloadManagedProject(),
      'hotRestart' => hotRestartManagedProject(),
      'rerun' => rerunManagedProject(),
      'pubGet' => projectPubGet(),
      'clean' => projectClean(),
      'devtools' => openProjectDevTools(),
      'openBuildOutput' => openBuildOutput(),
      'openApkOutput' => openProjectApkFolder(),
      'packageWindowsInstaller' => packageWindowsInstaller(),
      _ => null,
    };
    if (command != null) unawaited(command);
  }

  Future<void> setAutoOpenConsoleWindow(bool enabled) async {
    await ref
        .read(pubEnvironmentServiceProvider)
        .setAutoOpenConsoleWindow(enabled);
    state = state.copyWith(autoOpenConsoleWindow: enabled);
  }

  Future<void> setShowMainWindowConsole(bool enabled) async {
    await ref
        .read(pubEnvironmentServiceProvider)
        .setShowMainWindowConsole(enabled);
    state = state.copyWith(showMainWindowConsole: enabled);
  }

  Future<void> setShowConsoleQuickCommands(bool enabled) async {
    await ref
        .read(pubEnvironmentServiceProvider)
        .setShowConsoleQuickCommands(enabled);
    state = state.copyWith(showConsoleQuickCommands: enabled);
    for (final project in state.managedProjects) {
      _syncConsoleWindow(project.path);
    }
  }

  Future<void> setBuildOpensConsoleWindow(bool enabled) async {
    await ref
        .read(pubEnvironmentServiceProvider)
        .setBuildOpensConsoleWindow(enabled);
    state = state.copyWith(
      buildOpensConsoleWindow: enabled,
      buildConsoleVisible: enabled ? false : state.buildConsoleVisible,
    );
    if (enabled) _mainBuildConsoleProjectPath = null;
  }

  Future<void> setMcpServerEnabled(bool enabled) async {
    await ref.read(pubEnvironmentServiceProvider).setMcpServerEnabled(enabled);
    state = state.copyWith(mcpServerEnabled: enabled);
    await _syncMcpControlServer();
  }

  Future<void> setMcpServerPort(int port) async {
    final normalized = port.clamp(1024, 65535);
    await ref.read(pubEnvironmentServiceProvider).setMcpServerPort(normalized);
    state = state.copyWith(mcpServerPort: normalized);
    await _syncMcpControlServer();
  }

  Future<void> resetMcpServerToken() async {
    final environment = ref.read(pubEnvironmentServiceProvider);
    await environment.resetMcpServerToken();
    state = state.copyWith(mcpServerToken: environment.mcpServerToken);
    await _syncMcpControlServer();
  }

  Future<void> exportMcpSkill() async {
    try {
      final source = _mcpSkillDirectory();
      if (source == null) {
        throw Exception('未找到项目内 Skill：codex_skills/flutter-manager-mcp');
      }
      final downloads = _downloadsDirectory();
      await downloads.create(recursive: true);
      final outputPath =
          '${downloads.path}${Platform.pathSeparator}flutter-manager-mcp-skill.zip';
      final output = File(outputPath);
      if (await output.exists()) await output.delete();
      final encoder = ZipFileEncoder();
      encoder.create(outputPath);
      encoder.addDirectory(source, includeDirName: true);
      encoder.close();
      await ref.read(localProjectServiceProvider).revealFile(outputPath);
      state = state.copyWith(statusMessage: 'MCP Skill 已导出：$outputPath');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Directory? _mcpSkillDirectory() {
    final candidates = <Directory>[
      Directory(
        '${Directory.current.path}${Platform.pathSeparator}codex_skills'
        '${Platform.pathSeparator}flutter-manager-mcp',
      ),
      Directory(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}codex_skills'
        '${Platform.pathSeparator}flutter-manager-mcp',
      ),
      Directory(
        '${File(Platform.resolvedExecutable).parent.parent.path}'
        '${Platform.pathSeparator}codex_skills'
        '${Platform.pathSeparator}flutter-manager-mcp',
      ),
    ];
    return candidates.where((directory) => directory.existsSync()).firstOrNull;
  }

  Directory _downloadsDirectory() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return Directory('$home${Platform.pathSeparator}Downloads');
    }
    return Directory.current;
  }

  Future<void> _syncMcpControlServer() async {
    if (!state.mcpServerEnabled) {
      await _mcpControlServer.stop();
      return;
    }
    try {
      await _mcpControlServer.start(
        port: state.mcpServerPort,
        token: state.mcpServerToken,
        onToolCall: _handleMcpToolCall,
      );
      state = state.copyWith(
        statusMessage: 'MCP 控制接口已启动：127.0.0.1:${state.mcpServerPort}',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'MCP 控制接口启动失败：${_message(error)}');
    }
  }

  Future<Map<String, dynamic>> _handleMcpToolCall(
    String tool,
    Map<String, dynamic> arguments,
  ) async {
    switch (tool) {
      case 'list_projects':
        return {
          'projects': state.managedProjects.map(_mcpProjectJson).toList(),
        };
      case 'get_current_project':
        final project = _selectedManagedProject;
        return {'project': project == null ? null : _mcpProjectJson(project)};
      case 'select_project':
        final path = await _mcpProjectPath(arguments, requireExisting: false);
        await selectManagedProject(path);
        return {
          'projectPath': path,
          'project': _selectedManagedProject == null
              ? null
              : _mcpProjectJson(_selectedManagedProject!),
        };
      case 'list_devices':
        await _selectMcpProject(arguments);
        if (state.devices.isEmpty && !state.devicesLoading) {
          unawaited(loadDevices());
        }
        return {
          'projectPath': state.selectedManagedProjectPath,
          'devices': state.devices,
          'selectedDeviceId': state.selectedDeviceId,
          'loading': state.devicesLoading,
        };
      case 'run':
        await _selectMcpProject(arguments);
        _applyMcpRunOptions(arguments);
        _openMcpConsole(arguments);
        unawaited(runManagedProject());
        return _mcpCommandStarted('run');
      case 'rerun':
        await _selectMcpProject(arguments);
        _applyMcpRunOptions(arguments);
        _openMcpConsole(arguments);
        unawaited(rerunManagedProject());
        return _mcpCommandStarted('rerun');
      case 'hot_reload':
        return _mcpSendRuntimeCommand(arguments, reload: true);
      case 'hot_restart':
        return _mcpSendRuntimeCommand(arguments, reload: false);
      case 'pub_get':
        await _selectMcpProject(arguments);
        unawaited(projectPubGet());
        return _mcpCommandStarted('pub_get');
      case 'clean':
        await _selectMcpProject(arguments);
        unawaited(projectClean());
        return _mcpCommandStarted('clean');
      case 'build':
        await _selectMcpProject(arguments);
        unawaited(buildManagedProject());
        return _mcpCommandStarted('build');
      case 'devtools':
        await _selectMcpProject(arguments);
        unawaited(openProjectDevTools());
        return _mcpCommandStarted('devtools');
      case 'stop':
        final taskId = arguments['taskId'] as String?;
        final projectPath = await _mcpProjectPath(arguments);
        final resolvedTaskId =
            taskId ?? _tasksForProject(projectPath).firstOrNull?.id;
        if (resolvedTaskId == null) {
          return {'stopped': false, 'message': '当前项目没有正在运行的命令'};
        }
        await stopProjectCommand(resolvedTaskId);
        return {
          'stopped': true,
          'taskId': resolvedTaskId,
          'projectPath': projectPath,
        };
      case 'read_console':
        final projectPath = await _mcpProjectPath(arguments);
        return {
          'projectPath': projectPath,
          'tasks': _serializedTasks(projectPath),
          ..._mcpConsoleSnapshot(projectPath, arguments),
        };
      case 'list_running_projects':
        final projectPaths = _activeCommandTasks.values
            .map((task) => task.projectPath)
            .toSet();
        return {
          'projects': projectPaths
              .map((path) => _mcpRuntimeSnapshot(path, const {'tailChars': 0}))
              .toList(growable: false),
        };
      case 'get_runtime_status':
        final projectPath = await _mcpProjectPath(arguments);
        return _mcpRuntimeSnapshot(projectPath, arguments);
      case 'wait_for_runtime_change':
        return _mcpWaitForRuntimeChange(arguments);
      default:
        throw Exception('未知 MCP 工具：$tool');
    }
  }

  Future<Map<String, dynamic>> _mcpSendRuntimeCommand(
    Map<String, dynamic> arguments, {
    required bool reload,
  }) async {
    await _selectMcpProject(arguments);
    final projectPath = state.selectedManagedProjectPath!;
    final taskId = _taskId('run', projectPath);
    if (!_activeCommandTasks.containsKey(taskId)) {
      throw Exception('当前项目没有正在运行的 Flutter Run');
    }
    if (!reload) {
      if (_consoleTabById(taskId) != null) selectConsoleTab(taskId);
      _clearCommandLogFor(taskId);
    }
    final service = ref.read(flutterCommandServiceProvider);
    reload ? await service.hotReload(taskId) : await service.hotRestart(taskId);
    final action = reload ? 'hot_reload' : 'hot_restart';
    final label = reload ? '热重载' : '热重启';
    _appendCommandLog(taskId, '\n[$label 已由 MCP 触发]\n');
    return {
      'action': action,
      'sent': true,
      'projectPath': projectPath,
      'taskId': taskId,
      'cursor': _mcpRuntimeCursor(projectPath),
    };
  }

  Map<String, dynamic> _mcpRuntimeSnapshot(
    String projectPath,
    Map<String, dynamic> arguments,
  ) {
    final project = state.managedProjects
        .where((item) => item.path == projectPath)
        .firstOrNull;
    final runTaskId = _taskId('run', projectPath);
    return {
      'projectPath': projectPath,
      'project': project == null ? null : _mcpProjectJson(project),
      'running': _hasActiveTasks(projectPath),
      'flutterRunActive': _activeCommandTasks.containsKey(runTaskId),
      'tasks': _serializedTasks(projectPath),
      'vmServiceUri': state.vmServiceUris?[projectPath],
      'cursor': _mcpRuntimeCursor(projectPath),
      ..._mcpConsoleSnapshot(projectPath, arguments, defaultTailChars: 4000),
    };
  }

  Map<String, dynamic> _mcpConsoleSnapshot(
    String projectPath,
    Map<String, dynamic> arguments, {
    int? defaultTailChars,
  }) {
    final log = _commandLogs.logForProject(
      projectPath,
      state.consoleTabs
          .where((tab) => tab.projectPath == projectPath)
          .map((tab) => tab.id),
    );
    final requestedAfter = arguments['afterLogLength'] as int?;
    final requestedTail = arguments['tailChars'] as int? ?? defaultTailChars;
    var start = 0;
    var truncated = false;
    if (requestedAfter != null) {
      if (requestedAfter <= log.length) {
        start = requestedAfter;
      } else {
        truncated = true;
      }
    } else if (requestedTail != null) {
      final tailChars = requestedTail.clamp(0, 20000);
      start = (log.length - tailChars).clamp(0, log.length);
    }
    if (log.length - start > 20000) {
      start = log.length - 20000;
      truncated = true;
    }
    return {
      'log': log.substring(start),
      'logStart': start,
      'logLength': log.length,
      'logTruncated': truncated,
    };
  }

  Future<Map<String, dynamic>> _mcpWaitForRuntimeChange(
    Map<String, dynamic> arguments,
  ) async {
    final projectPath = await _mcpProjectPath(arguments);
    final initialCursor = _mcpRuntimeCursor(projectPath);
    final afterCursor = arguments['afterCursor'] as int? ?? initialCursor;
    final initialLogLength = _commandLogs
        .logForProject(
          projectPath,
          state.consoleTabs
              .where((tab) => tab.projectPath == projectPath)
              .map((tab) => tab.id),
        )
        .length;
    final afterLogLength =
        arguments['afterLogLength'] as int? ?? initialLogLength;
    final timeoutMs = (arguments['timeoutMs'] as int? ?? 15000).clamp(
      1000,
      30000,
    );
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (_mcpRuntimeCursor(projectPath) == afterCursor &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final cursor = _mcpRuntimeCursor(projectPath);
    return {
      'changed': cursor != afterCursor,
      'timedOut': cursor == afterCursor,
      ..._mcpRuntimeSnapshot(projectPath, {
        ...arguments,
        'afterLogLength': afterLogLength,
      }),
    };
  }

  int _mcpRuntimeCursor(String projectPath) =>
      _mcpRuntimeCursors[projectPath] ?? 0;

  void _bumpMcpRuntimeCursor(String projectPath) {
    _mcpRuntimeCursors[projectPath] = _mcpRuntimeCursor(projectPath) + 1;
  }

  Map<String, dynamic> _mcpCommandStarted(String action) {
    final path = state.selectedManagedProjectPath;
    return {
      'action': action,
      'projectPath': path,
      'tasks': path == null ? const [] : _serializedTasks(path),
      'message': '$action 已发起',
    };
  }

  Future<void> _selectMcpProject(Map<String, dynamic> arguments) async {
    final path = await _mcpProjectPath(arguments);
    if (state.selectedManagedProjectPath != path) {
      await selectManagedProject(path);
    }
  }

  void _applyMcpRunOptions(Map<String, dynamic> arguments) {
    final deviceId = (arguments['deviceId'] as String?)?.trim();
    final flavor = (arguments['flavor'] as String?)?.trim();
    state = state.copyWith(
      selectedDeviceId: deviceId?.isNotEmpty == true
          ? deviceId
          : state.selectedDeviceId,
      selectedAndroidFlavors: flavor?.isNotEmpty == true
          ? [flavor!]
          : state.selectedAndroidFlavors,
    );
  }

  void _openMcpConsole(Map<String, dynamic> arguments) {
    final openConsole = arguments['openConsole'] as bool? ?? true;
    final path = state.selectedManagedProjectPath;
    if (openConsole && path != null) {
      unawaited(_openConsoleWindow(path));
    }
  }

  Future<String> _mcpProjectPath(
    Map<String, dynamic> arguments, {
    bool requireExisting = true,
  }) async {
    final requested = (arguments['projectPath'] as String?)?.trim();
    final path = requested?.isNotEmpty == true
        ? requested!
        : state.selectedManagedProjectPath;
    if (path == null) throw Exception('未选择项目，请传入 projectPath');
    final project = state.managedProjects
        .where((item) => item.path == path)
        .firstOrNull;
    if (project == null) throw Exception('项目不在管理列表中：$path');
    if (requireExisting && !project.pathExists) {
      throw Exception('项目目录不存在：$path');
    }
    return path;
  }

  Map<String, dynamic> _mcpProjectJson(FlutterProject project) => {
    'name': project.name,
    'displayName': project.displayName,
    'alias': project.alias,
    'path': project.path,
    'pathExists': project.pathExists,
    'fvmVersion': project.fvmVersion,
    'hasAndroid': project.hasAndroid,
    'hasIos': project.hasIos,
    'hasMacos': project.hasMacos,
    'hasWindows': project.hasWindows,
  };

  static final _vmServiceUriPattern = RegExp(
    r'(?:Dart VM service.*?(?:at:|on)|Observatory listening on)\s*(https?://\S+)',
    caseSensitive: false,
  );

  void _parseVmServiceUri(String projectPath, String output) {
    for (final line in output.split('\n')) {
      final match = _vmServiceUriPattern.firstMatch(line);
      if (match != null) {
        var uri = match.group(1) ?? '';
        uri = uri.replaceAll(RegExp(r'[,\s]+$'), '');
        if (uri.isNotEmpty) {
          final uris = Map<String, String>.from(state.vmServiceUris ?? {});
          uris[projectPath] = uri;
          state = state.copyWith(vmServiceUris: uris);
        }
      }
    }
  }

  String _taskId(String kind, String projectPath) => '$kind::$projectPath';

  bool _hasActiveTasks(String projectPath) =>
      _activeCommandTasks.values.any((task) => task.projectPath == projectPath);

  String? _activeLabels(String projectPath) {
    final labels = _activeCommandTasks.values
        .where((task) => task.projectPath == projectPath)
        .map((task) => task.label)
        .toList();
    return labels.isEmpty ? null : labels.join('、');
  }

  void _startCommandTask(String taskId, String projectPath, String label) {
    final isBuildTask =
        taskId.startsWith('build::') || taskId.startsWith('workflow::');
    final isRunTask =
        taskId.startsWith('run::') || taskId.startsWith('devtools:');
    final kind = isBuildTask
        ? 'build'
        : isRunTask
        ? 'run'
        : 'operation';
    _consoleModes[projectPath] = isBuildTask ? 'build' : 'run';
    _activeCommandTasks[taskId] = (projectPath: projectPath, label: label);
    _ensureConsoleTab(
      tabId: taskId,
      projectPath: projectPath,
      title: label,
      kind: kind,
    );
    _appendCommandLog(taskId, '\n▶ $label\n');
    _syncSelectedCommandState();
    state = state.copyWith(errorMessage: null, statusMessage: '$label 已启动');
    if (isBuildTask) {
      if (state.buildOpensConsoleWindow) {
        unawaited(openConsoleTabWindow(taskId));
      } else if (state.selectedManagedProjectPath == projectPath) {
        _mainBuildConsoleProjectPath = projectPath;
        state = state.copyWith(buildConsoleVisible: true);
      }
    } else if (isRunTask && state.autoOpenConsoleWindow) {
      unawaited(openConsoleTabWindow(taskId));
    }
  }

  void _updateCommandTaskLabel(String taskId, String label) {
    final task = _activeCommandTasks[taskId];
    if (task == null) return;
    _activeCommandTasks[taskId] = (projectPath: task.projectPath, label: label);
    final tabs = state.consoleTabs
        .map(
          (item) => item.id == taskId
              ? ConsoleTabInfo(
                  id: item.id,
                  projectPath: item.projectPath,
                  title: label,
                  kind: item.kind,
                  running: item.running,
                )
              : item,
        )
        .toList(growable: false);
    state = state.copyWith(consoleTabs: tabs);
    _bumpMcpRuntimeCursor(task.projectPath);
    _syncConsoleWindow(taskId);
  }

  void _finishCommandTask(String taskId) {
    final task = _activeCommandTasks.remove(taskId);
    _stoppingCommandTasks.remove(taskId);
    _setConsoleTabRunning(taskId, false);
    _syncSelectedCommandState();
    if (task != null) {
      _bumpMcpRuntimeCursor(task.projectPath);
      _syncConsoleWindow(taskId);
      // 标签保留历史输出；独立窗口也保留，由用户手动关闭。
    }
  }

  void _syncSelectedCommandState() {
    final path = state.selectedManagedProjectPath;
    state = state.copyWith(
      commandRunning: path != null && _hasActiveTasks(path),
      activeCommand: path == null ? null : _activeLabels(path),
    );
    _publishStatusMenu();
  }

  void _publishStatusMenu() {
    final selectedProject = state.managedProjects
        .where((project) => project.path == state.selectedManagedProjectPath)
        .firstOrNull;
    final processes = _activeCommandTasks.entries
        .map((entry) {
          final project = state.managedProjects
              .where((project) => project.path == entry.value.projectPath)
              .firstOrNull;
          return <String, String>{
            'projectPath': entry.value.projectPath,
            'projectName':
                project?.displayName ?? _folderName(entry.value.projectPath),
            'processName': _statusProcessName(entry.key),
          };
        })
        .toList(growable: false);
    unawaited(
      StatusMenuService.instance.update(
        fvmVersion: state.fvmVersion ?? '未检测到',
        flutterVersion:
            selectedProject?.fvmVersion ?? state.globalVersion ?? '未检测到',
        projects: state.managedProjects
            .map(
              (project) => <String, String>{
                'projectPath': project.path,
                'projectName': project.displayName,
              },
            )
            .toList(growable: false),
        processes: processes,
      ),
    );
  }

  String _statusProcessName(String taskId) {
    if (taskId.startsWith('run::')) return 'Run';
    if (taskId.startsWith('devtools:')) return 'DevTools';
    if (taskId.startsWith('build::')) return 'Build';
    if (taskId.startsWith('workflow::')) return 'Workflow';
    return 'Command';
  }

  String _folderName(String path) {
    final segments = path.split(Platform.pathSeparator);
    return segments.where((segment) => segment.isNotEmpty).lastOrNull ?? path;
  }

  Future<void> stopProjectCommand(String taskId) async {
    _stoppingCommandTasks.add(taskId);
    state = state.copyWith(statusMessage: '正在停止命令…');
    await ref
        .read(flutterCommandServiceProvider)
        .stop(taskId, gracefulFlutterRun: taskId.startsWith('run::'));
  }

  void clearCommandLog() {
    final tabId = state.selectedConsoleTabId;
    if (tabId != null) {
      _clearCommandLogFor(tabId);
      return;
    }
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    _clearCommandLogFor(_tabIdForProjectFallback(path));
  }

  void _clearCommandLogFor(String tabId) {
    _commandLogs.clear(tabId);
    final tab = _consoleTabById(tabId);
    if (tab != null) _bumpMcpRuntimeCursor(tab.projectPath);
    if (state.selectedConsoleTabId == tabId) {
      state = state.copyWith(commandLog: '');
    }
    _syncConsoleWindow(tabId);
  }

  void clearStatus() => state = state.copyWith(statusMessage: null);
  void clearError() => state = state.copyWith(errorMessage: null);
  void showStatus(String message) =>
      state = state.copyWith(statusMessage: message, errorMessage: null);
  void showError(Object error) =>
      state = state.copyWith(errorMessage: _message(error));

  Future<void> openProjectApkFolder() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openApkOutput(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openBuildOutput() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref
          .read(localProjectServiceProvider)
          .openBuildOutput(path, state.projectBuildTarget.name);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> packageMacosDmg() async {
    final project = _selectedManagedProject;
    if (project == null) return;
    _consoleModes[project.path] = 'build';
    if (state.buildOpensConsoleWindow) {
      unawaited(_openConsoleWindow(project.path));
    } else {
      _mainBuildConsoleProjectPath = project.path;
      state = state.copyWith(buildConsoleVisible: true);
    }
    state = state.copyWith(loading: true, statusMessage: '正在打包 DMG…');
    try {
      final dmgPath = await ref
          .read(localProjectServiceProvider)
          .packageMacosDmg(project.path, project.name);
      state = state.copyWith(statusMessage: 'DMG 已生成：$dmgPath');
      await ref.read(localProjectServiceProvider).revealFile(dmgPath);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> packageWindowsInstaller({
    String? innoCompilerPath,
    bool rethrowInnoCompilerNotFound = false,
  }) async {
    final project = _selectedManagedProject;
    if (project == null) return;
    _consoleModes[project.path] = 'build';
    if (state.buildOpensConsoleWindow) {
      unawaited(_openConsoleWindow(project.path));
    } else {
      _mainBuildConsoleProjectPath = project.path;
      state = state.copyWith(buildConsoleVisible: true);
    }
    state = state.copyWith(
      loading: true,
      statusMessage: '正在生成 Windows 安装包…',
      errorMessage: null,
    );
    try {
      final environment = ref.read(pubEnvironmentServiceProvider);
      final savedCompilerPath = environment.innoCompilerPath;
      String? compilerPath;
      if (innoCompilerPath?.trim().isNotEmpty == true) {
        compilerPath = innoCompilerPath!.trim();
      } else if (savedCompilerPath.isNotEmpty &&
          File(savedCompilerPath).existsSync()) {
        compilerPath = savedCompilerPath;
      }
      final installerPath = await ref
          .read(localProjectServiceProvider)
          .packageWindowsInnoSetup(
            projectPath: project.path,
            appNameHint: project.displayName,
            innoCompilerPath: compilerPath,
            onOutput: (output) =>
                _appendCommandLog(_taskId('operation', project.path), output),
          );
      state = state.copyWith(statusMessage: 'Windows 安装包已生成：$installerPath');
      await ref.read(localProjectServiceProvider).revealFile(installerPath);
    } on InnoCompilerNotFoundException catch (error) {
      state = state.copyWith(loading: false);
      if (rethrowInnoCompilerNotFound) rethrow;
      state = state.copyWith(errorMessage: _message(error));
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> openProjectFolder() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    await openProjectFolderAt(path);
  }

  Future<void> openProjectFolderAt(String path) async {
    try {
      await ref.read(localProjectServiceProvider).openProjectFolder(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openInAndroidStudio() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    await openInAndroidStudioAt(path);
  }

  Future<void> openInAndroidStudioAt(String path) async {
    try {
      await ref.read(localProjectServiceProvider).openInAndroidStudio(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openAndroidProjectInAndroidStudio() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref
          .read(localProjectServiceProvider)
          .openAndroidModuleInAndroidStudio(path);
      state = state.copyWith(statusMessage: '已在 Android Studio 中打开安卓工程');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openIosProjectInXcode() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openIosProjectInXcode(path);
      state = state.copyWith(statusMessage: '已在 Xcode 中打开 iOS 工程');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openMacosProjectInXcode() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openMacosProjectInXcode(path);
      state = state.copyWith(statusMessage: '已在 Xcode 中打开 macOS 工程');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openWindowsProjectInVisualStudio() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref
          .read(localProjectServiceProvider)
          .openWindowsProjectInVisualStudio(path);
      state = state.copyWith(statusMessage: '已在 Visual Studio 中打开 Windows 工程');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openInVSCode() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    await openInVSCodeAt(path);
  }

  Future<void> openInVSCodeAt(String path) async {
    try {
      await ref.read(localProjectServiceProvider).openInVSCode(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> renameManagedProject(String path, String alias) async {
    final project = state.managedProjects
        .where((item) => item.path == path)
        .firstOrNull;
    if (project == null) return;
    final normalizedAlias = alias.trim();
    final updated = project.copyWith(alias: normalizedAlias);
    final projects = await ref
        .read(projectRepositoryProvider)
        .upsert(state.managedProjects, updated);
    state = state.copyWith(
      managedProjects: projects,
      statusMessage: normalizedAlias.isEmpty
          ? '已恢复显示项目原名 ${project.name}'
          : '项目备注名称已更新为 $normalizedAlias',
    );
    _publishStatusMenu();
  }

  Future<void> updateProjectTags(String path, List<String> tags) async {
    final project = state.managedProjects
        .where((item) => item.path == path)
        .firstOrNull;
    if (project == null) return;
    final updated = project.copyWith(tags: tags);
    final projects = await ref
        .read(projectRepositoryProvider)
        .upsert(state.managedProjects, updated);
    state = state.copyWith(managedProjects: projects, statusMessage: '项目标签已更新');
    _publishStatusMenu();
  }

  Future<void> addProjectTag(String path, String tag) async {
    final project = state.managedProjects
        .where((item) => item.path == path)
        .firstOrNull;
    if (project == null) return;
    if (project.tags.contains(tag)) return;
    final updated = project.copyWith(tags: [...project.tags, tag]);
    final projects = await ref
        .read(projectRepositoryProvider)
        .upsert(state.managedProjects, updated);
    state = state.copyWith(managedProjects: projects);
    _publishStatusMenu();
  }

  Future<void> removeProjectTag(String path, String tag) async {
    final project = state.managedProjects
        .where((item) => item.path == path)
        .firstOrNull;
    if (project == null) return;
    final updated = project.copyWith(
      tags: project.tags.where((t) => t != tag).toList(),
    );
    final projects = await ref
        .read(projectRepositoryProvider)
        .upsert(state.managedProjects, updated);
    state = state.copyWith(managedProjects: projects);
    _publishStatusMenu();
  }

  Future<void> loadDevices() async {
    await _startDeviceMonitoring();
  }

  Future<void> _startDeviceMonitoring() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    final monitor = ref.read(flutterDeviceMonitorProvider);
    if (!monitor.isRunning) {
      state = state.copyWith(devicesLoading: true);
    }
    await ref
        .read(flutterDeviceMonitorProvider)
        .start(
          projectPath: path,
          onDevices: (devices) {
            final selected = state.selectedDeviceId;
            state = state.copyWith(
              devices: devices,
              devicesLoading: false,
              selectedDeviceId:
                  selected != null &&
                      devices.any((device) => device['id'] == selected)
                  ? selected
                  : null,
            );
          },
          onError: (error) {
            final fallbackPath = state.selectedManagedProjectPath;
            if (fallbackPath != null) {
              unawaited(_loadDevicesOnce(fallbackPath));
            }
          },
        );
  }

  Future<void> _loadDevicesOnce(String path) async {
    try {
      final devices = await ref.read(fvmServiceProvider).listDevices(path);
      state = state.copyWith(devices: devices, devicesLoading: false);
    } catch (error) {
      state = state.copyWith(
        devicesLoading: false,
        errorMessage: _message(error),
      );
    }
  }

  void selectDevice(String? deviceId) {
    state = state.copyWith(selectedDeviceId: deviceId);
  }

  Future<void> setManagedProjectFvmVersion(
    String projectPath,
    String version,
  ) async {
    if (!_ensureFvmReady('切换项目 Flutter 版本')) return;
    if (_hasActiveTasks(projectPath)) {
      state = state.copyWith(errorMessage: '项目存在正在运行的命令，请先结束后再切换 Flutter 版本。');
      return;
    }
    if (version.isNotEmpty &&
        !state.installed.any((sdk) => sdk.name == version)) {
      state = state.copyWith(errorMessage: 'Flutter $version 尚未安装，无法切换。');
      return;
    }
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: version.isEmpty
          ? '正在移除项目 FVM 配置…'
          : '正在为项目设置 Flutter $version…',
    );
    try {
      final fvm = ref.read(fvmServiceProvider);
      if (version.isEmpty) {
        // 移除 FVM 版本（删除 .fvmrc 或 .fvm 目录）
        await fvm.removeProjectVersion(projectPath);
      } else {
        await fvm.setProjectVersion(projectPath: projectPath, version: version);
      }
      // 刷新项目列表
      final projects = state.managedProjects.map((p) {
        if (p.path != projectPath) return p;
        return p.copyWith(fvmVersion: version.isEmpty ? null : version);
      }).toList();
      await ref.read(projectRepositoryProvider).save(projects);
      state = state.copyWith(
        managedProjects: projects,
        statusMessage: version.isEmpty
            ? '已移除 FVM 配置'
            : '项目 FVM 版本已设置为 $version',
      );
      _publishStatusMenu();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  String? _validateBuglyBuild(FlutterProject project, List<String?> flavors) {
    if (state.projectBuildTarget != ProjectBuildTarget.apk) {
      return 'Bugly 符号上传仅支持 Android APK 构建';
    }
    if (state.projectBuildMode != ProjectBuildMode.release) {
      return 'Bugly 符号上传需要选择 release 构建模式';
    }
    if (flavors.any((flavor) => flavor == null)) {
      return '启用 Bugly 上传时，请至少选择一个 Android 渠道';
    }
    final config = project.bugly;
    final requiredValues = {
      'Bugly JAR': config.jarPath,
      'App ID': config.appId,
      'App Key': config.appKey,
      'Bundle ID': config.bundleId,
      'Version': config.version,
      'Build No': config.buildNo,
    };
    for (final entry in requiredValues.entries) {
      if (entry.value.trim().isEmpty) return '请填写 ${entry.key}';
    }
    if (!File(config.jarPath).existsSync()) return 'Bugly JAR 文件不存在';
    return null;
  }

  Future<void> _uploadBuglySymbols(
    FlutterProject project,
    String flavor,
  ) async {
    final config = project.bugly;
    final arguments = [
      '-jar',
      config.jarPath,
      '-appid',
      config.appId,
      '-appkey',
      config.appKey,
      '-bundleid',
      config.bundleId,
      '-version',
      config.version,
      '-buildNo',
      config.buildNo,
      '-platform',
      'Android',
      '-inputSymbol',
      './build/app/intermediates/merged_native_libs/'
          '${flavor}Release/out/lib/arm64-v8a',
      '-inputMapping',
      './build/app/outputs/mapping/${flavor}Release/mapping.txt',
    ];
    final displayArguments = [...arguments];
    displayArguments[displayArguments.indexOf('-appkey') + 1] = '********';
    final taskId = _taskId('build', project.path);
    _appendCommandLog(taskId, '\n[开始上传 Bugly 符号：$flavor]\n');
    final code = await ref
        .read(flutterCommandServiceProvider)
        .runExternal(
          taskId: taskId,
          executable: 'java',
          workingDirectory: project.path,
          arguments: arguments,
          displayArguments: displayArguments,
          onOutput: (output) => _appendCommandLog(taskId, output),
        );
    if (code != 0) throw Exception('Bugly 上传失败：$flavor（退出码 $code）');
    _appendCommandLog(taskId, '\n✅ 上传完成: $flavor\n');
  }

  FlutterProject? get _selectedManagedProject {
    final path = state.selectedManagedProjectPath;
    if (path == null) return null;
    return state.managedProjects
        .where((project) => project.path == path)
        .firstOrNull;
  }

  void _updateSelectedProject(
    FlutterProject Function(FlutterProject project) update, {
    bool persist = true,
  }) {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    _updateProjectByPath(path, update, persist: persist);
  }

  void _updateProjectByPath(
    String path,
    FlutterProject Function(FlutterProject project) update, {
    bool persist = true,
  }) {
    final projects = state.managedProjects
        .map((project) => project.path == path ? update(project) : project)
        .toList();
    state = state.copyWith(managedProjects: projects);
    _publishStatusMenu();
    if (persist) {
      unawaited(ref.read(projectRepositoryProvider).save(projects));
    }
  }

  ProjectBuildTarget _defaultBuildTarget(FlutterProject project) {
    if (project.hasAndroid) return ProjectBuildTarget.apk;
    if (project.hasMacos && Platform.isMacOS) return ProjectBuildTarget.macos;
    if (project.hasIos && Platform.isMacOS) return ProjectBuildTarget.ios;
    if (project.hasWindows && Platform.isWindows) {
      return ProjectBuildTarget.windows;
    }
    return ProjectBuildTarget.apk;
  }

  Future<void> setGlobal(String version) async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      await ref.read(fvmServiceProvider).setGlobal(version);
      state = state.copyWith(
        globalVersion: version,
        statusMessage: '全局版本已切换为 $version',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 将 FVM 管理的 Flutter SDK bin 目录设置到系统 PATH。
  ///
  /// [type] 可以是 'default'、'version'、'custom'。
  /// [versionOrPath] 当 type 为 'version' 时是版本号，为 'custom' 时是自定义路径。
  Future<void> setSystemFlutterPath({
    String type = 'default',
    String? versionOrPath,
  }) async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在设置系统 Flutter 环境变量…',
    );
    try {
      final fvm = ref.read(fvmServiceProvider);
      final env = ref.read(pubEnvironmentServiceProvider);

      // 获取 FVM 缓存路径
      final cachePath = await fvm.cachePath();

      String flutterBinPath;
      String displayName;

      if (type == 'custom') {
        // 自定义路径
        if (versionOrPath == null || versionOrPath.isEmpty) {
          throw Exception('请输入 Flutter bin 目录路径');
        }
        flutterBinPath = versionOrPath;
        displayName = flutterBinPath;

        // 验证路径是否存在
        final binDir = Directory(flutterBinPath);
        if (!await binDir.exists()) {
          throw Exception('目录不存在: $flutterBinPath');
        }
      } else if (type == 'version') {
        // 指定版本
        if (versionOrPath == null) {
          throw Exception('请选择一个 Flutter 版本');
        }
        flutterBinPath = versionOrPath;
        displayName = 'Flutter $versionOrPath';
      } else {
        // default 模式
        flutterBinPath = 'default';
        displayName = 'FVM Default';
      }

      // 设置系统环境变量
      await env.setSystemFlutterPath(
        fvmCachePath: cachePath,
        flutterBinPath: flutterBinPath,
        type: type,
      );

      state = state.copyWith(
        statusMessage: '已将 $displayName 添加到系统 PATH，新终端即可生效',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> removeFlutterVersion(InstalledSdk sdk) async {
    if (state.removingVersion != null || sdk.name == state.globalVersion) {
      return;
    }
    state = state.copyWith(
      removingVersion: sdk.name,
      errorMessage: null,
      statusMessage: '正在删除 Flutter ${sdk.flutterVersion}…',
    );
    try {
      await ref.read(fvmServiceProvider).removeVersion(sdk.name);
      await refreshInstalled();
      _syncUpdateState();
      state = state.copyWith(
        statusMessage: 'Flutter ${sdk.flutterVersion} 已删除',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(removingVersion: null);
    }
  }

  Future<void> refreshFvmCacheSize() async {
    if (!state.fvmInstalled || state.fvmCacheLoading) return;
    state = state.copyWith(fvmCacheLoading: true, errorMessage: null);
    try {
      final size = await ref.read(fvmServiceProvider).cacheSizeBytes();
      state = state.copyWith(
        fvmCacheSizeBytes: size,
        statusMessage: 'FVM 缓存大小已刷新',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(fvmCacheLoading: false);
    }
  }

  Future<void> clearUnusedFvmCache() async {
    if (!state.fvmInstalled || state.fvmCacheClearing) return;
    state = state.copyWith(
      fvmCacheClearing: true,
      errorMessage: null,
      statusMessage: '正在清理 FVM 缓存…',
    );
    try {
      final removedBytes = await ref
          .read(fvmServiceProvider)
          .clearInstalledFlutterCache();
      await refreshInstalled();
      _syncUpdateState();
      state = state.copyWith(
        fvmCacheSizeBytes: 0,
        statusMessage: removedBytes > 0
            ? '已清理 Flutter SDK bin/cache ${_formatBytes(removedBytes)}'
            : '没有可清理的 Flutter SDK bin/cache',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(fvmCacheClearing: false);
    }
  }

  Future<void> openFvmDirectory() async {
    try {
      await ref.read(fvmServiceProvider).openFvmDirectory();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openGlobalFlutterDirectory() async {
    try {
      await ref.read(fvmServiceProvider).openGlobalFlutterDirectory();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openInstalledFlutterDirectory(String path) async {
    try {
      await ref.read(fvmServiceProvider).openFlutterDirectory(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> useDomesticMirror() => setMirror('flutter-io');

  Future<void> restoreDefaultEnvironment() => setMirror('official');

  Future<void> setMirror(String mirrorId) async {
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在切换下载源…',
    );
    try {
      await ref.read(pubEnvironmentServiceProvider).setMirror(mirrorId);
      state = state.copyWith(
        mirrorId: mirrorId,
        useDomesticMirror: mirrorId != 'official',
        statusMessage: '下载源已切换',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> testMirror(String mirrorId) async {
    final results = Map<String, int>.from(state.mirrorTestResults);
    results.remove(mirrorId);
    state = state.copyWith(mirrorTestResults: results);
    final ms = await ref
        .read(pubEnvironmentServiceProvider)
        .testMirror(mirrorId);
    results[mirrorId] = ms;
    state = state.copyWith(mirrorTestResults: Map.from(results));
  }

  Future<void> testAllMirrors() async {
    state = state.copyWith(mirrorTestResults: {});
    for (final mirror in PubEnvironmentService.mirrors) {
      final ms = await ref
          .read(pubEnvironmentServiceProvider)
          .testMirror(mirror.id);
      final results = Map<String, int>.from(state.mirrorTestResults);
      results[mirror.id] = ms;
      state = state.copyWith(mirrorTestResults: results);
    }
  }

  Future<bool> switchToFastestAvailableMirror() async {
    if (state.loading) return false;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      mirrorTestResults: {},
      statusMessage: '正在测试全部下载源…',
    );
    try {
      final environment = ref.read(pubEnvironmentServiceProvider);
      final latencies = await Future.wait(
        PubEnvironmentService.mirrors.map(
          (mirror) async =>
              MapEntry(mirror.id, await environment.testMirror(mirror.id)),
        ),
      );
      final results = Map<String, int>.fromEntries(latencies);
      state = state.copyWith(mirrorTestResults: results);
      final available = latencies.where((entry) => entry.value >= 0).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (available.isEmpty) {
        state = state.copyWith(
          errorMessage: '所有 Pub 下载源都无法访问，请检查系统时间、代理、TLS 证书或防火墙。',
        );
        return false;
      }

      final fastest = available.first;
      await environment.setMirror(fastest.key);
      final option = PubEnvironmentService.mirrors
          .where((mirror) => mirror.id == fastest.key)
          .first;
      state = state.copyWith(
        mirrorId: fastest.key,
        useDomesticMirror: fastest.key != 'official',
        statusMessage: '已切换到 ${option.name}（${fastest.value}ms）',
      );
      return true;
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
      return false;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> ignoreFvmUpdate() async {
    final version = state.latestFvmVersion;
    if (version == null) return;
    await ref.read(pubEnvironmentServiceProvider).ignoreFvmVersion(version);
    state = state.copyWith(
      hasFvmUpdate: false,
      updateNotice: null,
      statusMessage: '已忽略 FVM $version 更新提醒',
    );
  }

  Future<void> ignoreFlutterUpdate() async {
    final version = state.latestFlutterVersion;
    if (version == null) return;
    await ref.read(pubEnvironmentServiceProvider).ignoreFlutterVersion(version);
    state = state.copyWith(
      hasFlutterUpdate: false,
      updateNotice: null,
      statusMessage: '已忽略 Flutter $version 更新提醒',
    );
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  void _syncUpdateState({bool showNotice = false}) {
    final environment = ref.read(pubEnvironmentServiceProvider);
    final latestFvm = state.latestFvmVersion;
    final latestFlutter = state.latestFlutterVersion;
    final hasFvmUpdate =
        state.fvmInstalled &&
        latestFvm != null &&
        latestFvm != environment.ignoredFvmVersion &&
        state.fvmVersion != null &&
        _isNewer(latestFvm, state.fvmVersion!);
    final hasFlutterUpdate =
        latestFlutter != null &&
        latestFlutter != environment.ignoredFlutterVersion &&
        !state.installed.any((sdk) => sdk.flutterVersion == latestFlutter);
    final updates = <String>[
      if (hasFlutterUpdate) 'Flutter $latestFlutter',
      if (hasFvmUpdate) 'FVM $latestFvm',
    ];
    state = state.copyWith(
      hasFvmUpdate: hasFvmUpdate,
      hasFlutterUpdate: hasFlutterUpdate,
      updateNotice: showNotice && updates.isNotEmpty
          ? '发现新版本：${updates.join('、')}'
          : state.updateNotice,
    );
  }

  bool _isNewer(String latest, String current) {
    try {
      return Version.parse(latest) > Version.parse(current);
    } on FormatException {
      return latest != current;
    }
  }

  int _compareInstalledSdks(InstalledSdk left, InstalledSdk right) {
    final leftVersion = _tryParseVersion(left.flutterVersion);
    final rightVersion = _tryParseVersion(right.flutterVersion);
    if (leftVersion != null && rightVersion != null) {
      final byVersion = rightVersion.compareTo(leftVersion);
      return byVersion != 0 ? byVersion : left.name.compareTo(right.name);
    }
    if (leftVersion != null) return -1;
    if (rightVersion != null) return 1;
    return right.flutterVersion.compareTo(left.flutterVersion);
  }

  Version? _tryParseVersion(String value) {
    try {
      return Version.parse(value);
    } on FormatException {
      return null;
    }
  }

  FlutterProject? get selectedManagedProject => _selectedManagedProject;

  String get _effectivePgyerApiKey {
    final project = _selectedManagedProject;
    if (project != null && project.pgyer.apiKey.isNotEmpty) {
      return project.pgyer.apiKey;
    }
    return ref.read(pubEnvironmentServiceProvider).globalPgyerApiKey;
  }

  String get _effectiveFirApiToken {
    final project = _selectedManagedProject;
    if (project != null && project.fir.apiToken.isNotEmpty) {
      return project.fir.apiToken;
    }
    return ref.read(pubEnvironmentServiceProvider).globalFirApiToken;
  }

  Future<void> uploadToPgyer(String filePath) async {
    final project = _selectedManagedProject;
    final apiKey = _effectivePgyerApiKey;
    if (apiKey.isEmpty) {
      state = state.copyWith(
        errorMessage: '请先配置蒲公英 API Key（可在设置页面配置全局 Key，或在项目中配置）',
      );
      return;
    }

    state = state.copyWith(
      pgyerUploadProgress: 0,
      pgyerUploadPhase: '准备上传',
      pgyerUploadResult: null,
      errorMessage: null,
    );

    try {
      final result = await ref
          .read(pgyerServiceProvider)
          .uploadApp(
            apiKey: apiKey,
            filePath: filePath,
            installType: project?.pgyer.installType ?? PgyerInstallType.public,
            installPassword:
                project?.pgyer.installType == PgyerInstallType.password
                ? project?.pgyer.installPassword
                : null,
            updateDescription: project?.pgyer.updateDescription,
            onProgress: (progress, phase) {
              state = state.copyWith(
                pgyerUploadProgress: progress,
                pgyerUploadPhase: phase,
              );
            },
          );

      final pgyerShortcut = Uri.tryParse(
        result.downloadUrl,
      )?.pathSegments.where((part) => part.isNotEmpty).lastOrNull;
      if (project != null &&
          pgyerShortcut != null &&
          pgyerShortcut.isNotEmpty) {
        _updateProjectByPath(
          project.path,
          (current) => current.copyWith(
            pgyer: current.pgyer.copyWith(buildShortcutUrl: pgyerShortcut),
          ),
        );
      }

      state = state.copyWith(
        pgyerUploadProgress: 1.0,
        pgyerUploadPhase: '上传完成',
        pgyerUploadResult: result.downloadUrl,
        statusMessage: '蒲公英上传完成: ${result.buildName} ${result.buildVersion}',
      );
    } catch (error) {
      state = state.copyWith(
        pgyerUploadProgress: 0,
        pgyerUploadPhase: '',
        errorMessage: '蒲公英上传失败: ${_message(error)}',
      );
    }
  }

  void updatePgyerConfig(PgyerConfig config) {
    _updateSelectedProject((project) => project.copyWith(pgyer: config));
  }

  void clearPgyerUploadResult() {
    state = state.copyWith(
      pgyerUploadProgress: 0,
      pgyerUploadPhase: '',
      pgyerUploadResult: null,
    );
  }

  Future<void> uploadToFir(String filePath) async {
    final project = _selectedManagedProject;
    final apiToken = _effectiveFirApiToken;
    if (apiToken.isEmpty) {
      state = state.copyWith(
        errorMessage: '请先配置 fir.im API Token（可在设置页面配置全局 Token，或在项目中配置）',
      );
      return;
    }

    final appName = project?.fir.appName.isNotEmpty == true
        ? project!.fir.appName
        : project?.displayName ?? 'App';
    final bundleId = project?.fir.bundleId.isNotEmpty == true
        ? project!.fir.bundleId
        : project?.bugly.bundleId ?? '';
    if (bundleId.isEmpty) {
      state = state.copyWith(errorMessage: '请先配置 Bundle ID');
      return;
    }

    state = state.copyWith(
      firUploadProgress: 0,
      firUploadPhase: '准备上传',
      firUploadResult: null,
      errorMessage: null,
    );

    try {
      final result = await ref
          .read(firServiceProvider)
          .uploadApp(
            apiToken: apiToken,
            filePath: filePath,
            appName: appName,
            bundleId: bundleId,
            version: project?.bugly.version.isNotEmpty == true
                ? project!.bugly.version
                : '1.0.0',
            build: project?.bugly.buildNo.isNotEmpty == true
                ? project!.bugly.buildNo
                : '1',
            changelog: project?.fir.changelog,
            onProgress: (progress, phase) {
              state = state.copyWith(
                firUploadProgress: progress,
                firUploadPhase: phase,
              );
            },
          );

      final shortCode = Uri.tryParse(
        result.downloadUrl,
      )?.pathSegments.where((part) => part.isNotEmpty).lastOrNull;
      if (project != null && shortCode != null && shortCode.isNotEmpty) {
        _updateProjectByPath(
          project.path,
          (current) =>
              current.copyWith(fir: current.fir.copyWith(shortCode: shortCode)),
        );
      }

      state = state.copyWith(
        firUploadProgress: 1.0,
        firUploadPhase: '上传完成',
        firUploadResult: result.downloadUrl,
        statusMessage: 'fir.im 上传完成: ${result.appName} ${result.version}',
      );
    } catch (error) {
      state = state.copyWith(
        firUploadProgress: 0,
        firUploadPhase: '',
        errorMessage: 'fir.im 上传失败: ${_message(error)}',
      );
    }
  }

  void updateFirConfig(FirConfig config) {
    _updateSelectedProject((project) => project.copyWith(fir: config));
  }

  void clearFirUploadResult() {
    state = state.copyWith(
      firUploadProgress: 0,
      firUploadPhase: '',
      firUploadResult: null,
    );
  }

  Future<void> setGlobalPgyerApiKey(String apiKey) async {
    await ref.read(pubEnvironmentServiceProvider).setGlobalPgyerApiKey(apiKey);
  }

  Future<void> setGlobalFirApiToken(String apiToken) async {
    await ref
        .read(pubEnvironmentServiceProvider)
        .setGlobalFirApiToken(apiToken);
  }

  Future<void> setInnoCompilerPath(String path) async {
    await ref.read(pubEnvironmentServiceProvider).setInnoCompilerPath(path);
  }
}
