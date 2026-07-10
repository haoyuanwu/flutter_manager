part of '../home_page.dart';

class _DownloadStatusBar extends StatelessWidget {
  const _DownloadStatusBar({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context) {
    final total = state.downloadTotalBytes;
    final received = state.downloadReceivedBytes;
    final speed = state.downloadBytesPerSecond;
    final remainingSeconds = total > received && speed > 0
        ? ((total - received) / speed).round()
        : null;
    return Container(
      width: double.infinity,
      color: AppColors.downloadBackground,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.lg + 2,
        runSpacing: AppSpacing.xs + 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.downloading, size: 17, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(
                'Flutter ${state.activeVersion} · ${state.downloadPhase}',
                style: AppTextStyles.label,
              ),
            ],
          ),
          Text(
            total > 0
                ? '${_formatBytes(received)} / ${_formatBytes(total)}'
                : _formatBytes(received),
            style: AppTextStyles.bodySmall,
          ),
          if (speed > 0)
            Text('${_formatBytes(speed.round())}/s', style: AppTextStyles.bodySmall),
          if (remainingSeconds != null)
            Text('预计剩余 ${_formatDuration(remainingSeconds)}', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes < 60) {
      return '$minutes 分 ${rest.toString().padLeft(2, '0')} 秒';
    }
    final hours = minutes ~/ 60;
    return '$hours 小时 ${minutes % 60} 分';
  }
}

class _MessageBar extends ConsumerStatefulWidget {
  const _MessageBar({
    super.key,
    required this.message,
    this.error = false,
    this.onDiagnosticsTap,
  });
  final String message;
  final bool error;
  final VoidCallback? onDiagnosticsTap;

  @override
  ConsumerState<_MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends ConsumerState<_MessageBar> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _startAutoDismiss();
  }

  @override
  void didUpdateWidget(_MessageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _visible = true;
      _timer?.cancel();
      _startAutoDismiss();
    }
  }

  void _startAutoDismiss() {
    _timer = Timer(
      widget.error ? const Duration(seconds: 8) : const Duration(seconds: 4),
      () {
        if (mounted) _dismiss();
      },
    );
  }

  void _dismiss() {
    setState(() => _visible = false);
    _timer?.cancel();
    Future.microtask(() {
      final controller = ref.read(fvmControllerProvider.notifier);
      if (widget.error) {
        controller.clearError();
      } else {
        controller.clearStatus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final foreground = widget.error
        ? AppColors.messageErrorText
        : AppColors.messageSuccessText;
    final showDiagnosticsAction =
        widget.error && widget.onDiagnosticsTap != null;
    return TweenAnimationBuilder<double>(
      duration: AppAnimations.normal,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -8 * (1 - value)),
          child: child,
        ),
      ),
      child: Material(
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        color: widget.error
            ? AppColors.messageErrorBackground
            : AppColors.messageSuccessBackground,
        borderRadius: AppRadius.mdAll,
        child: Container(
          width: 460,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md + 1, AppSpacing.md, AppSpacing.md + 1),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.error
                  ? AppColors.messageErrorBorder
                  : AppColors.messageSuccessBorder,
            ),
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            children: [
              Icon(
                widget.error ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(color: foreground, height: 1.35),
                ),
              ),
              if (showDiagnosticsAction) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () {
                    widget.onDiagnosticsTap?.call();
                    _dismiss();
                  },
                  icon: const Icon(Icons.health_and_safety_outlined, size: 16),
                  label: const Text('环境诊断'),
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: _dismiss,
                borderRadius: AppRadius.fullAll,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(Icons.close, size: 16, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateDot extends StatelessWidget {
  const _UpdateDot({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const dot = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 9),
    );
    if (onTap == null) return dot;
    return Tooltip(
      message: '忽略此次更新',
      child: InkResponse(
        onTap: onTap,
        radius: 12,
        child: const Padding(padding: EdgeInsets.all(4), child: dot),
      ),
    );
  }
}
