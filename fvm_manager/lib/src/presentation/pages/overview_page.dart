part of '../home_page.dart';

class _Overview extends ConsumerWidget {
  const _Overview({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '概览',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: state.fvmInstalled
                  ? ref.read(fvmControllerProvider.notifier).openFvmDirectory
                  : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('打开 FVM 目录'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: state.globalVersion != null
                  ? ref
                        .read(fvmControllerProvider.notifier)
                        .openGlobalFlutterDirectory
                  : null,
              icon: const Icon(Icons.folder_copy_outlined),
              label: const Text('打开 Flutter 目录'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              title: 'FVM 版本',
              value: state.fvmVersion ?? '未安装',
              subtitle: '最新：${state.latestFvmVersion ?? '检查中'}',
              icon: Icons.hub_outlined,
            ),
            _MetricCard(
              title: '当前全局版本',
              value: state.globalVersion ?? '未设置',
              icon: Icons.public,
            ),
            _MetricCard(
              title: '已安装 SDK',
              value: '${state.installed.length}',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!state.fvmInstalled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '开始使用 FVM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text('通过 Dart Pub 安装 FVM，完成后即可下载和切换 Flutter SDK。'),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: state.loading
                            ? null
                            : ref
                                  .read(fvmControllerProvider.notifier)
                                  .selectLocalFvmDirectory,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择本地 FVM'),
                      ),
                      FilledButton.icon(
                        onPressed: state.loading
                            ? null
                            : ref
                                  .read(fvmControllerProvider.notifier)
                                  .installFvm,
                        icon: const Icon(Icons.download),
                        label: const Text('安装 FVM'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (state.fvmInstalled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FVM 更新',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('当前版本：${state.fvmVersion ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('最新版本：${state.latestFvmVersion ?? '检查中'}'),
                      ],
                    ),
                  ),
                  if (state.hasFvmUpdate) ...[
                    TextButton.icon(
                      onPressed: ref
                          .read(fvmControllerProvider.notifier)
                          .ignoreFvmUpdate,
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('忽略此次更新'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: state.loading
                        ? null
                        : ref.read(fvmControllerProvider.notifier).updateFvm,
                    icon: const Icon(Icons.system_update_alt),
                    label: const Text('更新 FVM'),
                  ),
                ],
              ),
            ),
          ),
        if (state.installed.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            '已安装版本',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: state.installed
                  .map(
                    (sdk) => _InstalledRow(
                      sdk: sdk,
                      global: sdk.name == state.globalVersion,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
