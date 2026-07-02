import 'dart:io';

import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds GUI command paths required by FVM', () {
    final service = PubEnvironmentService();
    final paths = service.executableSearchPaths;
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];

    if (home != null && Platform.isMacOS) {
      expect(paths, contains('$home/.pub-cache/bin'));
      expect(paths, contains('$home/fvm/default/bin'));
      expect(paths, contains('/opt/homebrew/bin'));
      expect(paths, contains('/usr/local/bin'));
    }

    final path = service.processEnvironment['PATH'];
    expect(path, isNotNull);
    expect(path, isNotEmpty);
  });

  test('validates and persists a locally selected FVM directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_local_fvm_',
    );
    addTearDown(() => root.delete(recursive: true));
    final bin = Directory('${root.path}/bin');
    await bin.create();
    final executable = File(
      '${bin.path}/${Platform.isWindows ? 'fvm.bat' : 'fvm'}',
    );
    await executable.writeAsString(
      Platform.isWindows
          ? '@if "%1"=="--version" echo 9.9.9\r\n'
                '@if "%1"=="flutter" echo [{"id":"desktop","name":"Desktop","platform":"test"}]\r\n'
          : '#!/bin/sh\n'
                'if [ "\$1" = "--version" ]; then\n'
                '  echo 9.9.9\n'
                'elif [ "\$1" = "flutter" ]; then\n'
                '  if [ "\$2" = "devices" ]; then\n'
                '    echo \'[{"id":"desktop","name":"Desktop","platform":"test"}]\'\n'
                '  else\n'
                '    sleep 0.1\n'
                '    echo "\$2"\n'
                '  fi\n'
                'fi\n',
    );
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', executable.path]);
      expect(chmod.exitCode, 0);
    }

    final settings = File('${root.path}/settings.json');
    final environment = PubEnvironmentService(settingsFile: settings);
    final fvm = FvmService(environment);
    final version = await fvm.useLocalDirectory(root.path);

    expect(version, '9.9.9');
    expect(environment.customFvmExecutable, executable.path);

    await File('${root.path}/.fvmrc').writeAsString('{}');
    final devices = await fvm.listDevices(root.path);
    expect(devices, [
      {'id': 'desktop', 'name': 'Desktop', 'platform': 'test'},
    ]);
    final dartProcess = await fvm.startDartCommand(
      projectPath: root.path,
      arguments: const ['devtools', '--launch-browser', '--port=0'],
    );
    expect(await dartProcess.exitCode, 0);

    if (!Platform.isWindows) {
      final output = <String>[];
      final commands = FlutterCommandService(fvm);
      final exitCodes = await Future.wait([
        commands.run(
          taskId: 'run::demo',
          projectPath: root.path,
          arguments: const ['run'],
          onOutput: output.add,
        ),
        commands.run(
          taskId: 'build::demo',
          projectPath: root.path,
          arguments: const ['build', 'apk'],
          onOutput: output.add,
        ),
      ]);
      expect(exitCodes, [0, 0]);
      expect(output.join(), contains('run'));
      expect(output.join(), contains('build'));
    }

    final reloaded = PubEnvironmentService(settingsFile: settings);
    await reloaded.load();
    expect(reloaded.customFvmExecutable, executable.path);
    expect(await FvmService(reloaded).detect(), '9.9.9');
  });

  test('isolates command logs by project path', () {
    final logs = ProjectCommandLogBuffer(maxLength: 20);
    logs.append('/project/a', 'A log');
    logs.append('/project/b', 'B log');

    expect(logs.logFor('/project/a'), 'A log');
    expect(logs.logFor('/project/b'), 'B log');

    logs.clear('/project/a');
    expect(logs.logFor('/project/a'), isEmpty);
    expect(logs.logFor('/project/b'), 'B log');
  });

  test('persists console display settings', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_console_settings_',
    );
    addTearDown(() => root.delete(recursive: true));
    final settings = File('${root.path}/settings.json');
    final service = PubEnvironmentService(settingsFile: settings);

    expect(service.autoOpenConsoleWindow, isTrue);
    expect(service.showMainWindowConsole, isFalse);
    expect(service.showConsoleQuickCommands, isTrue);
    expect(service.buildOpensConsoleWindow, isFalse);

    await service.setAutoOpenConsoleWindow(false);
    await service.setShowMainWindowConsole(true);
    await service.setShowConsoleQuickCommands(false);
    await service.setBuildOpensConsoleWindow(true);

    final reloaded = PubEnvironmentService(settingsFile: settings);
    await reloaded.load();
    expect(reloaded.autoOpenConsoleWindow, isFalse);
    expect(reloaded.showMainWindowConsole, isTrue);
    expect(reloaded.showConsoleQuickCommands, isFalse);
    expect(reloaded.buildOpensConsoleWindow, isTrue);
  });
}
