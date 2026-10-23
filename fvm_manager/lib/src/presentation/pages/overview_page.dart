part of '../home_page.dart';

class _Overview extends ConsumerWidget {
  const _Overview({required this.state, required this.onNavigate});
  final FvmState state;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
    primary: false,
    padding: AppSpacing.pagePadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkbenchPageHeader(
          title: '概览',
          subtitle: '开发环境一目了然，从这里开始高效工作。',
          breakpoint: 700,
          actions: [
            OutlinedButton.icon(
              onPressed: state.fvmInstalled
                  ? ref.read(fvmControllerProvider.notifier).openFvmDirectory
                  : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('打开 FVM 目录'),
            ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 780
                ? 3
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
            final metrics = <Widget>[
              _MetricCard(
                title: 'FVM 版本',
                value: state.fvmVersion ?? '未安装',
                subtitle: '最新：${state.latestFvmVersion ?? '检查中'}',
                icon: Icons.hub_outlined,
                onTap: () => onNavigate(8),
              ),
              _MetricCard(
                title: '当前全局版本',
                value: state.globalVersion ?? '未设置',
                icon: Icons.public,
                accent: Theme.of(context).colorScheme.secondary,
                onTap: () => onNavigate(2),
              ),
              _MetricCard(
                title: '已安装 SDK',
                value: '${state.installed.length}',
                icon: Icons.inventory_2_outlined,
                accent: Theme.of(context).colorScheme.tertiary,
                onTap: () => onNavigate(2),
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var index = 0; index < metrics.length; index++)
                  SizedBox(
                    key: ValueKey('overview-metric-$index'),
                    width: columns == 2 && index == metrics.length - 1
                        ? constraints.maxWidth
                        : width,
                    child: metrics[index],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!state.fvmInstalled)
          WorkbenchSection(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
          WorkbenchSplitSections(
            equalHeight: true,
            leading: _FvmUpdateSection(state: state),
            trailing: _FvmCacheCard(state: state),
          ),
        if (state.installed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const WorkbenchSectionHeading(
            title: '已安装版本',
            icon: Icons.layers_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          WorkbenchSection(
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

class _FvmUpdateSection extends ConsumerWidget {
  const _FvmUpdateSection({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final currentVersion = state.fvmVersion?.trim();
    final latestVersion = state.latestFvmVersion?.trim();
    final sameVersion =
        currentVersion != null &&
        currentVersion.isNotEmpty &&
        currentVersion == latestVersion;
    return WorkbenchSection(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WorkbenchSectionHeading(
                  title: 'FVM 更新',
                  icon: Icons.system_update_alt,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text('当前版本：${state.fvmVersion ?? '-'}'),
                    Text('最新版本：${state.latestFvmVersion ?? '检查中'}'),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: state.loading
                        ? null
                        : () {
                            if (sameVersion) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('FVM 已是最新版'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              return;
                            }
                            controller.updateFvm();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                    ),
                    icon: Icon(
                      sameVersion
                          ? Icons.check_circle_outline
                          : Icons.system_update_alt,
                    ),
                    label: Text(sameVersion ? '已是最新版' : '更新 FVM'),
                  ),
                  if (state.hasFvmUpdate)
                    TextButton.icon(
                      onPressed: controller.ignoreFvmUpdate,
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('忽略此次更新'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FvmCacheCard extends ConsumerWidget {
  const _FvmCacheCard({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    return WorkbenchSection(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkbenchSectionHeading(
                  title: 'FVM 缓存',
                  icon: Icons.cleaning_services_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                  trailing: IconButton(
                    tooltip: '刷新大小',
                    onPressed: state.fvmCacheLoading
                        ? null
                        : controller.refreshFvmCacheSize,
                    icon: state.fvmCacheLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '当前缓存：${state.fvmCacheLoading ? '计算中…' : _Overview._formatBytes(state.fvmCacheSizeBytes)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'SDK bin/cache',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  OutlinedButton.icon(
                    onPressed: state.fvmInstalled
                        ? controller.openFvmDirectory
                        : null,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('打开 FVM 目录'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: state.fvmCacheClearing
                        ? null
                        : () => _confirmClearCache(context, controller),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onTertiaryContainer,
                    ),
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
    this.onTap,
    this.accent,
  });
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 128),
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        hoverColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .07),
        focusColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .12),
        child: Ink(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              (accent ?? Theme.of(context).colorScheme.primary).withValues(
                alpha: .07,
              ),
              Theme.of(context).colorScheme.surface,
            ),
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: (accent ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: .25),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl - 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (accent ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accent ?? Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
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
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 24,
                        color: accent ?? Theme.of(context).colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle ?? ' ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
