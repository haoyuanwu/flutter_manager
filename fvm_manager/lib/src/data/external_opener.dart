import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef WindowsShellLaunch = int Function(String target, String? parameters);
typedef ExternalProcessRun =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class ExternalOpener {
  const ExternalOpener({
    this.operatingSystem,
    this.windowsLaunch,
    this.processRun,
  });

  final String? operatingSystem;
  final WindowsShellLaunch? windowsLaunch;
  final ExternalProcessRun? processRun;
  String get _platform => operatingSystem ?? Platform.operatingSystem;

  Future<void> openDirectory(String path, {String description = '目录'}) async {
    if (!await Directory(path).exists()) {
      throw FileSystemException('$description不存在', path);
    }
    await _open(Directory(path).absolute.path, description: description);
  }

  Future<void> revealFile(String path) async {
    if (await FileSystemEntity.type(path) == FileSystemEntityType.notFound) {
      throw FileSystemException('文件或目录不存在', path);
    }
    final absolutePath = File(path).absolute.path;
    if (_platform == 'windows') {
      _launchWindows(
        'explorer.exe',
        parameters: '/select,"$absolutePath"',
        description: '文件所在目录',
      );
    } else if (_platform == 'macos') {
      await _run('open', ['-R', absolutePath], '文件所在目录');
    } else {
      await _run('xdg-open', [File(absolutePath).parent.path], '文件所在目录');
    }
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('无效的网页地址，仅支持 HTTP 或 HTTPS');
    }
    await _open(uri.toString(), description: '网页');
  }

  Future<void> openTextFile(String path) async {
    if (!await File(path).exists()) {
      throw FileSystemException('配置文件不存在', path);
    }
    final absolutePath = File(path).absolute.path;
    if (_platform == 'windows') {
      _launchWindows(
        'notepad.exe',
        parameters: '"$absolutePath"',
        description: '配置文件',
      );
    } else {
      await _open(absolutePath, description: '配置文件');
    }
  }

  Future<void> _open(String target, {required String description}) async {
    if (_platform == 'windows') {
      _launchWindows(target, description: description);
    } else {
      await _run(_platform == 'macos' ? 'open' : 'xdg-open', [
        target,
      ], description);
    }
  }

  void _launchWindows(
    String target, {
    String? parameters,
    required String description,
  }) {
    final result = (windowsLaunch ?? _nativeWindowsLaunch)(target, parameters);
    // Shell activation is successful above 32, independently of Explorer's exit code.
    if (result > 32) return;
    final reason = switch (result) {
      2 => '目标文件不存在',
      3 => '目标路径不存在',
      5 => '系统拒绝访问',
      8 || 0 => '系统资源不足',
      26 => '文件被其他程序占用',
      27 || 31 => '未找到关联的应用程序',
      28 => '应用程序响应超时',
      29 || 30 => '应用程序暂时无法响应',
      32 => '缺少所需的系统组件',
      _ => '系统未接受打开请求',
    };
    throw Exception('无法打开$description：$reason（系统错误 $result）');
  }

  Future<void> _run(
    String executable,
    List<String> arguments,
    String description,
  ) async {
    final result = await (processRun ?? Process.run)(executable, arguments);
    if (result.exitCode != 0) {
      final detail = result.stderr.toString().trim();
      throw Exception(
        '无法打开$description：${detail.isEmpty ? '退出码 ${result.exitCode}' : detail}',
      );
    }
  }

  static int _nativeWindowsLaunch(String target, String? parameters) {
    final shell = DynamicLibrary.open('shell32.dll');
    final ole = DynamicLibrary.open('ole32.dll');
    final initialize = ole
        .lookupFunction<
          Int32 Function(Pointer<Void>, Uint32),
          int Function(Pointer<Void>, int)
        >('CoInitializeEx');
    final uninitialize = ole.lookupFunction<Void Function(), void Function()>(
      'CoUninitialize',
    );
    final execute = shell
        .lookupFunction<
          IntPtr Function(
            Pointer<Void>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Int32,
          ),
          int Function(
            Pointer<Void>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            Pointer<Utf16>,
            int,
          )
        >('ShellExecuteW');
    return using((arena) {
      // Balance COM initialization only when this call acquired a reference.
      final initialized = initialize(nullptr, 0x2 | 0x4);
      if (initialized < 0 && initialized != -2147417850) {
        throw Exception('无法初始化 Windows Shell（错误 $initialized）');
      }
      try {
        return execute(
          nullptr,
          'open'.toNativeUtf16(allocator: arena),
          target.toNativeUtf16(allocator: arena),
          parameters?.toNativeUtf16(allocator: arena) ?? nullptr,
          nullptr,
          1,
        );
      } finally {
        if (initialized >= 0) uninitialize();
      }
    });
  }
}
