part of '../home_page.dart';

class _EnvironmentGuide extends ConsumerWidget {
  const _EnvironmentGuide({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = Platform.isWindows;
    final controller = ref.read(fvmControllerProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '环境配置',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('配置 Dart Pub 与 Flutter SDK 下载源。'),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pub 下载源',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: state.mirrorId,
                          decoration: const InputDecoration(
                            labelText: '选择下载源',
                            border: OutlineInputBorder(),
                          ),
                          items: PubEnvironmentService.mirrors
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: state.loading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    controller.setMirror(value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: state.loading
                            ? null
                            : controller.testAllMirrors,
                        icon: const Icon(Icons.speed),
                        label: const Text('测试连通性'),
                      ),
                    ],
                  ),
                  if (state.mirrorTestResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PubEnvironmentService.mirrors.map((m) {
                        final ms = state.mirrorTestResults[m.id];
                        final testing =
                            ms == null &&
                            state.mirrorTestResults.length <
                                PubEnvironmentService.mirrors.length;
                        return Chip(
                          avatar: ms == null
                              ? (testing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.help_outline, size: 18))
                              : Icon(
                                  ms < 0 ? Icons.close : Icons.check,
                                  size: 18,
                                  color: ms < 0 ? Colors.red : Colors.green,
                                ),
                          label: Text(
                            ms == null
                                ? m.name
                                : ms < 0
                                ? '${m.name}  超时'
                                : '${m.name}  ${ms}ms',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f8fa),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffe1e4e8)),
                    ),
                    child: Builder(
                      builder: (context) {
                        final current = PubEnvironmentService.mirrors
                            .where((m) => m.id == state.mirrorId)
                            .firstOrNull;
                        if (current == null || current.pubUrl == null) {
                          return const Text(
                            '使用官方默认源：pub.dev + storage.googleapis.com',
                            style: TextStyle(color: Colors.black54),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前生效地址',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _MirrorUrl('PUB_HOSTED_URL', current.pubUrl!),
                            const SizedBox(height: 2),
                            _MirrorUrl(
                              'FLUTTER_STORAGE_BASE_URL',
                              current.storageUrl ?? '',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '设置会持久化，并立即用于本工具启动的 FVM、Dart、Flutter 命令。新终端或其他应用需重新启动后读取系统环境。',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _FlutterPathSettings(state: state),
          const SizedBox(height: 28),
          const Text(
            '手动配置说明',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            windows ? 'Windows 配置指南' : 'macOS 配置指南',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          _GuideStep(
            number: '1',
            title: '确认 Dart 可用',
            command: 'dart --version',
            detail: '如果命令不可用，请先安装 Flutter，或将 Flutter 的 bin 目录加入 PATH。',
          ),
          _GuideStep(
            number: '2',
            title: '安装 FVM',
            command: 'dart pub global activate fvm',
            detail: '使用 Dart Pub 安装最新版 FVM。',
          ),
          _GuideStep(
            number: '3',
            title: '添加 FVM 到 PATH',
            command: windows
                ? r'%LOCALAPPDATA%\Pub\Cache\bin'
                : r'export PATH="$HOME/.pub-cache/bin:$PATH"',
            detail: windows
                ? '打开“系统属性 → 环境变量”，将上面的目录添加到用户 Path，然后重启终端和本应用。'
                : '把命令写入 ~/.zshrc（或对应 shell 配置文件），然后执行 source ~/.zshrc。',
          ),
          _GuideStep(
            number: '4',
            title: '让全局 Flutter 生效',
            command: windows
                ? r'%USERPROFILE%\fvm\default\bin'
                : r'export PATH="$HOME/fvm/default/bin:$PATH"',
            detail:
                '将 FVM 的 default/bin 放在其他 Flutter 路径之前，之后本工具切换全局版本会立即作用于新终端。',
          ),
          const _GuideStep(
            number: '5',
            title: '验证配置',
            command: 'fvm --version\nflutter --version',
            detail: '两个命令都能输出版本号即配置完成。',
          ),
        ],
      ),
    );
  }
}

class _MirrorUrl extends StatelessWidget {
  const _MirrorUrl(this.name, this.url);
  final String name;
  final String url;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 220,
        child: SelectableText(
          name,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      Expanded(
        child: SelectableText(
          url,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xff087ea4),
          ),
        ),
      ),
    ],
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.command,
    required this.detail,
  });
  final String number;
  final String title;
  final String command;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(number)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff101820),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      command,
                      style: const TextStyle(
                        color: Color(0xff9cdcfe),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FlutterPathSettings extends ConsumerStatefulWidget {
  const _FlutterPathSettings({required this.state});

  final FvmState state;

  @override
  ConsumerState<_FlutterPathSettings> createState() =>
      _FlutterPathSettingsState();
}

class _FlutterPathSettingsState extends ConsumerState<_FlutterPathSettings> {
  // 选择类型: 'default', 'version', 'custom'
  String _pathType = 'default';
  String? _selectedVersion;
  final TextEditingController _customPathController = TextEditingController();
  List<String> _systemPaths = [];
  bool _loadingPaths = true;
  String? _configFilePath;
  String? _configFileContent;

  @override
  void initState() {
    super.initState();
    // 如果有全局版本，默认选择 default
    if (widget.state.globalVersion != null) {
      _pathType = 'default';
    } else if (widget.state.installed.isNotEmpty) {
      _pathType = 'version';
      _selectedVersion = widget.state.installed.first.name;
    }
    _loadSystemPaths();
  }

  Future<void> _loadSystemPaths() async {
    final env = ref.read(pubEnvironmentServiceProvider);
    final paths = await env.getSystemPath();
    if (mounted) {
      setState(() {
        _systemPaths = paths;
        _loadingPaths = false;
      });
    }
    await _loadConfigFile();
  }

  Future<void> _loadConfigFile() async {
    final home = Platform.environment['HOME'];
    if (home == null) return;

    final configFiles = [
      '$home/.zshrc',
      '$home/.zshenv',
      '$home/.bash_profile',
      '$home/.bashrc',
      '$home/.profile',
    ];

    for (final path in configFiles) {
      final file = File(path);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          if (mounted) {
            setState(() {
              _configFilePath = path;
              _configFileContent = content;
            });
          }
        } catch (_) {}
        return;
      }
    }
  }

  @override
  void dispose() {
    _customPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final installed = state.installed;
    final globalVersion = state.globalVersion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '系统 Flutter 环境变量',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '将 Flutter SDK 的 bin 目录添加到系统 PATH，使终端和其他应用可以直接使用 flutter 命令。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _pathType,
              decoration: const InputDecoration(
                labelText: '选择 Flutter 来源',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'default',
                  child: Text('FVM Default（跟随全局版本切换）'),
                ),
                if (installed.isNotEmpty)
                  const DropdownMenuItem(
                    value: 'version',
                    child: Text('指定 FVM 版本'),
                  ),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('自定义路径'),
                ),
              ],
              onChanged: state.loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _pathType = value;
                          if (value == 'version' &&
                              _selectedVersion == null &&
                              installed.isNotEmpty) {
                            _selectedVersion = installed.first.name;
                          }
                        });
                      }
                    },
            ),
            if (_pathType == 'default') ...[
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
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Default 模式说明',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '设置后，系统 PATH 中的 Flutter 版本会跟随 FVM 的全局版本自动变化。\n'
                      '例如执行 fvm use 3.22.0 --global 后，终端的 flutter 命令也会切换到 3.22.0。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    if (globalVersion != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '当前全局版本：$globalVersion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff6f8fa),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffe1e4e8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '将要设置的路径',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      globalVersion != null
                          ? '~/.fvm/default/bin（当前指向 $globalVersion）'
                          : '~/.fvm/default/bin（未设置全局版本）',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xff087ea4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_pathType == 'version') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedVersion,
                decoration: const InputDecoration(
                  labelText: '选择 Flutter 版本',
                  border: OutlineInputBorder(),
                ),
                items: installed
                    .map(
                      (sdk) => DropdownMenuItem(
                        value: sdk.name,
                        child: Text('${sdk.name} (${sdk.flutterVersion})'),
                      ),
                    )
                    .toList(),
                onChanged: state.loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedVersion = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '固定版本说明',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '设置后，系统 PATH 中的 Flutter 版本固定为所选版本，不会随 fvm global 命令切换。\n'
                      '如需切换版本，需要重新执行此操作。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedVersion != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xfff6f8fa),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffe1e4e8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '将要设置的路径',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '~/.fvm/versions/$_selectedVersion/bin',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xff087ea4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_pathType == 'custom') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customPathController,
                      decoration: const InputDecoration(
                        labelText: 'Flutter bin 目录路径',
                        hintText: '/path/to/flutter/bin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final path = await getDirectoryPath(
                              confirmButtonText: '选择目录',
                            );
                            if (path != null) {
                              _customPathController.text = path;
                            }
                          },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('浏览'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '设置后需要重新打开终端才能生效。macOS 会同时写入 ~/.zshrc。',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: state.loading ? null : _apply,
                  icon: state.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.terminal),
                  label: const Text('设置到 PATH'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _configFilePath != null
                            ? '配置文件: $_configFilePath'
                            : '当前系统环境变量',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  if (_loadingPaths)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    // 图例
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _LegendItem(color: const Color(0xffff8a65), label: 'FVM'),
                          _LegendItem(color: const Color(0xff42a5f5), label: 'Flutter'),
                          _LegendItem(color: const Color(0xff66bb6a), label: 'Pub 镜像'),
                          _LegendItem(color: const Color(0xffce93d8), label: 'PATH'),
                          _LegendItem(color: const Color(0xff78909c), label: '注释'),
                          _LegendItem(color: const Color(0xffbdbdbd), label: '其他'),
                        ],
                      ),
                    ),
                    // 配置文件内容
                    if (_configFileContent != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff101820),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText.rich(
                          TextSpan(
                            children: _buildConfigFileSpans(),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else if (_systemPaths.isNotEmpty) ...[
                      // 回退显示 PATH
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff101820),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText.rich(
                          TextSpan(
                            children: _buildPathSpans(),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '未获取到配置文件或系统 PATH',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // 分类统计
                    if (_systemPaths.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff6f8fa),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffe1e4e8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PATH 路径统计',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildCategorizedPaths(),
                          ],
                        ),
                      ),
                    // 按钮行
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openShellConfig,
                            icon: const Icon(Icons.edit_document, size: 16),
                            label: const Text('打开配置文件'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    final controller = ref.read(fvmControllerProvider.notifier);

    String? flutterBinPath;

    if (_pathType == 'default') {
      // 使用 FVM default 路径
      flutterBinPath = null; // 由 controller 处理
    } else if (_pathType == 'version') {
      if (_selectedVersion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择一个 Flutter 版本')),
        );
        return;
      }
      flutterBinPath = _selectedVersion;
    } else if (_pathType == 'custom') {
      final customPath = _customPathController.text.trim();
      if (customPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入 Flutter bin 目录路径')),
        );
        return;
      }
      flutterBinPath = customPath;
    }

    await controller.setSystemFlutterPath(
      type: _pathType,
      versionOrPath: flutterBinPath,
    );

    // 刷新环境变量显示
    await _loadSystemPaths();
  }

  List<InlineSpan> _buildConfigFileSpans() {
    if (_configFileContent == null) return [];

    final spans = <InlineSpan>[];
    final lines = _configFileContent!.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // 添加行号
      spans.add(TextSpan(
        text: '${(i + 1).toString().padLeft(3)}  ',
        style: const TextStyle(color: Color(0xff616161)),
      ));

      // 根据内容类型设置颜色
      Color color;
      if (trimmed.startsWith('#')) {
        // 注释
        color = const Color(0xff78909c);
      } else if (trimmed.toLowerCase().contains('path')) {
        // PATH 相关
        color = const Color(0xffce93d8);
        // 对 PATH 行中的特殊路径高亮
        final pathSpans = _buildPathLineSpans(trimmed);
        spans.addAll(pathSpans);
        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n'));
        }
        continue;
      } else if (trimmed.toLowerCase().contains('fvm')) {
        // FVM 相关
        color = const Color(0xffff8a65);
      } else if (trimmed.toLowerCase().contains('flutter')) {
        // Flutter 相关
        color = const Color(0xff42a5f5);
      } else if (trimmed.toLowerCase().contains('pub') ||
          trimmed.toLowerCase().contains('mirror')) {
        // Pub 镜像相关
        color = const Color(0xff66bb6a);
      } else if (trimmed.startsWith('export') || trimmed.contains('=')) {
        // 其他环境变量
        color = const Color(0xffbdbdbd);
      } else {
        // 其他内容
        color = const Color(0xffe0e0e0);
      }

      spans.add(TextSpan(
        text: line,
        style: TextStyle(color: color),
      ));

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<InlineSpan> _buildPathLineSpans(String line) {
    final spans = <InlineSpan>[];

    // 找到 PATH= 后面的内容
    final pathMatch = RegExp(r'''(?:export\s+)?PATH\s*=\s*["']?([^"'\n]+)["']?''', caseSensitive: false).firstMatch(line);

    if (pathMatch == null) {
      // 如果没有匹配到 PATH=，整行用 PATH 颜色
      spans.add(TextSpan(
        text: line,
        style: const TextStyle(color: Color(0xffce93d8)),
      ));
      return spans;
    }

    // PATH= 前面的部分
    final prefix = line.substring(0, pathMatch.start);
    if (prefix.isNotEmpty) {
      spans.add(TextSpan(
        text: prefix,
        style: const TextStyle(color: Color(0xffce93d8)),
      ));
    }

    // PATH= 部分
    spans.add(TextSpan(
      text: 'PATH=',
      style: const TextStyle(color: Color(0xffce93d8)),
    ));

    // 引号
    final pathValue = pathMatch.group(1) ?? '';
    final quoteChar = line.contains('"$pathValue"') ? '"' : (line.contains("'$pathValue'") ? "'" : '');
    if (quoteChar.isNotEmpty) {
      spans.add(TextSpan(
        text: quoteChar,
        style: const TextStyle(color: Color(0xffce93d8)),
      ));
    }

    // 分割路径并高亮
    final paths = pathValue.split(':');
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i].trim();
      if (path.isEmpty) continue;

      if (i > 0) {
        spans.add(const TextSpan(
          text: ':',
          style: TextStyle(color: Color(0xff616161)),
        ));
      }

      // 根据路径内容设置颜色
      Color pathColor;
      if (path.toLowerCase().contains('fvm')) {
        pathColor = const Color(0xffff8a65);
      } else if (path.toLowerCase().contains('flutter')) {
        pathColor = const Color(0xff42a5f5);
      } else if (path.toLowerCase().contains('pub-cache') || path.toLowerCase().contains('pub_cache')) {
        pathColor = const Color(0xff66bb6a);
      } else if (path == '\$PATH' || path == '\${PATH}') {
        pathColor = const Color(0xffce93d8);
      } else {
        pathColor = const Color(0xffbdbdbd);
      }

      spans.add(TextSpan(
        text: path,
        style: TextStyle(color: pathColor),
      ));
    }

    // 关闭引号
    if (quoteChar.isNotEmpty) {
      spans.add(TextSpan(
        text: quoteChar,
        style: const TextStyle(color: Color(0xffce93d8)),
      ));
    }

    return spans;
  }

  Color _getPathColor(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('fvm')) return const Color(0xffff8a65); // 橙色 - FVM
    if (lower.contains('flutter')) return const Color(0xff42a5f5); // 蓝色 - Flutter
    if (lower.contains('pub-cache') || lower.contains('pub_cache')) {
      return const Color(0xff66bb6a); // 绿色 - Pub
    }
    return const Color(0xffbdbdbd); // 灰色 - 系统默认
  }

  List<InlineSpan> _buildPathSpans() {
    final spans = <InlineSpan>[];
    for (var i = 0; i < _systemPaths.length; i++) {
      final path = _systemPaths[i];
      final color = _getPathColor(path);

      if (i > 0) {
        spans.add(const TextSpan(
          text: ':',
          style: TextStyle(color: Color(0xff616161)),
        ));
      }

      spans.add(TextSpan(
        text: path,
        style: TextStyle(color: color),
      ));
    }
    return spans;
  }

  List<Widget> _buildCategorizedPaths() {
    final fvmPaths = <String>[];
    final flutterPaths = <String>[];
    final pubPaths = <String>[];
    final otherPaths = <String>[];

    for (final path in _systemPaths) {
      final lower = path.toLowerCase();
      if (lower.contains('fvm')) {
        fvmPaths.add(path);
      } else if (lower.contains('flutter')) {
        flutterPaths.add(path);
      } else if (lower.contains('pub-cache') || lower.contains('pub_cache')) {
        pubPaths.add(path);
      } else {
        otherPaths.add(path);
      }
    }

    final widgets = <Widget>[];

    if (fvmPaths.isNotEmpty) {
      widgets.add(_CategorySection(
        icon: Icons.storage,
        color: const Color(0xffff8a65),
        label: 'FVM',
        paths: fvmPaths,
      ));
    }

    if (flutterPaths.isNotEmpty) {
      widgets.add(_CategorySection(
        icon: Icons.flutter_dash,
        color: const Color(0xff42a5f5),
        label: 'Flutter',
        paths: flutterPaths,
      ));
    }

    if (pubPaths.isNotEmpty) {
      widgets.add(_CategorySection(
        icon: Icons.cloud_download_outlined,
        color: const Color(0xff66bb6a),
        label: 'Pub 缓存',
        paths: pubPaths,
      ));
    }

    if (otherPaths.isNotEmpty) {
      widgets.add(_CategorySection(
        icon: Icons.folder_outlined,
        color: const Color(0xffbdbdbd),
        label: '系统默认',
        paths: otherPaths,
      ));
    }

    return widgets;
  }

  Future<void> _openShellConfig() async {
    final home = Platform.environment['HOME'];
    if (home == null) return;

    // 检查存在的配置文件
    final configFiles = [
      ('$home/.zshrc', 'zsh'),
      ('$home/.zshenv', 'zsh'),
      ('$home/.bash_profile', 'bash'),
      ('$home/.bashrc', 'bash'),
      ('$home/.profile', 'sh'),
    ];

    String? fileToOpen;
    for (final (path, _) in configFiles) {
      if (await File(path).exists()) {
        fileToOpen = path;
        break;
      }
    }

    if (fileToOpen == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到 shell 配置文件')),
        );
      }
      return;
    }

    await Process.run('open', [fileToOpen]);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.icon,
    required this.color,
    required this.label,
    required this.paths,
  });

  final IconData icon;
  final Color color;
  final String label;
  final List<String> paths;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${paths.length})',
              style: TextStyle(
                fontSize: 11,
                color: color.withAlpha(180),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...paths.map((path) => Padding(
          padding: const EdgeInsets.only(left: 18, bottom: 2),
          child: SelectableText(
            path,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: color.withAlpha(200),
            ),
          ),
        )),
      ],
    ),
  );
}
