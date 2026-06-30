import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';

import '../domain/models.dart';
import 'pub_environment_service.dart';

class FlutterReleaseService {
  FlutterReleaseService(this._dio, this._environment);

  final Dio _dio;
  final PubEnvironmentService _environment;
  CancelToken? _cancelToken;

  Future<String?> fetchLatestFvmVersion() async {
    final endpoints = _environment.useDomesticMirror
        ? const [
            'https://pub.flutter-io.cn/api/packages/fvm',
            'https://pub.dev/api/packages/fvm',
          ]
        : const [
            'https://pub.dev/api/packages/fvm',
            'https://pub.flutter-io.cn/api/packages/fvm',
          ];
    for (final endpoint in endpoints) {
      try {
        final response = await _dio.get<Object>(endpoint);
        final data = response.data is String
            ? jsonDecode(response.data! as String) as Map<String, dynamic>
            : (response.data! as Map).cast<String, dynamic>();
        final latest = (data['latest'] as Map).cast<String, dynamic>();
        return latest['version'] as String?;
      } on DioException {
        // Try the mirror when the primary Pub API is unavailable.
      } on FormatException {
        // Ignore malformed responses and continue with the fallback.
      }
    }
    return null;
  }

  Future<List<FlutterRelease>> fetchReleases() async {
    final platform = Platform.isWindows ? 'windows' : 'macos';
    final uri =
        '${_environment.flutterStorageBaseUrl}/flutter_infra_release/'
        'releases/releases_$platform.json';
    final response = await _dio.get<Object>(uri);
    final data = response.data is String
        ? jsonDecode(response.data! as String) as Map<String, dynamic>
        : (response.data! as Map).cast<String, dynamic>();
    final baseUrl = _environment.rewriteStorageUrl(data['base_url'] as String);
    final releases =
        (data['releases'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where(_supportsCurrentMachine)
            .map((item) => FlutterRelease.fromMap(item, baseUrl))
            .toList()
          ..sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    return releases;
  }

  bool _supportsCurrentMachine(Map<String, dynamic> release) {
    final archive = release['archive'] as String? ?? '';
    final arm64 = Platform.version.toLowerCase().contains('arm64');
    final platformMatches = Platform.isWindows
        ? archive.contains('/windows/')
        : archive.contains('/macos/');
    return platformMatches &&
        (arm64 ? archive.contains('arm64') : !archive.contains('arm64'));
  }

  Future<void> downloadAndInstall({
    required FlutterRelease release,
    required String fvmCachePath,
    required void Function(
      double progress,
      int receivedBytes,
      int totalBytes,
      double bytesPerSecond,
      String phase,
    )
    onProgress,
  }) async {
    _cancelToken = CancelToken();
    final separator = Platform.pathSeparator;
    final work = Directory(
      '$fvmCachePath${separator}downloads$separator${release.version}',
    );
    final versions = Directory('$fvmCachePath${separator}versions');
    final target = Directory('${versions.path}$separator${release.version}');
    if (target.existsSync()) throw Exception('${release.version} 已经安装');
    if (work.existsSync()) await work.delete(recursive: true);
    await work.create(recursive: true);
    await versions.create(recursive: true);
    final archivePath = '${work.path}${separator}flutter.zip';
    var lastReceived = 0;
    var lastSample = DateTime.now();
    var smoothedSpeed = 0.0;
    try {
      await _dio.download(
        release.archiveUrl,
        archivePath,
        cancelToken: _cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastSample).inMilliseconds / 1000;
          if (elapsed >= .25) {
            final currentSpeed = (received - lastReceived) / elapsed;
            smoothedSpeed = smoothedSpeed == 0
                ? currentSpeed
                : smoothedSpeed * .72 + currentSpeed * .28;
            lastReceived = received;
            lastSample = now;
          }
          onProgress(
            total > 0 ? received / total * .9 : 0,
            received,
            total,
            smoothedSpeed,
            '正在下载',
          );
        },
      );
      final archiveBytes = await File(archivePath).length();
      onProgress(.92, archiveBytes, archiveBytes, 0, '正在解压');
      await extractFileToDisk(archivePath, work.path);
      final extracted = Directory('${work.path}${separator}flutter');
      if (!extracted.existsSync()) throw Exception('下载包中没有找到 Flutter SDK');
      await extracted.rename(target.path);
      onProgress(1, archiveBytes, archiveBytes, 0, '安装完成');
    } finally {
      if (work.existsSync()) await work.delete(recursive: true);
      _cancelToken = null;
    }
  }

  void cancel() => _cancelToken?.cancel('用户取消下载');
}
