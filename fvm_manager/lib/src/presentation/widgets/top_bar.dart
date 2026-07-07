part of '../home_page.dart';

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xffe1e6eb))),
    ),
    child: Row(
      children: [
        const Text(
          'Flutter 管理器',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              state.fvmInstalled
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: state.fvmInstalled ? Colors.green : Colors.orange,
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
        const SizedBox(width: 8),
        Text(state.fvmInstalled ? 'FVM ${state.fvmVersion}' : '未安装 FVM'),
        const SizedBox(width: 16),
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
