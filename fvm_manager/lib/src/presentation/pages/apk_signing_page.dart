part of '../home_page.dart';

class _ApkSigningPage extends ConsumerStatefulWidget {
  const _ApkSigningPage({required this.onOpenSettings, this.initialApkPath});
  final VoidCallback onOpenSettings;
  final String? initialApkPath;

  @override
  ConsumerState<_ApkSigningPage> createState() => _ApkSigningPageState();
}

class _ApkSigningPageState extends ConsumerState<_ApkSigningPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _keyAliasController = TextEditingController();
  final TextEditingController _outputNamePrefixController =
      TextEditingController();
  final TextEditingController _outputNameSuffixController =
      TextEditingController();
  ApkSigningConfig _config = const ApkSigningConfig();
  bool _loading = true;
  final Set<String> _selectedApkPaths = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialApkPath != null) {
      _selectedApkPaths.add(widget.initialApkPath!);
    }
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant _ApkSigningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialApkPath != null &&
        widget.initialApkPath != oldWidget.initialApkPath) {
      _selectedApkPaths.add(widget.initialApkPath!);
    }
  }

  Future<void> _loadConfig() async {
    final service = ref.read(apkSigningServiceProvider);
    var config = await service.loadConfig();
    if (config.outputDirectory.isEmpty) {
      config = config.copyWith(outputDirectory: service.defaultOutputDirectory);
    }
    if (mounted) {
      setState(() {
        _config = config;
        _passwordController.text = config.password;
        _keyAliasController.text = config.keyAlias;
        _outputNamePrefixController.text = config.outputNamePrefix;
        _outputNameSuffixController.text = config.outputNameSuffix;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _keyAliasController.dispose();
    _outputNamePrefixController.dispose();
    _outputNameSuffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(apkSigningControllerProvider.notifier);
    final state = ref.watch(apkSigningControllerProvider);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: AppSpacing.pagePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 900;
          final scrollPage = !sideBySide || constraints.maxHeight < 760;
          final panels = sideBySide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildUnsignedPanel(state, controller)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSignedPanel(state)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _buildUnsignedPanel(state, controller)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildSignedPanel(state)),
                  ],
                );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: scrollPage ? MainAxisSize.min : MainAxisSize.max,
            children: [
              WorkbenchPageHeader(
                title: 'APK 签名',
                subtitle: '配置签名凭据与输出规则，添加 APK 后批量签名。',
                actions: [
                  OutlinedButton.icon(
                    onPressed: state.signingInProgress ? null : _addProjectApk,
                    icon: const Icon(Icons.folder_copy_outlined, size: 18),
                    label: const Text('从项目获取 APK'),
                  ),
                  IconButton(
                    key: const ValueKey('apk-signing-settings'),
                    tooltip: '签名后的源文件处理设置',
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildConfigSection(),
              const SizedBox(height: 16),
              if (scrollPage)
                SizedBox(height: sideBySide ? 360 : 656, child: panels)
              else
                Expanded(child: panels),
            ],
          );
          return scrollPage
              ? SingleChildScrollView(primary: false, child: content)
              : content;
        },
      ),
    );
  }

  Widget _buildConfigSection() {
    return WorkbenchPanel(
      key: const ValueKey('apk-signing-config'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkbenchSectionHeading(
            title: '签名配置',
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 16),
          WorkbenchSplitSections(
            breakpoint: 900,
            leading: Column(
              key: const ValueKey('apk-signing-credentials'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('签名凭据', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildPathPicker(
                  buttonKey: const ValueKey('apk-signing-select-jks'),
                  label: 'JKS / Keystore 文件',
                  path: _config.jksPath,
                  placeholder: '尚未选择密钥库',
                  icon: Icons.key_outlined,
                  actionLabel: _config.jksPath.isEmpty ? '选择文件' : '更换文件',
                  onPressed: _pickJksFile,
                ),
                const SizedBox(height: 12),
                _buildCredentialFields(),
              ],
            ),
            trailing: Column(
              key: const ValueKey('apk-signing-output-settings'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输出设置', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildOutputDirectoryField(),
                const SizedBox(height: 12),
                _buildOutputNameFields(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '配置修改后自动保存；命名前缀和后缀应用于本次选中的所有 APK。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialFields() => Row(
    children: [
      Expanded(
        child: _config.keyAliasHistory.isEmpty
            ? TextField(
                controller: _keyAliasController,
                decoration: const InputDecoration(
                  labelText: 'Key Alias',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (_) => _saveConfig(),
              )
            : DropdownMenu<String>(
                controller: _keyAliasController,
                expandedInsets: EdgeInsets.zero,
                menuHeight: 280,
                label: const Text('Key Alias'),
                trailingIcon: const Icon(Icons.arrow_drop_down, size: 20),
                selectedTrailingIcon: const Icon(Icons.arrow_drop_up, size: 20),
                inputDecorationTheme: const InputDecorationTheme(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(),
                ),
                textStyle: Theme.of(context).textTheme.bodyLarge,
                dropdownMenuEntries: _config.keyAliasHistory.map((item) {
                  return DropdownMenuEntry<String>(
                    value: item,
                    label: item,
                    trailingIcon: GestureDetector(
                      onTap: () => _removeKeyAliasHistory(item),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  );
                }).toList(),
                onSelected: (value) {
                  if (value != null) {
                    _keyAliasController.text = value;
                    _saveConfig();
                  }
                },
              ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _config.passwordHistory.isEmpty
            ? TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (_) => _saveConfig(),
              )
            : DropdownMenu<String>(
                controller: _passwordController,
                expandedInsets: EdgeInsets.zero,
                menuHeight: 280,
                label: const Text('密码'),
                trailingIcon: const Icon(Icons.arrow_drop_down, size: 20),
                selectedTrailingIcon: const Icon(Icons.arrow_drop_up, size: 20),
                inputDecorationTheme: const InputDecorationTheme(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(),
                ),
                textStyle: Theme.of(context).textTheme.bodyLarge,
                dropdownMenuEntries: _config.passwordHistory.map((item) {
                  return DropdownMenuEntry<String>(
                    value: item,
                    label: item,
                    trailingIcon: GestureDetector(
                      onTap: () => _removePasswordHistory(item),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  );
                }).toList(),
                onSelected: (value) {
                  if (value != null) {
                    _passwordController.text = value;
                    _saveConfig();
                  }
                },
              ),
      ),
    ],
  );

  Widget _buildOutputDirectoryField() => _buildPathPicker(
    buttonKey: const ValueKey('apk-signing-select-output'),
    label: '输出目录',
    path: _config.outputDirectory,
    placeholder: '选择签名后的 APK 保存位置',
    icon: Icons.drive_folder_upload_outlined,
    actionLabel: '选择目录',
    onPressed: _pickOutputDirectory,
  );

  Widget _buildPathPicker({
    required Key buttonKey,
    required String label,
    required String path,
    required String placeholder,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: path.isEmpty ? placeholder : path,
                    child: Text(
                      path.isEmpty ? placeholder : path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: const Icon(Icons.folder_open, size: 16),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(104, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputNameFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _outputNamePrefixController,
                decoration: const InputDecoration(
                  labelText: '统一前缀（可选）',
                  hintText: '例如 release_',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => _saveConfig(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _outputNameSuffixController,
                decoration: const InputDecoration(
                  labelText: '统一后缀（可选）',
                  hintText: '例如 _signed',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => _saveConfig(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnsignedPanel(
    ApkSigningState state,
    ApkSigningController controller,
  ) {
    final hasApks = state.unsignedApks.isNotEmpty;
    final signing = state.signingInProgress;
    final progress = signing
        ? _parseSigningProgress(state.signingStatus, state.unsignedApks.length)
        : 0.0;

    return WorkbenchPanel(
      key: const ValueKey('apk-signing-unsigned-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .4),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '待签名',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (hasApks) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${state.unsignedApks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                if (_selectedApkPaths.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '已选 ${_selectedApkPaths.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                if (hasApks && !signing)
                  SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedApkPaths.length ==
                              state.unsignedApks.length) {
                            _selectedApkPaths.clear();
                          } else {
                            _selectedApkPaths.addAll(
                              state.unsignedApks.map((a) => a.path),
                            );
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedApkPaths.length == state.unsignedApks.length
                            ? '取消全选'
                            : '全选',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    key: const ValueKey('apk-signing-add-apks'),
                    onPressed: signing ? null : () => _addApks(controller),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加 APK', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (signing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress, minHeight: 4),
                  const SizedBox(height: 4),
                  Text(
                    state.signingStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 1),
          Expanded(
            child: hasApks
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: state.unsignedApks.length,
                    itemBuilder: (context, index) {
                      final apk = state.unsignedApks[index];
                      final selected = _selectedApkPaths.contains(apk.path);
                      return _buildUnsignedApkTile(
                        apk,
                        selected,
                        signing,
                        controller,
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '点击上方添加 APK',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              key: const ValueKey('apk-signing-submit'),
              onPressed: signing || _selectedApkPaths.isEmpty
                  ? null
                  : () => _signSelected(controller),
              icon: signing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.app_shortcut_outlined, size: 20),
              label: Text(
                signing ? '签名中...' : '签名选中 (${_selectedApkPaths.length})',
                style: const TextStyle(fontSize: 14),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsignedApkTile(
    ApkInfo apk,
    bool selected,
    bool signing,
    ApkSigningController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Checkbox(
              value: selected,
              onChanged: signing
                  ? null
                  : (_) {
                      setState(() {
                        if (selected) {
                          _selectedApkPaths.remove(apk.path);
                        } else {
                          _selectedApkPaths.add(apk.path);
                        }
                      });
                    },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  apk.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                _buildColoredSubtitle(_buildApkSubtitle(apk)),
                const SizedBox(height: 4),
                _OutputNameField(
                  path: apk.path,
                  value: apk.outputName,
                  onChanged: controller.updateApkOutputName,
                ),
              ],
            ),
          ),
          if (!signing)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() => _selectedApkPaths.remove(apk.path));
                  controller.removeUnsignedApk(apk.path);
                },
                padding: EdgeInsets.zero,
                tooltip: '移除',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignedPanel(ApkSigningState state) {
    final hasApks = state.signedApks.isNotEmpty;
    final successCount = state.signedApks.where((a) => a.success).length;

    return WorkbenchPanel(
      key: const ValueKey('apk-signing-signed-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: .4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '已签名',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (hasApks) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: successCount == state.signedApks.length
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : AppPalette.of(context).warningBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$successCount/${state.signedApks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: successCount == state.signedApks.length
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : AppPalette.of(context).warningText,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (hasApks)
                  SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () {
                        ref
                            .read(apkSigningControllerProvider.notifier)
                            .clearSignedApks();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('清空', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: _openSignedOutputDir,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('打开目录', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.signingStatus.isNotEmpty && !state.signingInProgress)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                state.signingStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: successCount == state.signedApks.length
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: hasApks
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: state.signedApks.length,
                    itemBuilder: (context, index) {
                      final apk = state.signedApks[index];
                      return _buildSignedApkTile(apk);
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '签名完成后显示结果',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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

  Widget _buildSignedApkTile(SignedApkInfo apk) {
    final name = apk.outputName.isNotEmpty
        ? apk.outputName
        : apk.originalPath.split('/').last;
    final subtitle = apk.success
        ? _buildSignedApkSubtitle(apk)
        : (apk.errorMessage ?? '签名失败');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              apk.success ? Icons.check_circle : Icons.error,
              size: 22,
              color: apk.success
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                apk.success
                    ? Tooltip(
                        message: subtitle,
                        child: _buildColoredSubtitle(subtitle),
                      )
                    : Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ],
            ),
          ),
          if (apk.success)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.folder_open, size: 18),
                onPressed: () => _revealFile(apk.outputPath),
                padding: EdgeInsets.zero,
                tooltip: '打开文件位置',
              ),
            ),
        ],
      ),
    );
  }

  String _buildApkSubtitle(ApkInfo apk) {
    final parts = <String>[];
    if (apk.channel.isNotEmpty && apk.channel != '未知') {
      parts.add('渠道: ${apk.channel}');
    }
    if (apk.gdtChannel.isNotEmpty) {
      parts.add('GDT: ${apk.gdtChannel}');
    }
    if (apk.versionName.isNotEmpty) {
      parts.add('版本: ${apk.versionName}(${apk.versionCode})');
    }
    return parts.isEmpty ? '无元数据' : parts.join(' · ');
  }

  Widget _buildColoredSubtitle(String text) {
    final spans = <TextSpan>[];
    final segments = text.split('·');

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i].trim();
      if (segment.isEmpty) continue;

      if (i > 0) {
        spans.add(
          TextSpan(
            text: ' · ',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }

      Color? color;
      if (segment.startsWith('渠道:') || segment.startsWith('渠道 :')) {
        color = Theme.of(context).colorScheme.primary;
      } else if (segment.startsWith('GDT:') || segment.startsWith('GDT :')) {
        color = Theme.of(context).colorScheme.secondary;
      } else if (segment.startsWith('版本:') || segment.startsWith('版本 :')) {
        color = Theme.of(context).colorScheme.tertiary;
      }

      spans.add(
        TextSpan(
          text: segment,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  String _buildSignedApkSubtitle(SignedApkInfo apk) {
    if (apk.sourceReplacementError != null) return apk.sourceReplacementError!;
    final parts = <String>[];
    if (apk.sourceBackupPath != null) {
      parts.add('已覆盖源文件，原文件备份：${apk.sourceBackupPath}');
    }
    if (apk.channel.isNotEmpty && apk.channel != '未知') {
      parts.add('渠道: ${apk.channel}');
    }
    if (apk.gdtChannel.isNotEmpty) {
      parts.add('GDT: ${apk.gdtChannel}');
    }
    if (apk.versionName.isNotEmpty) {
      parts.add('版本: ${apk.versionName}(${apk.versionCode})');
    }
    return parts.isEmpty ? '签名成功' : parts.join(' · ');
  }

  double _parseSigningProgress(String status, int total) {
    if (total == 0) return 0;
    final match = RegExp(r'\((\d+)/(\d+)\)').firstMatch(status);
    if (match != null) {
      final current = int.tryParse(match.group(1) ?? '0') ?? 0;
      return current / total;
    }
    return 0;
  }

  Future<void> _pickJksFile() async {
    final service = ref.read(apkSigningServiceProvider);
    final path = await service.pickJksFile();
    if (path != null) {
      setState(() => _config = _config.copyWith(jksPath: path));
      await _saveConfig();
    }
  }

  Future<void> _pickOutputDirectory() async {
    final service = ref.read(apkSigningServiceProvider);
    final path = await service.pickOutputDirectory();
    if (path != null) {
      setState(() => _config = _config.copyWith(outputDirectory: path));
      await _saveConfig();
    }
  }

  Future<void> _saveConfig() async {
    final service = ref.read(apkSigningServiceProvider);
    final keyAlias = _keyAliasController.text.trim();
    final password = _passwordController.text;

    List<String> keyAliasHistory = List<String>.from(_config.keyAliasHistory);
    if (keyAlias.isNotEmpty && !keyAliasHistory.contains(keyAlias)) {
      keyAliasHistory.insert(0, keyAlias);
      if (keyAliasHistory.length > 10) {
        keyAliasHistory = keyAliasHistory.sublist(0, 10);
      }
    }

    List<String> passwordHistory = List<String>.from(_config.passwordHistory);
    if (password.isNotEmpty && !passwordHistory.contains(password)) {
      passwordHistory.insert(0, password);
      if (passwordHistory.length > 10) {
        passwordHistory = passwordHistory.sublist(0, 10);
      }
    }

    final config = _config.copyWith(
      password: password,
      keyAlias: keyAlias,
      outputNamePrefix: _outputNamePrefixController.text,
      outputNameSuffix: _outputNameSuffixController.text,
      keyAliasHistory: keyAliasHistory,
      passwordHistory: passwordHistory,
    );
    await service.saveConfig(config);
    if (mounted) setState(() => _config = config);
  }

  Future<void> _removeKeyAliasHistory(String value) async {
    final newHistory = List<String>.from(_config.keyAliasHistory)
      ..remove(value);
    setState(() => _config = _config.copyWith(keyAliasHistory: newHistory));
    await ref.read(apkSigningServiceProvider).saveConfig(_config);
  }

  Future<void> _removePasswordHistory(String value) async {
    final newHistory = List<String>.from(_config.passwordHistory)
      ..remove(value);
    setState(() => _config = _config.copyWith(passwordHistory: newHistory));
    await ref.read(apkSigningServiceProvider).saveConfig(_config);
  }

  Future<void> _addApks(ApkSigningController controller) async {
    final service = ref.read(apkSigningServiceProvider);
    final paths = await service.pickLocalApks();
    if (paths.isEmpty) return;

    final apks = <ApkInfo>[];
    for (final path in paths) {
      final info = await service.extractApkInfo(path);
      apks.add(info);
    }
    controller.addUnsignedApks(apks);
  }

  Future<void> _addProjectApk() async {
    final state = ref.read(fvmControllerProvider);
    final path = await showProjectApkPicker(
      context,
      projects: state.managedProjects,
      initialProjectPath: state.selectedManagedProjectPath,
    );
    if (path == null || !mounted) return;
    try {
      final apk = await ref
          .read(apkSigningServiceProvider)
          .extractApkInfo(path);
      if (!mounted) return;
      ref.read(apkSigningControllerProvider.notifier).addUnsignedApks([apk]);
      setState(() => _selectedApkPaths.add(apk.path));
    } catch (error) {
      if (mounted) ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }

  Future<void> _signSelected(ApkSigningController controller) async {
    if (_config.jksPath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择 JKS 密钥库文件')));
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入密码')));
      return;
    }
    if (_keyAliasController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 Key Alias')));
      return;
    }

    await _saveConfig();
    await controller.signSelectedApks(
      jksPath: _config.jksPath,
      password: _passwordController.text,
      keyAlias: _keyAliasController.text,
      outputDir: _config.outputDirectory,
      outputNamePrefix: _outputNamePrefixController.text,
      outputNameSuffix: _outputNameSuffixController.text,
      selectedPaths: _selectedApkPaths.toList(),
      chooseSourceHandling: (count) => mounted
          ? confirmSigningSourceHandling(context, ref, count)
          : Future.value(false),
    );
    if (mounted) setState(() => _selectedApkPaths.clear());
  }

  Future<void> _openSignedOutputDir() async {
    try {
      final dir = Directory(_config.outputDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await const ExternalOpener().openDirectory(
        dir.path,
        description: '签名输出目录',
      );
    } catch (error) {
      if (mounted) ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }

  Future<void> _revealFile(String path) async {
    if (path.isEmpty) return;
    try {
      await const ExternalOpener().revealFile(path);
    } catch (error) {
      if (mounted) ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }
}

class _OutputNameField extends StatefulWidget {
  const _OutputNameField({
    required this.path,
    required this.value,
    required this.onChanged,
  });

  final String path;
  final String value;
  final void Function(String path, String value) onChanged;

  @override
  State<_OutputNameField> createState() => _OutputNameFieldState();
}

class _OutputNameFieldState extends State<_OutputNameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _OutputNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: '替换原文件名（可选）',
          hintStyle: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (value) => widget.onChanged(widget.path, value),
      ),
    );
  }
}
