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
                final artifacts = _ArtifactsPanel(
                  artifacts: _artifacts,
                  selectedPath: _selectedArtifactPath,
                  loading: _loading,
                  hasProject: state.selectedManagedProjectPath != null,
                  onSelected: (path) =>
                      setState(() => _selectedArtifactPath = path),
                  onReveal: (path) =>
                      ref.read(localProjectServiceProvider).revealFile(path),
                );
                final platforms = _DistributionPlatforms(
                  artifact: _selectedArtifact,
                );
                if (constraints.maxWidth < 900) {
                  return ListView(
                    children: [
                      SizedBox(height: 360, child: artifacts),
                      const SizedBox(height: 12),
                      platforms,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: artifacts),
                    const SizedBox(width: 16),
                    SizedBox(width: 330, child: platforms),
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
  });

  final List<DistributionArtifact> artifacts;
  final String? selectedPath;
  final bool loading;
  final bool hasProject;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onReveal;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Text(
            '已打包文件',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: artifacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artifact = artifacts[index];
                    final selected = selectedPath == artifact.path;
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
  const _DistributionPlatforms({required this.artifact});

  final DistributionArtifact? artifact;

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
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '分发渠道',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _PgyerTile(artifact: artifact, project: project, state: state),
          _FirTile(artifact: artifact, project: project, state: state),
          const SizedBox(height: 4),
          const Text(
            '打开平台',
            style: TextStyle(
              fontSize: 13,
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
    );
  }
}

class _PgyerTile extends ConsumerWidget {
  const _PgyerTile({
    required this.artifact,
    required this.project,
    required this.state,
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;

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
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 21),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '蒲公英',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 18),
                    tooltip: '配置蒲公英 API',
                    onPressed: () => _showPgyerConfigDialog(context, ref),
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              if (hasApiKey)
                Text(
                  'API Key: ${hasProjectKey ? pgyerConfig.apiKey.substring(0, 8) : env.globalPgyerApiKey.substring(0, 8)}... ($keySource)',
                  style: const TextStyle(color: Colors.black54),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '未配置 API Key',
                      style: TextStyle(color: Colors.orange),
                    ),
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
    await Process.run('open', [url]);
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
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: '在蒲公英官网获取',
                border: OutlineInputBorder(),
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
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;

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
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch_outlined, size: 21),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'fir.im',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 18),
                    tooltip: '配置 fir.im',
                    onPressed: () => _showFirConfigDialog(context, ref),
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              if (hasApiToken)
                Text(
                  'API Token: ${hasProjectToken ? firConfig.apiToken.substring(0, 8) : env.globalFirApiToken.substring(0, 8)}... ($tokenSource)',
                  style: const TextStyle(color: Colors.black54),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '未配置 API Token',
                      style: TextStyle(color: Colors.orange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '请在设置页面配置全局 API Token，或点击右侧齿轮为当前项目配置',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
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
    await Process.run('open', [url]);
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
              decoration: const InputDecoration(
                labelText: 'API Token',
                hintText: '在 fir.im 个人设置中获取',
                border: OutlineInputBorder(),
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
