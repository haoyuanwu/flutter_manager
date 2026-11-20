import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/project_repository.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Network extends HttpOverrides {}

class _Projects extends ProjectRepository {
  @override
  Future<void> save(List<FlutterProject> projects) async {}
}

class _Controller extends FvmController {
  final gate = Completer<void>();
  bool failUpload = false;
  @override
  FvmState build() => FvmState(
    mcpServerEnabled: true,
    mcpServerPort: 0,
    selectedManagedProjectPath: '/demo',
    managedProjects: [
      FlutterProject(
        name: 'demo',
        path: '/demo',
        lastOpened: DateTime(2026),
        hasAndroid: true,
        androidFlavors: const ['prod'],
        pgyer: const PgyerConfig(apiKey: 'secret-api-key'),
      ),
    ],
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> buildManagedProject() async {
    await gate.future;
  }

  @override
  Future<void> uploadToPgyer(String filePath) async {
    if (failUpload) {
      state = state.copyWith(errorMessage: 'failed secret-api-key');
    } else {
      state = state.copyWith(pgyerUploadResult: 'https://example.com/app');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Controller controller;
  late HttpClient client;
  late int port;
  setUp(() async {
    controller = _Controller();
    container = ProviderContainer(
      overrides: [
        fvmControllerProvider.overrideWith(() => controller),
        projectRepositoryProvider.overrideWithValue(_Projects()),
      ],
    );
    container.read(fvmControllerProvider);
    await controller.ensureMcpServerRunning();
    port = container.read(mcpControlServerProvider).activePort!;
    client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _Network());
  });
  tearDown(() async {
    if (!controller.gate.isCompleted) controller.gate.complete();
    client.close(force: true);
    await container.read(mcpControlServerProvider).stop();
    container.dispose();
  });
  Future<Map<String, dynamic>> call(
    String tool, [
    Map<String, dynamic> args = const {},
  ]) async {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/tools/$tool'),
    );
    request.write(jsonEncode(args));
    final response = await request.close();
    return (jsonDecode(await utf8.decoder.bind(response).join()) as Map)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> done(String id) async {
    for (var i = 0; i < 100; i++) {
      final job = await call('get_operation', {'operationId': id});
      if (job['status'] != 'running') return job;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('timeout');
  }

  test(
    'config masks secrets; build options persist and concurrent mutation is rejected',
    () async {
      final config = await call('get_project_config');
      expect(jsonEncode(config), isNot(contains('secret-api-key')));
      final accepted = await call('build', {
        'mode': 'debug',
        'target': 'apk',
        'flavors': ['prod'],
      });
      expect(accepted['accepted'], isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(fvmControllerProvider).projectBuildMode,
        ProjectBuildMode.debug,
      );
      expect(container.read(fvmControllerProvider).selectedAndroidFlavors, [
        'prod',
      ]);
      expect(
        (await call('configure_project', {'mode': 'release'}))['ok'],
        isFalse,
      );
      expect(
        (await call('select_project', {'projectPath': '/demo'}))['ok'],
        isFalse,
      );
      controller.gate.complete();
      expect(
        (await done(accepted['operationId'] as String))['status'],
        'success',
      );
    },
  );
  test(
    'upload returns final URL and redacts failure instead of claiming success',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mcp-upload-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final apk = File('${directory.path}/app.apk');
      await apk.writeAsString('test');
      final accepted = await call('upload_pgyer', {'filePath': apk.path});
      final success = await done(accepted['operationId'] as String);
      expect(success['status'], 'success');
      expect(
        (success['result'] as Map)['downloadUrl'],
        'https://example.com/app',
      );
      controller.failUpload = true;
      final retry = await call('upload_pgyer', {'filePath': apk.path});
      final failed = await done(retry['operationId'] as String);
      expect(failed['status'], 'failed');
      expect(jsonEncode(failed), isNot(contains('secret-api-key')));
      expect(failed['error'], contains('redacted'));
    },
  );
  test(
    'invalid build enum is a failed operation without changing settings',
    () async {
      final accepted = await call('build', {'mode': 'invalid'});
      final job = await done(accepted['operationId'] as String);
      expect(job['status'], 'failed');
      expect(
        container.read(fvmControllerProvider).projectBuildMode,
        ProjectBuildMode.release,
      );
    },
  );
}
