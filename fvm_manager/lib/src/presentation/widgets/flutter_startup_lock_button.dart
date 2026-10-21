import 'package:flutter/material.dart';

import '../../data/flutter_startup_lock_service.dart';

class FlutterStartupLockButton extends StatefulWidget {
  const FlutterStartupLockButton({
    super.key,
    required this.inspect,
    required this.stop,
    required this.rerun,
    this.compact = false,
    this.visible = true,
  });
  final Future<FlutterLockReport> Function() inspect;
  final Future<FlutterLockReport> Function(FlutterLockReport, bool) stop;
  final Future<void> Function() rerun;
  final bool compact;
  final bool visible;

  @override
  State<FlutterStartupLockButton> createState() =>
      _FlutterStartupLockButtonState();
}

class _FlutterStartupLockButtonState extends State<FlutterStartupLockButton> {
  bool _busy = false;

  Future<bool> _confirm(FlutterLockReport report, {required bool force}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(force ? '占用进程仍未退出，强制结束？' : '检查到 Flutter 启动锁占用'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('当前项目使用的 Flutter SDK：'),
                    SelectableText(report.sdkPath),
                    const SizedBox(height: 16),
                    const Text('占用进程：'),
                    for (final owner in report.owners)
                      SelectableText('PID ${owner.pid} · ${owner.identity}'),
                    const SizedBox(height: 16),
                    Text(
                      force
                          ? '正常停止后仍有进程占用。强制结束会立即中断相关构建、下载或 SDK 更新，可能需要重新执行。'
                          : '可以继续等待其他命令完成，也可以尝试正常停止占用进程。',
                    ),
                    const SizedBox(height: 8),
                    const Text('这可能中断其他共用此 SDK 的项目，不会全局结束所有 Dart 进程，也不会删除锁文件。'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续等待'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(force ? '强制结束并解锁' : '尝试正常停止'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _unlock() async {
    if (_busy) return;
    // Capture callbacks so switching projects while a dialog is open cannot
    // redirect an approved operation or its retry to a different project.
    final inspect = widget.inspect;
    final stop = widget.stop;
    final rerun = widget.rerun;
    setState(() => _busy = true);
    try {
      var report = await inspect();
      if (!mounted) return;
      if (report.owners.isNotEmpty) {
        if (!await _confirm(report, force: false) || !mounted) return;
        report = await stop(report, false);
        if (!mounted) return;
        if (report.owners.isNotEmpty) {
          if (!await _confirm(report, force: true) || !mounted) return;
          report = await stop(report, true);
          if (!mounted) return;
        }
      }
      if (report.owners.isNotEmpty) throw Exception('启动锁仍被占用，请稍后重新检查');
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('当前未检测到启动锁占用'),
          content: const Text('等待中的 Flutter 命令通常会自行继续。若仍卡住，可手动重新运行当前项目。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('完成'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重新运行'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) await rerun();
    } on Object catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('未能解除启动锁'),
          content: SelectableText(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && !_busy) return const SizedBox.shrink();
    final icon = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.lock_open_outlined);
    if (widget.compact) {
      return IconButton(
        tooltip: _busy ? '正在检查或解除启动锁…' : '解除 Flutter 启动锁',
        color: const Color(0xffffc857),
        onPressed: _busy ? null : _unlock,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : _unlock,
      icon: icon,
      label: Text(_busy ? '正在处理启动锁…' : '解除启动锁'),
    );
  }
}
