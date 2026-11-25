import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/data/fvm_service.dart';
import 'src/data/pub_environment_service.dart';
import 'src/data/startup_log.dart';
import 'src/presentation/pages/console_window_page.dart';

Future<void> main(List<String> args) async {
  StartupLog.write('main', {
    'executable': Platform.resolvedExecutable,
    'cwd': Directory.current.path,
    'home': Platform.environment['USERPROFILE'],
  });
  WidgetsFlutterBinding.ensureInitialized();

  if (args.length == 2 && args.first == '--diagnose-fvm') {
    final output = File(args[1]);
    final report = <String, Object?>{
      'executable': Platform.resolvedExecutable,
      'workingDirectory': Directory.current.path,
      'userProfile': Platform.environment['USERPROFILE'],
      'step': 'load settings',
    };
    Future<void> save() =>
        output.writeAsString(jsonEncode(report), flush: true);
    try {
      await save();
      final environment = PubEnvironmentService();
      await environment.load();
      report.addAll({
        'custom': environment.customFvmExecutable,
        'cached': environment.cachedFvmExecutable,
        'step': 'detect FVM',
      });
      await save();
      final fvm = FvmService(environment);
      report['version'] = await fvm
          .detect(allowRepair: false)
          .timeout(const Duration(seconds: 40));
      report['fvmExecutable'] = fvm.executablePath;
      report['step'] = 'complete';
    } catch (error, stack) {
      report['error'] = error.toString();
      report['stack'] = stack.toString();
    }
    await save();
    exit(0);
  }

  if (args.length >= 3 && args.first == 'multi_window') {
    final windowId = args[1];
    final argument = args[2];
    final params = _decodeWindowArguments(argument);
    final windowType = params['windowType'] as String? ?? '';
    if (windowType == 'console') {
      final projectTitle = params['projectTitle'] as String? ?? '控制台';
      final projectPath = params['projectPath'] as String? ?? '';
      final commandLog = params['commandLog'] as String? ?? '';
      final showQuickCommands = params['showQuickCommands'] as bool? ?? true;
      final consoleMode = params['consoleMode'] as String? ?? 'run';
      final buildTarget = params['buildTarget'] as String? ?? 'apk';
      final actionChannelName =
          params['actionChannelName'] as String? ??
          'fvm_manager/console_commands';
      final tasks = (params['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (task) => task.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
          .toList(growable: false);
      runApp(
        ProviderScope(
          child: ConsoleWindowApp(
            windowId: windowId,
            tabId: params['tabId'] as String?,
            projectTitle: projectTitle,
            projectPath: projectPath,
            initialCommandLog: commandLog,
            initialTasks: tasks,
            initialShowQuickCommands: showQuickCommands,
            initialConsoleMode: consoleMode,
            initialBuildTarget: buildTarget,
            initialActionChannelName: actionChannelName,
          ),
        ),
      );
      return;
    }
  }

  runApp(const ProviderScope(child: FvmManagerApp()));
}

Map<String, dynamic> _decodeWindowArguments(String source) {
  if (source.isEmpty) return const {};
  try {
    final decoded = jsonDecode(source);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}
