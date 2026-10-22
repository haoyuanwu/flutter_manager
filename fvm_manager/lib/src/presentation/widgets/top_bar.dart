part of '../home_page.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});
  final FvmState state;

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
        const Icon(Icons.code, size: 19),
        const SizedBox(width: 8),
        const Text(
          'Flutter 工作台',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
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
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(width: AppSpacing.lg),
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
