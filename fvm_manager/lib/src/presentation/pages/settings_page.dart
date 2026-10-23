part of '../home_page.dart';

class _SettingsPage extends ConsumerStatefulWidget {
  const _SettingsPage({required this.state, this.highlightSigning = false});

  final FvmState state;
  final bool highlightSigning;

  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  final _signingKey = GlobalKey();
  Timer? _highlightTimer;
  bool _highlight = false;
  late final TextEditingController _pgyerApiKeyController;
  late final TextEditingController _firApiTokenController;

  @override
  void initState() {
    super.initState();
    _highlight = widget.highlightSigning;
    if (_highlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _signingKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: .15,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
        }
        _highlightTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _highlight = false);
        });
      });
    }
    final env = ref.read(pubEnvironmentServiceProvider);
    _pgyerApiKeyController = TextEditingController(text: env.globalPgyerApiKey);
    _firApiTokenController = TextEditingController(text: env.globalFirApiToken);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _pgyerApiKeyController.dispose();
    _firApiTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveSigningPreference({
    bool? rememberChoice,
    bool? replaceSource,
  }) async {
    try {
      await ref
          .read(signingPreferencesProvider.notifier)
          .update(rememberChoice: rememberChoice, replaceSource: replaceSource);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法保存签名设置：$error')));
      }
    }
  }

  Widget _buildSigningPreferences() {
    final preference = ref.watch(signingPreferencesProvider);
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: _signingKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WorkbenchSectionHeading(
          title: 'APK 签名',
          icon: Icons.key_outlined,
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          key: const ValueKey('signing-source-preferences-highlight'),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _highlight ? colors.primaryContainer : colors.surface,
            border: Border.all(
              color: _highlight ? colors.primary : colors.outlineVariant,
              width: 1,
            ),
            borderRadius: AppRadius.lgAll,
          ),
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('签名后的源文件处理', style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Text(
                  '保留：签名包保存到输出目录。覆盖：替换源 APK，自动保存 .bak 备份。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    key: const ValueKey('signing-source-default-choice'),
                    segments: const [
                      ButtonSegment(value: false, label: Text('保留原文件')),
                      ButtonSegment(value: true, label: Text('覆盖源文件')),
                    ],
                    selected: {preference.replaceSource},
                    onSelectionChanged: (value) =>
                        _saveSigningPreference(replaceSource: value.single),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('signing-source-remember-setting'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('以后不再提示，使用以上选择'),
                  subtitle: const Text('取消勾选后，签名成功时会再次询问。'),
                  value: preference.rememberChoice,
                  onChanged: (value) =>
                      _saveSigningPreference(rememberChoice: value ?? false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    return WorkbenchScrollPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkbenchPageHeader(title: '设置'),
          const SizedBox(height: 20),
          const WorkbenchSectionHeading(
            title: '外观',
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 12),
          WorkbenchSection(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final selection = SegmentedButton<ThemeMode>(
                    key: const ValueKey('theme-mode-selector'),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('跟随系统'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('深色'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (value) async {
                      try {
                        await ref
                            .read(appThemeModeProvider.notifier)
                            .setMode(value.single);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('无法保存主题设置：$error')),
                          );
                        }
                      }
                    },
                  );
                  return Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const SizedBox(
                        width: 180,
                        child: Row(
                          children: [
                            Icon(Icons.palette_outlined),
                            SizedBox(width: 16),
                            Text('应用主题', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      selection,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSigningPreferences(),
          const SizedBox(height: 24),
          const WorkbenchSectionHeading(
            title: '窗口与控制台',
            icon: Icons.terminal_outlined,
          ),
          const SizedBox(height: 12),
          WorkbenchSection(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.open_in_new),
                  title: const Text('运行时自动打开独立控制台'),
                  subtitle: const Text('执行 Flutter Run 时，自动显示对应项目的运行控制台。'),
                  value: widget.state.autoOpenConsoleWindow,
                  onChanged: controller.setAutoOpenConsoleWindow,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.inventory_2_outlined),
                  title: const Text('构建时打开独立控制台'),
                  subtitle: const Text('默认关闭；关闭时构建输出显示在项目详情的主窗口打印台。'),
                  value: widget.state.buildOpensConsoleWindow,
                  onChanged: controller.setBuildOpensConsoleWindow,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.terminal),
                  title: const Text('在主窗口显示打印台'),
                  subtitle: const Text('默认关闭；开启后项目详情底部也会显示同步的命令输出。'),
                  value: widget.state.showMainWindowConsole,
                  onChanged: controller.setShowMainWindowConsole,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt_outlined),
                  title: const Text('控制台窗口显示常用命令'),
                  subtitle: const Text(
                    '在运行控制台显示 Run、热重载、热重启、Rerun 和 DevTools。',
                  ),
                  value: widget.state.showConsoleQuickCommands,
                  onChanged: controller.setShowConsoleQuickCommands,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          WorkbenchSectionHeading(
            title: '分发平台配置',
            icon: Icons.cloud_upload_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 6),
          Text(
            '配置全局的分发平台 API Key，所有项目共享。项目中配置的 Key 优先级更高。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          WorkbenchSection(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: WorkbenchSplitSections(
                breakpoint: 840,
                leading: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _pgyerApiKeyController,
                      decoration: InputDecoration(
                        labelText: '蒲公英 API Key',
                        hintText: '在蒲公英官网获取',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.cloud_upload_outlined),
                        suffixIcon: IconButton(
                          tooltip: '如何获取蒲公英 API Key',
                          onPressed: () => _showPgyerApiKeyHelp(context, ref),
                          icon: const Icon(Icons.help_outline),
                        ),
                      ),
                      onSubmitted: (value) => _savePgyerApiKey(value.trim()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _savePgyerApiKey(
                          _pgyerApiKeyController.text.trim(),
                        ),
                        child: const Text('保存蒲公英 Key'),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _firApiTokenController,
                      decoration: InputDecoration(
                        labelText: 'fir.im API Token',
                        hintText: '在 fir.im 个人设置中获取',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.rocket_launch_outlined),
                        suffixIcon: IconButton(
                          tooltip: '如何获取 fir.im API Token',
                          onPressed: () => _showFirApiTokenHelp(context, ref),
                          icon: const Icon(Icons.help_outline),
                        ),
                      ),
                      onSubmitted: (value) => _saveFirApiToken(value.trim()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _saveFirApiToken(
                          _firApiTokenController.text.trim(),
                        ),
                        child: const Text('保存 fir.im Token'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const WorkbenchSectionHeading(
            title: '应用信息',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 12),
          WorkbenchSection(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: packageInfoAsync.when(
                data: (packageInfo) => Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: const Text('版本号'),
                        subtitle: Text(packageInfo.version),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build_outlined),
                        title: const Text('版本编码'),
                        subtitle: Text(packageInfo.buildNumber),
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('无法获取应用信息: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePgyerApiKey(String apiKey) async {
    await ref.read(fvmControllerProvider.notifier).setGlobalPgyerApiKey(apiKey);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('蒲公英 API Key 已保存')));
    }
  }

  Future<void> _saveFirApiToken(String apiToken) async {
    await ref
        .read(fvmControllerProvider.notifier)
        .setGlobalFirApiToken(apiToken);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('fir.im API Token 已保存')));
    }
  }
}
