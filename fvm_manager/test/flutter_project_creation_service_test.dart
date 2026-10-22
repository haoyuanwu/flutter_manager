import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/flutter_project_creation_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/local_project_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/project_creation_options.dart';
import 'package:flutter_manager/src/domain/project_dependency.dart';
import 'package:yaml/yaml.dart';

class _Process implements Process {
  final done = Completer<int>();
  @override
  Future<int> get exitCode => done.future;
  @override
  Stream<List<int>> get stdout =>
      Stream.value(utf8.encode('Created project files.\n'));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!done.isCompleted) done.complete(-1);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runner extends ProcessRunner {
  _Runner(this.process);
  final _Process process;
  @override
  Future<void> stop(
    String taskId, {
    Future<bool> Function(Process)? gracefulStop,
  }) async {
    process.kill();
  }
}

class _Fvm extends FvmService {
  _Fvm(this.process) : super(PubEnvironmentService());
  final _Process process;
  final started = Completer<void>();
  List<String>? arguments;
  final commands = <List<String>>[];
  String? sdkDirectory;
  bool waitForStop = false;
  int code = 0;

  @override
  Future<Process> startProjectCreationCommand({
    required String parentDirectory,
    required List<String> arguments,
    String? sdkDirectory,
  }) async {
    this.arguments = arguments;
    commands.add(arguments);
    this.sdkDirectory = sdkDirectory;
    if (arguments.first == 'create') {
      final directory = Directory(arguments.last);
      await directory.create();
      await File('${directory.path}/pubspec.yaml').writeAsString(
        '# Template comment\nname: new_app\nversion: 0.0.1\ndependencies:\n  flutter:\n    sdk: flutter\ndev_dependencies:\n  flutter_lints: ^6.0.0\n',
      );
    }
    if (!started.isCompleted) started.complete();
    if (!waitForStop && !process.done.isCompleted) process.done.complete(code);
    return process;
  }
}

void main() {
  late Directory root;
  late _Process process;
  late _Fvm fvm;
  late FlutterProjectCreationService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('create_flutter_');
    process = _Process();
    fvm = _Fvm(process);
    service = FlutterProjectCreationService(
      fvm,
      _Runner(process),
      LocalProjectService(),
    );
  });
  tearDown(() => root.delete(recursive: true));

  ProjectCreationOptions options({
    FlutterProjectTemplate template = FlutterProjectTemplate.app,
    List<String> platforms = const ['android', 'windows'],
    FlutterAppStarter starter = FlutterAppStarter.standard,
    bool pubGet = false,
    bool offline = false,
    List<ProjectDependency> dependencies = const [],
  }) => ProjectCreationOptions(
    name: 'new_app',
    directoryName: 'folder with spaces',
    parentDirectory: root.path,
    template: template,
    platforms: platforms,
    starter: starter,
    sampleId: 'widgets.SingleChildScrollView.1',
    pubGet: pubGet,
    offline: offline,
    sdkDirectory: '/chosen/sdk',
    sdkVersion: '3.47.7',
    version: '2.1.0',
    buildNumber: '9',
    alias: 'New App',
    dependencies: dependencies,
  );

  test(
    'creates using selected SDK, streams output and persists version and FVM config',
    () async {
      final output = <String>[];
      final configuration = options();
      final project = await service.create(configuration, onOutput: output.add);
      expect(project.path, configuration.projectPath);
      expect(project.alias, 'New App');
      expect(project.fvmVersion, '3.47.7');
      expect(project.bugly.version, '2.1.0');
      expect(project.bugly.buildNo, '9');
      expect(fvm.sdkDirectory, '/chosen/sdk');
      expect(fvm.arguments, contains('--no-overwrite'));
      expect(fvm.arguments!.last, configuration.projectPath);
      expect(output.join(), contains('Created project files.'));
      expect(jsonDecode(await File('${project.path}/.fvmrc').readAsString()), {
        'flutter': '3.47.7',
      });
    },
  );

  test(
    'never runs the command for an existing file, directory or invalid project name',
    () async {
      await Directory(options().projectPath).create();
      final keep = File('${options().projectPath}/keep.txt');
      await keep.writeAsString('user content');
      await expectLater(
        service.create(options(), onOutput: (_) {}),
        throwsException,
      );
      expect(await keep.readAsString(), 'user content');
      expect(fvm.arguments, isNull);
      expect(ProjectCreationOptions.validateName('class'), isNotNull);
      expect(ProjectCreationOptions.validateName('New App'), isNotNull);
      expect(
        ProjectCreationOptions.validateDirectoryName('../other'),
        isNotNull,
      );
      expect(ProjectCreationOptions.validateDirectoryName('CON'), isNotNull);
    },
  );

  test(
    'template arguments omit unsupported flags and empty/sample stay exclusive',
    () {
      final ffi = options(
        template: FlutterProjectTemplate.packageFfi,
      ).arguments;
      expect(ffi.any((value) => value.startsWith('--platforms')), isFalse);
      expect(
        ffi.any((value) => value.startsWith('--android-language')),
        isFalse,
      );
      final module = options(template: FlutterProjectTemplate.module).arguments;
      expect(module, contains('--android-language=kotlin'));
      expect(module.any((value) => value.startsWith('--platforms')), isFalse);
      final sample = options(
        starter: FlutterAppStarter.sample,
        pubGet: true,
        offline: true,
      ).arguments;
      expect(sample, contains('--sample=widgets.SingleChildScrollView.1'));
      expect(sample, isNot(contains('--empty')));
      expect(sample, contains('--no-pub'));
      expect(
        options(starter: FlutterAppStarter.empty).arguments,
        contains('--empty'),
      );
      expect(
        () => options(
          template: FlutterProjectTemplate.pluginFfi,
          platforms: ['web'],
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => options(
          template: FlutterProjectTemplate.plugin,
          platforms: ['darwin', 'ios'],
        ).validate(),
        throwsArgumentError,
      );
    },
  );

  test(
    'failed command keeps generated files and does not return a project',
    () async {
      fvm.code = 1;
      await expectLater(
        service.create(options(), onOutput: (_) {}),
        throwsException,
      );
      expect(
        await File('${options().projectPath}/pubspec.yaml').exists(),
        isTrue,
      );
      expect(await File('${options().projectPath}/.fvmrc').exists(), isFalse);
    },
  );

  test(
    'writes dependency sections without losing SDK entries or comments, and fetches once',
    () async {
      final project = await service.create(
        options(
          pubGet: true,
          offline: true,
          dependencies: [
            const ProjectDependency(
              name: 'flutter_lints',
              constraint: '^6.0.0',
            ),
            const ProjectDependency(
              name: 'dio',
              constraint: '^5.0.0',
              development: true,
            ),
          ],
        ),
        onOutput: (_) {},
      );
      final source = await File('${project.path}/pubspec.yaml').readAsString();
      final pubspec = loadYaml(source) as YamlMap;
      expect(source, contains('# Template comment'));
      expect(pubspec['dependencies']['flutter']['sdk'], 'flutter');
      expect(pubspec['dependencies']['flutter_lints'], '^6.0.0');
      expect(pubspec['dev_dependencies']['dio'], '^5.0.0');
      expect(
        (pubspec['dev_dependencies'] as YamlMap).containsKey('flutter_lints'),
        isFalse,
      );
      expect(fvm.commands, hasLength(2));
      expect(fvm.commands.first, contains('--no-pub'));
      expect(fvm.commands.last, ['pub', 'get', '--offline']);
    },
  );

  test(
    'dependency validation rejects SDK replacement, duplicates and invalid constraints',
    () {
      expect(
        () => options(
          dependencies: [
            const ProjectDependency(name: 'flutter', constraint: 'any'),
          ],
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => options(
          dependencies: [
            const ProjectDependency(
              name: 'dio',
              constraint: 'not a constraint',
            ),
          ],
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => options(
          dependencies: [
            const ProjectDependency(name: 'dio', constraint: '^5.0.0'),
            const ProjectDependency(name: 'dio', constraint: '^4.0.0'),
          ],
        ).validate(),
        throwsArgumentError,
      );
    },
  );

  test(
    'recognizes Flutter-generated native asset packages without accepting arbitrary Dart projects',
    () async {
      final directory = Directory('${root.path}/native_package');
      await Directory('${directory.path}/hook').create(recursive: true);
      await File('${directory.path}/pubspec.yaml').writeAsString(
        'name: native_package\nversion: 1.0.0+1\ndependencies:\n  code_assets: ^1.0.0\n  hooks: ^2.0.0\n',
      );
      await File(
        '${directory.path}/hook/build.dart',
      ).writeAsString('void main() {}');
      final metadata = File('${directory.path}/.metadata');
      await metadata.writeAsString('project_type: package_ffi\n');
      expect(
        (await LocalProjectService().inspectProject(directory.path)).name,
        'native_package',
      );
      await metadata.delete();
      await expectLater(
        LocalProjectService().inspectProject(directory.path),
        throwsException,
      );
    },
  );

  test('cancel stops the managed process and keeps generated files', () async {
    fvm.waitForStop = true;
    final creation = service.create(options(), onOutput: (_) {});
    final expectation = expectLater(creation, throwsException);
    await fvm.started.future;
    await service.cancel();
    await expectation;
    expect(
      await File('${options().projectPath}/pubspec.yaml').exists(),
      isTrue,
    );
  });
}
