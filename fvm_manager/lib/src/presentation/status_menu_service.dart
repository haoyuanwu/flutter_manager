import 'package:flutter/services.dart';

class StatusMenuService {
  StatusMenuService._();

  static final instance = StatusMenuService._();

  static const _channel = MethodChannel('fvm_manager/status_menu');

  bool _initialized = false;

  Future<void> initialize(
    Future<void> Function(String projectPath) onOpenConsole, {
    required Future<void> Function(String projectPath, String action)
    onRunProjectAction,
  }) async {
    if (_initialized) return;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<dynamic, dynamic>?;
      final projectPath = arguments?['projectPath'] as String?;
      if (projectPath == null || projectPath.isEmpty) return;
      switch (call.method) {
        case 'openConsole':
          await onOpenConsole(projectPath);
        case 'runProjectAction':
          final action = arguments?['action'] as String?;
          if (action != null && action.isNotEmpty) {
            await onRunProjectAction(projectPath, action);
          }
      }
    });
    _initialized = true;
  }

  Future<void> update({
    required String fvmVersion,
    required String flutterVersion,
    required List<Map<String, String>> projects,
    required List<Map<String, String>> processes,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateStatus', {
        'fvmVersion': fvmVersion,
        'flutterVersion': flutterVersion,
        'projects': projects,
        'processes': processes,
      });
    } on MissingPluginException {
      // Widget tests and non-macOS platforms do not register the native menu.
    }
  }
}
