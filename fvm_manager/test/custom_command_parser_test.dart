import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/custom_command_parser.dart';

void main() {
  test('parses runCommand blocks and expands flavors and variables', () {
    const source = r'''
await runCommand('flutter', [
  'build', 'apk', '--flavor', '${flavor}',
  '--target-platform', '{targetPlatform}',
]);
await runCommand('java', [
  '-jar', './bugly/tool.jar', '-version', '{version}',
  '-inputMapping', './build/${flavor}Release/mapping.txt',
]);
''';

    final commands = CustomCommandParser().parse(
      source,
      flavors: const ['dev', 'prod'],
      variables: const {'version': '1.2.3', 'targetPlatform': 'android-arm64'},
    );

    expect(commands, hasLength(4));
    expect(commands[0].executable, 'flutter');
    expect(commands[0].arguments, containsAll(['dev', 'android-arm64']));
    expect(commands[1].arguments, contains('prod'));
    expect(commands[2].executable, 'java');
    expect(
      commands[2].arguments,
      containsAll(['1.2.3', './build/devRelease/mapping.txt']),
    );
    expect(commands[3].arguments, contains('./build/prodRelease/mapping.txt'));
  });
}
