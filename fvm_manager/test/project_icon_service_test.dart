import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/project_icon_service.dart';

void main() {
  late Directory project;
  final service = ProjectIconService();

  setUp(() async {
    project = await Directory.systemTemp.createTemp('project_icon_');
  });
  tearDown(() => project.delete(recursive: true));

  Future<File> file(String name, [String data = '']) async {
    final result = File(
      '${project.path}${Platform.pathSeparator}${name.replaceAll('/', Platform.pathSeparator)}',
    );
    await result.create(recursive: true);
    await result.writeAsString(data);
    return result;
  }

  test(
    'configured launcher image takes priority over generated icons',
    () async {
      await file(
        'pubspec.yaml',
        'flutter_launcher_icons:\n  image_path: branding/custom.png\n',
      );
      final expected = await file('branding/custom.png');
      await file('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');
      expect(await service.findIcon(project.path), expected.path);
    },
  );

  test(
    'reads Android application icon resource instead of activity icon',
    () async {
      await file(
        'android/app/src/main/AndroidManifest.xml',
        '<application android:icon="@mipmap/brand"><activity android:icon="@mipmap/other"/></application>',
      );
      final expected = await file(
        'android/app/src/main/res/mipmap-xxhdpi/brand.png',
      );
      await file('android/app/src/main/res/mipmap-mdpi/brand.png');
      expect(await service.findIcon(project.path), expected.path);
    },
  );

  test('reads custom Apple icon filenames from the asset catalog', () async {
    const path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
    await file(
      '$path/Contents.json',
      '{"images":[{"size":"16x16","scale":"1x","filename":"small.png"},{"size":"512x512","scale":"2x","filename":"custom.png"}]}',
    );
    await file('$path/small.png');
    final expected = await file('$path/custom.png');
    expect(await service.findIcon(project.path), expected.path);
  });

  test(
    'malformed config falls back to common assets and absent icons return null',
    () async {
      await file('pubspec.yaml', 'invalid: [');
      expect(await service.findIcon(project.path), isNull);
      final expected = await file('assets/images/app_logo.png');
      expect(await service.findIcon(project.path), expected.path);
      expect(await service.findIcon('${project.path}/missing'), isNull);
    },
  );
}
