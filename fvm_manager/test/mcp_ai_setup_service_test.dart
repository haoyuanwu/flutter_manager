import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/mcp_ai_setup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mcp_ai_setup_');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'exports server and complete skill including the linked command guide',
    () async {
      final result = await McpAiSetupService().prepare(
        directory: directory.path,
      );
      expect(await File(result.serverPath).exists(), isTrue);
      for (final name in McpAiSetupService.skillFiles) {
        expect(await File('${result.skillPath}/$name').exists(), isTrue);
      }
      expect(
        await File(
          '${result.skillPath}/references/command-guide.md',
        ).readAsString(),
        await rootBundle.loadString(
          'codex_skills/flutter-manager-mcp/references/command-guide.md',
        ),
      );
      final instructions = buildMcpAiSetupInstructions(
        port: 18999,
        token: 'test-token',
        serverPath: result.serverPath,
        skillPath: result.skillPath,
        operatingSystem: 'test',
      );
      expect(instructions, contains(jsonEncode(result.serverPath)));
      expect(instructions, contains('references/command-guide.md'));
    },
  );

  test(
    'reuses complete user-installed files without overwriting them',
    () async {
      final service = McpAiSetupService();
      final first = await service.prepare(directory: directory.path);
      await File(first.serverPath).writeAsString('custom-server');
      await File('${first.skillPath}/SKILL.md').writeAsString('custom-skill');
      final second = await service.prepare(
        directory: '${directory.path}/unused',
        serverPath: first.serverPath,
        skillPath: first.skillPath,
      );
      expect(second.serverPath, first.serverPath);
      expect(second.skillPath, first.skillPath);
      expect(await File(first.serverPath).readAsString(), 'custom-server');
      expect(
        await File('${first.skillPath}/SKILL.md').readAsString(),
        'custom-skill',
      );
      expect(await Directory('${directory.path}/unused').exists(), isFalse);
    },
  );

  test(
    'old skill without guide is replaced by a separate complete bundle',
    () async {
      final oldSkill = Directory('${directory.path}/old-skill');
      await oldSkill.create();
      await File('${oldSkill.path}/SKILL.md').writeAsString('old-skill');
      final result = await McpAiSetupService().prepare(
        directory: '${directory.path}/prepared',
        skillPath: oldSkill.path,
      );
      expect(result.skillPath, isNot(oldSkill.path));
      expect(
        await File('${oldSkill.path}/SKILL.md').readAsString(),
        'old-skill',
      );
      expect(
        await File('${result.skillPath}/references/command-guide.md').exists(),
        isTrue,
      );
    },
  );

  test(
    'generated stdio config preserves Windows paths and token characters',
    () {
      const server = r'C:\Users\Test User\MCP\manager.mjs';
      const token = 'test-"quoted"-token\\';
      final text = buildMcpAiSetupInstructions(
        port: 19001,
        token: token,
        serverPath: server,
        skillPath: r'C:\Users\Test User\skills\flutter-manager-mcp',
        operatingSystem: 'windows',
      );
      final json = RegExp(
        r'```json\n([\s\S]*?)\n```',
      ).firstMatch(text)!.group(1)!;
      final config = jsonDecode(json) as Map;
      final service = config['mcpServers']['flutter_manager'];
      expect(service['args'], [server]);
      expect(service['env']['FLUTTER_MANAGER_TOKEN'], token);
      expect(service['env']['FLUTTER_MANAGER_PORT'], '19001');
    },
  );
}
