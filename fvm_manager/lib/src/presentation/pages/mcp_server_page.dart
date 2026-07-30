part of '../home_page.dart';

class _McpServerPage extends ConsumerStatefulWidget {
  const _McpServerPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_McpServerPage> createState() => _McpServerPageState();
}

class _McpServerPageState extends ConsumerState<_McpServerPage> {
  late final TextEditingController _portController;
  String _installedMcpServerPath = '';
  String _installedMcpSkillPath = '';
  bool _downloadingMcpServer = false;
  bool _downloadingMcpSkill = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: widget.state.mcpServerPort.toString(),
    );
    _installedMcpServerPath = ref
        .read(pubEnvironmentServiceProvider)
        .mcpServerExecutablePath;
    _installedMcpSkillPath = ref
        .read(pubEnvironmentServiceProvider)
        .mcpSkillPath;
  }

  @override
  void didUpdateWidget(covariant _McpServerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mcpServerPort != widget.state.mcpServerPort &&
        _portController.text != widget.state.mcpServerPort.toString()) {
      _portController.text = widget.state.mcpServerPort.toString();
    }
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final endpoint = 'http://127.0.0.1:${widget.state.mcpServerPort}';
    final sourceMcpServerPath =
        '${Directory.current.path}${Platform.pathSeparator}mcp_server'
        '${Platform.pathSeparator}dist${Platform.pathSeparator}index.js';
    final mcpServerPath = _installedMcpServerPath.isNotEmpty
        ? _installedMcpServerPath
        : sourceMcpServerPath;
    final installedMcpServerExists =
        _installedMcpServerPath.isNotEmpty &&
        File(_installedMcpServerPath).existsSync();
    final installedMcpSkillExists =
        _installedMcpSkillPath.isNotEmpty &&
        File(
          '$_installedMcpSkillPath${Platform.pathSeparator}SKILL.md',
        ).existsSync();
    final codexConfig = _codexConfig(mcpServerPath);
    final openCodeConfig = _openCodeConfig(mcpServerPath);
    final crushConfigValue = _crushConfig(mcpServerPath);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MCP 服务',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('给 Claude、Cursor、Codex 等 AI 软件调用本工具的运行命令。'),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.smart_toy_outlined),
                    title: const Text('启用 MCP 控制接口'),
                    subtitle: Text('仅监听本机：$endpoint'),
                    value: widget.state.mcpServerEnabled,
                    onChanged: controller.setMcpServerEnabled,
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'HTTP 端口',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: _savePort,
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _savePort(_portController.text.trim()),
                        child: const Text('保存端口'),
                      ),
                      TextButton.icon(
                        onPressed: _resetToken,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重置 Token'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Token',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          widget.state.mcpServerToken,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      IconButton(
                        tooltip: '复制 Token',
                        onPressed: () =>
                            _copy(widget.state.mcpServerToken, 'Token 已复制'),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 工具安装',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '先将 App 内置的 MCP Server 下载到指定目录，再把自动生成的配置复制到 AI 工具。',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: installedMcpServerExists
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: installedMcpServerExists
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          installedMcpServerExists
                              ? Icons.check_circle_outline
                              : Icons.download_outlined,
                          color: installedMcpServerExists
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                installedMcpServerExists
                                    ? 'MCP Server 已下载'
                                    : '尚未下载 MCP Server',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _installedMcpServerPath.isEmpty
                                    ? '请选择一个长期保留的目录'
                                    : _installedMcpServerPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _downloadingMcpServer
                            ? null
                            : _downloadMcpServer,
                        icon: _downloadingMcpServer
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          installedMcpServerExists
                              ? '重新下载到指定目录'
                              : '下载 MCP Server',
                        ),
                      ),
                      if (installedMcpServerExists)
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(localProjectServiceProvider)
                              .revealFile(_installedMcpServerPath),
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('打开所在目录'),
                        ),
                      if (_installedMcpServerPath.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _copy(
                            _installedMcpServerPath,
                            'MCP Server 路径已复制',
                          ),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('复制路径'),
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'AI Skill',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Skill 为 AI 提供 Flutter Manager 的操作说明；它不能代替下方的 MCP 连接配置。',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: installedMcpSkillExists
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: installedMcpSkillExists
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          installedMcpSkillExists
                              ? Icons.check_circle_outline
                              : Icons.extension_outlined,
                          color: installedMcpSkillExists
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                installedMcpSkillExists
                                    ? 'Skill 已下载'
                                    : '尚未下载 Skill',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _installedMcpSkillPath.isEmpty
                                    ? '请选择 AI 工具的 Skills 根目录'
                                    : _installedMcpSkillPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _downloadingMcpSkill
                            ? null
                            : () => _downloadMcpSkill(
                                rootDirectory: _defaultSkillRoot(
                                  openCode: false,
                                ),
                              ),
                        icon: _downloadingMcpSkill
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: const Text('安装到 Codex'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _downloadingMcpSkill
                            ? null
                            : () => _downloadMcpSkill(
                                rootDirectory: _defaultSkillRoot(
                                  openCode: true,
                                ),
                              ),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('安装到 OpenCode'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _downloadingMcpSkill
                            ? null
                            : () => _downloadMcpSkill(),
                        icon: const Icon(Icons.folder_outlined),
                        label: const Text('选择其他目录'),
                      ),
                      if (installedMcpSkillExists)
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(localProjectServiceProvider)
                              .revealFile(
                                '$_installedMcpSkillPath'
                                '${Platform.pathSeparator}SKILL.md',
                              ),
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('打开 Skill 目录'),
                        ),
                      if (_installedMcpSkillPath.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _copy(_installedMcpSkillPath, 'Skill 路径已复制'),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('复制 Skill 路径'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CodeBlock(
                    title: 'Codex：选择此 Skills 根目录',
                    text: Platform.isWindows
                        ? r'%USERPROFILE%\.codex\skills'
                        : '~/.codex/skills',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: 'OpenCode：选择此 Skills 根目录',
                    text: Platform.isWindows
                        ? r'%USERPROFILE%\.config\opencode\skills'
                        : '~/.config/opencode/skills',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '选择根目录后，App 会自动创建 flutter-manager-mcp 文件夹。安装完成后重启 AI 工具。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 工具配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('将 MCP 服务配置到 AI 工具中，即可使用 Flutter Manager 的工具。'),
                  const SizedBox(height: 16),
                  _CodeBlock(
                    title: 'OpenCode 配置文件路径',
                    text: Platform.isMacOS
                        ? '~/.config/opencode/opencode.json'
                        : r'%USERPROFILE%\.config\opencode\opencode.json',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: 'OpenCode 配置内容',
                    text: openCodeConfig,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 16),
                  _CodeBlock(
                    title: 'Crush 配置文件路径',
                    text: Platform.isMacOS
                        ? '~/.config/crush/crush.json'
                        : r'%APPDATA%\crush\crush.json',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: 'Crush 配置内容',
                    text: crushConfigValue,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 16),
                  _CodeBlock(
                    title: 'codex 配置文件路径',
                    text: Platform.isMacOS
                        ? '~/.codex/config.toml'
                        : r'%USERPROFILE%\.codex\config.toml',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: 'codex 配置内容',
                    text: codexConfig,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '提示',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 配置完成后需要重启 OpenCode、Crush 或 Codex\n'
                          '• 确保上方的 MCP 控制接口已启用\n'
                          '• 请先在上方下载 MCP Server，目标电脑需安装 Node.js 18+\n'
                          '• Token 用于验证请求，请勿泄露',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _codexConfig(String mcpServerPath) =>
      '''
[mcp_servers.flutter_manager]
command = "node"
args = ["$mcpServerPath"]
startup_timeout_sec = 30

[mcp_servers.flutter_manager.env]
FLUTTER_MANAGER_PORT = "${widget.state.mcpServerPort}"
FLUTTER_MANAGER_TOKEN = "${widget.state.mcpServerToken}"
'''
          .trim();

  String _openCodeConfig(String mcpServerPath) {
    final jsonServerPath = _jsonString(mcpServerPath);
    return '''
{
  "\$schema": "https://opencode.ai/config.json",
  "mcp": {
    "flutter_manager": {
      "type": "local",
      "command": ["node", "$jsonServerPath"],
      "enabled": true,
      "timeout": 30000,
      "environment": {
        "FLUTTER_MANAGER_PORT": "${widget.state.mcpServerPort}",
        "FLUTTER_MANAGER_TOKEN": "${widget.state.mcpServerToken}"
      }
    }
  }
}
'''
        .trim();
  }

  String _crushConfig(String mcpServerPath) {
    final jsonServerPath = _jsonString(mcpServerPath);
    return '''
{
  "\$schema": "https://charm.land/crush.json",
  "mcp": {
    "flutter_manager": {
      "type": "stdio",
      "command": "node",
      "args": ["$jsonServerPath"],
      "env": {
        "FLUTTER_MANAGER_PORT": "${widget.state.mcpServerPort}",
        "FLUTTER_MANAGER_TOKEN": "${widget.state.mcpServerToken}"
      }
    }
  }
}
'''
        .trim();
  }

  String _jsonString(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  String _defaultSkillRoot({required bool openCode}) {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ??
        Directory.current.path;
    final relativePath = openCode
        ? ['.config', 'opencode', 'skills']
        : ['.codex', 'skills'];
    return [home, ...relativePath].join(Platform.pathSeparator);
  }

  Future<void> _downloadMcpSkill({String? rootDirectory}) async {
    final directory =
        rootDirectory ?? await getDirectoryPath(confirmButtonText: '安装到此目录');
    if (directory == null || directory.isEmpty || !mounted) return;

    setState(() => _downloadingMcpSkill = true);
    try {
      final selectedDirectory = Directory(directory);
      final selectedName = selectedDirectory.path
          .split(RegExp(r'[\\/]'))
          .where((part) => part.isNotEmpty)
          .lastOrNull;
      final skillDirectory = selectedName == 'flutter-manager-mcp'
          ? selectedDirectory
          : Directory('$directory${Platform.pathSeparator}flutter-manager-mcp');
      final agentsDirectory = Directory(
        '${skillDirectory.path}${Platform.pathSeparator}agents',
      );
      final scriptsDirectory = Directory(
        '${skillDirectory.path}${Platform.pathSeparator}scripts',
      );
      await agentsDirectory.create(recursive: true);
      await scriptsDirectory.create(recursive: true);

      final skillContent = await rootBundle.loadString(
        'codex_skills/flutter-manager-mcp/SKILL.md',
      );
      final agentContent = await rootBundle.loadString(
        'codex_skills/flutter-manager-mcp/agents/openai.yaml',
      );
      final scriptData = await rootBundle.load(
        'codex_skills/flutter-manager-mcp/scripts/call_flutter_manager.py',
      );
      await File(
        '${skillDirectory.path}${Platform.pathSeparator}SKILL.md',
      ).writeAsString(skillContent, flush: true);
      await File(
        '${agentsDirectory.path}${Platform.pathSeparator}openai.yaml',
      ).writeAsString(agentContent, flush: true);
      await File(
        '${scriptsDirectory.path}${Platform.pathSeparator}'
        'call_flutter_manager.py',
      ).writeAsBytes(
        scriptData.buffer.asUint8List(
          scriptData.offsetInBytes,
          scriptData.lengthInBytes,
        ),
        flush: true,
      );
      await ref
          .read(pubEnvironmentServiceProvider)
          .setMcpSkillPath(skillDirectory.path);
      if (!mounted) return;
      setState(() => _installedMcpSkillPath = skillDirectory.path);
      _snack('Skill 已下载，重启 AI 工具后生效');
    } on Object catch (error) {
      if (mounted) _snack('下载 Skill 失败：$error');
    } finally {
      if (mounted) setState(() => _downloadingMcpSkill = false);
    }
  }

  Future<void> _downloadMcpServer() async {
    final directory = await getDirectoryPath(confirmButtonText: '下载到此目录');
    if (directory == null || directory.isEmpty || !mounted) return;

    setState(() => _downloadingMcpServer = true);
    try {
      final data = await rootBundle.load(
        'mcp_server/dist/flutter-manager-mcp.mjs',
      );
      final outputPath =
          '$directory${Platform.pathSeparator}flutter-manager-mcp.mjs';
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(outputPath).writeAsBytes(bytes, flush: true);
      await ref
          .read(pubEnvironmentServiceProvider)
          .setMcpServerExecutablePath(outputPath);
      if (!mounted) return;
      setState(() => _installedMcpServerPath = outputPath);
      _snack('MCP Server 已下载，AI 工具配置已更新');
    } on Object catch (error) {
      if (mounted) _snack('下载 MCP Server 失败：$error');
    } finally {
      if (mounted) setState(() => _downloadingMcpServer = false);
    }
  }

  Future<void> _copy(String text, [String message = '已复制']) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack(message);
  }

  Future<void> _savePort(String value) async {
    final port = int.tryParse(value);
    if (port == null) {
      _snack('端口号无效');
      return;
    }
    await ref.read(fvmControllerProvider.notifier).setMcpServerPort(port);
    if (mounted) _snack('MCP 端口已保存');
  }

  Future<void> _resetToken() async {
    await ref.read(fvmControllerProvider.notifier).resetMcpServerToken();
    if (mounted) _snack('MCP Token 已重置');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.title,
    required this.text,
    required this.onCopy,
  });

  final String title;
  final String text;
  final Future<void> Function(String text, [String message]) onCopy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onCopy(text, '$title 已复制'),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('复制'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
