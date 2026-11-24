import 'dart:io';

/// 从已有盘符和 SDK 配置补找 Dart，不依赖启动终端临时设置的 FVM_CACHE_PATH。
List<String> windowsSdkPaths(
  Iterable<String> searchPaths, {
  bool Function(String)? fileExists,
}) {
  final exists = fileExists ?? (path) => File(path).existsSync();
  final drives = <String>{};
  final candidates = <String>{};
  for (final path in searchPaths) {
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) {
      drives.add(path.substring(0, 2).toUpperCase());
    }
    candidates.add(path);
  }
  for (final drive in drives) {
    for (final root in [
      r'fvm\default',
      'flutter',
      r'src\flutter',
      r'tools\flutter',
    ]) {
      candidates.add('$drive\\$root\\bin');
    }
  }
  return [
    for (final bin in candidates)
      if (exists('$bin\\cache\\dart-sdk\\bin\\dart.exe'))
        '$bin\\cache\\dart-sdk\\bin',
    for (final bin in candidates)
      if (exists('$bin\\dart.bat') || exists('$bin\\dart.exe')) bin,
  ];
}
