import 'dart:io';

import 'package:flutter_manager/src/data/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses plain epoch-delimited log items', () {
    final logs = LogParser().parseContent(
      '[epoch] first log [epoch]\n\n[epoch] second log [epoch]',
      isEncrypted: false,
    );

    expect(logs, ['first log', 'second log']);
  });

  test('decrypts encrypted epoch-delimited log items', () {
    final encryption = LogEncryptionService();
    final encrypted = encryption.encryptText('hello log');

    expect(LogParser().parseContent('[epoch]$encrypted[epoch]'), ['hello log']);
  });

  test('stores recent log history without duplicates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flutter_manager_log_history_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = LogHistoryStore(storageDirectory: directory);

    await store.add('/tmp/first.log');
    await store.add('/tmp/second.log');
    await store.add('/tmp/first.log');

    expect(await store.load(), ['/tmp/first.log', '/tmp/second.log']);
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('extracts file name on macOS and Windows paths', () {
    expect(logFileName('/tmp/example/wsLogs.txt'), 'wsLogs.txt');
    expect(logFileName(r'C:\logs\app.log'), 'app.log');
  });
}
