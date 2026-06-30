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
      color: const Color(0xffeef7fb),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.downloading, size: 17, color: Color(0xff087ea4)),
              const SizedBox(width: 7),
              Text(
                'Flutter ${state.activeVersion} · ${state.downloadPhase}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            total > 0
                ? '${_formatBytes(received)} / ${_formatBytes(total)}'
                : _formatBytes(received),
          ),
          if (speed > 0) Text('${_formatBytes(speed.round())}/s'),
          if (remainingSeconds != null)
            Text('预计剩余 ${_formatDuration(remainingSeconds)}'),
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
  const _MessageBar({required this.message, this.error = false});
  final String message;
  final bool error;

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
    // 清除 state 中的消息
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
    return Container(
      width: double.infinity,
      color: widget.error ? Colors.red.shade50 : Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.error
                    ? Colors.red.shade800
                    : Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _dismiss,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: widget.error
                    ? Colors.red.shade600
                    : Colors.blue.shade600,
              ),
            ),
          ),
        ],
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
        color: Color(0xfff04438),
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
