import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/build_history_repository.dart';
import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Controller extends FvmController {
  _Controller(this.path);
  final String path;
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
        customCommandCode:
            'runCommand("flutter", ["clean"]); runCommand("flutter", ["pub", "get"]);',
      ),
    ],
  );
}

class _Commands extends FlutterCommandService {
  _Commands() : super(FvmService(PubEnvironmentService()), ProcessRunner());
  int counter = 0;
  @override
  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String) onOutput,
  }) async {
    onOutput('OUTPUT-${++counter}\n');
    return 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final workflow in [false, true]) {
    test(
      '${workflow ? 'workflow' : 'build'} clears previous invocation but keeps all current steps and run output',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'console_build_clear_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final commands = _Commands();
        final container = ProviderContainer(
          overrides: [
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
      },
    );
  }
}
