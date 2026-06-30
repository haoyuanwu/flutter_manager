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
}
