import 'dart:async';
import 'dart:io';

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
import '../data/distribution_service.dart';
import '../data/pgyer_service.dart';
import '../data/fir_service.dart';
import '../data/custom_command_parser.dart';
import '../data/local_project_service.dart';
import '../data/project_repository.dart';
import '../data/pub_environment_service.dart';
import '../domain/models.dart';
import '../domain/project_models.dart';
import 'console_window_service.dart';
import 'status_menu_service.dart';

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

final fvmServiceProvider = Provider<FvmService>(
  (ref) => FvmService(ref.watch(pubEnvironmentServiceProvider)),
);

final localProjectServiceProvider = Provider<LocalProjectService>(
  (ref) => LocalProjectService(),
);

final distributionServiceProvider = Provider<DistributionService>(
  (ref) => DistributionService(),
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

final flutterCommandServiceProvider = Provider<FlutterCommandService>(
  (ref) => FlutterCommandService(ref.watch(fvmServiceProvider)),
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
  final Map<String, String> _consoleModes = {};
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
            final projectPath = arguments['projectPath'] as String?;
            if (projectPath != null) _clearCommandLogFor(projectPath);
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
      final projects = await ref.read(projectRepositoryProvider).load();
      state = state.copyWith(
        useDomesticMirror: environment.useDomesticMirror,
        mirrorId: environment.mirrorId,
        autoOpenConsoleWindow: environment.autoOpenConsoleWindow,
        showMainWindowConsole: environment.showMainWindowConsole,
        showConsoleQuickCommands: environment.showConsoleQuickCommands,
        buildOpensConsoleWindow: environment.buildOpensConsoleWindow,
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
      final results = await Future.wait<Object?>([
        fvm.detect(),
        ref.read(releaseServiceProvider).fetchReleases(),
        ref.read(releaseServiceProvider).fetchLatestFvmVersion(),
      ]);
      final version = results[0] as String?;
      final releases = results[1] as List<FlutterRelease>;
      final latestStable = releases
          .where((release) => release.channel == ReleaseChannel.stable)
          .firstOrNull;
      state = state.copyWith(
        fvmInstalled: version != null,
        fvmVersion: version,
        releases: releases,
        latestFvmVersion: results[2] as String?,
        latestFlutterVersion: latestStable?.version,
      );
      if (version != null) {
        await refreshInstalled();
      } else {
        unawaited(_startDeviceMonitoring());
      }
      _syncUpdateState(showNotice: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
      _publishStatusMenu();
    }
  }

  Future<void> refreshInstalled() async {
    final fvm = ref.read(fvmServiceProvider);
    try {
      final results = await Future.wait<Object?>([
        fvm.listInstalled(),
        fvm.globalVersion(),
        fvm.cacheSizeBytes(),
      ]);
      final installed = [...results[0] as List<InstalledSdk>]
        ..sort(_compareInstalledSdks);
      state = state.copyWith(
        installed: installed,
        globalVersion: results[1] as String?,
        fvmCacheSizeBytes: results[2] as int,
        errorMessage: null,
      );
      _publishStatusMenu();
      unawaited(_startDeviceMonitoring());
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
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
      final directory = await getDirectoryPath(confirmButtonText: '使用此目录');
      if (directory == null) return;
      state = state.copyWith(
        loading: true,
        errorMessage: null,
        statusMessage: '正在验证本地 FVM…',
      );
      final version = await ref
          .read(fvmServiceProvider)
          .useLocalDirectory(directory);
      state = state.copyWith(
        fvmInstalled: true,
        fvmVersion: version,
        statusMessage: '已使用本地 FVM $version',
      );
      await refreshInstalled();
      _syncUpdateState();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
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
        commandLog: _commandLogs.logFor(path),
        commandRunning: _hasActiveTasks(path),
        activeCommand: _activeLabels(path),
      );
      _publishStatusMenu();
    }
  }

  Future<void> refreshManagedProject() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
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
            onOutput: (output) => _appendCommandLog(path, output),
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
      _clearCommandLogFor(path);
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
    if (_activeCommandTasks.containsKey(taskId)) {
      _appendCommandLog(path, '\n[正在结束当前进程并重新运行]\n');
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
      final service = ref.read(flutterCommandServiceProvider);
      reload
          ? await service.hotReload(taskId)
          : await service.hotRestart(taskId);
      final action = reload ? '热重载' : '项目热重启';
      _appendCommandLog(path, '\n[$action 已触发]\n');
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
                onOutput: (output) => _appendCommandLog(project.path, output),
              )
            : await service.runExternal(
                taskId: taskId,
                executable: command.executable,
                workingDirectory: project.path,
                arguments: command.arguments,
                displayArguments: _maskSensitiveArguments(command.arguments),
                onOutput: (output) => _appendCommandLog(project.path, output),
              );
        if (_stoppingCommandTasks.contains(taskId)) {
          stoppedByUser = true;
          state = state.copyWith(statusMessage: '自定义构建工作流已停止');
          break;
        }
        if (code != 0 && !_stoppingCommandTasks.contains(taskId)) {
          throw Exception('${command.executable} 执行失败（退出码 $code）');
        }
        _appendCommandLog(project.path, '\n${List.filled(72, '─').join()}\n\n');
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
    final path = state.selectedManagedProjectPath;
    if (path == null || _selectedManagedProject?.pathExists != true) {
      return;
    }
    final taskId = _taskId(taskKind, path);
    if (_activeCommandTasks.containsKey(taskId)) return;
    _startCommandTask(taskId, path, label);
    var stoppedByUser = false;
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
              onOutput: (output) => _appendCommandLog(path, output),
            );
        if (_stoppingCommandTasks.contains(taskId)) {
          stoppedByUser = true;
          state = state.copyWith(statusMessage: '$label 已停止');
          break;
        }
        if (code != 0 && !_stoppingCommandTasks.contains(taskId)) {
          throw Exception('$label 失败（退出码 $code）');
        }
        if (afterEach != null) await afterEach(index);
        if (index < commands.length - 1) {
          _appendCommandLog(path, '\n${List.filled(72, '─').join()}\n\n');
        }
      }
      if (!stoppedByUser) {
        state = state.copyWith(statusMessage: '$label 完成');
      }
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      _finishCommandTask(taskId);
    }
  }

  void _appendCommandLog(String projectPath, String output) {
    final log = _commandLogs.append(projectPath, output);
    if (state.selectedManagedProjectPath == projectPath) {
      state = state.copyWith(commandLog: log);
    }
    final tail = log.length > 2000 ? log.substring(log.length - 2000) : log;
    _parseVmServiceUri(projectPath, tail);
    _syncConsoleWindow(projectPath);
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

  void _syncConsoleWindow(String projectPath) {
    unawaited(
      ConsoleWindowService.instance.sync(
        projectPath: projectPath,
        projectTitle: _projectTitle(projectPath),
        commandLog: _commandLogs.logFor(projectPath),
        tasks: _serializedTasks(projectPath),
        showQuickCommands: state.showConsoleQuickCommands,
        consoleMode: _consoleMode(projectPath),
        buildTarget: _projectBuildTarget(projectPath),
      ),
    );
  }

  Future<void> _openConsoleWindow(String projectPath) async {
    try {
      await ConsoleWindowService.instance.openOrFocus(
        projectPath: projectPath,
        projectTitle: _projectTitle(projectPath),
        commandLog: _commandLogs.logFor(projectPath),
        tasks: _serializedTasks(projectPath),
        showQuickCommands: state.showConsoleQuickCommands,
        consoleMode: _consoleMode(projectPath),
        buildTarget: _projectBuildTarget(projectPath),
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openSelectedProjectConsole() async {
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
    _consoleModes[projectPath] = isBuildTask ? 'build' : 'run';
    _activeCommandTasks[taskId] = (projectPath: projectPath, label: label);
    _appendCommandLog(projectPath, '\n▶ $label\n');
    _syncSelectedCommandState();
    state = state.copyWith(errorMessage: null, statusMessage: '$label 已启动');
    if (isBuildTask) {
      if (state.buildOpensConsoleWindow) {
        unawaited(_openConsoleWindow(projectPath));
      } else if (state.selectedManagedProjectPath == projectPath) {
        _mainBuildConsoleProjectPath = projectPath;
        state = state.copyWith(buildConsoleVisible: true);
      }
    } else if (isRunTask && state.autoOpenConsoleWindow) {
      unawaited(_openConsoleWindow(projectPath));
    }
  }

  void _updateCommandTaskLabel(String taskId, String label) {
    final task = _activeCommandTasks[taskId];
    if (task == null) return;
    _activeCommandTasks[taskId] = (projectPath: task.projectPath, label: label);
    _syncSelectedCommandState();
    _syncConsoleWindow(task.projectPath);
  }

  void _finishCommandTask(String taskId) {
    final task = _activeCommandTasks.remove(taskId);
    _stoppingCommandTasks.remove(taskId);
    _syncSelectedCommandState();
    if (task != null) {
      _syncConsoleWindow(task.projectPath);
      if (!_hasActiveTasks(task.projectPath)) {
        unawaited(ConsoleWindowService.instance.close(task.projectPath));
      }
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
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    _clearCommandLogFor(path);
  }

  void _clearCommandLogFor(String path) {
    _commandLogs.clear(path);
    if (state.selectedManagedProjectPath == path) {
      state = state.copyWith(commandLog: '');
    }
    _syncConsoleWindow(path);
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
    _appendCommandLog(project.path, '\n[开始上传 Bugly 符号：$flavor]\n');
    final code = await ref
        .read(flutterCommandServiceProvider)
        .runExternal(
          taskId: taskId,
          executable: 'java',
          workingDirectory: project.path,
          arguments: arguments,
          displayArguments: displayArguments,
          onOutput: (output) => _appendCommandLog(project.path, output),
        );
    if (code != 0) throw Exception('Bugly 上传失败：$flavor（退出码 $code）');
    _appendCommandLog(project.path, '\n✅ 上传完成: $flavor\n');
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

  /// 从已添加项目列表中选择项目路径
  Future<void> chooseProjectPath(String path) async {
    state = state.copyWith(errorMessage: null);
    try {
      state = state.copyWith(
        loading: true,
        projectPath: path,
        projectVersion: null,
        projectTargetVersion: null,
        statusMessage: '正在读取项目当前的 FVM 版本…',
      );
      final project = ref.read(localProjectServiceProvider);
      final version = await project.currentVersion(path);
      String? matchingInstalledVersion;
      if (version != null) {
        for (final sdk in state.installed) {
          if (sdk.name == version || sdk.flutterVersion == version) {
            matchingInstalledVersion = sdk.name;
            break;
          }
        }
      }
      state = state.copyWith(
        projectVersion: version,
        projectTargetVersion: matchingInstalledVersion,
        statusMessage: version == null
            ? '已选择项目，尚未配置 FVM 版本'
            : '项目当前使用 Flutter $version',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  void selectProjectVersion(String? version) {
    state = state.copyWith(projectTargetVersion: version);
  }

  Future<void> applyProjectVersion() async {
    final path = state.projectPath;
    final version = state.projectTargetVersion;
    if (path == null || version == null) return;
    state = state.copyWith(
      loading: true,
      errorMessage: null,
      statusMessage: '正在为项目配置 Flutter $version…',
    );
    try {
      await ref
          .read(fvmServiceProvider)
          .setProjectVersion(projectPath: path, version: version);
      state = state.copyWith(
        projectVersion: version,
        statusMessage: '项目 FVM 版本已设置为 Flutter $version',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
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
}
