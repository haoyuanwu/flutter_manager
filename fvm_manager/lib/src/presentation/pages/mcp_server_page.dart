part of '../home_page.dart';

class _McpServerPage extends ConsumerStatefulWidget {
  const _McpServerPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_McpServerPage> createState() => _McpServerPageState();
}

class _McpServerPageState extends ConsumerState<_McpServerPage> {
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(
      text: widget.state.mcpServerPort.toString(),
    );
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
    final mcpServerPath =
        '${Directory.current.path}${Platform.pathSeparator}mcp_server'
        '${Platform.pathSeparator}dist${Platform.pathSeparator}index.js';
    const relativeSkillPath = 'codex_skills/flutter-manager-mcp';
    final codexConfig = _codexConfig(mcpServerPath);
    final crushConfigValue = _crushConfig(mcpServerPath);
    final installCommands = _installCommands(relativeSkillPath);
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
                    '项目内已内置 Codex Skill。以后新增 MCP 工具时，更新项目里的 Skill，再从这里导出安装包。',
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: '本项目 Skill 路径',
                    text: relativeSkillPath,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: '安装到 Codex Skills',
                    text: installCommands,
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: controller.exportMcpSkill,
                        icon: const Icon(Icons.ios_share_outlined),
                        label: const Text('导出 Skill'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _copy(relativeSkillPath, 'Skill 路径已复制'),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制 Skill 路径'),
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
                    'opencode / codex 配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('将 MCP 服务配置到 AI 工具中，即可使用 Flutter Manager 的工具。'),
                  const SizedBox(height: 16),
                  _CodeBlock(
                    title: 'opencode (Crush) 配置文件路径',
                    text: Platform.isMacOS
                        ? '~/.config/crush/crush.json'
                        : r'%APPDATA%\crush\crush.json',
                    onCopy: _copy,
                  ),
                  const SizedBox(height: 12),
                  _CodeBlock(
                    title: 'opencode (Crush) 配置内容',
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
                            Icon(Icons.tips_and_updates_outlined, size: 16, color: Colors.blue.shade700),
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
                          '• 配置完成后需要重启 opencode (Crush) 或 codex\n'
                          '• 确保上方的 MCP 控制接口已启用\n'
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

  String _crushConfig(String mcpServerPath) =>
      '''
{
  "\$schema": "https://charm.land/crush.json",
  "mcp": {
    "flutter_manager": {
      "type": "stdio",
      "command": "node",
      "args": ["$mcpServerPath"],
      "env": {
        "FLUTTER_MANAGER_PORT": "${widget.state.mcpServerPort}",
        "FLUTTER_MANAGER_TOKEN": "${widget.state.mcpServerToken}"
      }
    }
  }
}
'''
          .trim();

  String _installCommands(String relativeSkillPath) =>
      '''
mkdir -p ~/.codex/skills
cp -R "$relativeSkillPath" ~/.codex/skills/
'''
          .trim();

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
