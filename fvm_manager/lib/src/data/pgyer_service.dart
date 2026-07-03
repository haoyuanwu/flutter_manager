import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/project_models.dart';

class PgyerUploadResult {
  const PgyerUploadResult({
    required this.buildKey,
    required this.buildName,
    required this.buildVersion,
    required this.buildVersionNo,
    required this.buildShortcutUrl,
    required this.buildQRCodeURL,
  });

  final String buildKey;
  final String buildName;
  final String buildVersion;
  final String buildVersionNo;
  final String buildShortcutUrl;
  final String buildQRCodeURL;

  String get downloadUrl {
    final value = buildShortcutUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) return value;
    return 'https://www.pgyer.com/${value.replaceAll(RegExp(r'^/+|/+$'), '')}';
  }
}

class PgyerService {
  PgyerService(this._dio);

  final Dio _dio;

  static const _baseUrl = 'https://www.pgyer.com/apiv2';
  static const _uploadEndpoint = '$_baseUrl/app/getCOSToken';
  static const _buildInfoEndpoint = '$_baseUrl/app/buildInfo';

  Future<PgyerUploadResult> uploadApp({
    required String apiKey,
    required String filePath,
    required PgyerInstallType installType,
    String? installPassword,
    String? updateDescription,
    void Function(double progress, String phase)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('文件不存在: $filePath');
    }

    onProgress?.call(0.0, '获取上传凭证');

    // Step 1: Get upload token
    final tokenResponse = await _dio.post<Map<String, dynamic>>(
      _uploadEndpoint,
      data: FormData.fromMap({
        '_api_key': apiKey,
        'buildType': _getBuildType(filePath),
        'buildInstallType': installType.index + 1,
        if (installType == PgyerInstallType.password && installPassword != null)
          'buildPassword': installPassword,
        if (updateDescription != null && updateDescription.isNotEmpty)
          'buildUpdateDescription': updateDescription,
      }),
      cancelToken: cancelToken,
    );

    final tokenData = tokenResponse.data?['data'] as Map<String, dynamic>?;
    if (tokenData == null) {
      throw Exception('获取上传凭证失败: ${tokenResponse.data?['message']}');
    }

    final endpoint = tokenData['endpoint'] as String;
    final params = tokenData['params'] as Map<String, dynamic>;
    final buildKey = tokenData['key'] as String;

    onProgress?.call(0.1, '上传文件到服务器');

    // Step 2: Upload file to COS
    final uploadData = FormData.fromMap({
      'key': params['key'],
      'signature': params['signature'],
      'x-cos-security-token': params['x-cos-security-token'],
      'x-cos-meta-file-name': file.uri.pathSegments.last,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: file.uri.pathSegments.last,
      ),
    });

    await _dio.post<void>(
      endpoint,
      data: uploadData,
      cancelToken: cancelToken,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      onSendProgress: (sent, total) {
        if (total > 0) {
          final uploadProgress = sent / total;
          onProgress?.call(
            0.1 + uploadProgress * 0.7,
            '上传中 ${(uploadProgress * 100).toStringAsFixed(0)}%',
          );
        }
      },
    );

    onProgress?.call(0.8, '等待发布完成');

    // Step 3: Poll for build info
    return _pollBuildInfo(
      apiKey: apiKey,
      buildKey: buildKey,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<PgyerUploadResult> _pollBuildInfo({
    required String apiKey,
    required String buildKey,
    void Function(double progress, String phase)? onProgress,
    CancelToken? cancelToken,
    int maxRetries = 60,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (cancelToken?.isCancelled == true) {
        throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        );
      }

      await Future<void>.delayed(const Duration(seconds: 3));

      final response = await _dio.get<Map<String, dynamic>>(
        _buildInfoEndpoint,
        queryParameters: {'_api_key': apiKey, 'buildKey': buildKey},
        cancelToken: cancelToken,
      );

      final code = response.data?['code'] as int?;
      final data = response.data?['data'] as Map<String, dynamic>?;

      if (code == 0 && data != null) {
        onProgress?.call(1.0, '发布完成');
        return PgyerUploadResult(
          buildKey: data['buildKey'] as String,
          buildName: data['buildName'] as String? ?? '',
          buildVersion: data['buildVersion'] as String? ?? '',
          buildVersionNo: data['buildVersionNo'] as String? ?? '',
          buildShortcutUrl: data['buildShortcutUrl'] as String? ?? '',
          buildQRCodeURL: data['buildQRCodeURL'] as String? ?? '',
        );
      }

      if (code == 1216) {
        throw Exception('应用发布失败');
      }

      // code == 1247 means still publishing, continue polling
      onProgress?.call(
        0.8 + (attempt / maxRetries) * 0.15,
        '发布中... (${attempt + 1}/$maxRetries)',
      );
    }

    throw Exception('发布超时，请稍后在蒲公英官网查看');
  }

  String _getBuildType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'apk':
        return 'android';
      case 'ipa':
        return 'ios';
      case 'hap':
        return 'harmonyos';
      default:
        return 'android';
    }
  }
}
