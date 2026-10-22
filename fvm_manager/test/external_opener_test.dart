import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/external_opener.dart';

void main() {
  late Directory root;
  late File artifact;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('external_opener_');
    artifact = await File(
      '${root.path}${Platform.pathSeparator}release package & local.apk',
    ).create();
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'Windows accepts shell success without inspecting an Explorer exit code',
    () async {
      final calls = <(String, String?)>[];
      final opener = ExternalOpener(
        operatingSystem: 'windows',
        windowsLaunch: (target, arguments) {
          calls.add((target, arguments));
          return 33;
        },
        processRun: (_, _) => throw StateError('Must not run Explorer or cmd'),
      );
      await opener.openDirectory(root.path);
      await opener.revealFile(artifact.path);
      expect(calls, [
        (root.absolute.path, null),
        ('explorer.exe', '/select,"${artifact.absolute.path}"'),
      ]);
    },
  );

  test('Windows reports genuine shell activation failures', () async {
    for (final (code, reason) in [
      (2, '目标文件不存在'),
      (3, '目标路径不存在'),
      (5, '系统拒绝访问'),
      (31, '未找到关联的应用程序'),
      (32, '缺少所需的系统组件'),
    ]) {
      final opener = ExternalOpener(
        operatingSystem: 'windows',
        windowsLaunch: (_, _) => code,
      );
      await expectLater(
        opener.openDirectory(root.path),
        throwsA(predicate((error) => error.toString().contains(reason))),
      );
    }
  });

  test('missing local targets fail before shell activation', () async {
    final opener = ExternalOpener(
      operatingSystem: 'windows',
      windowsLaunch: (_, _) => throw StateError('Should not launch'),
    );
    await expectLater(
      opener.openDirectory('${root.path}/missing'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      opener.revealFile('${root.path}/missing.apk'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      opener.openTextFile('${root.path}/missing.txt'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'URLs keep query arguments and fragments outside any command shell',
    () async {
      const url = 'https://example.test/download?a=1&b=2#v6';
      final calls = <(String, String?)>[];
      final opener = ExternalOpener(
        operatingSystem: 'windows',
        windowsLaunch: (target, arguments) {
          calls.add((target, arguments));
          return 42;
        },
      );
      await opener.openUrl(url);
      expect(calls, [(url, null)]);
      for (final invalid in [
        'not a URL',
        'file:///C:/test.exe',
        'javascript:alert(1)',
        'https:///',
      ]) {
        await expectLater(opener.openUrl(invalid), throwsFormatException);
      }
      expect(calls, hasLength(1));
    },
  );

  test('text files launch Notepad without waiting for it to close', () async {
    final calls = <(String, String?)>[];
    final opener = ExternalOpener(
      operatingSystem: 'windows',
      windowsLaunch: (target, arguments) {
        calls.add((target, arguments));
        return 42;
      },
    );
    await opener.openTextFile(artifact.path);
    expect(calls, [('notepad.exe', '"${artifact.absolute.path}"')]);
  });

  test(
    'macOS and Linux retain proper opener arguments and failure handling',
    () async {
      for (final platform in ['macos', 'linux']) {
        final calls = <(String, List<String>)>[];
        var exitCode = 0;
        final opener = ExternalOpener(
          operatingSystem: platform,
          processRun: (executable, arguments) async {
            calls.add((executable, arguments));
            return ProcessResult(
              1,
              exitCode,
              '',
              exitCode == 0 ? '' : 'launch denied',
            );
          },
        );
        await opener.openDirectory(root.path);
        await opener.revealFile(artifact.path);
        expect(calls, [
          (platform == 'macos' ? 'open' : 'xdg-open', [root.absolute.path]),
          platform == 'macos'
              ? ('open', ['-R', artifact.absolute.path])
              : ('xdg-open', [artifact.absolute.parent.path]),
        ]);
        exitCode = 1;
        await expectLater(
          opener.openUrl('https://example.test'),
          throwsA(
            predicate((error) => error.toString().contains('launch denied')),
          ),
        );
      }
    },
  );
}
