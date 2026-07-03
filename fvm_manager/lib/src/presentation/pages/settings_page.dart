part of '../home_page.dart';

class _SettingsPage extends ConsumerStatefulWidget {
  const _SettingsPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  late final TextEditingController _pgyerApiKeyController;
  late final TextEditingController _firApiTokenController;

  @override
  void initState() {
    super.initState();
    final env = ref.read(pubEnvironmentServiceProvider);
    _pgyerApiKeyController = TextEditingController(text: env.globalPgyerApiKey);
    _firApiTokenController = TextEditingController(text: env.globalFirApiToken);
  }

  @override
  void dispose() {
    _pgyerApiKeyController.dispose();
    _firApiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final packageInfoAsync = ref.watch(packageInfoProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '设置',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('配置窗口、打印台和命令操作习惯。'),
          const SizedBox(height: 20),
          Card(
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
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '分发平台配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '配置全局的分发平台 API Key，所有项目共享。项目中配置的 Key 优先级更高。',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pgyerApiKeyController,
                    decoration: const InputDecoration(
                      labelText: '蒲公英 API Key',
                      hintText: '在蒲公英官网获取',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cloud_upload_outlined),
                    ),
                    onSubmitted: (value) => _savePgyerApiKey(value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _savePgyerApiKey(_pgyerApiKeyController.text.trim()),
                      child: const Text('保存蒲公英 Key'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _firApiTokenController,
                    decoration: const InputDecoration(
                      labelText: 'fir.im API Token',
                      hintText: '在 fir.im 个人设置中获取',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.rocket_launch_outlined),
                    ),
                    onSubmitted: (value) => _saveFirApiToken(value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _saveFirApiToken(_firApiTokenController.text.trim()),
                      child: const Text('保存 fir.im Token'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: packageInfoAsync.when(
                data: (packageInfo) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '应用信息',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('版本号'),
                      subtitle: Text(packageInfo.version),
                    ),
                    ListTile(
                      leading: const Icon(Icons.build_outlined),
                      title: const Text('版本编码'),
                      subtitle: Text(packageInfo.buildNumber),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('蒲公英 API Key 已保存')),
      );
    }
  }

  Future<void> _saveFirApiToken(String apiToken) async {
    await ref.read(fvmControllerProvider.notifier).setGlobalFirApiToken(apiToken);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('fir.im API Token 已保存')),
      );
    }
  }
}
