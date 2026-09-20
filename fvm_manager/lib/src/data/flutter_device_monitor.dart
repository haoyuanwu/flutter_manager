import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'fvm_service.dart';

class FlutterDeviceMonitor {
  FlutterDeviceMonitor(this._fvmService);

  final FvmService _fvmService;
  final Map<String, Map<String, String>> _devices = {};
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Timer? _refreshTimer;
  Timer? _restartTimer;
  int _generation = 0;
  int _requestId = 0;
  final Set<int> _deviceSnapshotRequestIds = {};
  bool _refreshing = false;
  String? _projectPath;
  void Function(List<Map<String, String>> devices)? _onDevices;
  void Function(Object error)? _onError;

  bool get isRunning => _process != null;

  Future<void> start({
    required String projectPath,
    required void Function(List<Map<String, String>> devices) onDevices,
    required void Function(Object error) onError,
  }) async {
    _projectPath = projectPath;
    _onDevices = onDevices;
    _onError = onError;
    if (_process != null) {
      _emit(onDevices);
      await refresh();
      return;
    }
    await stop();
    final generation = ++_generation;
    _devices.clear();
    try {
      final process = await _fvmService.startFlutterCommand(
        projectPath: projectPath,
        arguments: const ['daemon', '--machine'],
      );
      if (generation != _generation) {
        process.kill();
        return;
      }
      _process = process;
      _stdoutSubscription = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (line) =>
                _handleLine(line, generation: generation, onDevices: onDevices),
          );
      _stderrSubscription = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((_) {});
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(refresh());
      });
      unawaited(
        process.exitCode.then((code) {
          if (generation == _generation) {
            _process = null;
            _refreshTimer?.cancel();
            _refreshTimer = null;
            onError(Exception('设备监听已停止（退出码 $code）'));
            _scheduleRestart(generation);
          }
        }),
      );
    } on Object catch (error) {
      if (generation == _generation) {
        onError(error);
        _scheduleRestart(generation);
      }
    }
  }

  void _scheduleRestart(int generation) {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 2), () {
      if (generation != _generation || _process != null) return;
      final projectPath = _projectPath;
      final onDevices = _onDevices;
      final onError = _onError;
      if (projectPath == null || onDevices == null || onError == null) return;
      unawaited(
        start(projectPath: projectPath, onDevices: onDevices, onError: onError),
      );
    });
  }

  void _handleLine(
    String line, {
    required int generation,
    required void Function(List<Map<String, String>> devices) onDevices,
  }) {
    if (generation != _generation || line.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(line);
      final messages = decoded is List<dynamic> ? decoded : [decoded];
      for (final raw in messages.whereType<Map<dynamic, dynamic>>()) {
        final message = raw.cast<String, dynamic>();
        final event = message['event'] as String?;
        if (event == 'daemon.connected') {
          unawaited(_enableDevices());
          continue;
        }
        if (event == 'device.added' || event == 'device.changed') {
          final device = _normalizeDevice(message['params']);
          if (device != null) _devices[device['id']!] = device;
          _emit(onDevices);
          continue;
        }
        if (event == 'device.removed') {
          final params = message['params'];
          final id = params is Map
              ? (params['id'] ?? params['deviceId'])?.toString()
              : params?.toString();
          if (id != null) _devices.remove(id);
          _emit(onDevices);
          continue;
        }
        final responseId = message['id'];
        if (responseId is int && _deviceSnapshotRequestIds.remove(responseId)) {
          final result = message['result'];
          if (result is List<dynamic>) {
            final snapshot = <String, Map<String, String>>{};
            for (final rawDevice in result) {
              final device = _normalizeDevice(rawDevice);
              if (device != null) snapshot[device['id']!] = device;
            }
            _devices
              ..clear()
              ..addAll(snapshot);
          }
          _emit(onDevices);
        }
      }
    } on FormatException {
      // Flutter can emit a small amount of non-protocol startup text.
    }
  }

  Map<String, String>? _normalizeDevice(Object? raw) {
    if (raw is! Map) return null;
    final outer = raw.cast<dynamic, dynamic>();
    final nested = outer['device'];
    final data = nested is Map ? nested.cast<dynamic, dynamic>() : outer;
    final id = (data['id'] ?? data['deviceId'] ?? '').toString();
    if (id.isEmpty) return null;
    return {
      'id': id,
      'name': (data['name'] ?? id).toString(),
      'platform':
          (data['platform'] ??
                  data['targetPlatform'] ??
                  data['platformType'] ??
                  '')
              .toString(),
    };
  }

  void _emit(void Function(List<Map<String, String>>) onDevices) {
    final devices = _devices.values.toList(growable: false)
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
    onDevices(devices);
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    final input = _process?.stdin;
    if (input == null) return;
    _refreshing = true;
    try {
      final requestId = ++_requestId;
      _deviceSnapshotRequestIds.add(requestId);
      input.writeln(
        jsonEncode([
          {'id': requestId, 'method': 'device.getDevices'},
        ]),
      );
      await input.flush();
    } on Object {
      // 进程退出回调会负责重连。
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _enableDevices() async {
    final input = _process?.stdin;
    if (input == null) return;
    final enableId = ++_requestId;
    input.writeln(
      jsonEncode([
        {'id': enableId, 'method': 'device.enable'},
      ]),
    );
    await input.flush();
    await refresh();
  }

  Future<void> stop() async {
    _generation++;
    _refreshTimer?.cancel();
    _restartTimer?.cancel();
    _refreshTimer = null;
    _restartTimer = null;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process?.kill();
    _process = null;
    _refreshing = false;
    _deviceSnapshotRequestIds.clear();
    _devices.clear();
  }

  Future<void> dispose() => stop();
}
