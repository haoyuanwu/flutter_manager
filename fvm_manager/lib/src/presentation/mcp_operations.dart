import 'dart:async';

/// Tracks bounded, single-flight MCP mutations without holding an HTTP request.
class McpOperations {
  final _jobs = <String, Map<String, dynamic>>{};
  int _sequence = 0;
  bool busy = false;

  Map<String, dynamic> start(
    String action,
    String? projectPath,
    Future<Map<String, dynamic>> Function() run, {
    String Function(Object)? describeError,
  }) {
    if (busy) throw StateError('已有 MCP 操作进行中，请等待完成后再提交');
    busy = true;
    final id = 'mcp-${++_sequence}';
    final job = <String, dynamic>{
      'operationId': id,
      'action': action,
      'projectPath': projectPath,
      'status': 'running',
      'startedAt': DateTime.now().toIso8601String(),
    };
    _jobs[id] = job;
    while (_jobs.length > 100) {
      _jobs.remove(_jobs.keys.first);
    }
    unawaited(
      Future<void>(() async {
        try {
          job['result'] = await run();
          job['status'] = job['cancelRequested'] == true
              ? 'cancelled'
              : 'success';
        } on Object catch (error) {
          job['status'] = 'failed';
          job['error'] = describeError?.call(error) ?? error.toString();
        } finally {
          job['finishedAt'] = DateTime.now().toIso8601String();
          busy = false;
        }
      }),
    );
    return {'accepted': true, ...job};
  }

  void requestCancellation(String action, String? projectPath) {
    for (final job in _jobs.values) {
      if (job['status'] == 'running' &&
          job['action'] == action &&
          (projectPath == null || job['projectPath'] == projectPath)) {
        job['cancelRequested'] = true;
      }
    }
  }

  Map<String, dynamic> get(String id) {
    final job = _jobs[id];
    if (job == null) throw ArgumentError('未知操作 ID：$id');
    return Map.of(job);
  }

  List<Map<String, dynamic>> list() =>
      _jobs.values.map(Map<String, dynamic>.of).toList();
}

const mcpExtendedCommands = {
  'get_capabilities',
  'get_operation',
  'list_operations',
  'get_project_config',
  'configure_project',
  'scan_artifacts',
  'build_history',
  'package_macos',
  'package_windows',
  'upload_pgyer',
  'upload_fir',
  'sign_apk',
  'install_apk',
  'list_android_devices',
  'signing_info',
  'project_action',
  'sdk_action',
  'environment_action',
  'get_environment',
  'custom_workflow',
  'update_version',
  'upload_bugly',
  'file_action',
  'console_action',
  'dependencies',
  'create_project',
  'parse_log',
  'settings',
};
