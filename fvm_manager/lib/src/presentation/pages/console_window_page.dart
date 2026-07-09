import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../confirm_dialog.dart';
import '../console_window_service.dart';

class ConsoleWindowApp extends StatelessWidget {
  const ConsoleWindowApp({
    super.key,
    required this.windowId,
    required this.projectTitle,
    required this.projectPath,
    required this.initialCommandLog,
    required this.initialTasks,
    required this.initialShowQuickCommands,
    required this.initialConsoleMode,
    required this.initialBuildTarget,
    required this.initialActionChannelName,
  });

  final String windowId;
  final String projectTitle;
  final String projectPath;
  final String initialCommandLog;
  final List<Map<String, String>> initialTasks;
  final bool initialShowQuickCommands;
  final String initialConsoleMode;
  final String initialBuildTarget;
  final String initialActionChannelName;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '$projectTitle - 控制台',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087ea4)),
      useMaterial3: true,
    ),
    home: ConsoleWindowPage(
      projectTitle: projectTitle,
      projectPath: projectPath,
      initialCommandLog: initialCommandLog,
      initialTasks: initialTasks,
      initialShowQuickCommands: initialShowQuickCommands,
      initialConsoleMode: initialConsoleMode,
      initialBuildTarget: initialBuildTarget,
      initialActionChannelName: initialActionChannelName,
    ),
  );
}

class ConsoleWindowPage extends StatefulWidget {
  const ConsoleWindowPage({
    super.key,
    required this.projectTitle,
    required this.projectPath,
    required this.initialCommandLog,
    required this.initialTasks,
    required this.initialShowQuickCommands,
    required this.initialConsoleMode,
    required this.initialBuildTarget,
    required this.initialActionChannelName,
  });

  final String projectTitle;
  final String projectPath;
  final String initialCommandLog;
  final List<Map<String, String>> initialTasks;
  final bool initialShowQuickCommands;
  final String initialConsoleMode;
  final String initialBuildTarget;
  final String initialActionChannelName;

  @override
  State<ConsoleWindowPage> createState() => _ConsoleWindowPageState();
}

class _ConsoleWindowPageState extends State<ConsoleWindowPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late String _projectTitle;
  late String _commandLog;
  late List<Map<String, String>> _tasks;
  late bool _showQuickCommands;
  late String _consoleMode;
  late String _buildTarget;
  late String _actionChannelName;
  bool _showSearch = false;
  bool _stickToBottom = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _projectTitle = widget.projectTitle;
    _commandLog = widget.initialCommandLog;
    _tasks = widget.initialTasks;
    _showQuickCommands = widget.initialShowQuickCommands;
    _consoleMode = widget.initialConsoleMode;
    _buildTarget = widget.initialBuildTarget;
    _actionChannelName = widget.initialActionChannelName;
    _scrollController.addListener(_handleScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _registerChannel();
    _scrollToBottom();
  }

  Future<void> _registerChannel() async {
    final controller = await WindowController.fromCurrentEngine();
    await controller.setWindowMethodHandler((call) async {
      if (call.method != 'consoleSync' || !mounted) return;
      final data = call.arguments as Map<dynamic, dynamic>? ?? const {};
      final tasks = (data['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (task) => task.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
          .toList(growable: false);
      setState(() {
        _projectTitle = data['projectTitle'] as String? ?? _projectTitle;
        _commandLog = data['commandLog'] as String? ?? _commandLog;
        _tasks = tasks;
        _showQuickCommands =
            data['showQuickCommands'] as bool? ?? _showQuickCommands;
        _consoleMode = data['consoleMode'] as String? ?? _consoleMode;
        _buildTarget = data['buildTarget'] as String? ?? _buildTarget;
        _actionChannelName =
            data['actionChannelName'] as String? ?? _actionChannelName;
      });
      if (_stickToBottom) _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_notifyReady());
    });
  }

  Future<void> _notifyReady() async {
    try {
      await _request(
        onGlobal: () =>
            ConsoleWindowService.instance.notifyReady(widget.projectPath),
        onChannel: () => ConsoleWindowService.instance.notifyReadyOn(
          _actionChannelName,
          widget.projectPath,
        ),
      );
    } on Object {
      // The main window has a timeout fallback if the handshake is delayed.
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        (keyboard.isMetaPressed || keyboard.isControlPressed)) {
      setState(() => _showSearch = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
      return true;
    }
    return false;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _stickToBottom = position.maxScrollExtent - position.pixels <= 24;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  bool _taskActive(String kind) =>
      _tasks.any((task) => (task['id'] ?? '').startsWith('$kind:'));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fa),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (_consoleMode == 'build') ...[
            const SizedBox(height: 12),
            _buildActions(),
          ] else if (_showQuickCommands) ...[
            const SizedBox(height: 12),
            _quickCommands(),
          ],
          const SizedBox(height: 12),
          Expanded(child: _console()),
        ],
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Icon(
        _consoleMode == 'build' ? Icons.inventory_2_outlined : Icons.terminal,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _consoleMode == 'build'
                  ? '$_projectTitle · 构建控制台'
                  : _projectTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              _tasks.isEmpty ? '当前没有运行中的命令' : '正在运行 ${_tasks.length} 个命令',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
      _stopButton(),
    ],
  );

  Widget _buildActions() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '构建操作 · ${_buildTarget.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _runAction('openBuildOutput'),
            icon: const Icon(Icons.folder_open),
            label: const Text('打开构建目录'),
          ),
          if (_buildTarget == 'apk')
            OutlinedButton.icon(
              onPressed: () => _runAction('openApkOutput'),
              icon: const Icon(Icons.android),
              label: const Text('打开 APK 目录'),
            ),
        ],
      ),
    ),
  );

  Widget _quickCommands() {
    final running = _taskActive('run');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                '常用命令',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: running ? null : () => _runAction('run'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Flutter Run'),
            ),
            OutlinedButton.icon(
              onPressed: running ? () => _runAction('hotReload') : null,
              icon: const Icon(Icons.bolt),
              label: const Text('热重载'),
            ),
            OutlinedButton.icon(
              onPressed: running ? () => _runAction('hotRestart') : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('热重启'),
            ),
            OutlinedButton.icon(
              onPressed: running ? () => _runAction('rerun') : null,
              icon: const Icon(Icons.replay),
              label: const Text('Rerun'),
            ),
            OutlinedButton.icon(
              onPressed: () => _runAction('devtools'),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('DevTools'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(String action) async {
    try {
      await _request(
        onGlobal: () => ConsoleWindowService.instance.requestAction(
          widget.projectPath,
          action,
        ),
        onChannel: () => ConsoleWindowService.instance.requestActionOn(
          _actionChannelName,
          widget.projectPath,
          action,
        ),
      );
    } on Object catch (error) {
      _showError('执行命令失败：$error');
    }
  }

  Widget _stopButton() {
    if (_tasks.isEmpty) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('结束运行'),
      );
    }
    if (_tasks.length == 1) {
      return OutlinedButton.icon(
        onPressed: () => _confirmStop(_tasks.single),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('结束运行'),
      );
    }
    return PopupMenuButton<String>(
      tooltip: '选择要结束的命令',
      onSelected: (id) =>
          _confirmStop(_tasks.firstWhere((task) => task['id'] == id)),
      itemBuilder: (_) => _tasks
          .map(
            (task) => PopupMenuItem<String>(
              value: task['id'],
              child: Text(task['label'] ?? '运行命令'),
            ),
          )
          .toList(growable: false),
      child: const Chip(
        avatar: Icon(Icons.stop_circle_outlined),
        label: Text('结束运行 ▾'),
      ),
    );
  }

  Future<void> _confirmStop(Map<String, String> task) async {
    final confirmed = await confirmDeletion(
      context,
      title: '确认结束运行？',
      message: '将停止“${task['label'] ?? '运行命令'}”。正在执行的操作会立即中断。',
      confirmLabel: '结束运行',
    );
    if (!confirmed) return;
    try {
      await _request(
        onGlobal: () => ConsoleWindowService.instance.requestStop(task['id']!),
        onChannel: () => ConsoleWindowService.instance.requestStopOn(
          _actionChannelName,
          task['id']!,
        ),
      );
    } on Object catch (error) {
      _showError('结束命令失败：$error');
    }
  }

  Widget _console() => Card(
    color: const Color(0xff101820),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _tasks.isEmpty ? '命令输出' : '正在执行 ${_tasks.length} 个任务',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '搜索输出',
                onPressed: () => setState(() => _showSearch = !_showSearch),
                icon: const Icon(Icons.search, color: Colors.white70),
              ),
              IconButton(
                tooltip: '清空输出',
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              ),
            ],
          ),
          if (_showSearch)
            TextField(
              key: const ValueKey('command-console-search-field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '搜索输出内容…',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          const Divider(color: Colors.white24),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText.rich(
                    TextSpan(children: _spans()),
                    style: const TextStyle(
                      color: Color(0xffc9d1d9),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmClear() async {
    final confirmed = await confirmDeletion(
      context,
      title: '确认清空命令输出？',
      message: '将清空当前项目打印台中的全部输出内容，此操作不可撤销。',
      confirmLabel: '清空输出',
    );
    if (confirmed) {
      await _request(
        onGlobal: () =>
            ConsoleWindowService.instance.requestClear(widget.projectPath),
        onChannel: () => ConsoleWindowService.instance.requestClearOn(
          _actionChannelName,
          widget.projectPath,
        ),
      );
    }
  }

  Future<void> _request({
    required Future<void> Function() onGlobal,
    required Future<void> Function() onChannel,
  }) {
    return _actionChannelName == 'fvm_manager/console_commands'
        ? onGlobal()
        : onChannel();
  }

  List<TextSpan> _spans() {
    final text = _commandLog.isEmpty ? '等待执行命令…' : _commandLog;
    if (_searchQuery.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final query = _searchQuery.toLowerCase();
    var offset = 0;
    while (offset < text.length) {
      final index = lower.indexOf(query, offset);
      if (index < 0) break;
      if (index > offset) {
        spans.add(TextSpan(text: text.substring(offset, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            color: Color(0xff101820),
            backgroundColor: Color(0xffffc857),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      offset = index + query.length;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
