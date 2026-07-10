import 'dart:io';

import 'package:file_selector/file_selector.dart';

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

  Future<List<DistributionArtifact>> scanArtifacts(String projectPath) async {
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
    return artifacts;
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
