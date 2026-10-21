import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'posix_lock_owner.dart';

typedef LockProcessRun = Future<ProcessResult> Function(String, List<String>);

bool hasFlutterStartupLockWarning(String log) {
  final tail = log.length > 2000 ? log.substring(log.length - 2000) : log;
  return tail.contains(
    'Waiting for another flutter command to release the startup lock',
  );
}

class FlutterLockOwner {
  const FlutterLockOwner(this.pid, this.identity);
  final int pid;
  // Start time + executable; prevents signalling a recycled PID after a dialog.
  final String identity;

  Map<String, dynamic> toJson() => {'pid': pid, 'identity': identity};
  factory FlutterLockOwner.fromJson(Map<dynamic, dynamic> json) =>
      FlutterLockOwner(json['pid'] as int, json['identity'] as String);
}

class FlutterLockReport {
  const FlutterLockReport(this.sdkPath, this.owners);
  final String sdkPath;
  final List<FlutterLockOwner> owners;
  Map<String, dynamic> toJson() => {
    'sdkPath': sdkPath,
    'owners': owners.map((owner) => owner.toJson()).toList(),
  };
  factory FlutterLockReport.fromJson(Map<dynamic, dynamic> json) =>
      FlutterLockReport(
        json['sdkPath'] as String,
        (json['owners'] as List)
            .map((item) => FlutterLockOwner.fromJson(item as Map))
            .toList(),
      );
}

/// Operates on proven lock owners only. Never deletes the lockfile (doing so
/// creates a second inode and lets concurrent Flutter commands corrupt caches).
class FlutterStartupLockService {
  FlutterStartupLockService({
    LockProcessRun? run,
    bool? windows,
    bool Function(int, ProcessSignal)? signal,
    Future<void> Function(Duration)? delay,
    int? Function(String)? recordLockOwner,
  }) : _run = run ?? _runProcess,
       _windows = windows ?? Platform.isWindows,
       _signal = signal ?? Process.killPid,
       _recordLockOwner = recordLockOwner ?? posixRecordLockOwner,
       _delay = delay ?? Future<void>.delayed;

  final LockProcessRun _run;
  final bool _windows;
  final bool Function(int, ProcessSignal) _signal;
  final int? Function(String) _recordLockOwner;
  final Future<void> Function(Duration) _delay;
  bool _stopping = false;

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> args,
  ) async {
    final process = await Process.start(executable, args);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 15));
      return ProcessResult(process.pid, code, await output, await errors);
    } on TimeoutException {
      process.kill();
      throw Exception('检查锁占用超时，请稍后重试');
    }
  }

  Future<FlutterLockReport> inspect(String sdkPath) async {
    if (_windows) return _inspectWindows(sdkPath);
    final owners = <int>{};
    final cacheLock = '$sdkPath/bin/cache/lockfile';
    if (await File(cacheLock).exists()) {
      final pid = _recordLockOwner(cacheLock);
      if (pid != null) owners.add(pid);
    }
    // Linux shell bootstrap uses flock on shared.sh, rather than record locks.
    for (final path in ['$sdkPath/bin/internal/shared.sh']) {
      if (!await File(path).exists()) continue;
      final result = await _run('lsof', ['-nP', '-F', 'pfl', path]);
      if ((result.exitCode != 0 && result.exitCode != 1) ||
          result.stderr.toString().trim().isNotEmpty) {
        throw Exception('无法检查锁占用：${result.stderr}');
      }
      owners.addAll(parsePosixLockOwners(result.stdout.toString()));
    }
    final processes = <FlutterLockOwner>[];
    for (final pid in owners) {
      final result = await _run('ps', [
        '-p',
        '$pid',
        '-o',
        'lstart=',
        '-o',
        'comm=',
      ]);
      final identity = result.stdout.toString().trim();
      if (result.exitCode == 0 && identity.isNotEmpty) {
        processes.add(FlutterLockOwner(pid, identity));
      }
    }
    // A lock we cannot attribute is not permission to kill arbitrary Dart
    // processes or delete an upgrade lock. Report that limitation explicitly.
    if (processes.isEmpty) await _verifyPosixUnlocked(sdkPath);
    return FlutterLockReport(sdkPath, processes);
  }

  static Set<int> parsePosixLockOwners(String output) {
    final owners = <int>{};
    int? pid;
    for (final line in const LineSplitter().convert(output)) {
      if (line.startsWith('p')) pid = int.tryParse(line.substring(1));
      if (pid != null &&
          pid > 0 &&
          (line == 'lW' || line == 'lw' || line == 'lu')) {
        owners.add(pid);
      }
    }
    return owners;
  }

  Future<void> _verifyPosixUnlocked(String sdkPath) async {
    if (await FileSystemEntity.type('$sdkPath/bin/cache/.upgrade_lock') !=
        FileSystemEntityType.notFound) {
      throw Exception(
        '检测到 Flutter SDK 更新锁，但无法安全确定占用者。请等待 SDK 更新完成，或关闭相关终端后重试；未删除任何锁文件。',
      );
    }
    final file = File('$sdkPath/bin/cache/lockfile');
    if (!await file.exists()) return;
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      await handle.unlock();
    } on FileSystemException {
      throw Exception('启动锁仍被占用，但无法识别占用进程。请检查进程权限后重试；未结束任何未知进程。');
    } finally {
      await handle.close();
    }
  }

  Future<FlutterLockReport> stop(
    FlutterLockReport approved, {
    bool force = false,
  }) async {
    if (_stopping) throw Exception('已有解锁操作正在进行，请稍候');
    _stopping = true;
    try {
      // Re-check each owner immediately before signalling. Never kill a new
      // owner that appeared while the user was reading the confirmation.
      for (final owner in approved.owners) {
        if (owner.pid == pid) throw Exception('无法停止 Flutter Manager 自身的进程');
        final current = await inspect(approved.sdkPath);
        if (!current.owners.any(
          (item) => item.pid == owner.pid && item.identity == owner.identity,
        )) {
          continue;
        }
        if (_windows) {
          await _windowsStop(owner, force: force);
        } else {
          _signal(
            owner.pid,
            force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
          );
        }
      }
      for (var attempt = 0; attempt < 12; attempt++) {
        await _delay(const Duration(milliseconds: 250));
        final current = await inspect(approved.sdkPath);
        if (current.owners.isEmpty || attempt == 11) return current;
      }
      throw StateError('Unreachable');
    } finally {
      _stopping = false;
    }
  }

  Future<FlutterLockReport> _inspectWindows(String sdkPath) async {
    // Restart Manager enumerates actual file owners, not all dart.exe processes.
    final paths = [
      for (final name in ['lockfile', 'flutter.bat.lock'])
        '$sdkPath/bin/cache/$name',
    ];
    final result = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$ErrorActionPreference = 'Stop';\n$_restartManager\n"
          '\$files = @(${paths.map(_psQuote).join(',')}) | Where-Object { Test-Path -LiteralPath \$_ };\n'
          '\$owners = @([FlutterLockFinder]::Find([string[]]\$files) | ForEach-Object { '
          '\$p = Get-Process -Id \$_ -ErrorAction Stop; '
          '@{pid=\$p.Id; identity=(\$p.StartTime.ToUniversalTime().Ticks.ToString() + " " + \$p.ProcessName)} }); '
          'ConvertTo-Json -InputObject \$owners -Compress',
    ]);
    if (result.exitCode != 0) throw Exception('无法检查启动锁：${result.stderr}');
    final owners = (jsonDecode(result.stdout.toString()) as List)
        .map((item) => FlutterLockOwner.fromJson(item as Map))
        .toList();
    return FlutterLockReport(sdkPath, owners);
  }

  Future<void> _windowsStop(
    FlutterLockOwner owner, {
    required bool force,
  }) async {
    final result = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$ErrorActionPreference='Stop'; \$p=Get-Process -Id ${owner.pid} -ErrorAction SilentlyContinue; "
          'if (\$null -ne \$p -and (\$p.StartTime.ToUniversalTime().Ticks.ToString() + " " + \$p.ProcessName) -eq ${_psQuote(owner.identity)}) { '
          '${force ? '\$p.Kill()' : '[void]\$p.CloseMainWindow()'} }',
    ]);
    if (result.exitCode != 0) throw Exception('停止占用进程失败：${result.stderr}');
  }

  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  static const _restartManager = r'''
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class FlutterLockFinder {
  [StructLayout(LayoutKind.Sequential)] struct UniqueProcess {
    public int pid; public System.Runtime.InteropServices.ComTypes.FILETIME start;
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Info {
    public UniqueProcess process;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string name;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string service;
    public uint type, status, session;
    [MarshalAs(UnmanagedType.Bool)] public bool restartable;
  }
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)] static extern int RmStartSession(out uint h, int flags, StringBuilder key);
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)] static extern int RmRegisterResources(uint h, uint count, string[] files, uint apps, IntPtr processes, uint services, IntPtr names);
  [DllImport("rstrtmgr.dll")] static extern int RmGetList(uint h, out uint needed, ref uint count, [In,Out] Info[] info, ref uint reason);
  [DllImport("rstrtmgr.dll")] static extern int RmEndSession(uint h);
  public static int[] Find(string[] files) {
    if (files.Length == 0) return new int[0];
    uint h; int code=RmStartSession(out h, 0, new StringBuilder(33));
    if (code != 0) throw new Exception("RmStartSession: " + code);
    try {
      code=RmRegisterResources(h, (uint)files.Length, files, 0, IntPtr.Zero, 0, IntPtr.Zero);
      if (code != 0) throw new Exception("RmRegisterResources: " + code);
      for (int attempt=0; attempt<3; attempt++) {
        uint needed, count=0, reason=0;
        code=RmGetList(h, out needed, ref count, null, ref reason);
        if (code == 0) return new int[0];
        if (code != 234) throw new Exception("RmGetList: " + code);
        Info[] info=new Info[needed]; count=needed;
        code=RmGetList(h, out needed, ref count, info, ref reason);
        if (code == 234) continue;
        if (code != 0) throw new Exception("RmGetList: " + code);
        var ids=new List<int>();
        for (int i=0; i<count; i++) if (!ids.Contains(info[i].process.pid)) ids.Add(info[i].process.pid);
        return ids.ToArray();
      }
      throw new Exception("Lock owners changed; retry");
    } finally { RmEndSession(h); }
  }
}
'@
''';
}
