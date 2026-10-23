part of '../home_page.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state, required this.page});
  final FvmState state;
  final int page;

  String get _pageTitle => switch (page) {
    0 => '概览',
    1 => '环境诊断',
    2 => 'Flutter 版本',
    3 => '项目管理',
    4 => '产物中心',
    5 => 'APK 签名',
    6 => '应用签名',
    8 => '环境配置',
    9 => 'MCP 服务',
    10 => '设置',
    11 => 'APK 安装',
    12 => '请我喝个茶',
    _ => '日志',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 56,
    padding: AppSpacing.pagePaddingHorizontal,
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      border: Border(bottom: BorderSide(color: AppPalette.of(context).border)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.code,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '工作台  /  ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(text: _pageTitle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Tooltip(
          message: state.fvmInstalled ? 'FVM 已就绪' : '请先安装 FVM',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: state.fvmInstalled
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      state.fvmInstalled
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: state.fvmInstalled
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.tertiary,
                      size: 16,
                    ),
                    if (state.hasFvmUpdate)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: _UpdateDot(
                          key: const ValueKey('fvm-update-dot-top'),
                          onTap: ref
                              .read(fvmControllerProvider.notifier)
                              .ignoreFvmUpdate,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  state.fvmInstalled ? 'FVM ${state.fvmVersion}' : '未安装 FVM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: state.fvmInstalled
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<ThemeMode>(
          key: const ValueKey('quick-theme-menu'),
          tooltip: '切换主题',
          initialValue: ref.watch(appThemeModeProvider),
          icon: Icon(switch (ref.watch(appThemeModeProvider)) {
            ThemeMode.system => Icons.brightness_auto_outlined,
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
          }, size: 20),
          onSelected: (mode) async {
            try {
              await ref.read(appThemeModeProvider.notifier).setMode(mode);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('无法保存主题设置：$error')));
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
            PopupMenuItem(value: ThemeMode.light, child: Text('浅色')),
            PopupMenuItem(value: ThemeMode.dark, child: Text('深色')),
          ],
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: state.loading
              ? null
              : ref.read(fvmControllerProvider.notifier).initialize,
          icon: state.loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}
