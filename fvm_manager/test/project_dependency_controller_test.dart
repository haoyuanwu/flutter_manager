import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/project_dependency_service.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_dependency.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Controller extends FvmController {
  _Controller(this.initial);
  final FvmState initial;
  @override
  FvmState build() => initial;
}

class _Commands extends FlutterCommandService {
  _Commands() : super(FvmService(PubEnvironmentService()), ProcessRunner());
  final calls = <(String, List<String>)>[];
  int exitCode = 0;
  @override
  Future<int> run({
    required String taskId,
    required String projectPath,
    required List<String> arguments,
    required void Function(String) onOutput,
  }) async {
    calls.add((projectPath, arguments));
    expect(
      await File(
        '$projectPath${Platform.pathSeparator}pubspec.yaml',
      ).readAsString(),
      contains('dio:'),
    );
    onOutput('pub get output\n');
    return exitCode;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory first;
  late Directory second;
  late _Commands commands;
  late ProviderContainer container;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dependency_controller_');
    first = await Directory('${root.path}/first').create();
    second = await Directory('${root.path}/second').create();
    for (final directory in [first, second]) {
      await File('${directory.path}/pubspec.yaml').writeAsString(
        'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
    }
    commands = _Commands();
    container = ProviderContainer(
      overrides: [
        flutterCommandServiceProvider.overrideWithValue(commands),
        fvmControllerProvider.overrideWith(
          () => _Controller(
            FvmState(
              fvmInstalled: true,
              globalVersion: '3.47.7',
              selectedManagedProjectPath: first.path,
              installed: [
                InstalledSdk(
                  name: '3.47.7',
                  flutterVersion: '3.47.7',
                  dartVersion: '3.11.0',
                  directory: root.path,
                ),
              ],
              managedProjects: [
                FlutterProject(
                  name: 'first',
                  path: first.path,
                  lastOpened: DateTime(2026),
                ),
                FlutterProject(
                  name: 'second',
                  path: second.path,
                  lastOpened: DateTime(2026),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await root.delete(recursive: true);
  });

  test(
    'writes selected dialog project before Pub Get without changing main project selection',
    () async {
      final snapshot = await const ProjectDependencyService().load(second.path);
      final saved = await container
          .read(fvmControllerProvider.notifier)
          .updateProjectDependencies(
            snapshot,
            additions: const [
              ProjectDependency(name: 'dio', constraint: '^5.0.0'),
            ],
            removals: {},
          );
      expect(saved.projectPath, second.path);
      expect(commands.calls, [
        (second.path, ['pub', 'get']),
      ]);
      expect(
        container.read(fvmControllerProvider).selectedManagedProjectPath,
        first.path,
      );
      expect(
        await File('${first.path}/pubspec.yaml').readAsString(),
        isNot(contains('dio:')),
      );
    },
  );

  test(
    'Pub Get failure preserves saved dependencies and allows a retry',
    () async {
      final snapshot = await const ProjectDependencyService().load(second.path);
      commands.exitCode = 1;
      ProjectDependencySnapshot? saved;
      try {
        await container
            .read(fvmControllerProvider.notifier)
            .updateProjectDependencies(
              snapshot,
              additions: const [
                ProjectDependency(name: 'dio', constraint: '^5.0.0'),
              ],
              removals: {},
            );
        fail('Expected a Pub Get failure');
      } on DependencySyncException catch (error) {
        saved = error.snapshot;
      }
      expect(saved, isNotNull);
      expect(
        await File('${second.path}/pubspec.yaml').readAsString(),
        contains('dio:'),
      );
      commands.exitCode = 0;
      await container
          .read(fvmControllerProvider.notifier)
          .updateProjectDependencies(saved, additions: [], removals: {});
      expect(commands.calls, hasLength(2));
    },
  );

  test(
    'conflicting YAML edits prevent Pub Get and leave external content intact',
    () async {
      final snapshot = await const ProjectDependencyService().load(second.path);
      final external = '${snapshot.source}# changed elsewhere\n';
      await File('${second.path}/pubspec.yaml').writeAsString(external);
      await expectLater(
        container
            .read(fvmControllerProvider.notifier)
            .updateProjectDependencies(
              snapshot,
              additions: const [
                ProjectDependency(name: 'dio', constraint: '^5.0.0'),
              ],
              removals: {},
            ),
        throwsStateError,
      );
      expect(commands.calls, isEmpty);
      expect(
        await File('${second.path}/pubspec.yaml').readAsString(),
        external,
      );
    },
  );
}
