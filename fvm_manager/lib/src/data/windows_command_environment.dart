/// Windows 批处理调用 dart/git 等裸命令时依赖 PATHEXT；GUI 可能继承空值。
Map<String, String> windowsCommandEnvironment(
  Map<String, String> environment,
  Iterable<String> searchPaths,
) {
  final result = Map<String, String>.from(environment);
  final extensions = <String>{};
  for (final entry in environment.entries) {
    if (entry.key.toLowerCase() == 'pathext') {
      extensions.addAll(
        entry.value
            .split(';')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty),
      );
    }
  }
  extensions.addAll(['.COM', '.EXE', '.BAT', '.CMD']);
  result.removeWhere(
    (key, _) => ['path', 'pathext'].contains(key.toLowerCase()),
  );
  result['PATH'] = searchPaths.join(';');
  result['PATHEXT'] = extensions.join(';');
  return result;
}
