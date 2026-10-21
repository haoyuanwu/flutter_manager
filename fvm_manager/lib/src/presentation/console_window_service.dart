import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

class ConsoleWindowService {
  ConsoleWindowService._();

  static final instance = ConsoleWindowService._();

  static const _commandChannel = WindowMethodChannel(
    'fvm_manager/console_commands',
    mode: ChannelMode.unidirectional,
  );

  final Map<String, WindowController> _windows = {};
  final Map<String, String> _actionChannelNames = {};
  final Map<String, WindowMethodChannel> _actionChannels = {};
  final Map<String, Map<String, dynamic>> _latestPayloads = {};
  final Map<String, Map<String, dynamic>> _pendingSync = {};
  final Set<String> _syncingProjects = {};
  final Map<String, Completer<void>> _readySignals = {};
  Future<dynamic> Function(MethodCall call)? _mainHandler;
  bool _mainHandlerRegistered = false;

  Future<void> registerMainHandler(
    Future<dynamic> Function(MethodCall call) handler,
  ) async {
    _mainHandler = handler;
    if (_mainHandlerRegistered) return;
    await _commandChannel.setMethodCallHandler(handler);
    _mainHandlerRegistered = true;
  }

  Future<void> openOrFocus({
    required String windowKey,
    required String projectPath,
    required String projectTitle,
    required String commandLog,
    required List<Map<String, String>> tasks,
    required bool showQuickCommands,
    required String consoleMode,
    required String buildTarget,
  }) async {
    final actionChannelName = await _actionChannelNameFor(windowKey);
    final payload = _payload(
      projectPath: projectPath,
      projectTitle: projectTitle,
      commandLog: commandLog,
      tasks: tasks,
      showQuickCommands: showQuickCommands,
      consoleMode: consoleMode,
      buildTarget: buildTarget,
      actionChannelName: actionChannelName,
    );
    _latestPayloads[windowKey] = payload;
    final existing = _windows[windowKey];
    if (existing != null) {
      try {
        await existing.show();
        await existing.invokeMethod<void>('consoleSync', payload);
        return;
      } on Object {
        _windows.remove(windowKey);
      }
    }

    final ready = Completer<void>();
    _readySignals[windowKey] = ready;
    try {
      final window = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode(payload),
          hiddenAtLaunch: true,
        ),
      );
      _windows[windowKey] = window;
      try {
        await ready.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Still show the window if a plugin delays the ready handshake.
      }
      await window.show();
      await _syncWhenReady(windowKey, window);
    } finally {
      if (identical(_readySignals[windowKey], ready)) {
        _readySignals.remove(windowKey);
      }
    }
  }

  Future<void> sync({
    required String windowKey,
    required String projectPath,
    required String projectTitle,
    required String commandLog,
    required List<Map<String, String>> tasks,
    required bool showQuickCommands,
    required String consoleMode,
    required String buildTarget,
  }) async {
    final actionChannelName = await _actionChannelNameFor(windowKey);
    final payload = _payload(
      projectPath: projectPath,
      projectTitle: projectTitle,
      commandLog: commandLog,
      tasks: tasks,
      showQuickCommands: showQuickCommands,
      consoleMode: consoleMode,
      buildTarget: buildTarget,
      actionChannelName: actionChannelName,
    );
    _latestPayloads[windowKey] = payload;
    _pendingSync[windowKey] = payload;
    if (!_syncingProjects.add(windowKey)) return;
    try {
      while (_pendingSync.containsKey(windowKey)) {
        final payload = _pendingSync.remove(windowKey)!;
        final window = _windows[windowKey];
        if (window == null) return;
        try {
          await window.invokeMethod<void>('consoleSync', payload);
        } on Object {
          return;
        }
      }
    } finally {
      _syncingProjects.remove(windowKey);
    }
  }

  bool isTracking(String windowKey) => _latestPayloads.containsKey(windowKey);

  Future<void> _syncWhenReady(String windowKey, WindowController window) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!identical(_windows[windowKey], window)) return;
      final payload = _latestPayloads[windowKey];
      if (payload == null) return;
      try {
        await window.invokeMethod<void>('consoleSync', payload);
        return;
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (identical(_windows[windowKey], window)) {
      _windows.remove(windowKey);
    }
  }

  Future<void> requestStop(String taskId) =>
      _commandChannel.invokeMethod<void>('stopCommand', {'taskId': taskId});

  Future<void> requestStopOn(String channelName, String taskId) =>
      _actionChannel(
        channelName,
      ).invokeMethod<void>('stopCommand', {'taskId': taskId});

  Future<void> requestClear(String projectPath) => _commandChannel
      .invokeMethod<void>('clearCommandLog', {'projectPath': projectPath});

  Future<void> requestClearOn(String channelName, String projectPath) =>
      _actionChannel(
        channelName,
      ).invokeMethod<void>('clearCommandLog', {'projectPath': projectPath});

  Future<void> close(String windowKey) async {
    final window = _windows.remove(windowKey);
    _latestPayloads.remove(windowKey);
    _pendingSync.remove(windowKey);
    _readySignals.remove(windowKey);
    final actionChannelName = _actionChannelNames.remove(windowKey);
    if (actionChannelName != null) {
      final actionChannel = _actionChannels.remove(actionChannelName);
      unawaited(actionChannel?.setMethodCallHandler(null));
    }
    if (window == null) return;
    try {
      await window.hide();
    } on Object {
      // Window may already be closed by the user.
    }
  }

  Future<void> requestAction(String projectPath, String action) =>
      _commandChannel.invokeMethod<void>('runProjectAction', {
        'projectPath': projectPath,
        'action': action,
      });

  Future<Map<dynamic, dynamic>> requestStartupLock(
    String channelName,
    String projectPath, {
    Map<String, dynamic>? report,
    bool force = false,
  }) async {
    final channel = channelName == 'fvm_manager/console_commands'
        ? _commandChannel
        : _actionChannel(channelName);
    final result = await channel.invokeMethod<dynamic>(
      report == null ? 'inspectStartupLock' : 'stopStartupLock',
      {'projectPath': projectPath, 'report': ?report, 'force': force},
    );
    return result as Map<dynamic, dynamic>;
  }

  Future<void> requestActionOn(
    String channelName,
    String projectPath,
    String action,
  ) => _actionChannel(channelName).invokeMethod<void>('runProjectAction', {
    'projectPath': projectPath,
    'action': action,
  });

  Future<void> notifyReady(String projectPath) => _commandChannel
      .invokeMethod<void>('consoleReady', {'projectPath': projectPath});

  Future<void> notifyReadyOn(String channelName, String projectPath) =>
      _actionChannel(
        channelName,
      ).invokeMethod<void>('consoleReady', {'projectPath': projectPath});

  void markReady(String projectPath) {
    final signal = _readySignals[projectPath];
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  Future<String> _ensureActionChannel(String windowKey) async {
    final existing = _actionChannelNames[windowKey];
    if (existing != null) return existing;
    final handler = _mainHandler;
    final channelName =
        'fvm_manager/console_commands/${DateTime.now().microsecondsSinceEpoch}';
    _actionChannelNames[windowKey] = channelName;
    if (handler != null) {
      final channel = _actionChannel(channelName);
      await channel.setMethodCallHandler(handler);
    }
    return channelName;
  }

  Future<String> _actionChannelNameFor(String windowKey) {
    if (!Platform.isWindows) {
      return Future.value('fvm_manager/console_commands');
    }
    return _ensureActionChannel(windowKey);
  }

  WindowMethodChannel _actionChannel(String channelName) =>
      _actionChannels.putIfAbsent(
        channelName,
        () =>
            WindowMethodChannel(channelName, mode: ChannelMode.unidirectional),
      );

  Map<String, dynamic> _payload({
    required String projectPath,
    required String projectTitle,
    required String commandLog,
    required List<Map<String, String>> tasks,
    required bool showQuickCommands,
    required String consoleMode,
    required String buildTarget,
    required String actionChannelName,
  }) => {
    'windowType': 'console',
    'projectPath': projectPath,
    'projectTitle': projectTitle,
    'commandLog': commandLog,
    'tasks': tasks,
    'showQuickCommands': showQuickCommands,
    'consoleMode': consoleMode,
    'buildTarget': buildTarget,
    'actionChannelName': actionChannelName,
  };
}
