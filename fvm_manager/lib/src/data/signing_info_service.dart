import 'dart:io';

import 'process_runner.dart';

class SigningInfo {
  const SigningInfo({
    required this.fileName,
    required this.filePath,
    this.certificateAlias,
    this.issuer,
    this.subject,
    this.validFrom,
    this.validTo,
    this.serialNumber,
    this.sha1,
    this.sha256,
    this.md5,
    this.version,
  });

  final String fileName;
  final String filePath;
  final String? certificateAlias;
  final String? issuer;
  final String? subject;
  final String? validFrom;
  final String? validTo;
  final String? serialNumber;
  final String? sha1;
  final String? sha256;
  final String? md5;
  final String? version;
}

class SigningInfoService {
  SigningInfoService(this._processRunner);

  final ProcessRunner _processRunner;

  Future<SigningInfo> extractFromApk(String apkPath) async {
    final file = File(apkPath);
    if (!await file.exists()) {
      throw Exception('APK 文件不存在: $apkPath');
    }

    final fileName = apkPath.split(Platform.pathSeparator).last;

    // 使用 apksigner 获取签名信息（如果可用）
    // 否则使用 keytool 尝试读取
    try {
      return await _extractUsingKeytool(apkPath, fileName);
    } catch (e) {
      // 如果 keytool 失败，尝试使用 jarsigner
      return await _extractUsingJarsigner(apkPath, fileName);
    }
  }

  Future<SigningInfo> extractFromJks(String jksPath, {String? password}) async {
    final file = File(jksPath);
    if (!await file.exists()) {
      throw Exception('JKS 文件不存在: $jksPath');
    }

    final fileName = jksPath.split(Platform.pathSeparator).last;
    final storePassword = password ?? 'changeit'; // 默认密码

    // 使用 keytool 获取 JKS 信息
    final result = await _processRunner.run(
      executable: 'keytool',
      arguments: [
        '-list',
        '-v',
        '-keystore',
        jksPath,
        '-storepass',
        storePassword,
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('读取 JKS 失败: ${result.stderr}');
    }

    return _parseKeytoolOutput(result.stdout, fileName, jksPath);
  }

  Future<SigningInfo> _extractUsingKeytool(String filePath, String fileName) async {
    final result = await _processRunner.run(
      executable: 'keytool',
      arguments: [
        '-printcert',
        '-jarfile',
        filePath,
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('keytool 失败');
    }

    return _parseCertificateOutput(result.stdout, fileName, filePath);
  }

  Future<SigningInfo> _extractUsingJarsigner(String filePath, String fileName) async {
    final result = await _processRunner.run(
      executable: 'jarsigner',
      arguments: [
        '-verify',
        '-verbose',
        '-certs',
        filePath,
      ],
    );

    // jarsigner 返回 0 表示验证成功
    if (result.exitCode != 0 && !result.stdout.toString().contains('verified')) {
      throw Exception('jarsigner 失败: ${result.stderr}');
    }

    return _parseJarsignerOutput(result.stdout, fileName, filePath);
  }

  SigningInfo _parseCertificateOutput(String output, String fileName, String filePath) {
    final lines = output.split('\n');
    String? owner;
    String? issuer;
    String? serialNumber;
    String? sha256;
    String? sha1;
    String? md5;
    String? validFrom;
    String? validTo;
    String? version;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('Owner:') || line.startsWith('所有者:')) {
        owner = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Issuer:') || line.startsWith('发布者:')) {
        issuer = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Serial number:') || line.startsWith('序列号:')) {
        serialNumber = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Valid from:') || line.startsWith('有效期从:')) {
        // 下一行包含有效期信息
        if (i + 1 < lines.length) {
          final dateLine = lines[i + 1].trim();
          final untilIndex = dateLine.indexOf('until');
          if (untilIndex == -1) {
            // 中文格式
            final zhUntilIndex = dateLine.indexOf('至');
            if (zhUntilIndex != -1) {
              validFrom = dateLine.substring(0, zhUntilIndex).trim();
              validTo = dateLine.substring(zhUntilIndex + 1).trim();
            }
          } else {
            validFrom = dateLine.substring(0, untilIndex).trim();
            validTo = dateLine.substring(untilIndex + 5).trim();
          }
        }
      } else if (line.contains('SHA256:') || line.contains('SHA-256:')) {
        sha256 = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.contains('SHA1:') || line.contains('SHA-1:')) {
        sha1 = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.contains('MD5:')) {
        md5 = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Certificate fingerprints') || line.startsWith('证书指纹')) {
        // 下面几行包含指纹信息
        for (var j = i + 1; j < lines.length && j < i + 10; j++) {
          final fingerprintLine = lines[j].trim();
          if (fingerprintLine.contains('SHA-256:') || fingerprintLine.contains('SHA256:')) {
            sha256 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          } else if (fingerprintLine.contains('SHA-1:') || fingerprintLine.contains('SHA1:')) {
            sha1 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          } else if (fingerprintLine.contains('MD5:')) {
            md5 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          }
        }
      } else if (line.contains('Certificate version') || line.startsWith('证书版本')) {
        version = line.substring(line.indexOf(':') + 1).trim();
      }
    }

    return SigningInfo(
      fileName: fileName,
      filePath: filePath,
      certificateAlias: owner,
      issuer: issuer,
      subject: owner,
      validFrom: validFrom,
      validTo: validTo,
      serialNumber: serialNumber,
      sha1: sha1?.replaceAll(':', '').toUpperCase(),
      sha256: sha256?.replaceAll(':', '').toUpperCase(),
      md5: md5?.replaceAll(':', '').toUpperCase(),
      version: version,
    );
  }

  SigningInfo _parseKeytoolOutput(String output, String fileName, String filePath) {
    final lines = output.split('\n');
    String? alias;
    String? owner;
    String? issuer;
    String? serialNumber;
    String? sha256;
    String? sha1;
    String? md5;
    String? validFrom;
    String? validTo;
    String? version;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('Alias name:') || line.startsWith('别名:')) {
        alias = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Owner:') || line.startsWith('所有者:')) {
        owner = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Issuer:') || line.startsWith('发布者:')) {
        issuer = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Serial number:') || line.startsWith('序列号:')) {
        serialNumber = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('Valid from:') || line.startsWith('有效期从:')) {
        if (i + 1 < lines.length) {
          final dateLine = lines[i + 1].trim();
          final untilIndex = dateLine.indexOf('until');
          if (untilIndex == -1) {
            final zhUntilIndex = dateLine.indexOf('至');
            if (zhUntilIndex != -1) {
              validFrom = dateLine.substring(0, zhUntilIndex).trim();
              validTo = dateLine.substring(zhUntilIndex + 1).trim();
            }
          } else {
            validFrom = dateLine.substring(0, untilIndex).trim();
            validTo = dateLine.substring(untilIndex + 5).trim();
          }
        }
      } else if (line.startsWith('Certificate fingerprints') || line.startsWith('证书指纹')) {
        for (var j = i + 1; j < lines.length && j < i + 10; j++) {
          final fingerprintLine = lines[j].trim();
          if (fingerprintLine.contains('SHA-256:') || fingerprintLine.contains('SHA256:')) {
            sha256 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          } else if (fingerprintLine.contains('SHA-1:') || fingerprintLine.contains('SHA1:')) {
            sha1 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          } else if (fingerprintLine.contains('MD5:')) {
            md5 = fingerprintLine.substring(fingerprintLine.indexOf(':') + 1).trim();
          }
        }
      }
    }

    return SigningInfo(
      fileName: fileName,
      filePath: filePath,
      certificateAlias: alias,
      issuer: issuer,
      subject: owner,
      validFrom: validFrom,
      validTo: validTo,
      serialNumber: serialNumber,
      sha1: sha1?.replaceAll(':', '').toUpperCase(),
      sha256: sha256?.replaceAll(':', '').toUpperCase(),
      md5: md5?.replaceAll(':', '').toUpperCase(),
      version: version,
    );
  }

  SigningInfo _parseJarsignerOutput(String output, String fileName, String filePath) {
    final lines = output.split('\n');
    String? owner;
    String? sha1;
    String? sha256;
    String? md5;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // jarsigner 输出格式
      if (line.startsWith('X.509') || line.contains('CN=')) {
        // 证书信息行
        final cnMatch = RegExp(r'CN=([^,\]]+)').firstMatch(line);
        if (cnMatch != null) {
          owner ??= cnMatch.group(1);
        }
      }

      // 尝试提取指纹
      if (line.contains('SHA-256:') || line.contains('SHA256:')) {
        sha256 = _extractFingerprint(line);
      } else if (line.contains('SHA-1:') || line.contains('SHA1:')) {
        sha1 = _extractFingerprint(line);
      } else if (line.contains('MD5:')) {
        md5 = _extractFingerprint(line);
      }
    }

    return SigningInfo(
      fileName: fileName,
      filePath: filePath,
      subject: owner,
      sha1: sha1,
      sha256: sha256,
      md5: md5,
    );
  }

  String? _extractFingerprint(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return null;
    final fingerprint = line.substring(colonIndex + 1).trim();
    return fingerprint.replaceAll(':', '').toUpperCase();
  }
}