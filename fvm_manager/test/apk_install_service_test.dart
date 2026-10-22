import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/apk_install_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';

class _FakeRunner extends ProcessRunner {
  List<String>? arguments;
  ProcessRunResult result = const ProcessRunResult(
    exitCode: 0,
    stdout: 'Success\n',
    stderr: '',
  );

  @override
  Future<ProcessRunResult> run({
    required String executable,
    required List<String> arguments,
    String? taskId,
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    this.arguments = arguments;
    return result;
  }
}

void main() {
  test('parses ADB devices and marks unauthorized devices unavailable', () {
    final devices = parseAdbDevices('''
List of devices attached
serial-1 device product:demo model:Pixel_8 device:demo
serial-2 unauthorized
serial-3 offline
''');
    expect(devices, hasLength(3));
    expect(devices.first.displayName, 'Pixel 8 (serial-1)');
    expect(devices.first.available, isTrue);
    expect(devices[1].available, isFalse);
    expect(devices[2].available, isFalse);
  });

  test('installs an existing APK on exactly the selected device', () async {
    final directory = await Directory.systemTemp.createTemp(
      'apk_install_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final apk = File('${directory.path}/demo app.apk');
    await apk.writeAsBytes([1]);
    final runner = _FakeRunner();
    final service = ApkInstallService(
      runner,
      PubEnvironmentService(),
      adbExecutable: '/test/adb',
    );

    await service.install(apkPath: apk.path, deviceId: 'serial-1');

    expect(runner.arguments, ['-s', 'serial-1', 'install', '-r', apk.path]);
  });

  test(
    'does not report installation success when ADB reports failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'apk_install_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final apk = File('${directory.path}/demo.apk');
      await apk.writeAsBytes([1]);
      final runner = _FakeRunner()
        ..result = const ProcessRunResult(
          exitCode: 0,
          stdout: 'Failure [INSTALL_FAILED_VERSION_DOWNGRADE]',
          stderr: '',
        );
      final service = ApkInstallService(
        runner,
        PubEnvironmentService(),
        adbExecutable: '/test/adb',
      );

      expect(
        () => service.install(apkPath: apk.path, deviceId: 'serial-1'),
        throwsA(isA<ApkInstallException>()),
      );
    },
  );
}
