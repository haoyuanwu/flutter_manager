import 'dart:io';

/// 查找未加入 PATH 的常见 Git for Windows 安装，只返回包含 git.exe 的目录。
List<String> windowsGitPaths(
  Map<String, String> environment, {
  bool Function(String path)? fileExists,
  Iterable<String> installationRoots = const [],
}) {
  final exists = fileExists ?? (path) => File(path).existsSync();
  String? env(String name) {
    for (final entry in environment.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase() &&
          entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return null;
  }

  final home = env('USERPROFILE');
  final local =
      env('LOCALAPPDATA') ?? (home == null ? null : '$home\\AppData\\Local');
  final roots = <String>[
    '${env('ProgramW6432') ?? env('ProgramFiles') ?? r'C:\Program Files'}\\Git',
    '${env('ProgramFiles(x86)') ?? r'C:\Program Files (x86)'}\\Git',
    if (local != null) '$local\\Programs\\Git',
    if (home != null) '$home\\scoop\\apps\\git\\current',
    if (env('SCOOP') case final scoop?) '$scoop\\apps\\git\\current',
    if (env('SCOOP_GLOBAL') case final scoop?) '$scoop\\apps\\git\\current',
    r'C:\Git',
    ...installationRoots,
    // Codex 自带完整 PortableGit，但只在其终端中临时加入 PATH。
    // 从资源管理器启动的 GUI 也需要能找到这份 Git。
    if (home != null)
      '$home\\.cache\\codex-runtimes\\codex-primary-runtime'
          '\\dependencies\\native\\git',
  ];
  final paths = <String>[];
  final seen = <String>{};
  for (final root in roots) {
    for (final suffix in const [r'cmd', r'bin']) {
      final path = '$root\\$suffix';
      if (seen.add(path.toLowerCase()) && exists('$path\\git.exe')) {
        paths.add(path);
      }
    }
  }
  return paths;
}
