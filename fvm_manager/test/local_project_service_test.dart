import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/local_project_service.dart';

void main() {
  test('reads Flutter platforms, FVM version, and Android flavors', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_project_',
    );
    addTearDown(() => root.delete(recursive: true));

    await File('${root.path}/pubspec.yaml').writeAsString('''
name: demo_app
description: Demo project
version: 1.0.0+7
dependencies:
  flutter:
    sdk: flutter
''');
    await File('${root.path}/.fvmrc').writeAsString('{"flutter":"3.44.2"}');
    await Directory('${root.path}/android/app').create(recursive: true);
    await Directory('${root.path}/ios').create();
    await File('${root.path}/android/app/build.gradle.kts').writeAsString('''
android {
  defaultConfig {
    applicationId = "com.example.demo"
    versionCode = 8
    versionName = "1.2.0"
  }
  productFlavors {
    create("dev") { dimension = "env" }
    create("prod") { dimension = "env" }
  }
  buildTypes {
    getByName("debug") { }
    getByName("release") { }
  }
}
''');

    final project = await LocalProjectService().inspectProject(root.path);

    expect(project.name, 'demo_app');
    expect(project.fvmVersion, '3.44.2');
    expect(project.hasAndroid, isTrue);
    expect(project.hasIos, isTrue);
    expect(project.androidFlavors, ['dev', 'prod']);
    expect(project.androidBuildTypes, ['debug', 'release']);
    expect(project.bugly.bundleId, 'com.example.demo');
    expect(project.bugly.version, '1.2.0');
    expect(project.bugly.buildNo, '8');
  });

  test(
    'finds macOS Release app when product name differs from pubspec name',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'flutter_manager_macos_product_',
      );
      addTearDown(() => root.delete(recursive: true));

      final app = Directory(
        '${root.path}/build/macos/Build/Products/Release/Demo App.app',
      );
      await app.create(recursive: true);

      final result = await LocalProjectService().findMacosReleaseApp(
        root.path,
        'demo_app',
      );

      expect(result.path, app.path);
    },
  );

  test('uses Flutter generated macOS app filename when available', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_macos_filename_',
    );
    addTearDown(() => root.delete(recursive: true));

    final release = Directory(
      '${root.path}/build/macos/Build/Products/Release',
    );
    final expected = Directory('${release.path}/Chosen App.app');
    await expected.create(recursive: true);
    await Directory('${release.path}/Other App.app').create();
    final filename = File('${root.path}/macos/Flutter/ephemeral/.app_filename');
    await filename.create(recursive: true);
    await filename.writeAsString('Chosen App.app\n');

    final result = await LocalProjectService().findMacosReleaseApp(
      root.path,
      'unrelated_package_name',
    );

    expect(result.path, expected.path);
  });

  test('updates pubspec version and hardcoded Android version', () async {
    final root = await Directory.systemTemp.createTemp(
      'flutter_manager_project_version_',
    );
    addTearDown(() => root.delete(recursive: true));
    final pubspec = File('${root.path}/pubspec.yaml');
    await pubspec.writeAsString('''
name: demo
version: 1.0.0+1 # old version
''');
    final android = File('${root.path}/android/app/build.gradle.kts');
    await android.create(recursive: true);
    await android.writeAsString('''
android {
  defaultConfig {
    versionName = "1.0.0"
    versionCode = 1
  }
}
''');

    final synchronized = await LocalProjectService().updateProjectVersion(
      root.path,
      version: '2.3.0-beta.1',
      buildNo: '42',
    );

    expect(synchronized, isTrue);
    expect(await pubspec.readAsString(), contains('version: 2.3.0-beta.1+42'));
    final gradle = await android.readAsString();
    expect(gradle, contains('versionName = "2.3.0-beta.1"'));
    expect(gradle, contains('versionCode = 42'));
  });

  test(
    'keeps Android version expressions that already read Flutter config',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'flutter_manager_project_version_expression_',
      );
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}/pubspec.yaml').writeAsString('''
name: demo
version: 1.0.0+1
''');
      final android = File('${root.path}/android/app/build.gradle.kts');
      await android.create(recursive: true);
      const original = '''
versionName = flutter.versionName
versionCode = flutter.versionCode
''';
      await android.writeAsString(original);

      final synchronized = await LocalProjectService().updateProjectVersion(
        root.path,
        version: '2.0.0',
        buildNo: '9',
      );

      expect(synchronized, isFalse);
      expect(await android.readAsString(), original);
    },
  );
}
