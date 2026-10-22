import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../domain/project_dependency.dart';

class InstalledProjectDependency {
  const InstalledProjectDependency({
    required this.name,
    required this.development,
    required this.description,
  });
  final String name;
  final bool development;
  final String description;
  String get section => development ? 'dev_dependencies' : 'dependencies';
  String get key => '$section:$name';
  bool get removable => name != 'flutter';
}

class ProjectDependencySnapshot {
  const ProjectDependencySnapshot({
    required this.projectPath,
    required this.source,
    required this.dependencies,
  });
  final String projectPath;
  final String source;
  final List<InstalledProjectDependency> dependencies;
}

class DependencySyncException implements Exception {
  const DependencySyncException(this.snapshot, this.message);
  final ProjectDependencySnapshot snapshot;
  final String message;
  @override
  String toString() => '依赖已保存，但 Pub Get 未完成：$message';
}

class ProjectDependencyService {
  const ProjectDependencyService();

  Future<File> _pubspec(String projectPath) async {
    final file = File('$projectPath${Platform.pathSeparator}pubspec.yaml');
    if (await FileSystemEntity.isLink(file.path)) {
      return File(await file.resolveSymbolicLinks());
    }
    return file;
  }

  Future<ProjectDependencySnapshot> load(String projectPath) async {
    final file = await _pubspec(projectPath);
    return _snapshot(projectPath, await file.readAsString());
  }

  YamlMap _parse(String source) {
    final parsed = loadYaml(source);
    if (parsed is! YamlMap) {
      throw const FormatException('pubspec.yaml 必须是 YAML 映射');
    }
    for (final section in ['dependencies', 'dev_dependencies']) {
      if (parsed[section] != null && parsed[section] is! YamlMap) {
        throw FormatException('$section 配置格式不正确');
      }
    }
    return parsed;
  }

  ProjectDependencySnapshot _snapshot(String path, String source) {
    final parsed = _parse(source);
    final dependencies = <InstalledProjectDependency>[];
    for (final section in ['dependencies', 'dev_dependencies']) {
      final entries = parsed[section];
      if (entries is! YamlMap) continue;
      for (final entry in entries.entries) {
        if (entry.key is! String) throw const FormatException('依赖名称必须是字符串');
        final value = entry.value;
        final description = switch (value) {
          YamlMap map when map.containsKey('sdk') => 'SDK · ${map['sdk']}',
          YamlMap map when map.containsKey('path') => 'Path · ${map['path']}',
          YamlMap map when map.containsKey('git') =>
            'Git · ${map['git'] is YamlMap ? map['git']['url'] : map['git']}',
          YamlMap map => 'Hosted · ${map['version'] ?? 'any'}',
          null => 'any',
          _ => '$value',
        };
        dependencies.add(
          InstalledProjectDependency(
            name: entry.key as String,
            development: section == 'dev_dependencies',
            description: description,
          ),
        );
      }
    }
    dependencies.sort((a, b) {
      final section = (a.development ? 1 : 0).compareTo(b.development ? 1 : 0);
      return section == 0 ? a.name.compareTo(b.name) : section;
    });
    return ProjectDependencySnapshot(
      projectPath: path,
      source: source,
      dependencies: List.unmodifiable(dependencies),
    );
  }

  Future<ProjectDependencySnapshot> save(
    ProjectDependencySnapshot snapshot, {
    required List<ProjectDependency> additions,
    required Set<String> removals,
  }) async {
    final parsed = _parse(snapshot.source);
    final editor = YamlEditor(snapshot.source);
    final known = {
      for (final dependency in snapshot.dependencies)
        dependency.key: dependency,
    };
    for (final key in removals) {
      final dependency = known[key];
      if (dependency == null || !dependency.removable) {
        throw StateError('不能删除该依赖：${dependency?.name ?? key}');
      }
      editor.remove([dependency.section, dependency.name]);
    }
    final names = snapshot.dependencies
        .where((dependency) => !removals.contains(dependency.key))
        .map((dependency) => dependency.name)
        .toSet();
    final sections = <String>{
      for (final section in ['dependencies', 'dev_dependencies'])
        if (parsed[section] is YamlMap) section,
    };
    for (final dependency in additions) {
      dependency.validate();
      if (!names.add(dependency.name)) {
        throw StateError('项目中已存在依赖 ${dependency.name}，请先删除旧配置');
      }
      final section = dependency.development
          ? 'dev_dependencies'
          : 'dependencies';
      if (sections.add(section)) editor.update([section], <String, dynamic>{});
      editor.update([section, dependency.name], dependency.constraint.trim());
    }
    final source = editor.toString();
    final result = _snapshot(snapshot.projectPath, source);
    final file = await _pubspec(snapshot.projectPath);
    if (await file.readAsString() != snapshot.source) {
      throw StateError('pubspec.yaml 已被其他操作修改，请重新读取后再保存');
    }
    if (source == snapshot.source) return result;
    final temporary = File(
      '${file.path}.fvm-manager-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(source, flush: true);
      if (await file.readAsString() != snapshot.source) {
        throw StateError('pubspec.yaml 已被其他操作修改，请重新读取后再保存');
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return result;
  }
}
