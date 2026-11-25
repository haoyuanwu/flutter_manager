import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/data/project_repository.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Environment extends PubEnvironmentService {
  @override
  Future<void> load() async {}
}

class _Projects extends ProjectRepository {
  @override
  Future<List<FlutterProject>> load() async => [];
}

class _Fvm extends FvmService {
  _Fvm(super.environment);
  bool reached = false;
  @override
  Future<String?> detect({bool allowRepair = true}) async {
    reached = true;
    throw StateError('probe reached');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'window channel registration failure must not skip FVM detection',
    () async {
      const channel = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'registration_failed');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final environment = _Environment();
      final fvm = _Fvm(environment);
      final container = ProviderContainer(
        overrides: [
          pubEnvironmentServiceProvider.overrideWithValue(environment),
          fvmServiceProvider.overrideWithValue(fvm),
          projectRepositoryProvider.overrideWithValue(_Projects()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(fvmControllerProvider.notifier).initialize();
      expect(fvm.reached, isTrue);
    },
  );
}
