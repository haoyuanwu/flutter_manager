class EditableCommand {
  const EditableCommand({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

class CustomCommandParser {
  List<EditableCommand> parse(
    String source, {
    required List<String> flavors,
    required Map<String, String> variables,
  }) {
    final pattern = RegExp(
      r'''runCommand\s*\(\s*["']([^"']+)["']\s*,\s*\[(.*?)\]\s*\)\s*;?''',
      dotAll: true,
    );
    final argumentPattern = RegExp(r'''["']([^"']*)["']''');
    final commands = <EditableCommand>[];
    for (final match in pattern.allMatches(source)) {
      final executable = match.group(1)!;
      final arguments = argumentPattern
          .allMatches(match.group(2)!)
          .map((item) => item.group(1)!)
          .toList();
      final usesFlavor = [executable, ...arguments].any(
        (value) => value.contains('{flavor}') || value.contains(r'${flavor}'),
      );
      if (usesFlavor && flavors.isEmpty) {
        throw const FormatException('自定义命令使用了 flavor 占位符，请先选择渠道');
      }
      final expandedFlavors = usesFlavor ? flavors : const <String?>[null];
      for (final flavor in expandedFlavors) {
        commands.add(
          EditableCommand(
            executable: _replace(executable, variables, flavor),
            arguments: arguments
                .map((value) => _replace(value, variables, flavor))
                .toList(),
          ),
        );
      }
    }
    if (commands.isEmpty) {
      throw const FormatException('没有找到有效的 runCommand("命令", [...]) 代码');
    }
    return commands;
  }

  String _replace(String value, Map<String, String> variables, String? flavor) {
    var result = value
        .replaceAll(r'${flavor}', flavor ?? '')
        .replaceAll('{flavor}', flavor ?? '');
    for (final entry in variables.entries) {
      result = result
          .replaceAll('\${${entry.key}}', entry.value)
          .replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}
