import 'dart:io';

import 'package:flutter_manager/src/data/flutter_command_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
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

    if (Platform.isWindows) {
      // FVM_CACHE_PATH 指向自定义缓存时，default/bin 中的 dart 必须可被 fvm.bat 找到。
      final fvmCache = Platform.environment['FVM_CACHE_PATH'] ??
          Platform.environment['FVM_HOME'];
      if (fvmCache != null && fvmCache.trim().isNotEmpty) {
        final cache = fvmCache.trim().replaceAll(RegExp(r'[\\/]$'), '');
        expect(paths, contains('$cache\\default\\bin'));
      }
    }

    final path = service.processEnvironment['PATH'];
    expect(path, isNotNull);
    expect(path, isNotEmpty);
    // Windows 上 PATH 键大小写不敏感，不应残留 Path/PATH 双份。
    if (Platform.isWindows) {
      final keys = service.processEnvironment.keys
          .where((key) => key.toLowerCase() == 'path')
          .toList();
      expect(keys, hasLength(1));
    }
  });

  test('accepts Windows fvm.exe when selecting a local directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_local_fvm_exe_',
    );
    addTearDown(() => root.delete(recursive: true));
    final bin = Directory('${root.path}/bin');
    await bin.create();
    final executable = File(
      '${bin.path}/${Platform.isWindows ? 'fvm.bat' : 'fvm'}',
    );
    // Windows 上优先尝试 fvm.exe，这里放一个会失败的假 fvm.exe，
    // 再放可用的 fvm.bat，验证多名称回退。
    if (Platform.isWindows) {
      await File('${bin.path}/fvm.exe').writeAsString('not-an-exe');
    }
    await executable.writeAsString(
      Platform.isWindows
          ? '@if "%1"=="--version" echo 8.8.8\r\n'
          : '#!/bin/sh\nif [ "\$1" = "--version" ]; then echo 8.8.8; fi\n',
    );
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', executable.path]);
      expect(chmod.exitCode, 0);
    }

    final settings = File('${root.path}/settings.json');
    final environment = PubEnvironmentService(settingsFile: settings);
    final fvm = FvmService(environment);
    final version = await fvm.useLocalDirectory(root.path);

    expect(version, '8.8.8');
    expect(fvm.executablePath, isNotNull);
    expect(
      _normalizedPath(fvm.executablePath!),
      _normalizedPath(executable.path),
    );
    expect(
      _normalizedPath(environment.customFvmExecutable!),
      _normalizedPath(executable.path),
    );
  });

  test('accepts selecting the fvm executable file itself', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_local_fvm_file_',
    );
    addTearDown(() => root.delete(recursive: true));
    final executable = File(
      '${root.path}/${Platform.isWindows ? 'fvm.cmd' : 'fvm'}',
    );
    await executable.writeAsString(
      Platform.isWindows
          ? '@if "%1"=="--version" echo 7.7.7\r\n'
          : '#!/bin/sh\nif [ "\$1" = "--version" ]; then echo 7.7.7; fi\n',
    );
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', executable.path]);
      expect(chmod.exitCode, 0);
    }

    final settings = File('${root.path}/settings.json');
    final environment = PubEnvironmentService(settingsFile: settings);
    final fvm = FvmService(environment);
    final version = await fvm.useLocalDirectory(executable.path);

    expect(version, '7.7.7');
    expect(
      _normalizedPath(environment.customFvmExecutable!),
      _normalizedPath(executable.path),
    );
  });

  test('accepts parent directory that only has bin/fvm', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_local_fvm_parent_',
    );
    addTearDown(() => root.delete(recursive: true));
    final cacheDir = Directory('${root.path}/Pub/Cache');
    final bin = Directory('${cacheDir.path}/bin');
    await bin.create(recursive: true);
    final executable = File(
      '${bin.path}/${Platform.isWindows ? 'fvm.bat' : 'fvm'}',
    );
    await executable.writeAsString(
      Platform.isWindows
          ? '@if "%1"=="--version" echo 6.6.6\r\n'
          : '#!/bin/sh\nif [ "\$1" = "--version" ]; then echo 6.6.6; fi\n',
    );
    if (!Platform.isWindows) {
      final chmod = await Process.run('chmod', ['+x', executable.path]);
      expect(chmod.exitCode, 0);
    }

    final settings = File('${root.path}/settings.json');
    final environment = PubEnvironmentService(settingsFile: settings);
    final fvm = FvmService(environment);
    // 用户选到 Pub\\Cache 这一级即可，不必点进 bin。
    final version = await fvm.useLocalDirectory(cacheDir.path);
    expect(version, '6.6.6');
  });

  test('processEnvironment keeps Windows system dirs and PATH', () {
    final service = PubEnvironmentService();
    final env = service.processEnvironment;
    final path = env['PATH'] ?? '';
    expect(path, isNotEmpty);
    if (Platform.isWindows) {
      final lower = path.toLowerCase();
      expect(lower, contains('windows'));
      expect(env.keys.where((k) => k.toLowerCase() == 'path'), hasLength(1));
    }
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
    expect(
      _normalizedPath(environment.customFvmExecutable!),
      _normalizedPath(executable.path),
    );

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
      final commands = FlutterCommandService(fvm, ProcessRunner());
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
    expect(
      _normalizedPath(reloaded.customFvmExecutable!),
      _normalizedPath(executable.path),
    );
    expect(await FvmService(reloaded).detect(), '9.9.9');
  });

  test('isolates command logs by console tab id', () {
    final logs = ProjectCommandLogBuffer(maxLength: 20);
    logs.append('run::/project/a', 'A log');
    logs.append('build::/project/a', 'B log');

    expect(logs.logFor('run::/project/a'), 'A log');
    expect(logs.logFor('build::/project/a'), 'B log');

    logs.clear('run::/project/a');
    expect(logs.logFor('run::/project/a'), isEmpty);
    expect(logs.logFor('build::/project/a'), 'B log');

    expect(
      logs.logForProject('/project/a', ['run::/project/a', 'build::/project/a']),
      contains('B log'),
    );
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

String _normalizedPath(String path) =>
    File(path).absolute.path.replaceAll('/', Platform.pathSeparator);
