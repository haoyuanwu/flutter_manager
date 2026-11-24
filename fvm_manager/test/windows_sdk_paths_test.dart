import 'package:flutter_manager/src/data/windows_sdk_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds SDK after reboot when PATH points to a removed Flutter', () {
    final files = {
      r'D:\fvm\default\bin\dart.bat',
      r'D:\fvm\default\bin\cache\dart-sdk\bin\dart.exe',
    };
    expect(
      windowsSdkPaths([
        r'C:\Windows',
        r'D:\flutter\bin',
      ], fileExists: files.contains),
      [r'D:\fvm\default\bin\cache\dart-sdk\bin', r'D:\fvm\default\bin'],
    );
  });
  test('does not add missing SDKs', () {
    expect(windowsSdkPaths([r'E:\Apps'], fileExists: (_) => false), isEmpty);
  });
}
