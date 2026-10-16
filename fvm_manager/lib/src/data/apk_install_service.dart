import 'dart:io';

import 'process_runner.dart';
import 'pub_environment_service.dart';

class ApkInstallException implements Exception {
  const ApkInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AndroidDevice {
  const AndroidDevice({
    required this.id,
    required this.status,
    this.model = '',
  });

  final String id;
  final String status;
  final String model;

  bool get available => status == 'device';

  String get displayName => model.isEmpty ? id : '$model ($id)';
}

class ApkInstallService {
  ApkInstallService(this._runner, this._environment, {this.adbExecutable});

  final ProcessRunner _runner;
  final PubEnvironmentService _environment;
  final String? adbExecutable;

  Future<String> _findAdb() async {
    if (adbExecutable != null) return adbExecutable!;
    final env = _environment.processEnvironment;
    final home = env[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final sdkPaths = <String?>[
      env['ANDROID_SDK_ROOT'],
      env['ANDROID_HOME'],
      if (Platform.isMacOS && home != null) '$home/Library/Android/sdk',
      if (Platform.isWindows)
        env['LOCALAPPDATA'] == null
            ? null
            : '${env['LOCALAPPDATA']}\\Android\\Sdk',
      if (Platform.isLinux && home != null) '$home/Android/Sdk',
    ];
    final fileName = Platform.isWindows ? 'adb.exe' : 'adb';
    for (final sdk in sdkPaths) {
      if (sdk == null || sdk.isEmpty) continue;
      final path =
          '$sdk${Platform.pathSeparator}platform-tools'
          '${Platform.pathSeparator}$fileName';
      if (await File(path).exists()) return path;
    }
    final pathKey = env.keys.firstWhere(
      (key) => key.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    for (final directory in (env[pathKey] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      if (directory.isEmpty) continue;
      final path = '$directory${Platform.pathSeparator}$fileName';
      if (await File(path).exists()) return path;
    }
    throw const ApkInstallException(
      '未找到 ADB。请安装 Android SDK Platform-Tools，并配置 ANDROID_HOME 或 PATH。',
    );
  }

  Future<List<AndroidDevice>> listDevices() async {
    final adb = await _findAdb();
    final result = await _runner.run(
      executable: adb,
      arguments: const ['devices', '-l'],
      environment: _environment.processEnvironment,
      timeout: const Duration(seconds: 15),
    );
    if (result.exitCode != 0) {
      throw ApkInstallException(
        '获取设备失败：${result.bestMessage.isEmpty ? 'ADB 退出码 ${result.exitCode}' : result.bestMessage}',
      );
    }
    return parseAdbDevices(result.stdout);
  }

  Future<void> install({
    required String apkPath,
    required String deviceId,
  }) async {
    if (!apkPath.toLowerCase().endsWith('.apk')) {
      throw const ApkInstallException('请选择 APK 文件。');
    }
    if (!await File(apkPath).exists()) {
      throw const ApkInstallException('APK 文件不存在，请重新选择。');
    }
    if (deviceId.trim().isEmpty) {
      throw const ApkInstallException('请先选择设备。');
    }
    final adb = await _findAdb();
    final result = await _runner.run(
      executable: adb,
      arguments: ['-s', deviceId, 'install', '-r', apkPath],
      environment: _environment.processEnvironment,
      timeout: const Duration(minutes: 5),
    );
    if (result.exitCode != 0 || !result.stdout.contains('Success')) {
      throw ApkInstallException(
        '安装失败：${result.bestMessage.isEmpty ? 'ADB 退出码 ${result.exitCode}' : result.bestMessage}',
      );
    }
  }
}

List<AndroidDevice> parseAdbDevices(String output) {
  final devices = <AndroidDevice>[];
  for (final rawLine in output.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty ||
        line.startsWith('List of devices attached') ||
        line.startsWith('* daemon')) {
      continue;
    }
    final fields = line.split(RegExp(r'\s+'));
    if (fields.length < 2) continue;
    final model = fields
        .firstWhere((field) => field.startsWith('model:'), orElse: () => '')
        .replaceFirst('model:', '')
        .replaceAll('_', ' ');
    devices.add(
      AndroidDevice(id: fields.first, status: fields[1], model: model),
    );
  }
  return devices;
}
