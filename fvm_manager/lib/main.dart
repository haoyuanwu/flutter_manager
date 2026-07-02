import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/presentation/pages/console_window_page.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

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
            projectTitle: projectTitle,
            projectPath: projectPath,
            initialCommandLog: commandLog,
            initialTasks: tasks,
            initialShowQuickCommands: showQuickCommands,
            initialConsoleMode: consoleMode,
            initialBuildTarget: buildTarget,
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
