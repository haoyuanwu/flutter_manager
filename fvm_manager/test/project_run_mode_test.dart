import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/app.dart';
import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/project_repository.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Repository extends ProjectRepository {
  @override
  Future<void> save(List<FlutterProject> projects) async {}
}

class _Controller extends FvmController {
  final openedTabs = <String>[];

  @override
  Future<void> openConsoleTabWindow(String tabId) async =>
      openedTabs.add(tabId);

  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    autoOpenConsoleWindow: false,
    buildOpensConsoleWindow: false,
    installed: const [
      InstalledSdk(
        name: 'stable',
        flutterVersion: '3.47.5',
        dartVersion: '3.13.5',
        directory: '/unused',
      ),
    ],
    managedProjects: [
      FlutterProject(
        name: 'demo',
        path: '/tmp/mode-test',
        lastOpened: DateTime(2026),
      ),
    ],
    selectedManagedProjectPath: '/tmp/mode-test',
    selectedDeviceId: 'device-id',
    devices: const [
      {'id': 'device-id', 'name': '手机', 'platform': 'android'},
      {'id': 'desktop-id', 'name': '桌面', 'platform': 'macos'},
    ],
    selectedAndroidFlavors: const ['prod'],
  );
  @override
  Future<void> initialize() async {}
}

class _Commands extends FlutterCommandService {
  _Commands() : super(FvmService(PubEnvironmentService()), ProcessRunner());
  final arguments = <List<String>>[];
  final completions = <Completer<int>>[];
  final outputs = <void Function(String)>[];
  final taskIds = <String>[];
  final stoppedTasks = <String>[];
  final secondStarted = Completer<void>();
  var hotCalls = 0;
  @override
  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String) onOutput,
  }) {
    this.arguments.add(arguments);
    taskIds.add(taskId);
    outputs.add(onOutput);
    final completion = Completer<int>();
    completions.add(completion);
    if (completions.length == 2) secondStarted.complete();
    return completion.future;
  }

  @override
  Future<void> stop(String taskId, {bool gracefulFlutterRun = false}) async {
    stoppedTasks.add(taskId);
    completions[taskIds.lastIndexOf(taskId)].complete(0);
  }

  @override
  Future<void> hotReload(String taskId) async {
    hotCalls++;
  }

  @override
  Future<void> hotRestart(String taskId) async {
    hotCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ProjectRunMode.values) {
    test(
      'run uses ${mode.name}, keeps device/flavor, and locks mode during execution',
      () async {
        final commands = _Commands();
        final container = ProviderContainer(
          overrides: [
            fvmControllerProvider.overrideWith(_Controller.new),
            flutterCommandServiceProvider.overrideWithValue(commands),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(fvmControllerProvider.notifier);
        if (mode == ProjectRunMode.release) {
          controller.selectProjectRunMode(mode);
        }
        final running = controller.runManagedProject();
        expect(commands.arguments.single, [
          'run',
          '--${mode.name}',
          '-d',
          'device-id',
          '--flavor',
          'prod',
        ]);
        expect(
          controller.selectedRunSupportsHotActions,
          mode == ProjectRunMode.debug,
        );
        controller.selectProjectRunMode(
          mode == ProjectRunMode.debug
              ? ProjectRunMode.release
              : ProjectRunMode.debug,
        );
        expect(
          container.read(projectRunModesProvider)['/tmp/mode-test'] ??
              ProjectRunMode.debug,
          mode,
        );
        await controller.hotReloadManagedProject();
        await controller.hotRestartManagedProject();
        expect(commands.hotCalls, mode == ProjectRunMode.debug ? 2 : 0);
        final rerunning = controller.rerunManagedProject();
        await commands.secondStarted.future;
        expect(commands.arguments.last[1], '--${mode.name}');
        commands.completions.last.complete(0);
        await rerunning;
        await running;
        expect(
          container.read(fvmControllerProvider).projectBuildMode,
          ProjectBuildMode.release,
        );
      },
    );
  }

  testWidgets(
    'switching devices keeps both runs and tab double click opens its console',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final commands = _Commands();
      final controller = _Controller();
      final container = ProviderContainer(
        overrides: [
          fvmControllerProvider.overrideWith(() => controller),
          flutterCommandServiceProvider.overrideWithValue(commands),
          projectRepositoryProvider.overrideWithValue(_Repository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FvmManagerApp(),
        ),
      );
      await tester.tap(find.text('项目管理'));
      await tester.pumpAndSettle();

      final first = controller.runManagedProject();
      commands.outputs.first('手机专属日志');
      await tester.pumpAndSettle();
      final currentDevice = find.text('手机  (android)');
      await tester.ensureVisible(currentDevice);
      await tester.tap(currentDevice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('桌面  (macos)').last);
      await tester.pumpAndSettle();
      expect(commands.stoppedTasks, isEmpty);
      expect(commands.arguments, hasLength(1));

      final runButton = find.text('Flutter Run').first;
      await tester.ensureVisible(runButton);
      await tester.tap(runButton);
      await tester.pumpAndSettle();
      expect(commands.arguments.last, containsAllInOrder(['-d', 'desktop-id']));
      expect(commands.taskIds.toSet(), hasLength(2));
      expect(commands.stoppedTasks, isEmpty);
      final tabs = container.read(fvmControllerProvider).consoleTabs;
      expect(tabs.map((tab) => tab.deviceName), ['手机', '桌面']);
      expect(tabs.every((tab) => tab.running), isTrue);

      final phoneTab = find.text('手机 · demo');
      await tester.ensureVisible(phoneTab);
      await tester.pumpAndSettle();
      await tester.tap(phoneTab);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(phoneTab);
      await tester.pumpAndSettle();
      expect(controller.openedTabs, [commands.taskIds.first]);
      final state = container.read(fvmControllerProvider);
      expect(state.commandLog, contains('手机专属日志'));
      expect(state.selectedDeviceId, 'desktop-id');

      commands.completions.first.complete(0);
      commands.completions.last.complete(0);
      await first;
      await tester.pumpAndSettle();
    },
  );

  for (final width in [960.0, 1400.0]) {
    testWidgets(
      'run controls wrap at $width and mode selector updates independently',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [fvmControllerProvider.overrideWith(_Controller.new)],
            child: const FvmManagerApp(),
          ),
        );
        await tester.tap(find.text('项目管理'));
        await tester.pumpAndSettle();
        final selector = find.byType(DropdownButtonFormField<ProjectRunMode>);
        await tester.ensureVisible(selector);
        expect(find.text('Debug · 调试'), findsOneWidget);
        await tester.tap(find.text('Debug · 调试'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Release · 正式').last);
        await tester.pumpAndSettle();
        expect(find.text('Release 用于验证正式运行效果，不支持热重载与热重启。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
