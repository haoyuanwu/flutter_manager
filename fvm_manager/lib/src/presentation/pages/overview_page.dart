part of '../home_page.dart';

class _Overview extends ConsumerWidget {
  const _Overview({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
    padding: AppSpacing.pagePadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('概览', style: AppTextStyles.h1),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: state.fvmInstalled
                  ? ref.read(fvmControllerProvider.notifier).openFvmDirectory
                  : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('打开 FVM 目录'),
            ),
            const SizedBox(width: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
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
            _MetricCard(
              title: 'FVM 缓存',
              value: state.fvmCacheLoading
                  ? '计算中…'
                  : _formatBytes(state.fvmCacheSizeBytes),
              subtitle: 'SDK bin/cache',
              icon: Icons.storage_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!state.fvmInstalled)
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('开始使用 FVM', style: AppTextStyles.h3),
                        SizedBox(height: AppSpacing.xs + 2),
                        Text('通过 Dart Pub 安装 FVM，完成后即可下载和切换 Flutter SDK。'),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
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
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FVM 更新', style: AppTextStyles.h3),
                        const SizedBox(height: AppSpacing.xs + 2),
                        Text('当前版本：${state.fvmVersion ?? '-'}', style: AppTextStyles.bodyMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text('最新版本：${state.latestFvmVersion ?? '检查中'}', style: AppTextStyles.bodyMedium),
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
                    const SizedBox(width: AppSpacing.sm),
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
        if (state.fvmInstalled) ...[
          const SizedBox(height: AppSpacing.lg),
          _FvmCacheCard(state: state),
        ],
        if (state.installed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const Text('已安装版本', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
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

  static String _formatBytes(int? bytes) {
    if (bytes == null) return '未计算';
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }
}

class _FvmCacheCard extends ConsumerWidget {
  const _FvmCacheCard({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.cleaning_services_outlined)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FVM 缓存管理', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    '当前缓存：${_Overview._formatBytes(state.fvmCacheSizeBytes)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                OutlinedButton.icon(
                  onPressed: state.fvmCacheLoading
                      ? null
                      : controller.refreshFvmCacheSize,
                  icon: state.fvmCacheLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('刷新大小'),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.fvmCacheClearing
                      ? null
                      : () => _confirmClearCache(context, controller),
                  icon: state.fvmCacheClearing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined),
                  label: const Text('清理缓存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    FvmController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('确认清理 FVM 缓存？'),
        content: const Text(
          '只会清理每个 Flutter SDK 下的 bin/cache 目录，不会删除 Flutter 版本目录本身。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: AppButtonStyles.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearUnusedFvmCache();
  }
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
    height: 116,
    child: Card(
      child: Container(
        decoration: AppCardStyles.metricDecoration,
        padding: const EdgeInsets.all(AppSpacing.xl - 4),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 16,
                    child: subtitle == null
                        ? const SizedBox.shrink()
                        : Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.captionSmall,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
