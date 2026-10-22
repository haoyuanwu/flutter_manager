import 'dart:io';

import 'package:flutter_manager/src/data/distribution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scans distributable build files and ignores intermediate archives',
    () async {
      final project = await Directory.systemTemp.createTemp(
        'distribution_service_test_',
      );
      addTearDown(() => project.delete(recursive: true));

      final apk = File(
        '${project.path}${Platform.pathSeparator}build${Platform.pathSeparator}'
        'app${Platform.pathSeparator}outputs${Platform.pathSeparator}'
        'flutter-apk${Platform.pathSeparator}app-release.apk',
      );
      final dmg = File(
        '${project.path}${Platform.pathSeparator}build${Platform.pathSeparator}'
        'Desktop.dmg',
      );
      final intermediateZip = File(
        '${project.path}${Platform.pathSeparator}build${Platform.pathSeparator}'
        'cache${Platform.pathSeparator}assets.zip',
      );
      await apk.parent.create(recursive: true);
      await dmg.parent.create(recursive: true);
      await intermediateZip.parent.create(recursive: true);
      await apk.writeAsBytes([1, 2, 3]);
      await dmg.writeAsBytes([1]);
      await intermediateZip.writeAsBytes([1]);

      final artifacts = await DistributionService().scanArtifacts(project.path);

      expect(
        artifacts.map((item) => item.name),
        containsAll(['app-release.apk', 'Desktop.dmg']),
      );
      expect(artifacts.map((item) => item.name), isNot(contains('assets.zip')));
      expect(
        artifacts.firstWhere((item) => item.name.endsWith('.apk')).type,
        DistributionArtifactType.apk,
      );
    },
  );

  group('versioned distribution packages', () {
    late Directory project;
    late DistributionService service;
    setUp(() async {
      project = await Directory.systemTemp.createTemp('versioned_artifacts_');
      service = DistributionService();
      await File(
        '${project.path}/pubspec.yaml',
      ).writeAsString('name: demo_app\nversion: 1.2.6+12\n');
    });
    tearDown(() => project.delete(recursive: true));

    Future<File> file(String path, List<int> bytes) async {
      final file = File(
        '${project.path}${Platform.pathSeparator}build${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}',
      );
      await file.parent.create(recursive: true);
      return file.writeAsBytes(bytes);
    }

    test(
      'merges identical Gradle and Flutter APKs, prefers final Flutter output',
      () async {
        final flutter = await file('app/outputs/flutter-apk/app-release.apk', [
          1,
          2,
          3,
        ]);
        final gradle = await file('app/outputs/apk/release/app-release.apk', [
          1,
          2,
          3,
        ]);
        final artifacts = await service.scanArtifacts(project.path);
        expect(artifacts, hasLength(1));
        expect(artifacts.single.path, flutter.path);
        expect(await gradle.exists(), isTrue);
      },
    );

    test(
      'does not merge packages with equal names and sizes but different bytes',
      () async {
        await file('app/outputs/flutter-apk/app-release.apk', [1, 2]);
        await file('app/outputs/apk/release/app-release.apk', [3, 4]);
        expect(await service.scanArtifacts(project.path), hasLength(2));
      },
    );

    test(
      'publishes incremental APK with version/build and preserves originals',
      () async {
        final original = await file('app/outputs/flutter-apk/app-release.apk', [
          1,
          2,
          3,
        ]);
        await original.setLastModified(DateTime(2020));
        final naming = await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
          '--release',
        ]);
        final published = await service.publishBuildArtifacts(
          project.path,
          naming!,
          DateTime.now(),
        );
        expect(
          published.single.replaceAll('\\', '/'),
          endsWith('/build/outputs/release/apk/demo_app-v1.2.6+12-release.apk'),
        );
        expect(await File(published.single).readAsBytes(), [1, 2, 3]);
        expect(await original.exists(), isTrue);
        expect(
          (await service.scanArtifacts(
            project.path,
          )).single.path.replaceAll('\\', '/'),
          published.single.replaceAll('\\', '/'),
        );
      },
    );

    test(
      'keeps ABI and flavor and ignores stale universal and other channel',
      () async {
        await file('app/outputs/flutter-apk/app-arm64-v8a-prod-release.apk', [
          1,
        ]);
        await file('app/outputs/flutter-apk/app-prod-release.apk', [2]);
        await file('app/outputs/flutter-apk/app-arm64-v8a-test-release.apk', [
          3,
        ]);
        final naming = await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
          '--flavor',
          'prod',
          '--split-per-abi',
          '--target-platform=android-arm64',
        ]);
        final published = await service.publishBuildArtifacts(
          project.path,
          naming!,
          DateTime.now(),
        );
        expect(published, hasLength(1));
        expect(
          published.single,
          endsWith('demo_app-v1.2.6+12-arm64-v8a-prod-release.apk'),
        );
      },
    );

    test(
      'command version overrides and captured pubspec version are respected',
      () async {
        final naming = await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
          '--build-name=2.0.0',
          '--build-number',
          '42',
        ]);
        expect(
          naming!.fileName('app-release.apk'),
          'demo_app-v2.0.0+42-release.apk',
        );
        final captured = await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
        ]);
        await File(
          '${project.path}/pubspec.yaml',
        ).writeAsString('name: changed\nversion: 9.0.0+99\n');
        expect(
          captured!.fileName('app-release.apk'),
          'demo_app-v1.2.6+12-release.apk',
        );
        expect(
          await service.buildArtifactNaming(project.path, ['clean']),
          isNull,
        );
      },
    );

    test(
      'same version with changed contents never overwrites a shared package',
      () async {
        final original = await file('app/outputs/flutter-apk/app-release.apk', [
          1,
          2,
        ]);
        final naming = (await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
        ]))!;
        final first = (await service.publishBuildArtifacts(
          project.path,
          naming,
          DateTime.now(),
        )).single;
        await original.writeAsBytes([3, 4, 5]);
        final second = (await service.publishBuildArtifacts(
          project.path,
          naming,
          DateTime.now(),
        )).single;
        expect(second, isNot(first));
        expect(await File(first).readAsBytes(), [1, 2]);
        expect(await File(second).readAsBytes(), [3, 4, 5]);
        expect(await service.scanArtifacts(project.path), hasLength(2));
      },
    );

    test(
      'identical rerun reuses its versioned copy rather than making duplicates',
      () async {
        await file('app/outputs/flutter-apk/app-debug.apk', [1, 2]);
        final naming = (await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
          '--debug',
        ]))!;
        final first = await service.publishBuildArtifacts(
          project.path,
          naming,
          DateTime.now(),
        );
        final second = await service.publishBuildArtifacts(
          project.path,
          naming,
          DateTime.now(),
        );
        expect(second, first);
        expect(
          (await Directory(
            '${project.path}/build/outputs/release/apk',
          ).list().toList()),
          hasLength(1),
        );
      },
    );

    test(
      'AAB from Gradle bundle directory also gets a versioned distribution copy',
      () async {
        await file('app/outputs/bundle/release/app-release.aab', [1, 2]);
        final naming = (await service.buildArtifactNaming(project.path, [
          'build',
          'appbundle',
        ]))!;
        final published = await service.publishBuildArtifacts(
          project.path,
          naming,
          DateTime.now(),
        );
        expect(
          published.single,
          endsWith('/aab/demo_app-v1.2.6+12-release.aab'),
        );
      },
    );

    test(
      'does not publish APKs from another variant or rename existing archives',
      () async {
        await file('app/outputs/flutter-apk/app-demo-release.apk', [1, 2]);
        await file('outputs/release/apk/demo_app-v1.0.0+1-release.apk', [3, 4]);
        final naming = (await service.buildArtifactNaming(project.path, [
          'build',
          'apk',
          '--debug',
        ]))!;
        expect(
          await service.publishBuildArtifacts(
            project.path,
            naming,
            DateTime.now(),
          ),
          isEmpty,
        );
      },
    );
  });
}
