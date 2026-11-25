import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/windows_command_environment.dart';

void main() {
  test('repairs blank PATHEXT inherited by desktop applications', () {
    final env = windowsCommandEnvironment(
      {'Path': 'old', 'PATHEXT': ''},
      [r'D:\SDK\bin'],
    );
    expect(env['PATH'], r'D:\SDK\bin');
    expect(env['PATHEXT'], contains('.EXE'));
    expect(env['PATHEXT'], contains('.BAT'));
    expect(env.containsKey('Path'), isFalse);
  });
  test('merges case variants without dropping custom extensions', () {
    final env = windowsCommandEnvironment({
      'Pathext': '.PY;.exe',
      'PATHEXT': '.CMD',
    }, []);
    expect(
      env['PATHEXT']!.split(';'),
      containsAll(['.PY', '.EXE', '.BAT', '.CMD']),
    );
    expect(
      env.keys.where((key) => key.toLowerCase() == 'pathext'),
      hasLength(1),
    );
  });
}
