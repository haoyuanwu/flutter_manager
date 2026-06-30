import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pub_semver/pub_semver.dart';

import '../data/flutter_release_service.dart';
import '../data/fvm_service.dart';
import '../data/flutter_command_service.dart';
import '../data/custom_command_parser.dart';
import '../data/local_project_service.dart';
import '../data/project_repository.dart';
import '../data/pub_environment_service.dart';
import '../domain/models.dart';
import '../domain/project_models.dart';

final dioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ),
  ),
);

final pubEnvironmentServiceProvider = Provider<PubEnvironmentService>(
  (ref) => PubEnvironmentService(),
);

final fvmServiceProvider = Provider<FvmService>(
  (ref) => FvmService(ref.watch(pubEnvironmentServiceProvider)),
);

final localProjectServiceProvider = Provider<LocalProjectService>(
  (ref) => LocalProjectService(),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(),
);

final flutterCommandServiceProvider = Provider<FlutterCommandService>(
  (ref) => FlutterCommandService(ref.watch(fvmServiceProvider)),
);

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
  @override
  FvmState build() => const FvmState();

  Future<void> initialize() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, errorMessage: null);
    final fvm = ref.read(fvmServiceProvider);
    try {
      final environment = ref.read(pubEnvironmentServiceProvider);
      await environment.load();
      final projects = await ref.read(projectRepositoryProvider).load();
      state = state.copyWith(
        useDomesticMirror: environment.useDomesticMirror,
        mirrorId: environment.mirrorId,
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
      if (version != null) await refreshInstalled();
      _syncUpdateState(showNotice: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> refreshInstalled() async {
    final fvm = ref.read(fvmServiceProvider);
    try {
      final results = await Future.wait<Object?>([
        fvm.listInstalled(),
        fvm.globalVersion(),
      ]);
      final installed = [...results[0] as List<InstalledSdk>]
        ..sort(_compareInstalledSdks);
      state = state.copyWith(
        installed: installed,
        globalVersion: results[1] as String?,
        errorMessage: null,
      );
      // 全局加载一次设备列表
      loadDevices();
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
        statusMessage: '已添加项目 ${project.name}',
      );
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
        selectedDeviceId: null,
      );
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
              bugly: previous.bugly,
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
  }

  Future<void> relocateManagedProject(FlutterProject missingProject) async {
    try {
      final service = ref.read(localProjectServiceProvider);
      final path = await service.chooseDirectory();
      if (path == null) return;
      final inspected = await service.inspectProject(path);
      final relocated = inspected.copyWith(
        bugly: missingProject.bugly,
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

  Future<void> projectPubGet() =>
      _runProjectCommand(const ['pub', 'get'], label: 'Pub Get');

  Future<void> runManagedProject() {
    final arguments = <String>['run'];
    final deviceId = state.selectedDeviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      arguments.addAll(['-d', deviceId]);
    }
    if (state.selectedAndroidFlavors.length == 1) {
      arguments.addAll(['--flavor', state.selectedAndroidFlavors.single]);
    }
    return _runProjectCommand(arguments, label: '运行项目');
  }

  Future<void> hotReloadManagedProject() => _sendRuntimeCommand(reload: true);

  Future<void> hotRestartManagedProject() => _sendRuntimeCommand(reload: false);

  Future<void> _sendRuntimeCommand({required bool reload}) async {
    if (!state.commandRunning || state.activeCommand != '运行项目') return;
    try {
      final service = ref.read(flutterCommandServiceProvider);
      reload ? await service.hotReload() : await service.hotRestart();
      final action = reload ? '热重载' : '项目热重启';
      _appendCommandLog('\n[$action 已触发]\n');
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
    if (project == null || !project.pathExists || state.commandRunning) return;
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
    state = state.copyWith(
      commandRunning: true,
      commandLog: '',
      activeCommand: '自定义构建工作流',
      errorMessage: null,
    );
    try {
      for (var index = 0; index < commands.length; index++) {
        final command = commands[index];
        state = state.copyWith(
          activeCommand: '自定义工作流（${index + 1}/${commands.length}）',
        );
        final service = ref.read(flutterCommandServiceProvider);
        final code = command.executable == 'flutter'
            ? await service.run(
                projectPath: project.path,
                arguments: command.arguments,
                onOutput: _appendCommandLog,
              )
            : await service.runExternal(
                executable: command.executable,
                workingDirectory: project.path,
                arguments: command.arguments,
                displayArguments: _maskSensitiveArguments(command.arguments),
                onOutput: _appendCommandLog,
              );
        if (code != 0) {
          throw Exception('${command.executable} 执行失败（退出码 $code）');
        }
        _appendCommandLog('\n${List.filled(72, '─').join()}\n\n');
      }
      state = state.copyWith(statusMessage: '自定义构建工作流完成');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(commandRunning: false, activeCommand: null);
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
  }) => _runProjectCommands([arguments], label: label);

  Future<void> _runProjectCommands(
    List<List<String>> commands, {
    required String label,
    Future<void> Function(int index)? afterEach,
  }) async {
    final path = state.selectedManagedProjectPath;
    if (path == null || _selectedManagedProject?.pathExists != true) {
      return;
    }
    // 如果有旧命令在运行，先停掉
    if (state.commandRunning) {
      await ref.read(flutterCommandServiceProvider).stop();
      // 等待旧进程退出
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    state = state.copyWith(
      commandRunning: true,
      commandLog: '',
      activeCommand: label,
      errorMessage: null,
      statusMessage: '$label 已启动',
    );
    try {
      for (var index = 0; index < commands.length; index++) {
        state = state.copyWith(
          activeCommand: commands.length == 1
              ? label
              : '$label（${index + 1}/${commands.length}）',
        );
        final code = await ref
            .read(flutterCommandServiceProvider)
            .run(
              projectPath: path,
              arguments: commands[index],
              onOutput: _appendCommandLog,
            );
        if (code != 0) throw Exception('$label 失败（退出码 $code）');
        if (afterEach != null) await afterEach(index);
        if (index < commands.length - 1) {
          _appendCommandLog('\n${List.filled(72, '─').join()}\n\n');
        }
      }
      state = state.copyWith(statusMessage: '$label 完成');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(commandRunning: false, activeCommand: null);
    }
  }

  void _appendCommandLog(String output) {
    var log = state.commandLog + output;
    if (log.length > 120000) log = log.substring(log.length - 120000);
    state = state.copyWith(commandLog: log);
  }

  Future<void> stopProjectCommand() async {
    await ref.read(flutterCommandServiceProvider).stop();
    state = state.copyWith(statusMessage: '正在停止命令…');
  }

  void clearCommandLog() => state = state.copyWith(commandLog: '');
  void clearStatus() => state = state.copyWith(statusMessage: null);
  void clearError() => state = state.copyWith(errorMessage: null);

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
    state = state.copyWith(loading: true, statusMessage: '正在打包 DMG…');
    try {
      final dmgPath = await ref
          .read(localProjectServiceProvider)
          .packageMacosDmg(project.path, project.name);
      state = state.copyWith(statusMessage: 'DMG 已生成：$dmgPath');
      // 打开 dmg 所在目录
      await ref
          .read(localProjectServiceProvider)
          .openBuildOutput(project.path, 'macos');
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> openProjectFolder() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openProjectFolder(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openInAndroidStudio() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openInAndroidStudio(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> openInVSCode() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    try {
      await ref.read(localProjectServiceProvider).openInVSCode(path);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<void> loadDevices() async {
    final path = state.selectedManagedProjectPath;
    if (path == null) return;
    state = state.copyWith(devicesLoading: true);
    try {
      final devices = await ref
          .read(localProjectServiceProvider)
          .listDevices(path);
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
    _appendCommandLog('\n[开始上传 Bugly 符号：$flavor]\n');
    final code = await ref
        .read(flutterCommandServiceProvider)
        .runExternal(
          executable: 'java',
          workingDirectory: project.path,
          arguments: arguments,
          displayArguments: displayArguments,
          onOutput: _appendCommandLog,
        );
    if (code != 0) throw Exception('Bugly 上传失败：$flavor（退出码 $code）');
    _appendCommandLog('\n✅ 上传完成: $flavor\n');
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
    final projects = state.managedProjects
        .map((project) => project.path == path ? update(project) : project)
        .toList();
    state = state.copyWith(managedProjects: projects);
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
}
