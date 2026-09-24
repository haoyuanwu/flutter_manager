import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_manager/src/app.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';
import 'package:flutter_manager/src/presentation/pages/console_window_page.dart';

final _searchLog = List.generate(140, (index) {
  final content = 'x' * (index % 7 == 0 ? 100 : 8);
  final match = {5, 65, 125}.contains(index) ? ' TARGET' : '';
  return '$index $content$match';
}).join('\n');

class _TestPubEnvironmentService extends PubEnvironmentService {
  @override
  Future<List<String>> getSystemPath() async => const ['/tmp/fvm/bin'];
}

class _TestController extends FvmController {
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    fvmVersion: '4.1.1',
    latestFvmVersion: '4.1.2',
    globalVersion: '3.44.2',
    installed: const [
      InstalledSdk(
        name: '3.43.0',
        flutterVersion: '3.43.0',
        dartVersion: '3.12.0',
        directory: '/tmp/fvm/versions/3.43.0',
      ),
    ],
    hasFvmUpdate: true,
    hasFlutterUpdate: true,
    activeVersion: '3.44.4',
    downloadProgress: .3,
    downloadReceivedBytes: 10 * 1024 * 1024,
    downloadTotalBytes: 100 * 1024 * 1024,
    downloadBytesPerSecond: 2 * 1024 * 1024,
    downloadPhase: '正在下载',
    projectPath: '/tmp/demo',
    selectedManagedProjectPath: '/tmp/demo',
    showMainWindowConsole: true,
    managedProjects: [
      FlutterProject(
        name: 'demo',
        path: '/tmp/demo',
        lastOpened: DateTime(2026),
        hasAndroid: true,
        androidFlavors: const ['dev', 'prod'],
        androidBuildTypes: const ['debug', 'release'],
        bugly: const BuglyUploadConfig(version: '1.0.0', buildNo: '7'),
      ),
    ],
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ignoreFvmUpdate() async {
    state = state.copyWith(hasFvmUpdate: false);
  }

  @override
  Future<void> ignoreFlutterUpdate() async {
    state = state.copyWith(hasFlutterUpdate: false);
  }

  @override
  Future<void> renameManagedProject(String path, String alias) async {
    state = state.copyWith(
      managedProjects: state.managedProjects
          .map(
            (project) => project.path == path
                ? project.copyWith(alias: alias.trim())
                : project,
          )
          .toList(),
    );
  }
}

class _MissingFvmController extends FvmController {
  @override
  FvmState build() => const FvmState(loading: true);

  @override
  Future<void> initialize() async {
    state = state.copyWith(loading: false);
  }
}

class _CloseTabController extends FvmController {
  _CloseTabController(this.stopGate);

  final Completer<void> stopGate;
  final List<String> stoppedTaskIds = [];

  @override
  FvmState build() => const FvmState(
    consoleTabs: [
      ConsoleTabInfo(
        id: 'run::demo',
        projectPath: 'demo',
        title: '运行项目',
        running: true,
      ),
      ConsoleTabInfo(id: 'build::demo', projectPath: 'demo', title: '构建完成'),
    ],
    selectedConsoleTabId: 'run::demo',
  );

  @override
  Future<void> stopProjectCommand(String taskId) async {
    stoppedTaskIds.add(taskId);
    await stopGate.future;
  }
}

class _PendingProcess implements Process {
  final _exit = Completer<int>();
  bool killed = false;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _exit.complete(0);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AllConsoleTabsController extends FvmController {
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    selectedManagedProjectPath: '/tmp/project-a',
    managedProjects: [
      FlutterProject(
        name: 'project-a',
        alias: '项目 A',
        path: '/tmp/project-a',
        lastOpened: DateTime(2026),
      ),
      FlutterProject(
        name: 'project-b',
        alias: '项目 B',
        path: '/tmp/project-b',
        lastOpened: DateTime(2026),
      ),
    ],
    consoleTabs: [
      const ConsoleTabInfo(
        id: 'run::/tmp/project-a',
        projectPath: '/tmp/project-a',
        title: '运行',
      ),
      const ConsoleTabInfo(
        id: 'build::/tmp/project-b',
        projectPath: '/tmp/project-b',
        title: '构建',
      ),
      ...List.generate(
        12,
        (index) => ConsoleTabInfo(
          id: 'history::$index',
          projectPath: '/tmp/project-a',
          title: '历史命令 $index',
        ),
      ),
    ],
    selectedConsoleTabId: 'run::/tmp/project-a',
    commandLog: '只属于项目 A 的日志',
  );

  @override
  Future<void> initialize() async {}
}

class _RunConsoleController extends FvmController {
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    autoOpenConsoleWindow: false,
    installed: const [
      InstalledSdk(
        name: '3.44.0',
        flutterVersion: '3.44.0',
        dartVersion: '3.12.0',
        directory: '/tmp/flutter',
      ),
    ],
    managedProjects: [
      FlutterProject(
        name: 'demo',
        path: '/tmp/demo',
        lastOpened: DateTime(2026),
      ),
    ],
    selectedManagedProjectPath: '/tmp/demo',
    consoleTabs: const [
      ConsoleTabInfo(
        id: 'build::/tmp/demo',
        projectPath: '/tmp/demo',
        title: '构建',
      ),
    ],
  );
}

class _FakeRunCommandService extends FlutterCommandService {
  _FakeRunCommandService()
    : super(FvmService(PubEnvironmentService()), ProcessRunner());

  final completion = Completer<int>();
  void Function(String)? emit;
  bool restarted = false;

  @override
  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String output) onOutput,
  }) {
    emit = onOutput;
    return completion.future;
  }

  @override
  Future<void> hotRestart(String taskId) async {
    restarted = true;
  }
}

class _RerunConsoleController extends FvmController {
  bool runStarted = false;

  @override
  FvmState build() => const FvmState(
    selectedManagedProjectPath: '/tmp/demo',
    consoleTabs: [
      ConsoleTabInfo(
        id: 'run::/tmp/demo',
        projectPath: '/tmp/demo',
        title: '运行',
      ),
      ConsoleTabInfo(
        id: 'build::/tmp/demo',
        projectPath: '/tmp/demo',
        title: '构建',
      ),
    ],
    selectedConsoleTabId: 'build::/tmp/demo',
    commandLog: '旧构建日志',
  );

  @override
  Future<void> runManagedProject() async {
    runStarted = true;
  }
}

class _SearchConsoleController extends FvmController {
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    showMainWindowConsole: true,
    managedProjects: [
      FlutterProject(
        name: 'search',
        path: '/tmp/search',
        lastOpened: DateTime(2026),
      ),
    ],
    selectedManagedProjectPath: '/tmp/search',
    consoleTabs: const [
      ConsoleTabInfo(
        id: 'run::/tmp/search',
        projectPath: '/tmp/search',
        title: '运行',
      ),
    ],
    selectedConsoleTabId: 'run::/tmp/search',
    commandLog: _searchLog,
  );

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('main console Enter visits search results in order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_SearchConsoleController.new),
        ],
        child: const FvmManagerApp(),
      ),
    );
    await tester.tap(find.text('项目管理'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('搜索日志 (⌘F)'));
    await tester.tap(find.byTooltip('搜索日志 (⌘F)'));
    await tester.pump();
    final field = find.byKey(const ValueKey('command-console-search-field'));
    await tester.enterText(field, 'target');
    await tester.pump();
    expect(find.text('共 3 处 · 0/3'), findsOneWidget);

    final output = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('command-console-output-scroll')),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 1/3'), findsOneWidget);
    final firstOffset = output.controller!.offset;

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 2/3'), findsOneWidget);
    final secondOffset = output.controller!.offset;
    expect(secondOffset, greaterThan(firstOffset));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 3/3'), findsOneWidget);
    expect(output.controller!.offset, greaterThan(secondOffset));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 1/3'), findsOneWidget);
    expect(output.controller!.offset, closeTo(firstOffset, 1));
  });

  testWidgets('separate console Enter visits search results in order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ConsoleWindowApp(
        windowId: 'search',
        projectTitle: 'search',
        projectPath: '/tmp/search',
        initialCommandLog: _searchLog,
        initialTasks: const [],
        initialShowQuickCommands: false,
        initialConsoleMode: 'run',
        initialBuildTarget: 'apk',
        initialActionChannelName: 'fvm_manager/console_commands',
      ),
    );
    await tester.tap(find.byTooltip('搜索输出'));
    await tester.pump();
    final field = find.byKey(const ValueKey('command-console-search-field'));
    await tester.enterText(field, 'target');
    await tester.pump();
    expect(find.text('共 3 处 · 0/3'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 1/3'), findsOneWidget);
    final output = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('console-window-output-scroll')),
    );
    final firstOffset = output.controller!.offset;

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('共 3 处 · 2/3'), findsOneWidget);
    expect(output.controller!.offset, greaterThan(firstOffset));
  });

  test('rerun selects and clears the run tab', () async {
    final controller = _RerunConsoleController();
    final container = ProviderContainer(
      overrides: [fvmControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);
    container.read(fvmControllerProvider);

    await controller.rerunManagedProject();

    final state = container.read(fvmControllerProvider);
    expect(controller.runStarted, isTrue);
    expect(state.selectedConsoleTabId, 'run::/tmp/demo');
    expect(state.commandLog, isEmpty);
  });

  test('hot restart clears the full run tab before new output', () async {
    final commandService = _FakeRunCommandService();
    final container = ProviderContainer(
      overrides: [
        fvmControllerProvider.overrideWith(_RunConsoleController.new),
        flutterCommandServiceProvider.overrideWithValue(commandService),
      ],
    );
    addTearDown(container.dispose);
    container.read(fvmControllerProvider);
    final controller = container.read(fvmControllerProvider.notifier);
    final running = controller.runManagedProject();
    commandService.emit!('旧输出');
    expect(container.read(fvmControllerProvider).commandLog, contains('旧输出'));
    controller.selectConsoleTab('build::/tmp/demo');

    await controller.hotRestartManagedProject();

    final state = container.read(fvmControllerProvider);
    expect(commandService.restarted, isTrue);
    expect(state.selectedConsoleTabId, 'run::/tmp/demo');
    expect(state.commandLog, isNot(contains('旧输出')));
    expect(state.commandLog, contains('项目热重启 已触发'));

    commandService.completion.complete(0);
    await running;
  });

  testWidgets('main console shows tabs from all projects and one log', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_AllConsoleTabsController.new),
        ],
        child: const FvmManagerApp(),
      ),
    );

    await tester.tap(find.text('项目管理'));
    await tester.pump();
    expect(find.text('项目 A · 运行'), findsOneWidget);
    expect(find.text('项目 B · 构建'), findsOneWidget);
    final tabList = tester.widget<ListView>(
      find.byKey(const ValueKey('console-tabs-horizontal-scroll')),
    );
    expect(tabList.scrollDirection, Axis.horizontal);
    expect(tabList.controller!.position.maxScrollExtent, greaterThan(0));

    await tester.ensureVisible(find.text('项目 B · 构建'));
    await tester.tap(find.text('项目 B · 构建'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FvmManagerApp)),
    );
    final state = container.read(fvmControllerProvider);
    expect(state.selectedManagedProjectPath, '/tmp/project-b');
    expect(state.selectedConsoleTabId, 'build::/tmp/project-b');
    expect(state.commandLog, isEmpty);

    await container
        .read(fvmControllerProvider.notifier)
        .closeConsoleTab('build::/tmp/project-b');
    final afterClose = container.read(fvmControllerProvider);
    expect(afterClose.selectedConsoleTabId, 'history::0');
    expect(afterClose.selectedManagedProjectPath, '/tmp/project-a');
    expect(afterClose.commandLog, isEmpty);
  });

  test('stop waits for a process that is still starting', () async {
    if (Platform.isWindows) return;
    final runner = ProcessRunner();
    final starting = Completer<Process>();
    final start = runner.startManaged(
      taskId: 'run::demo',
      starter: () => starting.future,
    );

    final stop = runner.stop('run::demo');
    expect(runner.isRunning('run::demo'), isTrue);

    final process = _PendingProcess();
    starting.complete(process);
    await start;
    await stop;

    expect(process.killed, isTrue);
  });

  test('closing a running console tab stops its task before removal', () async {
    final stopGate = Completer<void>();
    final controller = _CloseTabController(stopGate);
    final container = ProviderContainer(
      overrides: [fvmControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);
    container.read(fvmControllerProvider);

    final close = controller.closeConsoleTab('run::demo');
    expect(controller.stoppedTaskIds, ['run::demo']);
    expect(container.read(fvmControllerProvider).consoleTabs, hasLength(2));

    stopGate.complete();
    await close;

    final state = container.read(fvmControllerProvider);
    expect(state.consoleTabs.map((tab) => tab.id), ['build::demo']);
    expect(state.selectedConsoleTabId, 'build::demo');
  });

  test('closing a completed console tab does not stop a task', () async {
    final controller = _CloseTabController(Completer<void>());
    final container = ProviderContainer(
      overrides: [fvmControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);
    container.read(fvmControllerProvider);

    await controller.closeConsoleTab('build::demo');

    expect(controller.stoppedTaskIds, isEmpty);
    expect(
      container.read(fvmControllerProvider).consoleTabs.map((tab) => tab.id),
      ['run::demo'],
    );
  });

  testWidgets('guides user when FVM cannot be detected', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_MissingFvmController.new),
          pubEnvironmentServiceProvider.overrideWithValue(
            _TestPubEnvironmentService(),
          ),
        ],
        child: const FvmManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('未检测到 FVM'), findsOneWidget);
    expect(find.text('安装 FVM'), findsWidgets);
    expect(find.text('选择本地 FVM'), findsWidgets);
  });

  testWidgets('collapses project list when window is narrow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_TestController.new),
          pubEnvironmentServiceProvider.overrideWithValue(
            _TestPubEnvironmentService(),
          ),
        ],
        child: const FvmManagerApp(),
      ),
    );

    await tester.tap(find.text('项目管理'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('collapsed-project-list')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('expanded-project-list')), findsNothing);
    expect(find.byTooltip('选择项目'), findsOneWidget);
  });

  testWidgets('shows FVM dashboard status', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_TestController.new),
          pubEnvironmentServiceProvider.overrideWithValue(
            _TestPubEnvironmentService(),
          ),
        ],
        child: const FvmManagerApp(),
      ),
    );

    expect(find.text('Flutter Manager'), findsOneWidget);
    expect(find.text('FVM 4.1.1'), findsOneWidget);
    expect(find.text('3.44.2'), findsOneWidget);
    expect(find.text('更新 FVM'), findsOneWidget);
    expect(find.text('最新版本：4.1.2'), findsOneWidget);
    expect(find.text('打开 FVM 目录'), findsOneWidget);
    expect(find.text('打开 Flutter 目录'), findsOneWidget);
    expect(find.text('10.0 MB / 100.0 MB'), findsOneWidget);
    expect(find.text('2.0 MB/s'), findsOneWidget);
    await tester.tap(find.byTooltip('删除此 Flutter 版本'));
    await tester.pumpAndSettle();
    expect(find.text('确认删除 Flutter 版本？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('项目管理'), findsOneWidget);
    expect(find.text('Flutter 版本'), findsOneWidget);
    expect(find.byKey(const ValueKey('fvm-update-dot-top')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flutter-update-dot-nav')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fvm-update-dot-top')));
    await tester.pump();
    expect(find.byKey(const ValueKey('fvm-update-dot-top')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('flutter-update-dot-nav')));
    await tester.pump();
    expect(find.byKey(const ValueKey('flutter-update-dot-nav')), findsNothing);

    await tester.tap(find.text('项目管理'));
    await tester.pump();
    expect(find.text('添加项目'), findsOneWidget);
    await tester.tap(find.byTooltip('更多项目操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('备注名称'));
    await tester.pumpAndSettle();
    expect(find.text('设置项目备注名称'), findsOneWidget);
    final aliasField = tester.widget<TextField>(find.byType(TextField).last);
    expect(aliasField.controller?.text, 'demo');
    await tester.enterText(find.byType(TextField).last, '客户项目');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('客户项目'), findsWidgets);
    expect(find.text('打包版本'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('project-build-version-field')),
          )
          .controller
          ?.text,
      '1.0.0',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('command-console-search-field')),
      findsOneWidget,
    );
    expect(find.text('运行与调试'), findsOneWidget);
    expect(find.text('构建与打包'), findsOneWidget);
    expect(find.text('Android 渠道（可多选）'), findsNothing);
    await tester.ensureVisible(find.text('构建与打包'));
    await tester.tap(find.text('构建与打包'));
    await tester.pump();
    expect(find.text('Android 渠道（可多选）'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-build-output-button')),
      findsOneWidget,
    );
    expect(find.text('DevTools'), findsOneWidget);
    expect(find.text('热重载'), findsOneWidget);
    expect(find.text('热重启'), findsOneWidget);
    await tester.ensureVisible(find.text('dev'));
    await tester.tap(find.text('dev'));
    await tester.pump();
    expect(find.text('已选择 1 个'), findsOneWidget);
    expect(find.text('构建后上传 Bugly 符号表'), findsOneWidget);
    expect(find.text('使用自定义 runCommand 工作流'), findsOneWidget);
    await tester.ensureVisible(find.text('构建与打包'));
    await tester.tap(find.text('构建与打包'));
    await tester.pump();

    await tester.tap(find.text('Flutter 版本'));
    await tester.pump();
    expect(find.text('Flutter 版本'), findsWidgets);
    expect(find.text('稳定版 Stable'), findsOneWidget);
    expect(find.text('FVM 目录'), findsOneWidget);

    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();
    expect(find.text('选择日志文件'), findsOneWidget);
    expect(find.text('选择一个日志文件开始查看。'), findsOneWidget);

    await tester.tap(find.text('环境配置'));
    await tester.pump();
    expect(find.text('选择下载源'), findsOneWidget);
    expect(find.text('测试连通性'), findsOneWidget);
  });
}
