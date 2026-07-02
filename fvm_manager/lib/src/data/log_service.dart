import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

const String epochLogDelimiter = '[epoch]';

class LogParser {
  List<String> parseContent(String content, {bool isEncrypted = true}) {
    final encryption = LogEncryptionService();
    final items = content
        .split(epochLogDelimiter)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    final logs = <String>[];
    for (final item in items) {
      if (!isEncrypted) {
        logs.add(item);
        continue;
      }
      try {
        logs.add(encryption.decrypt(item));
      } on Object {
        logs.add('[日志解密失败] $item');
      }
    }
    return logs;
  }

  Future<List<String>> parseFile(String path, {bool isEncrypted = true}) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    return parseContent(await file.readAsString(), isEncrypted: isEncrypted);
  }
}

class LogEncryptionService {
  LogEncryptionService()
    : _key = encrypt.Key(base64Decode(_keyString)),
      _iv = encrypt.IV.fromUtf8('1234567890123456');

  static const _keyString = 'Vui6Qah3kqtpLp9MVWhoBBz20blgQCqjHgu3LOcrzEY=';
  final encrypt.Key _key;
  final encrypt.IV _iv;

  String encryptText(String text) => encrypt.Encrypter(
    encrypt.AES(_key, mode: encrypt.AESMode.cbc),
  ).encrypt(text, iv: _iv).base64;

  String decrypt(String value) => encrypt.Encrypter(
    encrypt.AES(_key, mode: encrypt.AESMode.cbc),
  ).decrypt64(value, iv: _iv);
}

class LogHistoryStore {
  LogHistoryStore({this.storageDirectory});

  static const _maxItems = 20;
  final Directory? storageDirectory;

  Future<List<String>> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return const [];
      final value = jsonDecode(await file.readAsString());
      if (value is! List) return const [];
      return value.whereType<String>().toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<String>> add(String path) async {
    final history = await load();
    final updated = <String>[
      path,
      ...history.where((item) => item != path),
    ].take(_maxItems).toList(growable: false);
    await _save(updated);
    return updated;
  }

  Future<void> clear() async {
    final file = _file;
    if (await file.exists()) await file.delete();
  }

  Future<void> _save(List<String> history) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(history), flush: true);
  }

  File get _file {
    final directory = storageDirectory ?? _defaultDirectory;
    return File('${directory.path}${Platform.pathSeparator}log_history.json');
  }

  Directory get _defaultDirectory {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null) return Directory.systemTemp;
    return Directory('$home${Platform.pathSeparator}.fvm_manager');
  }
}

class LogFileService {
  Future<String?> chooseFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: '日志文件', extensions: ['log', 'txt']),
        ],
        confirmButtonText: '打开日志',
      );
      return file?.path;
    } on MissingPluginException {
      throw Exception('文件选择插件尚未加载，请彻底停止应用后重新运行');
    }
  }
}

String logFileName(String path) =>
    path.split(RegExp(r'[/\\]')).where((item) => item.isNotEmpty).last;
