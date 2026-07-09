part of '../home_page.dart';

class _DistributionPage extends ConsumerStatefulWidget {
  const _DistributionPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_DistributionPage> createState() => _DistributionPageState();
}

class _DistributionPageState extends ConsumerState<_DistributionPage> {
  List<DistributionArtifact> _artifacts = const [];
  String? _selectedArtifactPath;
  String? _scannedProjectPath;
  bool _loading = false;

  DistributionArtifact? get _selectedArtifact => _artifacts
      .where((artifact) => artifact.path == _selectedArtifactPath)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void didUpdateWidget(_DistributionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedManagedProjectPath !=
        widget.state.selectedManagedProjectPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  Future<void> _scan() async {
    if (!mounted) return;
    final projectPath = widget.state.selectedManagedProjectPath;
    if (projectPath == null) {
      setState(() {
        _artifacts = const [];
        _selectedArtifactPath = null;
        _scannedProjectPath = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _scannedProjectPath = projectPath;
    });
    try {
      final artifacts = await ref
          .read(distributionServiceProvider)
          .scanArtifacts(projectPath);
      if (!mounted || widget.state.selectedManagedProjectPath != projectPath) {
        return;
      }
      setState(() {
        _artifacts = artifacts;
        _selectedArtifactPath = artifacts
            .where((item) => item.path == _selectedArtifactPath)
            .firstOrNull
            ?.path;
      });
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    } finally {
      if (mounted && _scannedProjectPath == projectPath) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _chooseArtifact() async {
    try {
      final artifact = await ref
          .read(distributionServiceProvider)
          .chooseArtifact();
      if (artifact == null || !mounted) return;
      setState(() {
        _artifacts = [
          artifact,
          ..._artifacts.where((item) => item.path != artifact.path),
        ];
        _selectedArtifactPath = artifact.path;
      });
      ref
          .read(fvmControllerProvider.notifier)
          .showStatus('已选择安装包：${artifact.name}');
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final projects = state.managedProjects.where(
      (project) => project.pathExists,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '分发平台',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('扫描项目构建产物，选择安装包后上传或打开对应平台。'),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _chooseArtifact,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('选择本地安装包'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '重新扫描构建产物',
                onPressed: _loading ? null : _scan,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue:
                projects.any(
                  (project) => project.path == state.selectedManagedProjectPath,
                )
                ? state.selectedManagedProjectPath
                : null,
            decoration: const InputDecoration(
              labelText: '选择项目',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.workspaces_outline),
            ),
            items: projects
                .map(
                  (project) => DropdownMenuItem(
                    value: project.path,
                    child: Text(project.displayName),
                  ),
                )
                .toList(),
            onChanged: (path) {
              if (path != null) {
                unawaited(
                  ref
                      .read(fvmControllerProvider.notifier)
                      .selectManagedProject(path),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final artifacts = _ArtifactsPanel(
                  artifacts: _artifacts,
                  selectedPath: _selectedArtifactPath,
                  loading: _loading,
                  hasProject: state.selectedManagedProjectPath != null,
                  onSelected: (path) =>
                      setState(() => _selectedArtifactPath = path),
                  onReveal: (path) =>
                      ref.read(localProjectServiceProvider).revealFile(path),
                  compact: isNarrow,
                );
                final platforms = _DistributionPlatforms(
                  artifact: _selectedArtifact,
                  compact: isNarrow,
                );
                if (isNarrow) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: _artifacts.isEmpty ? 120 : 200,
                          child: artifacts,
                        ),
                        const SizedBox(height: 12),
                        platforms,
                      ],
                    ),
                  );
                }
                // 宽度足够时，左右布局，各自独立滚动
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: artifacts),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 330,
                      child: platforms,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactsPanel extends StatelessWidget {
  const _ArtifactsPanel({
    required this.artifacts,
    required this.selectedPath,
    required this.loading,
    required this.hasProject,
    required this.onSelected,
    required this.onReveal,
    this.compact = false,
  });

  final List<DistributionArtifact> artifacts;
  final String? selectedPath;
  final bool loading;
  final bool hasProject;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onReveal;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 12 : 16, 18, compact ? 8 : 12),
          child: Row(
            children: [
              Text(
                '已打包文件',
                style: TextStyle(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (artifacts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '(${artifacts.length})',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : artifacts.isEmpty
              ? Center(
                  child: Text(
                    hasProject ? '未找到可分发的构建产物' : '请先选择项目',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
                  itemCount: artifacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artifact = artifacts[index];
                    final selected = selectedPath == artifact.path;
                    if (compact) {
                      return ListTile(
                        dense: true,
                        selected: selected,
                        selectedTileColor: const Color(0xffeef8ff),
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected ? const Color(0xff087ea4) : null,
                          size: 20,
                        ),
                        title: Text(
                          artifact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${artifact.platformLabel} · ${_formatArtifactSize(artifact.size)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          tooltip: '在文件管理器中显示',
                          onPressed: () => onReveal(artifact.path),
                          icon: const Icon(Icons.folder_open, size: 17),
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        onTap: () => onSelected(artifact.path),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      );
                    }
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xffeef8ff),
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? const Color(0xff087ea4) : null,
                      ),
                      title: Text(
                        artifact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${artifact.platformLabel} · ${artifact.typeLabel} · '
                        '${_formatArtifactSize(artifact.size)} · '
                        '${_formatArtifactTime(artifact.modified)}',
                      ),
                      trailing: IconButton(
                        tooltip: '在文件管理器中显示',
                        onPressed: () => onReveal(artifact.path),
                        icon: const Icon(Icons.folder_open, size: 19),
                      ),
                      onTap: () => onSelected(artifact.path),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _DistributionPlatforms extends ConsumerWidget {
  const _DistributionPlatforms({required this.artifact, this.compact = false});

  final DistributionArtifact? artifact;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(distributionServiceProvider);
    final controller = ref.read(fvmControllerProvider.notifier);
    final state = ref.watch(fvmControllerProvider);
    final project = state.managedProjects
        .where((p) => p.path == state.selectedManagedProjectPath)
        .firstOrNull;

    Future<void> run(Future<void> Function() action, String message) async {
      try {
        await action();
        controller.showStatus(message);
      } catch (error) {
        controller.showError(error);
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '分发渠道',
                style: TextStyle(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              _PgyerTile(
                artifact: artifact,
                project: project,
                state: state,
                compact: compact,
              ),
              _FirTile(
                artifact: artifact,
                project: project,
                state: state,
                compact: compact,
              ),
              const SizedBox(height: 4),
              Text(
                '打开平台',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PlatformActionChip(
                    icon: Icons.apple,
                    label: 'App Store',
                    onPressed: () =>
                        run(service.openAppStoreConnect, '已打开 App Store Connect'),
                  ),
                  _PlatformActionChip(
                    icon: Icons.local_shipping_outlined,
                    label: 'Transporter',
                    onPressed: Platform.isMacOS
                        ? () => run(
                            () => service.openTransporter(artifact),
                            '已打开 Transporter',
                          )
                        : null,
                  ),
                  _PlatformActionChip(
                    icon: Icons.android,
                    label: 'Google Play',
                    onPressed: () => run(
                      service.openGooglePlayConsole,
                      '已打开 Google Play Console',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PgyerTile extends ConsumerWidget {
  const _PgyerTile({
    required this.artifact,
    required this.project,
    required this.state,
    this.compact = false,
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final env = ref.read(pubEnvironmentServiceProvider);
    final pgyerConfig = project?.pgyer ?? const PgyerConfig();
    final hasProjectKey = pgyerConfig.apiKey.isNotEmpty;
    final hasGlobalKey = env.globalPgyerApiKey.isNotEmpty;
    final hasApiKey = hasProjectKey || hasGlobalKey;
    final keySource = hasProjectKey ? '项目配置' : (hasGlobalKey ? '全局配置' : '');
    final isUploading =
        state.pgyerUploadProgress > 0 && state.pgyerUploadProgress < 1.0;
    final hasResult = state.pgyerUploadResult != null;
    final storedDownloadUrl = pgyerConfig.buildShortcutUrl.isEmpty
        ? null
        : 'https://www.pgyer.com/${pgyerConfig.buildShortcutUrl}';
    final downloadUrl = state.pgyerUploadResult ?? storedDownloadUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: compact ? 18 : 21),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Text(
                      '蒲公英',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: compact ? 16 : 18),
                    tooltip: '配置蒲公英 API',
                    onPressed: () => _showPgyerConfigDialog(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              SizedBox(height: compact ? 3 : 5),
              if (hasApiKey)
                Text(
                  'API Key: ${hasProjectKey ? pgyerConfig.apiKey.substring(0, 8) : env.globalPgyerApiKey.substring(0, 8)}... ($keySource)',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: compact ? 12 : null,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未配置 API Key',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '请在设置页面配置全局 API Key，或点击右侧齿轮为当前项目配置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('去设置页面配置'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请点击左侧导航栏的"设置"菜单，配置全局 API Key'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              if (isUploading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: state.pgyerUploadProgress),
                const SizedBox(height: 4),
                Text(
                  state.pgyerUploadPhase,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              if (hasResult) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '上传完成',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: artifact == null || !hasApiKey || isUploading
                      ? null
                      : () => controller.uploadToPgyer(artifact!.path),
                  child: Text(
                    isUploading
                        ? '上传中...'
                        : artifact == null
                        ? '请选择文件'
                        : hasApiKey
                        ? '上传到蒲公英'
                        : '请先配置 API Key',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPgyerConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _PgyerConfigDialog(project: project),
    );
  }

  Future<void> _openUrl(String url) async {
    await _openExternalUrl(url);
  }
}

class _PgyerConfigDialog extends ConsumerStatefulWidget {
  const _PgyerConfigDialog({required this.project});

  final FlutterProject? project;

  @override
  ConsumerState<_PgyerConfigDialog> createState() => _PgyerConfigDialogState();
}

class _PgyerConfigDialogState extends ConsumerState<_PgyerConfigDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _passwordController;
  late final TextEditingController _descriptionController;
  late PgyerInstallType _installType;

  @override
  void initState() {
    super.initState();
    final config = widget.project?.pgyer ?? const PgyerConfig();
    _apiKeyController = TextEditingController(text: config.apiKey);
    _passwordController = TextEditingController(text: config.installPassword);
    _descriptionController = TextEditingController(
      text: config.updateDescription,
    );
    _installType = config.installType;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('蒲公英配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '在蒲公英官网获取',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '如何获取 API Key',
                  onPressed: () => _showPgyerApiKeyHelp(context, ref),
                  icon: const Icon(Icons.help_outline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PgyerInstallType>(
              initialValue: _installType,
              decoration: const InputDecoration(
                labelText: '安装方式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PgyerInstallType.public,
                  child: Text('公开安装'),
                ),
                DropdownMenuItem(
                  value: PgyerInstallType.password,
                  child: Text('密码安装'),
                ),
                DropdownMenuItem(
                  value: PgyerInstallType.invite,
                  child: Text('邀请安装'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _installType = value);
                }
              },
            ),
            if (_installType == PgyerInstallType.password) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '安装密码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '版本更新描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final config = PgyerConfig(
      apiKey: _apiKeyController.text.trim(),
      installType: _installType,
      installPassword: _passwordController.text,
      updateDescription: _descriptionController.text.trim(),
      buildShortcutUrl: widget.project?.pgyer.buildShortcutUrl ?? '',
    );
    ref.read(fvmControllerProvider.notifier).updatePgyerConfig(config);
    Navigator.pop(context);
  }
}

class _FirTile extends ConsumerWidget {
  const _FirTile({
    required this.artifact,
    required this.project,
    required this.state,
    this.compact = false,
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final env = ref.read(pubEnvironmentServiceProvider);
    final firConfig = project?.fir ?? const FirConfig();
    final hasProjectToken = firConfig.apiToken.isNotEmpty;
    final hasGlobalToken = env.globalFirApiToken.isNotEmpty;
    final hasApiToken = hasProjectToken || hasGlobalToken;
    final tokenSource = hasProjectToken
        ? '项目配置'
        : (hasGlobalToken ? '全局配置' : '');
    final isUploading =
        state.firUploadProgress > 0 && state.firUploadProgress < 1.0;
    final hasResult = state.firUploadResult != null;
    final storedDownloadUrl = firConfig.shortCode.isEmpty
        ? null
        : 'https://fir.xcxwo.com/${firConfig.shortCode}';
    final downloadUrl = state.firUploadResult ?? storedDownloadUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, size: compact ? 18 : 21),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Text(
                      'fir.im',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: compact ? 16 : 18),
                    tooltip: '配置 fir.im',
                    onPressed: () => _showFirConfigDialog(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              SizedBox(height: compact ? 3 : 5),
              if (hasApiToken)
                Text(
                  'API Token: ${hasProjectToken ? firConfig.apiToken.substring(0, 8) : env.globalFirApiToken.substring(0, 8)}... ($tokenSource)',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: compact ? 12 : null,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未配置 API Token',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '请在设置页面配置全局 API Token，或点击右侧齿轮为当前项目配置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              if (isUploading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: state.firUploadProgress),
                const SizedBox(height: 4),
                Text(
                  state.firUploadPhase,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              if (hasResult) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '上传完成',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: artifact == null || !hasApiToken || isUploading
                      ? null
                      : () => controller.uploadToFir(artifact!.path),
                  child: Text(
                    isUploading
                        ? '上传中...'
                        : artifact == null
                        ? '请选择文件'
                        : hasApiToken
                        ? '上传到 fir.im'
                        : '请先配置 API Token',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFirConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _FirConfigDialog(project: project),
    );
  }

  Future<void> _openUrl(String url) async {
    await _openExternalUrl(url);
  }
}

Future<void> _openExternalUrl(String url) async {
  late final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('cmd.exe', [
      '/c',
      'start',
      '',
      url,
    ], runInShell: true);
  } else if (Platform.isMacOS) {
    result = await Process.run('open', [url]);
  } else {
    result = await Process.run('xdg-open', [url]);
  }
  if (result.exitCode != 0) {
    throw Exception('无法打开页面：$url');
  }
}

class _FirConfigDialog extends ConsumerStatefulWidget {
  const _FirConfigDialog({required this.project});

  final FlutterProject? project;

  @override
  ConsumerState<_FirConfigDialog> createState() => _FirConfigDialogState();
}

class _FirConfigDialogState extends ConsumerState<_FirConfigDialog> {
  late final TextEditingController _apiTokenController;
  late final TextEditingController _appNameController;
  late final TextEditingController _bundleIdController;
  late final TextEditingController _changelogController;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    final config = project?.fir ?? const FirConfig();
    _apiTokenController = TextEditingController(text: config.apiToken);
    _appNameController = TextEditingController(
      text: config.appName.isNotEmpty
          ? config.appName
          : project?.displayName ?? '',
    );
    _bundleIdController = TextEditingController(
      text: config.bundleId.isNotEmpty
          ? config.bundleId
          : project?.bugly.bundleId ?? '',
    );
    _changelogController = TextEditingController(text: config.changelog);
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    _appNameController.dispose();
    _bundleIdController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('fir.im 配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiTokenController,
              decoration: InputDecoration(
                labelText: 'API Token',
                hintText: '在 fir.im 个人设置中获取',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '如何获取 API Token',
                  onPressed: () => _showFirApiTokenHelp(context, ref),
                  icon: const Icon(Icons.help_outline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: '应用名称（可选）',
                hintText: '默认使用项目名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bundleIdController,
              decoration: const InputDecoration(
                labelText: 'Bundle ID（可选）',
                hintText: '默认使用项目的 Bundle ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _changelogController,
              decoration: const InputDecoration(
                labelText: '更新日志（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final config = FirConfig(
      apiToken: _apiTokenController.text.trim(),
      appName: _appNameController.text.trim(),
      bundleId: _bundleIdController.text.trim(),
      changelog: _changelogController.text.trim(),
      shortCode: widget.project?.fir.shortCode ?? '',
    );
    ref.read(fvmControllerProvider.notifier).updateFirConfig(config);
    Navigator.pop(context);
  }
}

class _PlatformActionChip extends StatelessWidget {
  const _PlatformActionChip({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    onPressed: onPressed,
    backgroundColor: const Color(0xfff7f9fb),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xffe4e8ec)),
    ),
  );
}

String _formatArtifactSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String _formatArtifactTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

Future<void> _showPgyerApiKeyHelp(BuildContext context, WidgetRef ref) =>
    _showDistributionCredentialHelp(
      context: context,
      title: '如何获取蒲公英 API Key',
      icon: Icons.cloud_upload_outlined,
      steps: const [
        '1. 登录蒲公英开发者平台。',
        '2. 进入账号设置中的“API 信息”页面。',
        '3. 找到 API Key 并复制到当前输入框。',
        '4. 请勿填写 User Key；上传接口使用的是 API Key。',
      ],
      onOpenPage: ref.read(distributionServiceProvider).openPgyerApiSettings,
    );

Future<void> _showFirApiTokenHelp(BuildContext context, WidgetRef ref) =>
    _showDistributionCredentialHelp(
      context: context,
      title: '如何获取 fir.im API Token',
      icon: Icons.rocket_launch_outlined,
      steps: const [
        '1. 登录 fir.im 开发者平台。',
        '2. 打开个人设置中的“API Token”页面。',
        '3. 复制 API Token，并粘贴到当前输入框。',
        '4. Token 属于敏感信息，请勿提交到项目代码仓库。',
      ],
      onOpenPage: ref.read(distributionServiceProvider).openFirApiTokenSettings,
    );

Future<void> _showDistributionCredentialHelp({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<String> steps,
  required Future<void> Function() onOpenPage,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: Icon(icon),
    title: Text(title),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps) ...[Text(step), const SizedBox(height: 9)],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('知道了'),
      ),
      FilledButton.icon(
        onPressed: () async {
          Navigator.pop(dialogContext);
          await onOpenPage();
        },
        icon: const Icon(Icons.open_in_new),
        label: const Text('打开获取页面'),
      ),
    ],
  ),
);
