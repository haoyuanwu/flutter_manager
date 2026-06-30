import 'dart:convert';
import 'dart:io';

import '../domain/project_models.dart';

class ProjectRepository {
  Future<void> _writeQueue = Future.value();

  Future<List<FlutterProject>> load() async {
    final file = _file;
    if (!await file.exists()) return const [];
    try {
      final data = jsonDecode(await file.readAsString()) as List<dynamic>;
      final projects =
          data
              .cast<Map<String, dynamic>>()
              .map(FlutterProject.fromMap)
              .map(
                (project) => project.copyWith(
                  pathExists: Directory(project.path).existsSync(),
                ),
              )
              .toList()
            ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
      return projects;
    } on Object {
      return const [];
    }
  }

  Future<List<FlutterProject>> upsert(
    List<FlutterProject> projects,
    FlutterProject project,
  ) async {
    final updated = [
      project,
      ...projects.where((item) => item.path != project.path),
    ];
    await save(updated);
    return updated;
  }

  Future<List<FlutterProject>> remove(
    List<FlutterProject> projects,
    String path,
  ) async {
    final updated = projects.where((item) => item.path != path).toList();
    await save(updated);
    return updated;
  }

  Future<List<FlutterProject>> relocate(
    List<FlutterProject> projects,
    String oldPath,
    FlutterProject project,
  ) async {
    final updated = [
      project,
      ...projects.where(
        (item) => item.path != oldPath && item.path != project.path,
      ),
    ];
    await save(updated);
    return updated;
  }

  Future<void> save(List<FlutterProject> projects) {
    _writeQueue = _writeQueue.then(
      (_) => _save(projects),
      onError: (_) => _save(projects),
    );
    return _writeQueue;
  }

  Future<void> _save(List<FlutterProject> projects) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(projects.map((project) => project.toMap()).toList()),
      flush: true,
    );
  }

  File get _file {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null) throw Exception('无法确定用户目录');
    return File(
      '$home${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}projects.json',
    );
  }
}
