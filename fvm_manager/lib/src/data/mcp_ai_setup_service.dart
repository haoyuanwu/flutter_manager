import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class McpAiSetupFiles {
  const McpAiSetupFiles({required this.serverPath, required this.skillPath});

  final String serverPath;
  final String skillPath;
}

class McpAiSetupService {
  McpAiSetupService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const skillFiles = [
    'SKILL.md',
    'agents/openai.yaml',
    'scripts/call_flutter_manager.py',
    'references/command-guide.md',
  ];

  /// Export bundled files to a stable location, independent of the source tree.
  Future<McpAiSetupFiles> prepare({
    required String directory,
    String serverPath = '',
    String skillPath = '',
  }) async {
    final separator = Platform.pathSeparator;
    if (serverPath.isEmpty || !await File(serverPath).exists()) {
      serverPath = '$directory${separator}flutter-manager-mcp.mjs';
      final bytes = await _bundle.load(
        'mcp_server/dist/flutter-manager-mcp.mjs',
      );
      final file = File(serverPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }
    var skillReady = skillPath.isNotEmpty;
    for (final name in skillFiles) {
      if (!await File(
        '$skillPath$separator${name.replaceAll('/', separator)}',
      ).exists()) {
        skillReady = false;
      }
    }
    if (!skillReady) {
      skillPath = '$directory${separator}flutter-manager-mcp';
      for (final name in skillFiles) {
        final bytes = await _bundle.load(
          'codex_skills/flutter-manager-mcp/$name',
        );
        final file = File(
          '$skillPath$separator${name.replaceAll('/', separator)}',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      }
    }
    return McpAiSetupFiles(serverPath: serverPath, skillPath: skillPath);
  }
}

String buildMcpAiSetupInstructions({
  required int port,
  required String token,
  required String serverPath,
  required String skillPath,
  required String operatingSystem,
}) {
  final config = const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'flutter_manager': {
        'command': 'node',
        'args': [serverPath],
        'env': {
          'FLUTTER_MANAGER_HOST': '127.0.0.1',
          'FLUTTER_MANAGER_PORT': '$port',
          'FLUTTER_MANAGER_TOKEN': token,
        },
      },
    },
  });
  return '''请帮我在当前 AI 工具中连接本机 Flutter Manager MCP，并安装配套 Skill。请直接完成本机可执行的配置操作。

本机信息：
- 系统：$operatingSystem
- Flutter Manager 地址：http://127.0.0.1:$port
- 接口仅监听本机，需要保持 Flutter Manager 运行。
- MCP Server 文件：${jsonEncode(serverPath)}
- Skill 源目录：${jsonEncode(skillPath)}
- 命令选择指南：${jsonEncode('$skillPath${Platform.pathSeparator}references${Platform.pathSeparator}command-guide.md')}
- 本次只配置连接和 Skill，不运行、构建或停止项目。

请按顺序执行：
1. 确认你运行在这台电脑上，并可访问上述文件。远程或云端环境的 127.0.0.1 不是这台电脑，不要误报已连接。
2. 检查 Node.js 18+ 及 MCP Server 文件。识别当前 AI 客户端、已有配置与实际支持的配置格式，将下方 stdio 配置转换为客户端所需格式并合并进去。保留其他 MCP 服务、设置和 JSONC 注释；已有 flutter_manager 条目则更新，不要重复添加。
3. 读取 Skill 源目录中的 SKILL.md 和 references/command-guide.md，把整个 flutter-manager-mcp 目录（包括 agents、scripts、references 及其他附属文件）安装到当前客户端支持的 Skills 目录。若源目录已经是有效安装位置则复用；已有不同内容时先保留备份，不覆盖其他 Skill。不要把连接 Token 写入 SKILL.md。若客户端没有 Skill 功能，请明确说明，并读取这些说明作为本次操作指引。
4. 先用下方 env 中的 Token，通过 Authorization: Bearer <Token> 请求 GET http://127.0.0.1:$port/health，检查 App 可达与鉴权。
5. 使用客户端支持的方式重新加载 MCP，调用 flutter_manager_list_projects 做只读验证。只有该调用成功后才报告 MCP 已连接。HTTP 健康检查成功不等于客户端已加载 MCP。若需要用户重启客户端、新开会话或授予文件权限，请说明具体剩余步骤。
6. 学习命令选择指南，并简述已经掌握的规则：普通 Flutter UI 修改优先 hot_reload，Dart 初始化变化用 hot_restart，原生代码/插件/启动参数变化用 rerun，未运行时先 run，依赖变化先 pub_get；不要把 hot_restart 当作原生重编译，也不要默认 clean。
7. 报告实际修改的 MCP 配置文件、Skill 和指南安装位置以及验证结果。后续经我要求操作项目时，先结合改动和运行状态选择合适命令，再读取对应控制台反馈。不要仅因安装指南就运行或重启我的项目。

通用 MCP stdio 配置（按当前客户端格式适配，不要将 JSON 直接写入 TOML）：
```json
$config
```
'''
      .trim();
}
