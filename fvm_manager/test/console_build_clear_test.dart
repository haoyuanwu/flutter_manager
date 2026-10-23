import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/build_history_repository.dart';
import 'package:flutter_manager/src/data/build_notification_service.dart';
import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Controller extends FvmController {
  _Controller(this.path, {this.customBuild = false});
  final String path;
  final bool customBuild;
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
    selectedManagedProjectPath: path,
    projectBuildTarget: ProjectBuildTarget.macos,
    cleanBeforeBuild: true,
    managedProjects: [
      FlutterProject(
        name: 'test',
        path: path,
        lastOpened: DateTime(2026),
        customCommandCode: customBuild
            ? 'runCommand("flutter", ["build", "macos"]); runCommand("flutter", ["build", "macos"]);'
            : 'runCommand("flutter", ["clean"]); runCommand("flutter", ["pub", "get"]);',
      ),
    ],
  );
}

class _Commands extends FlutterCommandService {
  _Commands() : super(FvmService(PubEnvironmentService()), ProcessRunner());
  int counter = 0;
  int exitCode = 0;
  @override
  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String) onOutput,
  }) async {
    onOutput('OUTPUT-${++counter}\n');
    return exitCode;
  }
}

class _Notifications extends BuildNotificationService {
  final List<String> directories = [];
  @override
  Future<bool> completed({
    required String projectName,
    required String directory,
  }) async {
    directories.add(directory);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'custom workflow notifies once after every build command completes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'workflow_notification_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final output = await Directory('${directory.path}/build').create();
      final commands = _Commands();
      final notifications = _Notifications();
      final container = ProviderContainer(
        overrides: [
          fvmControllerProvider.overrideWith(
            () => _Controller(directory.path, customBuild: true),
          ),
          flutterCommandServiceProvider.overrideWithValue(commands),
          buildNotificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(fvmControllerProvider.notifier)
          .runCustomBuildWorkflow();
      expect(commands.counter, 2);
      expect(notifications.directories, [output.absolute.path]);
      commands.exitCode = 1;
      await container
          .read(fvmControllerProvider.notifier)
          .runCustomBuildWorkflow();
      expect(notifications.directories, hasLength(1));
    },
  );
  for (final workflow in [false, true]) {
    test(
      '${workflow ? 'workflow' : 'build'} clears previous invocation but keeps all current steps and run output',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'console_build_clear_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final commands = _Commands();
        final notifications = _Notifications();
        final container = ProviderContainer(
          overrides: [
            buildNotificationServiceProvider.overrideWithValue(notifications),
            fvmControllerProvider.overrideWith(
              () => _Controller(directory.path),
            ),
            flutterCommandServiceProvider.overrideWithValue(commands),
            buildHistoryRepositoryProvider.overrideWithValue(
              BuildHistoryRepository(
                storageFile: File('${directory.path}/history.json'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(fvmControllerProvider.notifier);
        await controller.runManagedProject();
        final runTab = 'run::${directory.path}';
        final runLog = container.read(fvmControllerProvider).commandLog;
        expect(runLog, contains('OUTPUT-1'));
        Future<void> execute() => workflow
            ? controller.runCustomBuildWorkflow()
            : controller.buildManagedProject();
        await execute();
        expect(
          container.read(fvmControllerProvider).commandLog,
          contains('OUTPUT-2'),
        );
        final firstCount = commands.counter;
        await execute();
        final log = container.read(fvmControllerProvider).commandLog;
        expect(log, isNot(contains('OUTPUT-2\n')));
        for (var index = firstCount + 1; index <= commands.counter; index++) {
          expect(log, contains('OUTPUT-$index\n'));
        }
        controller.selectConsoleTab(runTab);
        expect(container.read(fvmControllerProvider).commandLog, runLog);
        expect(notifications.directories.length, workflow ? 0 : 2);
        if (!workflow) {
          expect(
            notifications.directories.every(
              (path) => path == directory.absolute.path,
            ),
            true,
          );
          commands.exitCode = 1;
          await controller.buildManagedProject();
          expect(notifications.directories.length, 2);
        }
      },
    );
  }
}
