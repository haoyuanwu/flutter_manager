part of '../home_page.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 72,
    padding: AppSpacing.pagePaddingHorizontal,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        const Text('Flutter 管理器', style: AppTextStyles.h2),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              state.fvmInstalled
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: state.fvmInstalled ? AppColors.success : AppColors.warning,
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
