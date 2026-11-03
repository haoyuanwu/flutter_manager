import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/project_repository.dart';
import 'package:flutter_manager/src/data/flutter_device_monitor.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Repository extends ProjectRepository {
  List<FlutterProject> saved = [];
  @override
  Future<void> save(List<FlutterProject> projects) async {
    saved = projects;
  }
}

class _Monitor extends FlutterDeviceMonitor {
  _Monitor() : super(FvmService(PubEnvironmentService()));
  void Function(List<Map<String, String>>)? emit;
  @override
  bool get isRunning => true;
  @override
  Future<void> start({
    required String projectPath,
    required void Function(List<Map<String, String>>) onDevices,
    required void Function(Object) onError,
  }) async {
    emit = onDevices;
  }
}

class _Controller extends FvmController {
  @override
  FvmState build() => FvmState(
    managedProjects: [
      for (final path in ['a', 'b'])
        FlutterProject(name: path, path: path, lastOpened: DateTime(2026)),
    ],
    selectedManagedProjectPath: 'a',
    devices: const [
      {'id': 'phone'},
      {'id': 'desktop'},
    ],
  );
  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy config defaults to automatic and device survives serialization',
    () {
      final project = FlutterProject.fromMap({'path': 'a'});
      expect(project.selectedDeviceId, isNull);
      expect(
        FlutterProject.fromMap(
          project.copyWith(selectedDeviceId: 'phone').toMap(),
        ).selectedDeviceId,
        'phone',
      );
    },
  );
  test(
    'projects remember independently and removed device persists automatic',
    () async {
      final repository = _Repository();
      final monitor = _Monitor();
      final container = ProviderContainer(
        overrides: [
          fvmControllerProvider.overrideWith(_Controller.new),
          projectRepositoryProvider.overrideWithValue(repository),
          flutterDeviceMonitorProvider.overrideWithValue(monitor),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(fvmControllerProvider.notifier);
      controller.selectDevice('phone');
      await controller.selectManagedProject('b');
      expect(container.read(fvmControllerProvider).selectedDeviceId, isNull);
      controller.selectDevice('desktop');
      await controller.selectManagedProject('a');
      expect(container.read(fvmControllerProvider).selectedDeviceId, 'phone');
      await controller.loadDevices();
      monitor.emit!([
        {'id': 'desktop'},
      ]);
      expect(container.read(fvmControllerProvider).selectedDeviceId, isNull);
      expect(
        repository.saved.firstWhere((p) => p.path == 'a').selectedDeviceId,
        isNull,
      );
      await controller.selectManagedProject('b');
      expect(container.read(fvmControllerProvider).selectedDeviceId, 'desktop');
      controller.selectDevice(null);
      expect(
        repository.saved.firstWhere((p) => p.path == 'b').selectedDeviceId,
        isNull,
      );
    },
  );
}
