import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_manager/src/data/project_dependency_service.dart';
import 'package:flutter_manager/src/domain/project_dependency.dart';

void main() {
  const service = ProjectDependencyService();
  late Directory root;
  late File pubspec;
  const source = '''
# keep project comment
name: example_app
environment:
  sdk: ^3.10.0
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  local_plugin:
    path: ../local_plugin
  git_plugin:
    git:
      url: https://example.test/plugin.git
      ref: stable
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.25.0
dependency_overrides:
  http: 1.2.1
flutter:
  uses-material-design: true
''';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('project_dependencies_');
    pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
    await pubspec.writeAsString(source);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'reads hosted, SDK, Git, Path and development dependencies without writing',
    () async {
      final snapshot = await service.load(root.path);
      expect(
        snapshot.dependencies.map((entry) => entry.name),
        containsAll([
          'flutter',
          'http',
          'local_plugin',
          'git_plugin',
          'flutter_test',
          'test',
        ]),
      );
      expect(
        snapshot.dependencies
            .singleWhere((entry) => entry.name == 'flutter')
            .removable,
        isFalse,
      );
      expect(
        snapshot.dependencies
            .singleWhere((entry) => entry.name == 'test')
            .development,
        isTrue,
      );
      expect(
        snapshot.dependencies
            .singleWhere((entry) => entry.name == 'git_plugin')
            .description,
        contains('Git'),
      );
      expect(await pubspec.readAsString(), source);
    },
  );

  test(
    'applies additions and removals while preserving unrelated YAML and comments',
    () async {
      final snapshot = await service.load(root.path);
      final saved = await service.save(
        snapshot,
        additions: const [
          ProjectDependency(name: 'dio', constraint: '^5.0.0'),
          ProjectDependency(
            name: 'mocktail',
            constraint: '^1.0.0',
            development: true,
          ),
        ],
        removals: {'dependencies:http', 'dev_dependencies:test'},
      );
      final yaml = loadYaml(saved.source) as YamlMap;
      expect(yaml['dependencies']['http'], isNull);
      expect(yaml['dev_dependencies']['test'], isNull);
      expect(yaml['dependencies']['dio'], '^5.0.0');
      expect(yaml['dev_dependencies']['mocktail'], '^1.0.0');
      expect(yaml['dependencies']['local_plugin']['path'], '../local_plugin');
      expect(yaml['dependencies']['git_plugin']['git']['ref'], 'stable');
      expect(yaml['dependencies']['flutter']['sdk'], 'flutter');
      expect(yaml['dependency_overrides']['http'], '1.2.1');
      expect(yaml['flutter']['uses-material-design'], isTrue);
      expect(saved.source, contains('# keep project comment'));
      expect(await pubspec.readAsString(), saved.source);
      expect(
        root.listSync().whereType<File>().map(
          (file) => file.uri.pathSegments.last,
        ),
        ['pubspec.yaml'],
      );
    },
  );

  test(
    'creates a missing development section and permits explicit section moves',
    () async {
      await pubspec.writeAsString(
        'name: demo\ndependencies:\n  http: ^1.0.0\n',
      );
      final snapshot = await service.load(root.path);
      final saved = await service.save(
        snapshot,
        additions: const [
          ProjectDependency(
            name: 'http',
            constraint: '^1.2.0',
            development: true,
          ),
        ],
        removals: {'dependencies:http'},
      );
      final yaml = loadYaml(saved.source) as YamlMap;
      expect(yaml['dependencies']['http'], isNull);
      expect(yaml['dev_dependencies']['http'], '^1.2.0');
    },
  );

  test(
    'rejects core SDK deletion, duplicate packages and invalid constraints without writing',
    () async {
      final snapshot = await service.load(root.path);
      await expectLater(
        service.save(
          snapshot,
          additions: [],
          removals: {'dependencies:flutter'},
        ),
        throwsStateError,
      );
      await expectLater(
        service.save(
          snapshot,
          additions: const [
            ProjectDependency(name: 'http', constraint: '^2.0.0'),
          ],
          removals: {},
        ),
        throwsStateError,
      );
      await expectLater(
        service.save(
          snapshot,
          additions: const [
            ProjectDependency(name: 'dio', constraint: 'not a constraint'),
          ],
          removals: {},
        ),
        throwsArgumentError,
      );
      expect(await pubspec.readAsString(), source);
    },
  );

  test('refuses to overwrite edits made after loading', () async {
    final snapshot = await service.load(root.path);
    final externalSource = '$source\n# external edit\n';
    await pubspec.writeAsString(externalSource);
    await expectLater(
      service.save(
        snapshot,
        additions: const [ProjectDependency(name: 'dio', constraint: '^5.0.0')],
        removals: {},
      ),
      throwsStateError,
    );
    expect(await pubspec.readAsString(), externalSource);
  });

  test('invalid dependency sections are not rewritten', () async {
    const invalid = 'name: demo\ndependencies: [bad]\n';
    await pubspec.writeAsString(invalid);
    await expectLater(service.load(root.path), throwsFormatException);
    expect(await pubspec.readAsString(), invalid);
  });
}
