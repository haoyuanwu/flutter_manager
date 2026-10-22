import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WindowAppearance extends StatefulWidget {
  const WindowAppearance({super.key, required this.mode, required this.child});
  final ThemeMode mode;
  final Widget child;

  @override
  State<WindowAppearance> createState() => _WindowAppearanceState();
}

class _WindowAppearanceState extends State<WindowAppearance> {
  static const _channel = MethodChannel('fvm_manager/appearance');
  Brightness? _brightness;
  ThemeMode? _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WindowAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final brightness = Theme.of(context).brightness;
    if (_brightness == brightness && _mode == widget.mode) return;
    _brightness = brightness;
    _mode = widget.mode;
    unawaited(_apply(brightness, widget.mode));
  }

  Future<void> _apply(Brightness brightness, ThemeMode mode) async {
    try {
      await _channel.invokeMethod<void>('setTheme', {
        'mode': mode.name,
        'dark': brightness == Brightness.dark,
      });
    } on MissingPluginException {
      // Native chrome is optional on non-desktop hosts and in widget tests.
    } on PlatformException {
      // Older Windows versions may not support dark title bars.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
