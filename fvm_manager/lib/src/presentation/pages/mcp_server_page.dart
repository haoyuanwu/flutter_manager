part of '../home_page.dart';

const _whisperJsonConfig = '''{
  "mcpServers": {
    "flutter-ai-whisper": {
      "command": "flutter_ai_whisper"
    }
  }
}''';

const _whisperTomlConfig = '''[mcp_servers.flutter-ai-whisper]
command = "flutter_ai_whisper"''';

const _whisperUsagePrompt =
    '''请使用 Flutter AI Whisper 的 discover_running_apps 查找目标项目，
再使用 connect_to_app 连接；多个应用时通过 workspaceFilter 指定项目路径。
使用 list_active_state_holders 查看当前状态，先只读检查，不修改。
需要修改时，结合源码用 inject_state_variable 调用已有方法，
然后检查页面是否更新；只有明确要求时才跳转已注册路由。
连接失败时先重新发现应用；仅在自动发现失败时使用当前会话的 vmUri。''';

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
          WorkbenchPageHeader(
            title: 'MCP 服务',
            accentColor: AppPalette.of(context).violet,
            subtitle: '连接 AI 工具，在本机管理项目、运行命令和查看控制台。',
          ),
          const SizedBox(height: 20),
          WorkbenchSplitSections(
            breakpoint: 1000,
            equalHeight: true,
            leading: WorkbenchPanel(
              key: const ValueKey('mcp-local-service-panel'),
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .45),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '仅监听本机地址，外部网络无法访问。请在同一台电脑的 AI 工具中接入。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
              key: const ValueKey('mcp-ai-setup-panel'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WorkbenchSectionHeading(
                      title: '一键接入 AI',
                      icon: Icons.auto_awesome_outlined,
                      color: AppPalette.of(context).violet,
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
              key: const ValueKey('flutter-ai-whisper-guide'),
              leading: const Icon(Icons.code_outlined, size: 20),
              title: const Text('Flutter AI Whisper', style: AppTextStyles.h3),
              subtitle: const Text('连接 Debug 应用，查看状态、调试页面与导航'),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('copy-whisper-ai-setup'),
                    onPressed: _copyingAiSetup
                        ? null
                        : () => _copyAiSetupInstructions(forWhisper: true),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(_copyingAiSetup ? '正在准备…' : '一键复制接入提示词'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '复制时自动准备并启用 Manager 本机服务。提示词包含本机连接凭据，并授权 AI 在目标未运行时启动 Debug、连接及只读验证；请仅粘贴给本机可信 AI 客户端。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Flutter Manager MCP 管理项目与运行命令；flutter_ai_whisper 连接运行中的 Flutter 应用，读取状态、执行状态修改和已注册路由导航。两者可配合使用。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. 在开发机安装独立 MCP 工具（Dart 3.8+），无需添加应用依赖或修改 main.dart。',
                ),
                const SizedBox(height: 8),
                _CodeBlock(
                  title: '安装与检查',
                  text:
                      'dart pub global activate flutter_ai_whisper\nflutter_ai_whisper --help',
                  onCopy: _copy,
                ),
                const SizedBox(height: 12),
                const Text(
                  '2. 将配置合并到 AI 客户端，保留已有 flutter_manager 服务。若客户端找不到命令，请使用 Pub 缓存 bin 目录中可执行文件的绝对路径，并确认该客户端能找到 Dart。',
                ),
                const SizedBox(height: 8),
                _CodeBlock(
                  title: 'Cursor / Claude Desktop 通用配置',
                  text: _whisperJsonConfig,
                  onCopy: _copy,
                ),
                const SizedBox(height: 12),
                _CodeBlock(
                  title: 'Codex 配置片段（config.toml）',
                  text: _whisperTomlConfig,
                  onCopy: _copy,
                ),
                const SizedBox(height: 12),
                const Text(
                  '3. 在项目管理页以 Debug 模式运行目标项目，重新加载 AI 客户端后，让 AI 发现并连接对应应用。多个项目同时运行时按项目路径筛选；应用重启后重新连接，不要复用旧 VM Service 地址。',
                ),
                const SizedBox(height: 8),
                _CodeBlock(
                  title: '复制给 AI 的使用示例',
                  text: _whisperUsagePrompt,
                  onCopy: _copy,
                ),
                const SizedBox(height: 12),
                const Text(
                  '仅用于自己控制的本机 Debug 应用；Profile / Release 不支持。状态注入会执行 Dart 并改变应用状态，先读取、再按需修改。Web 不能枚举堆对象，需要结合源码指定 expressions；页面跳转要求路由已注册，改值后还需确认页面实际刷新。',
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openExternalUrl(
                    'https://pub.dev/packages/flutter_ai_whisper',
                    context: context,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('打开 flutter_ai_whisper 文档'),
                ),
              ],
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
                            if (mounted) {
                              ref
                                  .read(fvmControllerProvider.notifier)
                                  .showError(error);
                            }
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

  Future<void> _copyAiSetupInstructions({bool forWhisper = false}) async {
    final projectPath = ref
        .read(fvmControllerProvider)
        .selectedManagedProjectPath;
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
      final text = forWhisper
          ? buildFlutterWhisperSetupPrompt(
              projectPath: projectPath,
              managerConfig: buildFlutterManagerMcpConfig(
                port: state.mcpServerPort,
                token: state.mcpServerToken,
                serverPath: files.serverPath,
              ),
              managerSkillPath: files.skillPath,
            )
          : buildMcpAiSetupInstructions(
              port: state.mcpServerPort,
              token: state.mcpServerToken,
              serverPath: files.serverPath,
              skillPath: files.skillPath,
              operatingSystem: Platform.operatingSystem,
            );
      await _copy(
        text,
        forWhisper ? 'Flutter AI Whisper 接入提示词已复制' : '接入说明已复制，粘贴给 AI 即可开始配置',
      );
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
