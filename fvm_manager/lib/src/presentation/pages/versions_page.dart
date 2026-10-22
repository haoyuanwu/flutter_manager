part of '../home_page.dart';

class _Versions extends ConsumerWidget {
  const _Versions({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final channelReleases = state.releases
        .where((item) => item.channel == state.selectedChannel)
        .toList();
    final releases = channelReleases.take(state.releaseDisplayLimit).toList();
    final hasMore = releases.length < channelReleases.length;
    final installedNames = state.installed
        .expand((sdk) => [sdk.name, sdk.flutterVersion])
        .toSet();
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkbenchPageHeader(
            title: 'Flutter 版本',
            breakpoint: 1000,
            actions: [
              if (state.hasFlutterUpdate) ...[
                _UpdateDot(onTap: controller.ignoreFlutterUpdate),
                Text(
                  'Stable ${state.latestFlutterVersion}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                TextButton(
                  onPressed: controller.ignoreFlutterUpdate,
                  child: const Text('忽略'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: state.fvmInstalled
                    ? controller.openFvmDirectory
                    : null,
                icon: const Icon(Icons.folder_open),
                label: const Text('FVM 目录'),
              ),
              OutlinedButton.icon(
                onPressed: state.globalVersion != null
                    ? controller.openGlobalFlutterDirectory
                    : null,
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('Flutter 目录'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SegmentedButton<ReleaseChannel>(
            segments: const [
              ButtonSegment(
                value: ReleaseChannel.stable,
                label: Text('稳定版 Stable'),
              ),
              ButtonSegment(
                value: ReleaseChannel.beta,
                label: Text('测试版 Beta'),
              ),
              ButtonSegment(value: ReleaseChannel.dev, label: Text('开发版 Dev')),
            ],
            selected: {state.selectedChannel},
            onSelectionChanged: (value) =>
                controller.selectChannel(value.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: WorkbenchPanel(
              child: releases.isEmpty
                  ? const Center(child: Text('该通道暂无可用版本'))
                  : ListView.separated(
                      itemCount: releases.length + (hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == releases.length) {
                          final remaining =
                              channelReleases.length - releases.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed: controller.loadMoreReleases,
                                icon: const Icon(Icons.expand_more),
                                label: Text('加载下一页（剩余 $remaining 个版本）'),
                              ),
                            ),
                          );
                        }
                        final release = releases[index];
                        final installed = installedNames.contains(
                          release.version,
                        );
                        final installedSdk = state.installed
                            .where(
                              (sdk) =>
                                  sdk.name == release.version ||
                                  sdk.flutterVersion == release.version,
                            )
                            .firstOrNull;
                        final downloading =
                            state.activeVersion == release.version;
                        final isGlobal =
                            installedSdk != null &&
                            state.globalVersion == installedSdk.name;
                        final removing =
                            installedSdk != null &&
                            state.removingVersion == installedSdk.name;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          leading: Icon(
                            Icons.flutter_dash,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Flutter ${release.version}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Dart ${release.dartVersion ?? '-'}  ·  ${_date(release.releaseDate)}',
                          ),
                          trailing: downloading
                              ? OutlinedButton.icon(
                                  onPressed: controller.cancelDownload,
                                  icon: const Icon(Icons.close),
                                  label: Text(
                                    '${(state.downloadProgress * 100).round()}% 取消',
                                  ),
                                )
                              : installed
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Chip(label: Text('已安装')),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: '打开 Flutter SDK 目录',
                                      onPressed: installedSdk == null
                                          ? null
                                          : () => controller
                                                .openInstalledFlutterDirectory(
                                                  installedSdk.directory,
                                                ),
                                      icon: const Icon(Icons.folder_open),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton.tonal(
                                      onPressed: isGlobal
                                          ? null
                                          : () => controller.setGlobal(
                                              installedSdk?.name ??
                                                  release.version,
                                            ),
                                      child: Text(isGlobal ? '当前全局' : '设为全局'),
                                    ),
                                    const SizedBox(width: 4),
                                    if (removing)
                                      const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        tooltip: isGlobal
                                            ? '请先切换全局版本'
                                            : '删除此 Flutter 版本',
                                        onPressed:
                                            installedSdk == null ||
                                                isGlobal ||
                                                state.removingVersion != null
                                            ? null
                                            : () => _confirmRemoval(
                                                context,
                                                controller,
                                                installedSdk,
                                              ),
                                        color: Colors.red,
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                  ],
                                )
                              : FilledButton.icon(
                                  onPressed:
                                      state.fvmInstalled &&
                                          state.activeVersion == null
                                      ? () => controller.download(release)
                                      : null,
                                  icon: const Icon(Icons.download),
                                  label: const Text('下载'),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<void> _confirmRemoval(
    BuildContext context,
    FvmController controller,
    InstalledSdk sdk,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('确认删除 Flutter 版本？'),
        content: Text(
          '将从 FVM 缓存中删除 Flutter ${sdk.flutterVersion}，并释放对应磁盘空间。此操作不可撤销。\n\n${sdk.directory}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeFlutterVersion(sdk);
  }
}

class _InstalledRow extends ConsumerWidget {
  const _InstalledRow({required this.sdk, required this.global});
  final InstalledSdk sdk;
  final bool global;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fvmControllerProvider);
    final controller = ref.read(fvmControllerProvider.notifier);
    return ListTile(
      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
      title: Text('Flutter ${sdk.flutterVersion}'),
      subtitle: Text('Dart ${sdk.dartVersion} · ${sdk.directory}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '打开 Flutter SDK 目录',
            onPressed: () =>
                controller.openInstalledFlutterDirectory(sdk.directory),
            icon: const Icon(Icons.folder_open),
          ),
          const SizedBox(width: 4),
          if (global)
            const Chip(label: Text('当前全局'))
          else ...[
            TextButton(
              onPressed: () => controller.setGlobal(sdk.name),
              child: const Text('设为全局'),
            ),
            if (state.removingVersion == sdk.name)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: '删除此 Flutter 版本',
                onPressed: state.removingVersion == null
                    ? () => _Versions._confirmRemoval(context, controller, sdk)
                    : null,
                color: Colors.red,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ],
      ),
    );
  }
}
