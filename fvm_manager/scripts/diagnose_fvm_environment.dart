// 用真实系统/用户环境模拟从资源管理器启动，避免继承 Codex 的临时 PATH。
// 运行：<dart.exe 绝对路径> scripts/diagnose_fvm_environment.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_manager/src/data/pub_environment_service.dart';

Future<void> main(List<String> arguments) async {
  if (!Platform.isWindows) throw UnsupportedError('Windows only');
  if (!arguments.contains('--child')) {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final result = await Process.run(
      '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
      [
        '-NoProfile',
        '-Command',
        r'''
$machine = [Environment]::GetEnvironmentVariables('Machine')
$user = [Environment]::GetEnvironmentVariables('User')
$result = @{}
foreach ($key in $machine.Keys) { $result[$key] = $machine[$key] }
foreach ($key in $user.Keys) { $result[$key] = $user[$key] }
$result['Path'] = $machine['Path'] + ';' + $user['Path']
foreach ($key in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','USERNAME','USERDOMAIN','HOMEDRIVE','HOMEPATH','SystemDrive','SystemRoot','windir','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','PROCESSOR_ARCHITECTURE','NUMBER_OF_PROCESSORS')) {
  $value = [Environment]::GetEnvironmentVariable($key)
  if ($value) { $result[$key] = $value }
}
$result | ConvertTo-Json -Compress
''',
      ],
      stdoutEncoding: utf8,
    );
    if (result.exitCode != 0) throw StateError(result.stderr.toString());
    final environment = (jsonDecode(result.stdout.toString()) as Map)
        .cast<String, String>();
    final child = await Process.start(
      Platform.resolvedExecutable,
      [Platform.script.toFilePath(), '--child'],
      environment: environment,
      includeParentEnvironment: false,
    );
    await Future.wait([
      stdout.addStream(child.stdout),
      stderr.addStream(child.stderr),
    ]);
    exitCode = await child.exitCode;
    return;
  }

  final service = PubEnvironmentService();
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final where = '$systemRoot\\System32\\where.exe';
  stdout.writeln('模拟来源：Windows 系统/用户环境，不继承 Codex 的临时变量');
  for (final name in ['git', 'dart', 'fvm']) {
    for (final entry in {
      '系统原始环境': Platform.environment,
      '软件补齐环境': service.processEnvironment,
    }.entries) {
      final result = await Process.run(
        where,
        [name],
        environment: entry.value,
        includeParentEnvironment: false,
      );
      stdout.writeln(
        '${entry.key} $name: ${result.exitCode == 0 ? result.stdout.toString().trim() : '未找到'}',
      );
    }
  }
  final fvm =
      '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\bin\\fvm.bat';
  final result = await Process.run(
    fvm,
    ['--version'],
    environment: service.processEnvironment,
    includeParentEnvironment: false,
    runInShell: true,
  ).timeout(const Duration(seconds: 45));
  stdout.writeln('实际执行：$fvm --version');
  stdout.writeln('退出码：${result.exitCode}');
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
