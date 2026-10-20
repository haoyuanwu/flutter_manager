import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Only inspect known icon locations; never scan the project's build/cache tree.
class ProjectIconService {
  Future<String?> findIcon(String projectPath) async {
    String path(String relative) =>
        '$projectPath${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

    Future<String?> existing(String relative) async {
      final file = File(path(relative));
      return await file.exists() ? file.path : null;
    }

    for (final config in ['flutter_launcher_icons.yaml', 'pubspec.yaml']) {
      try {
        final file = File(path(config));
        if (!await file.exists()) continue;
        final yaml = loadYaml(await file.readAsString());
        if (yaml is! YamlMap) continue;
        final icons = yaml['flutter_launcher_icons'] ?? yaml['flutter_icons'];
        if (icons is! YamlMap) continue;
        for (final key in [
          'image_path',
          'image_path_android',
          'image_path_ios',
        ]) {
          final value = icons[key];
          if (value is! String || value.trim().isEmpty) continue;
          final icon = await existing(value);
          if (icon != null) return icon;
        }
      } on Object {
        // A missing/unreadable/malformed config must not break the project list.
      }
    }

    var resource = 'mipmap/ic_launcher';
    try {
      final manifest = File(path('android/app/src/main/AndroidManifest.xml'));
      if (await manifest.exists()) {
        final source = await manifest.readAsString();
        final application = RegExp(
          r'<application\b[^>]*>',
          dotAll: true,
        ).firstMatch(source)?.group(0);
        final icon = RegExp(
          r'''android:icon\s*=\s*["']@(mipmap|drawable)/([\w]+)["']''',
        ).firstMatch(application ?? '');
        if (icon != null) resource = '${icon[1]}/${icon[2]}';
      }
    } on Object {
      // Try conventional platform icon locations below.
    }
    final parts = resource.split('/');
    for (final density in ['xxxhdpi', 'xxhdpi', 'xhdpi', 'hdpi', 'mdpi', '']) {
      for (final extension in ['png', 'webp']) {
        final icon = await existing(
          'android/app/src/main/res/${parts[0]}${density.isEmpty ? '' : '-$density'}/${parts[1]}.$extension',
        );
        if (icon != null) return icon;
      }
    }

    for (final platform in ['macos', 'ios']) {
      final directory = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
      try {
        final contents = File(path('$directory/Contents.json'));
        if (!await contents.exists()) continue;
        final data = jsonDecode(await contents.readAsString());
        if (data is! Map || data['images'] is! List) continue;
        final images = (data['images'] as List).whereType<Map>().toList();
        double pixels(Map image) {
          final size =
              double.tryParse('${image['size']}'.split('x').first) ?? 0;
          final scale =
              double.tryParse('${image['scale']}'.replaceAll('x', '')) ?? 1;
          return size * scale;
        }

        images.sort((a, b) => pixels(b).compareTo(pixels(a)));
        for (final image in images) {
          final filename = image['filename'];
          if (filename is! String) continue;
          final icon = await existing('$directory/$filename');
          if (icon != null) return icon;
        }
      } on Object {
        // Continue with common asset names.
      }
    }

    for (final relative in [
      'assets/images/app_logo.png',
      'assets/images/logo.png',
      'assets/icon/icon.png',
      'assets/icons/app_icon.png',
      'assets/icon.png',
      'assets/logo.png',
      'web/icons/Icon-512.png',
    ]) {
      final icon = await existing(relative);
      if (icon != null) return icon;
    }
    return null;
  }
}
