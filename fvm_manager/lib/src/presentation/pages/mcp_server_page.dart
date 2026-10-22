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
  bool _copyingAiSetup = false;
  bool _showToken = false;
  String _configTarget = 'Codex';

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
    final runtime = ref.watch(mcpServerRuntimeProvider);
    final endpoint = 'http://127.0.0.1:${widget.state.mcpServerPort}';
    final sourcePath =
        '${Directory.current.path}${Platform.pathSeparator}mcp_server'
        '${Platform.pathSeparator}dist${Platform.pathSeparator}index.js';
    final serverPath =
        _installedMcpServerPath.isNotEmpty &&
            File(_installedMcpServerPath).existsSync()
        ? _installedMcpServerPath
        : File(sourcePath).existsSync()
        ? sourcePath
        : '';
    final skillReady =
        _installedMcpSkillPath.isNotEmpty &&
        File(
          '$_installedMcpSkillPath${Platform.pathSeparator}SKILL.md',
        ).existsSync();
    final guideReady =
        _installedMcpSkillPath.isNotEmpty &&
        File(
          '$_installedMcpSkillPath${Platform.pathSeparator}references${Platform.pathSeparator}command-guide.md',
        ).existsSync();
    final busy =
        _copyingAiSetup || _downloadingMcpServer || _downloadingMcpSkill;
    final config = switch (_configTarget) {
      'OpenCode' => _openCodeConfig(serverPath),
      'Crush' => _crushConfig(serverPath),
      'Xiaomi MiMo' => _mimoConfig(serverPath),
      _ => _codexConfig(serverPath),
    };
    final home = Platform.isWindows ? r'%USERPROFILE%' : '~';
    final configPath = switch (_configTarget) {
      'OpenCode' => '$home/.config/opencode/opencode.json',
      'Crush' =>
        Platform.isWindows
            ? r'%APPDATA%\crush\crush.json'
            : '~/.config/crush/crush.json',
      'Xiaomi MiMo' => '$home/.config/mimocode/mimocode.jsonc',
      _ => '$home/.codex/config.toml',
    };
    return WorkbenchScrollPage(
      maxWidth: 1040,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkbenchPageHeader(
            title: 'MCP 服务',
            subtitle: '连接 AI 工具，在本机管理项目、运行命令和查看控制台。',
          ),
          const SizedBox(height: 20),
          WorkbenchSplitSections(
            breakpoint: 1000,
            leading: WorkbenchPanel(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.lan_outlined,
                        color: runtime.running
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: const Text(
                        '本机服务',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        runtime.starting
                            ? '正在启动…'
                            : runtime.running
                            ? '运行中 · 127.0.0.1:${runtime.port}'
                            : widget.state.mcpServerEnabled
                            ? '未启动 · $endpoint'
                            : '已关闭 · $endpoint',
                      ),
                      value: widget.state.mcpServerEnabled,
                      onChanged: busy || runtime.starting
                          ? null
                          : controller.setMcpServerEnabled,
                    ),
                    if (runtime.error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          key: const ValueKey('mcp-service-error'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                runtime.error!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                              if (runtime.running)
                                Text(
                                  '原有服务仍在 127.0.0.1:${runtime.port} 运行。',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const ValueKey('retry-mcp-service'),
                                onPressed: runtime.starting
                                    ? null
                                    : controller.retryMcpServer,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('重试启动'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    ExpansionTile(
                      key: ValueKey(
                        'mcp-port-settings-${runtime.error != null}',
                      ),
                      initiallyExpanded: runtime.error != null,
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        '端口与 Token',
                        style: TextStyle(fontSize: 14),
                      ),
                      childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _portController,
                                enabled: !busy,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'HTTP 端口',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: _savePort,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        _savePort(_portController.text.trim()),
                              child: const Text('保存端口'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Token'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(
                                _showToken
                                    ? widget.state.mcpServerToken
                                    : '••••••••••••••••',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _showToken ? '隐藏 Token' : '显示 Token',
                              onPressed: () =>
                                  setState(() => _showToken = !_showToken),
                              icon: Icon(
                                _showToken
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                            IconButton(
                              tooltip: '复制 Token',
                              onPressed: () => _copy(
                                widget.state.mcpServerToken,
                                'Token 已复制',
                              ),
                              icon: const Icon(Icons.copy_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: '重置 Token',
                              onPressed: busy ? null : _resetToken,
                              icon: const Icon(Icons.refresh, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            trailing: WorkbenchPanel(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WorkbenchSectionHeading(
                      title: '一键接入 AI',
                      icon: Icons.auto_awesome_outlined,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '准备 MCP、Skill 与命令选择指南。复制后粘贴给 AI，完成本机连接并学习何时热重载、热重启或重新运行。',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('copy-mcp-ai-setup'),
                      onPressed: busy ? null : _copyAiSetupInstructions,
                      icon: _copyingAiSetup
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.copy_all_outlined),
                      label: Text(_copyingAiSetup ? '正在准备…' : '一键复制接入说明'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _setupStatus('MCP Server', serverPath.isNotEmpty),
                        _setupStatus('Skill', skillReady),
                        _setupStatus('命令指南', guideReady),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击时自动启用本机服务。需 Node.js 18+ 和本机 AI 工具；部分客户端配置后需重启。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          WorkbenchPanel(
            child: ExpansionTile(
              key: const ValueKey('mcp-manual-setup'),
              leading: const Icon(Icons.tune, size: 20),
              title: const Text('手动配置', style: AppTextStyles.h3),
              subtitle: const Text(
                '按需下载文件、安装 Skill 或复制配置',
                style: TextStyle(fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'MCP Server',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : _downloadMcpServer,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('下载到指定目录'),
                    ),
                    if (serverPath.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await ref
                                .read(localProjectServiceProvider)
                                .revealFile(serverPath);
                          } catch (error) {
                            if (mounted)
                              ref
                                  .read(fvmControllerProvider.notifier)
                                  .showError(error);
                          }
                        },
                        icon: const Icon(Icons.folder_open_outlined, size: 18),
                        label: const Text('打开文件'),
                      ),
                  ],
                ),
                if (serverPath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      serverPath,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Skill',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _downloadMcpSkill(
                              rootDirectory: _defaultSkillRoot(),
                            ),
                      child: const Text('安装到 Codex'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _downloadMcpSkill(
                              rootDirectory: _defaultSkillRoot(openCode: true),
                            ),
                      child: const Text('安装到 OpenCode'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _downloadMcpSkill(
                              rootDirectory: _defaultSkillRoot(mimo: true),
                              forMimo: true,
                            ),
                      child: const Text('安装到 Xiaomi MiMo'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => _downloadMcpSkill(),
                      child: const Text('其他目录'),
                    ),
                  ],
                ),
                if (skillReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      _installedMcpSkillPath,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _configTarget,
                  decoration: const InputDecoration(
                    labelText: 'AI 工具',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Codex', 'OpenCode', 'Crush', 'Xiaomi MiMo']
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _configTarget = value);
                  },
                ),
                const SizedBox(height: 12),
                _CodeBlock(title: '配置文件路径', text: configPath, onCopy: _copy),
                const SizedBox(height: 12),
                if (serverPath.isNotEmpty)
                  _CodeBlock(title: '配置内容', text: config, onCopy: _copy)
                else
                  const Text('先下载 MCP Server，或点击上方“一键复制接入说明”自动准备文件。'),
                const SizedBox(height: 12),
                Text(
                  '将配置合并到现有文件，安装 Skill 后重新加载或重启 AI 工具。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupStatus(String title, bool ready) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        ready ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 16,
        color: ready
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(
        '$title ${ready ? '已就绪' : '待准备'}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  Future<void> _copyAiSetupInstructions() async {
    setState(() => _copyingAiSetup = true);
    try {
      final home =
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
      if (home == null || home.isEmpty) throw Exception('无法确定用户目录');
      final environment = ref.read(pubEnvironmentServiceProvider);
      final controller = ref.read(fvmControllerProvider.notifier);
      final files = await ref
          .read(mcpAiSetupServiceProvider)
          .prepare(
            directory: [
              home,
              '.fvm_manager',
              'ai_setup',
            ].join(Platform.pathSeparator),
            serverPath: _installedMcpServerPath,
            skillPath: _installedMcpSkillPath,
          );
      await environment.setMcpServerExecutablePath(files.serverPath);
      await environment.setMcpSkillPath(files.skillPath);
      if (!mounted) return;
      setState(() {
        _installedMcpServerPath = files.serverPath;
        _installedMcpSkillPath = files.skillPath;
      });
      if (ref.read(fvmControllerProvider).mcpServerToken.isEmpty) {
        await controller.resetMcpServerToken();
      }
      if (!mounted) return;
      final running = await controller.ensureMcpServerRunning();
      if (!mounted) return;
      final state = ref.read(fvmControllerProvider);
      if (!running) {
        throw Exception(
          ref.read(mcpServerRuntimeProvider).error ?? 'MCP 本机服务尚未启动，请先解决服务错误。',
        );
      }
      final text = buildMcpAiSetupInstructions(
        port: state.mcpServerPort,
        token: state.mcpServerToken,
        serverPath: files.serverPath,
        skillPath: files.skillPath,
        operatingSystem: Platform.operatingSystem,
      );
      await _copy(text, '接入说明已复制，粘贴给 AI 即可开始配置');
    } on Object catch (error) {
      if (mounted) _snack('准备接入说明失败：$error');
    } finally {
      if (mounted) setState(() => _copyingAiSetup = false);
    }
  }

  String _codexConfig(String mcpServerPath) =>
      '''
[mcp_servers.flutter_manager]
command = "node"
args = ["${_jsonString(mcpServerPath)}"]
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

  String _mimoConfig(String mcpServerPath) {
    final jsonServerPath = _jsonString(mcpServerPath);
    return '''
{
  "mcp": {
    "flutter_manager": {
      "type": "local",
      "command": ["node", "$jsonServerPath"],
      "environment": {
        "FLUTTER_MANAGER_PORT": "${widget.state.mcpServerPort}",
        "FLUTTER_MANAGER_TOKEN": "${widget.state.mcpServerToken}"
      },
      "enabled": true
    }
  }
}
'''
        .trim();
  }

  String _jsonString(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  String _defaultSkillRoot({bool openCode = false, bool mimo = false}) {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ??
        Directory.current.path;
    final relativePath = switch ((openCode, mimo)) {
      (_, true) => ['.config', 'mimocode', 'skills'],
      (true, false) => ['.config', 'opencode', 'skills'],
      (false, false) => ['.codex', 'skills'],
    };
    return [home, ...relativePath].join(Platform.pathSeparator);
  }

  Future<void> _downloadMcpSkill({
    String? rootDirectory,
    bool forMimo = false,
  }) async {
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
      for (final name in McpAiSetupService.skillFiles) {
        final data = await rootBundle.load(
          'codex_skills/flutter-manager-mcp/$name',
        );
        final file = File(
          '${skillDirectory.path}${Platform.pathSeparator}'
          '${name.replaceAll('/', Platform.pathSeparator)}',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      if (forMimo) {
        final localesDirectory = Directory(
          '${skillDirectory.path}${Platform.pathSeparator}locales',
        );
        await localesDirectory.create(recursive: true);
        const displayName = 'Flutter Manager MCP';
        await File(
          '${localesDirectory.path}${Platform.pathSeparator}zh-CN.json',
        ).writeAsString(
          '{"displayName":"$displayName","brief":"通过 MCP 控制本机 Flutter Manager 桌面应用"}',
          flush: true,
        );
        await File(
          '${localesDirectory.path}${Platform.pathSeparator}en-US.json',
        ).writeAsString(
          '{"displayName":"$displayName","brief":"Control the local Flutter Manager app via MCP"}',
          flush: true,
        );
      }
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
        borderRadius: BorderRadius.circular(6),
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
