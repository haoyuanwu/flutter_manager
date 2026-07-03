import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

class FirUploadResult {
  const FirUploadResult({
    required this.appId,
    required this.shortUrl,
    required this.appName,
    required this.version,
    required this.build,
  });

  final String appId;
  final String shortUrl;
  final String appName;
  final String version;
  final String build;

  String get downloadUrl => 'https://www.betaqr.com.cn/$shortUrl';
}

class FirService {
  FirService(this._dio);

  final Dio _dio;

  static const _baseUrl = 'http://api.appmeta.cn';

  Future<FirUploadResult> uploadApp({
    required String apiToken,
    required String filePath,
    required String appName,
    required String bundleId,
    required String version,
    required String build,
    String? changelog,
    void Function(double progress, String phase)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('文件不存在: $filePath');
    }

    final fileType = _getFileType(filePath);

    onProgress?.call(0.0, '获取上传凭证');

    // Step 1: Get upload credentials
    final credResponse = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/apps',
      data: {
        'type': fileType,
        'bundle_id': bundleId,
        'api_token': apiToken,
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
      ),
      cancelToken: cancelToken,
    );

    final appId = credResponse.data?['id'] as String?;
    final cert = credResponse.data?['cert'] as Map<String, dynamic>?;
    final short = credResponse.data?['short'] as String?;

    if (appId == null || cert == null) {
      throw Exception('获取上传凭证失败: ${credResponse.data}');
    }

    final binaryCert = cert['binary'] as Map<String, dynamic>;

    onProgress?.call(0.1, '上传应用图标');

    // Step 2: Upload icon (optional - skip if no icon)
    // We'll skip icon upload for now, focus on binary upload

    onProgress?.call(0.2, '上传安装包');

    // Step 3: Upload binary file
    final binaryFormData = FormData.fromMap({
      'key': binaryCert['key'],
      'token': binaryCert['token'],
      'file': await MultipartFile.fromFile(
        filePath,
        filename: file.uri.pathSegments.last,
      ),
      'x:name': appName,
      'x:version': version,
      'x:build': build,
      if (changelog != null && changelog.isNotEmpty) 'x:changelog': changelog,
    });

    await _dio.post<void>(
      binaryCert['upload_url'] as String,
      data: binaryFormData,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) {
          final progress = sent / total;
          onProgress?.call(0.2 + progress * 0.8, '上传中 ${(progress * 100).toStringAsFixed(0)}%');
        }
      },
    );

    onProgress?.call(1.0, '上传完成');

    return FirUploadResult(
      appId: appId,
      shortUrl: short ?? '',
      appName: appName,
      version: version,
      build: build,
    );
  }

  String _getFileType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'ipa':
        return 'ios';
      case 'apk':
      case 'aab':
        return 'android';
      default:
        return 'android';
    }
  }
}
