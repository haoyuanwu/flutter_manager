import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:yaml/yaml.dart';

enum DistributionArtifactType { apk, aab, ipa, hap, dmg, pkg, msix, exe, zip }

class DistributionArtifact {
  const DistributionArtifact({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modified,
  });

  final String path;
  final String name;
  final DistributionArtifactType type;
  final int size;
  final DateTime modified;

  String get typeLabel => type.name.toUpperCase();

  String get platformLabel => switch (type) {
    DistributionArtifactType.apk || DistributionArtifactType.aab => 'Android',
    DistributionArtifactType.ipa => 'iOS',
    DistributionArtifactType.hap => 'HarmonyOS',
    DistributionArtifactType.dmg || DistributionArtifactType.pkg => 'macOS',
    DistributionArtifactType.msix || DistributionArtifactType.exe => 'Windows',
    DistributionArtifactType.zip => '压缩包',
  };
}

class DistributionService {
  final _digestCache = <String, String>{};
  static const _extensions = <String, DistributionArtifactType>{
    'apk': DistributionArtifactType.apk,
    'aab': DistributionArtifactType.aab,
    'ipa': DistributionArtifactType.ipa,
    'hap': DistributionArtifactType.hap,
    'dmg': DistributionArtifactType.dmg,
    'pkg': DistributionArtifactType.pkg,
    'msix': DistributionArtifactType.msix,
    'exe': DistributionArtifactType.exe,
    'zip': DistributionArtifactType.zip,
  };

  Future<List<DistributionArtifact>> scanArtifacts(
    String projectPath, {
    bool deduplicate = true,
  }) async {
    final buildDirectory = Directory(
      '$projectPath${Platform.pathSeparator}build',
    );
    if (!await buildDirectory.exists()) return const [];

    final artifacts = <DistributionArtifact>[];
    await for (final entity in buildDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final name = _fileName(entity.path);
      final dot = name.lastIndexOf('.');
      if (dot < 0) continue;
      final type = _extensions[name.substring(dot + 1).toLowerCase()];
      if (type == null) continue;
      if (!_isDistributionCandidate(entity.path, type, buildDirectory.path)) {
        continue;
      }
      final stat = await entity.stat();
      artifacts.add(
        DistributionArtifact(
          path: entity.path,
          name: name,
          type: type,
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
    artifacts.sort((a, b) => b.modified.compareTo(a.modified));
    return deduplicate ? _deduplicate(artifacts) : artifacts;
  }

  // Prefer our versioned distribution copies, then Flutter's final APKs,
  // then Gradle originals. Only byte-identical packages are merged.
  int _priority(DistributionArtifact artifact) {
    final path = artifact.path.replaceAll('\\', '/');
    if (path.contains('/build/outputs/release/')) return 0;
    if (path.contains('/outputs/flutter-apk/')) return 1;
    return 2;
  }

  Future<String> _digest(DistributionArtifact artifact) async {
    final stat = await File(artifact.path).stat();
    final key =
        '${artifact.path}|${stat.size}|${stat.modified.microsecondsSinceEpoch}|${stat.changed.microsecondsSinceEpoch}';
    final cached = _digestCache[key];
    if (cached != null) return cached;
    final digest = (await sha256.bind(File(artifact.path).openRead()).first)
        .toString();
    if (_digestCache.length >= 512) _digestCache.clear();
    _digestCache[key] = digest;
    return digest;
  }

  Future<List<DistributionArtifact>> _deduplicate(
    List<DistributionArtifact> artifacts,
  ) async {
    final groups = <String, List<DistributionArtifact>>{};
    for (final artifact in artifacts) {
      groups
          .putIfAbsent('${artifact.type.name}|${artifact.size}', () => [])
          .add(artifact);
    }
    final result = <DistributionArtifact>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        result.add(group.single);
        continue;
      }
      group.sort((a, b) {
        final priority = _priority(a).compareTo(_priority(b));
        return priority != 0 ? priority : b.modified.compareTo(a.modified);
      });
      final seen = <String>{};
      for (final artifact in group) {
        if (seen.add(await _digest(artifact))) result.add(artifact);
      }
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  /// Capture before the build: editing pubspec during a long build must not
  /// relabel its outputs with the next version. Explicit Flutter flags win.
  Future<BuildArtifactNaming?> buildArtifactNaming(
    String projectPath,
    List<String> arguments,
  ) async {
    if (arguments.length < 2 ||
        arguments.first != 'build' ||
        !const ['apk', 'appbundle', 'ipa'].contains(arguments[1])) {
      return null;
    }
    final pubspec =
        loadYaml(await File('$projectPath/pubspec.yaml').readAsString())
            as YamlMap;
    final version = (pubspec['version']?.toString() ?? '1.0.0+1').split('+');
    String? option(String flag) {
      for (var i = 0; i < arguments.length; i++) {
        if (arguments[i].startsWith('$flag=')) {
          return arguments[i].substring(flag.length + 1);
        }
        if (arguments[i] == flag && i + 1 < arguments.length) {
          return arguments[i + 1];
        }
      }
      return null;
    }

    return BuildArtifactNaming(
      name: pubspec['name']?.toString() ?? _fileName(projectPath),
      version: option('--build-name') ?? version.first,
      buildNumber:
          option('--build-number') ?? (version.length > 1 ? version[1] : '1'),
      target: arguments[1],
      mode: arguments.contains('--debug')
          ? 'debug'
          : arguments.contains('--profile')
          ? 'profile'
          : 'release',
      flavor: option('--flavor'),
      splitPerAbi: arguments.contains('--split-per-abi'),
      targetPlatforms:
          (option('--target-platform') ??
                  'android-arm,android-arm64,android-x64')
              .split(','),
    );
  }

  Future<List<String>> publishBuildArtifacts(
    String projectPath,
    BuildArtifactNaming naming,
    DateTime startedAt,
  ) async {
    final type = switch (naming.target) {
      'apk' => DistributionArtifactType.apk,
      'appbundle' => DistributionArtifactType.aab,
      _ => DistributionArtifactType.ipa,
    };
    final earliest = startedAt.subtract(const Duration(seconds: 2));
    final artifacts = (await scanArtifacts(projectPath, deduplicate: false)).where((
      artifact,
    ) {
      final path = artifact.path.replaceAll('\\', '/');
      if (artifact.type != type || path.contains('/build/outputs/release/')) {
        return false;
      }
      if (type == DistributionArtifactType.ipa) {
        return !artifact.modified.isBefore(earliest);
      }
      // Exact variants allow successful incremental builds whose timestamps
      // did not change, without publishing old flavors or a stale universal APK.
      return naming.expectedAndroidNames.contains(artifact.name.toLowerCase());
    }).toList();
    final flutterApks = artifacts
        .where(
          (artifact) => artifact.path
              .replaceAll('\\', '/')
              .contains('/outputs/flutter-apk/'),
        )
        .toList();
    // Flutter's final copies are authoritative for this successful command;
    // a stale Gradle output with different bytes must not get today's version.
    final unique = await _deduplicate(
      type == DistributionArtifactType.apk && flutterApks.isNotEmpty
          ? flutterApks
          : artifacts,
    );
    final published = <String>[];
    for (final artifact in unique) {
      final outputDirectory = Directory(
        '$projectPath/build/outputs/release/${type.name}',
      );
      await outputDirectory.create(recursive: true);
      final baseName = naming.fileName(artifact.name);
      var destination = File('${outputDirectory.path}/$baseName');
      if (await destination.exists()) {
        final existing = DistributionArtifact(
          path: destination.path,
          name: baseName,
          type: type,
          size: await destination.length(),
          modified: await destination.lastModified(),
        );
        if (await _digest(existing) == await _digest(artifact)) {
          await destination.setLastModified(DateTime.now());
          published.add(destination.path);
          continue;
        }
        // Rebuilding an unchanged version must not silently overwrite an older
        // package that may already have been shared with testers.
        final dot = baseName.lastIndexOf('.');
        destination = File(
          '${outputDirectory.path}/${baseName.substring(0, dot)}-${DateTime.now().microsecondsSinceEpoch}${baseName.substring(dot)}',
        );
      }
      final staging = await outputDirectory.createTemp('.publishing_');
      try {
        final copy = await File(
          artifact.path,
        ).copy('${staging.path}/package.part');
        await copy.rename(destination.path);
      } finally {
        await staging.delete(recursive: true);
      }
      published.add(destination.path);
    }
    return published;
  }

  Future<DistributionArtifact?> chooseArtifact() async {
    final selected = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: '可分发安装包',
          extensions: _extensions.keys.toList(growable: false),
        ),
      ],
      confirmButtonText: '选择安装包',
    );
    if (selected == null) return null;
    final file = File(selected.path);
    final name = _fileName(file.path);
    final dot = name.lastIndexOf('.');
    final type = dot < 0
        ? null
        : _extensions[name.substring(dot + 1).toLowerCase()];
    if (type == null) throw Exception('不支持该文件类型：$name');
    final stat = await file.stat();
    return DistributionArtifact(
      path: file.path,
      name: name,
      type: type,
      size: stat.size,
      modified: stat.modified,
    );
  }

  bool _isDistributionCandidate(
    String path,
    DistributionArtifactType type,
    String buildPath,
  ) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    if (normalized.startsWith(
      '${buildPath.replaceAll('\\', '/').toLowerCase()}/outputs/release/',
    )) {
      return true;
    }
    return switch (type) {
      DistributionArtifactType.apk =>
        normalized.contains('/app/outputs/flutter-apk/') ||
            normalized.contains('/app/outputs/apk/'),
      DistributionArtifactType.aab =>
        normalized.contains('/app/outputs/flutter-aab/') ||
            normalized.contains('/app/outputs/bundle/'),
      DistributionArtifactType.ipa => normalized.contains('/ios/ipa/'),
      DistributionArtifactType.exe =>
        normalized.contains('/runner/release/') ||
            normalized.contains('/outputs/release/'),
      DistributionArtifactType.zip =>
        File(path).parent.path == buildPath ||
            normalized.contains('/outputs/release/'),
      DistributionArtifactType.hap ||
      DistributionArtifactType.dmg ||
      DistributionArtifactType.pkg ||
      DistributionArtifactType.msix => true,
    };
  }

  Future<void> openAppStoreConnect() =>
      _openUrl('https://appstoreconnect.apple.com/apps');

  Future<void> openGooglePlayConsole() =>
      _openUrl('https://play.google.com/console/');

  Future<void> openPgyerApiSettings() =>
      _openUrl('https://www.pgyer.com/account/api');

  Future<void> openFirApiTokenSettings() =>
      _openUrl('https://fir.xcxwo.com/apps/apitoken');

  Future<void> openTransporter(DistributionArtifact? artifact) async {
    if (!Platform.isMacOS) throw Exception('Transporter 仅支持 macOS');
    final arguments = ['-a', 'Transporter'];
    if (artifact != null &&
        (artifact.type == DistributionArtifactType.ipa ||
            artifact.type == DistributionArtifactType.pkg)) {
      arguments.add(artifact.path);
    }
    final result = await Process.run('open', arguments);
    if (result.exitCode != 0) {
      throw Exception('无法打开 Transporter，请先从 Mac App Store 安装');
    }
  }

  Future<void> _openUrl(String url) async {
    late final ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run('cmd.exe', [
        '/c',
        'start',
        '',
        url,
      ], runInShell: true);
    } else if (Platform.isMacOS) {
      result = await Process.run('open', [url]);
    } else {
      result = await Process.run('xdg-open', [url]);
    }
    if (result.exitCode != 0) throw Exception('无法打开页面：$url');
  }

  String _fileName(String path) => path
      .split(Platform.pathSeparator)
      .where((segment) => segment.isNotEmpty)
      .last;
}

class BuildArtifactNaming {
  static bool supportsCommand(List<String> arguments) =>
      arguments.length >= 2 &&
      arguments.first == 'build' &&
      const ['apk', 'appbundle', 'ipa'].contains(arguments[1]);

  const BuildArtifactNaming({
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.target,
    required this.mode,
    this.flavor,
    this.splitPerAbi = false,
    this.targetPlatforms = const [
      'android-arm',
      'android-arm64',
      'android-x64',
    ],
  });
  final String name;
  final String version;
  final String buildNumber;
  final String target;
  final String mode;
  final String? flavor;
  final bool splitPerAbi;
  final List<String> targetPlatforms;

  Set<String> get expectedAndroidNames {
    final suffix = '${flavor == null ? '' : '-${flavor!.toLowerCase()}'}-$mode';
    if (target == 'appbundle') return {'app$suffix.aab'};
    if (!splitPerAbi) return {'app$suffix.apk'};
    const abis = {
      'android-arm': 'armeabi-v7a',
      'android-arm64': 'arm64-v8a',
      'android-x64': 'x86_64',
    };
    return {
      for (final platform in targetPlatforms)
        if (abis[platform] != null) ...[
          'app-${abis[platform]}$suffix.apk',
          'app${flavor == null ? '' : '-${flavor!.toLowerCase()}'}-${abis[platform]}-$mode.apk',
        ],
    };
  }

  static String _safe(String value) => value.trim().replaceAll(
    RegExp(r'[^\p{L}\p{N}._+\-]+', unicode: true),
    '-',
  );

  String fileName(String original) {
    final dot = original.lastIndexOf('.');
    final stem = original.substring(0, dot);
    var variant = stem.replaceFirst(
      RegExp(r'^app(?:-|$)', caseSensitive: false),
      '',
    );
    if (variant.isEmpty) variant = mode;
    if (flavor != null &&
        !variant.toLowerCase().contains(flavor!.toLowerCase())) {
      variant = '$flavor-$variant';
    }
    return '${_safe(name)}-v${_safe(version)}+${_safe(buildNumber)}-${_safe(variant)}${original.substring(dot)}';
  }
}
