import 'package:flutter_manager/src/data/windows_git_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds bundled Codex Git and a custom Visual Studio installation', () {
    final files = {
      r'C:\Users\Alice\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe',
      r'D:\Apps\VS\Git\cmd\git.exe',
    };
    expect(
      windowsGitPaths(
        {'USERPROFILE': r'C:\Users\Alice'},
        fileExists: files.contains,
        installationRoots: [r'D:\Apps\VS\Git'],
      ),
      [
        r'D:\Apps\VS\Git\cmd',
        r'C:\Users\Alice\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd',
      ],
    );
  });

  test('discovers Git with an empty PATH and case insensitive environment', () {
    final files = {
      r'D:\Program Files\Git\cmd\git.exe',
      r'C:\Users\Alice\AppData\Local\Programs\Git\cmd\git.exe',
      r'C:\Users\Alice\scoop\apps\git\current\bin\git.exe',
    };
    expect(
      windowsGitPaths({
        'Path': '',
        'programw6432': r'D:\Program Files',
        'userprofile': r'C:\Users\Alice',
      }, fileExists: files.contains),
      [
        r'D:\Program Files\Git\cmd',
        r'C:\Users\Alice\AppData\Local\Programs\Git\cmd',
        r'C:\Users\Alice\scoop\apps\git\current\bin',
      ],
    );
  });

  test('uses LocalAppData and custom Scoop roots without duplicate paths', () {
    final files = {
      r'E:\Local\Programs\Git\cmd\git.exe',
      r'C:\Users\Alice\scoop\apps\git\current\cmd\git.exe',
      r'E:\Scoop\apps\git\current\cmd\git.exe',
    };
    final paths = windowsGitPaths({
      'USERPROFILE': r'C:\Users\Alice',
      'LOCALAPPDATA': r'E:\Local',
      'SCOOP': r'C:\Users\Alice\scoop',
      'SCOOP_GLOBAL': r'E:\Scoop',
    }, fileExists: files.contains);
    expect(paths, hasLength(3));
    expect(paths, contains(r'E:\Local\Programs\Git\cmd'));
    expect(paths, contains(r'E:\Scoop\apps\git\current\cmd'));
  });

  test('does not add missing installations to PATH', () {
    expect(windowsGitPaths({}, fileExists: (_) => false), isEmpty);
    expect(
      windowsGitPaths({}, fileExists: (path) => path == r'C:\Git\cmd\git.exe'),
      [r'C:\Git\cmd'],
    );
  });
}
