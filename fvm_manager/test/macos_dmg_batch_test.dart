import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/local_project_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Controller extends FvmController {
  @override
  FvmState build() => FvmState(
    selectedManagedProjectPath: '/demo',
    managedProjects: [
      FlutterProject(name: 'Demo', path: '/demo', lastOpened: DateTime(2026)),
    ],
  );
}

class _Service extends LocalProjectService {
  final calls = <MacosPackageArchitecture>[];
  final revealed = <String>[];
  MacosPackageArchitecture? failOn;
  Completer<void>? gate;

  @override
  Future<String> packageMacosDmg(
    String projectPath,
    String appName,
    MacosPackageArchitecture architecture,
  ) async {
    calls.add(architecture);
    if (gate != null) await gate!.future;
    if (failOn == architecture) {
      throw Exception('缺少 ${architecture.machineName} 架构');
    }
    return '/demo/build/${macosDmgFileName(appName, '1.3.0', architecture)}';
  }

  @override
  Future<void> revealFile(String path) async => revealed.add(path);
}

void main() {
  const both = [
    MacosPackageArchitecture.appleSilicon,
    MacosPackageArchitecture.intel,
  ];

  ProviderContainer setup(_Service service) => ProviderContainer(
    overrides: [
      fvmControllerProvider.overrideWith(_Controller.new),
      localProjectServiceProvider.overrideWithValue(service),
    ],
  );

  test(
    'dual architecture produces two distinct DMGs and reveals once',
    () async {
      final service = _Service();
      final container = setup(service);
      addTearDown(container.dispose);
      await container
          .read(fvmControllerProvider.notifier)
          .packageMacosDmgs(both);
      expect(service.calls, both);
      expect(service.revealed, ['/demo/build/Demo-1.3.0-x86_64.dmg']);
      final state = container.read(fvmControllerProvider);
      expect(state.loading, isFalse);
      expect(state.statusMessage, contains('已生成 2 个 DMG'));
      expect(state.statusMessage, contains('Demo-1.3.0-arm64.dmg'));
      expect(state.errorMessage, isNull);
    },
  );

  test('single architecture still packages only one DMG', () async {
    final service = _Service();
    final container = setup(service);
    addTearDown(container.dispose);
    await container
        .read(fvmControllerProvider.notifier)
        .packageMacosDmg(both.first);
    expect(service.calls, [both.first]);
    expect(service.revealed.single, endsWith('-arm64.dmg'));
  });

  test('failure preserves partial result and resets loading', () async {
    final service = _Service()..failOn = both.last;
    final container = setup(service);
    addTearDown(container.dispose);
    await container.read(fvmControllerProvider.notifier).packageMacosDmgs(both);
    final state = container.read(fvmControllerProvider);
    expect(state.loading, isFalse);
    expect(state.statusMessage, contains('已生成 1 个 DMG'));
    expect(state.errorMessage, contains('x86_64'));
    expect(service.revealed, isEmpty);
  });

  test('busy batch rejects duplicate packaging and reports progress', () async {
    final service = _Service()..gate = Completer<void>();
    final container = setup(service);
    addTearDown(container.dispose);
    final controller = container.read(fvmControllerProvider.notifier);
    final pending = controller.packageMacosDmgs(both);
    expect(container.read(fvmControllerProvider).loading, isTrue);
    expect(
      container.read(fvmControllerProvider).statusMessage,
      contains('1/2'),
    );
    await controller.packageMacosDmgs(both);
    expect(service.calls, [both.first]);
    service.gate!.complete();
    await pending;
    expect(service.calls, both);
  });
}
