part of '../home_page.dart';

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  value: state.autoOpenConsoleWindow,
                  onChanged: controller.setAutoOpenConsoleWindow,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.inventory_2_outlined),
                  title: const Text('构建时打开独立控制台'),
                  subtitle: const Text('默认关闭；关闭时构建输出显示在项目详情的主窗口打印台。'),
                  value: state.buildOpensConsoleWindow,
                  onChanged: controller.setBuildOpensConsoleWindow,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.terminal),
                  title: const Text('在主窗口显示打印台'),
                  subtitle: const Text('默认关闭；开启后项目详情底部也会显示同步的命令输出。'),
                  value: state.showMainWindowConsole,
                  onChanged: controller.setShowMainWindowConsole,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt_outlined),
                  title: const Text('控制台窗口显示常用命令'),
                  subtitle: const Text(
                    '在运行控制台显示 Run、热重载、热重启、Rerun 和 DevTools。',
                  ),
                  value: state.showConsoleQuickCommands,
                  onChanged: controller.setShowConsoleQuickCommands,
                ),
              ],
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
}
