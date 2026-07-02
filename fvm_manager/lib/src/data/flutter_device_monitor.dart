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
  int _generation = 0;

  bool get isRunning => _process != null;

  Future<void> start({
    required String projectPath,
    required void Function(List<Map<String, String>> devices) onDevices,
    required void Function(Object error) onError,
  }) async {
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
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) =>
                _handleLine(line, generation: generation, onDevices: onDevices),
          );
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((_) {});
      unawaited(
        process.exitCode.then((code) {
          if (generation == _generation) {
            _process = null;
            onError(Exception('设备监听已停止（退出码 $code）'));
          }
        }),
      );
    } on Object catch (error) {
      if (generation == _generation) onError(error);
    }
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
          final input = _process?.stdin;
          if (input != null) {
            input.writeln(
              jsonEncode([
                {'id': 1, 'method': 'device.enable'},
                {'id': 2, 'method': 'device.getDevices'},
              ]),
            );
            unawaited(input.flush());
          }
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
        if (message['id'] == 2) {
          final result = message['result'];
          if (result is List<dynamic>) {
            for (final rawDevice in result) {
              final device = _normalizeDevice(rawDevice);
              if (device != null) _devices[device['id']!] = device;
            }
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
    final data = raw.cast<dynamic, dynamic>();
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
    final input = _process?.stdin;
    if (input == null) return;
    input.writeln(
      jsonEncode([
        {'id': 2, 'method': 'device.getDevices'},
      ]),
    );
    await input.flush();
  }

  Future<void> stop() async {
    _generation++;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _process?.kill();
    _process = null;
    _devices.clear();
  }

  Future<void> dispose() => stop();
}
