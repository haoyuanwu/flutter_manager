import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../domain/project_creation_options.dart';
import '../domain/project_models.dart';
import 'fvm_service.dart';
import 'local_project_service.dart';
import 'process_runner.dart';

class FlutterProjectCreationService {
  FlutterProjectCreationService(this._fvm, this._runner, this._projects);

  final FvmService _fvm;
  final ProcessRunner _runner;
  final LocalProjectService _projects;
  static const taskId = 'create-flutter-project';
  bool _creating = false;
  bool _cancelled = false;

  Future<void> cancel() async {
    _cancelled = true;
    await _runner.stop(taskId);
  }

  Future<FlutterProject> create(
    ProjectCreationOptions options, {
    required void Function(String) onOutput,
  }) async {
    if (_creating) throw StateError('已有项目正在创建');
    _creating = true;
    _cancelled = false;
    try {
      options.validate();
      if (!await Directory(options.parentDirectory.trim()).exists()) {
        throw Exception('保存位置不存在，请选择已有文件夹');
      }
      if (await FileSystemEntity.type(
            options.projectPath,
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        throw Exception('目标目录已存在，请更换文件夹名称：${options.projectPath}');
      }
      if (_cancelled) throw Exception('创建已取消');
      await _run(
        options,
        options.arguments,
        Directory(options.parentDirectory.trim()).absolute.path,
        onOutput,
      );
      await _projects.updateProjectVersion(
        options.projectPath,
        version: options.version,
        buildNo: options.buildNumber,
      );
      if (options.dependencies.isNotEmpty) {
        final pubspecFile = File(
          '${options.projectPath}${Platform.pathSeparator}pubspec.yaml',
        );
        final source = await pubspecFile.readAsString();
        final editor = YamlEditor(source);
        final sections = <String, Set<String>>{};
        final parsed = loadYaml(source) as YamlMap;
        for (final section in ['dependencies', 'dev_dependencies']) {
          final existing = parsed[section];
          sections[section] = existing is YamlMap
              ? existing.keys.cast<String>().toSet()
              : <String>{};
        }
        for (final dependency in options.dependencies) {
          final section = dependency.development
              ? 'dev_dependencies'
              : 'dependencies';
          final other = dependency.development
              ? 'dependencies'
              : 'dev_dependencies';
          if (sections[other]!.remove(dependency.name)) {
            editor.remove([other, dependency.name]);
          }
          if (parsed[section] is! YamlMap && sections[section]!.isEmpty) {
            editor.update([section], <String, dynamic>{});
          }
          editor.update([
            section,
            dependency.name,
          ], dependency.constraint.trim());
          sections[section]!.add(dependency.name);
        }
        await pubspecFile.writeAsString(editor.toString(), flush: true);
        onOutput(
          '\n已写入依赖：${options.dependencies.map((dependency) => dependency.name).join(', ')}\n',
        );
      }
      if (options.pinSdk && options.sdkVersion != null) {
        await File(
          '${options.projectPath}${Platform.pathSeparator}.fvmrc',
        ).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert({'flutter': options.sdkVersion})}\n',
          flush: true,
        );
      }
      if (options.pubGet) {
        await _run(
          options,
          ['pub', 'get', if (options.offline) '--offline'],
          options.projectPath,
          onOutput,
        );
      }
      final project = await _projects.inspectProject(options.projectPath);
      if (_cancelled) {
        throw Exception('已取消自动导入，已生成的项目保留在 ${options.projectPath}');
      }
      return project.copyWith(alias: options.alias.trim());
    } finally {
      _creating = false;
    }
  }

  Future<void> _run(
    ProjectCreationOptions options,
    List<String> arguments,
    String workingDirectory,
    void Function(String) onOutput,
  ) async {
    if (_cancelled) throw Exception('创建已取消，已生成的文件保留在 ${options.projectPath}');
    onOutput('flutter ${arguments.map(jsonEncode).join(' ')}\n\n');
    final process = await _runner.startManaged(
      taskId: taskId,
      starter: () => _fvm.startProjectCreationCommand(
        parentDirectory: workingDirectory,
        arguments: arguments,
        sdkDirectory: options.sdkDirectory,
      ),
    );
    final output = Future.wait([
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(onOutput),
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(onOutput),
    ]);
    final code = await process.exitCode.timeout(
      const Duration(minutes: 15),
      onTimeout: () async {
        await _runner.stop(taskId);
        throw TimeoutException('创建超时，已停止命令。已生成的文件保留在 ${options.projectPath}');
      },
    );
    await output;
    if (_cancelled) throw Exception('创建已取消，已生成的文件保留在 ${options.projectPath}');
    if (code != 0) {
      throw Exception(
        'Flutter 命令失败（退出码 $code）。请查看日志；已生成的文件保留在 ${options.projectPath}',
      );
    }
  }
}
