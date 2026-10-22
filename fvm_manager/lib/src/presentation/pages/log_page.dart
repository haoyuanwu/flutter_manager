part of '../home_page.dart';

class _LogPage extends StatefulWidget {
  const _LogPage();

  @override
  State<_LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<_LogPage> {
  final _parser = LogParser();
  final _fileService = LogFileService();
  final _historyStore = LogHistoryStore();
  final _pathController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<String> _history = const [];
  List<String> _logs = const [];
  List<GlobalKey> _logKeys = const [];
  List<_LoggerSearchMatch> _matches = const [];
  String? _selectedPath;
  String? _error;
  String _query = '';
  int _currentMatch = -1;
  bool _encrypted = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _pickFile() async {
    try {
      final path = await _fileService.chooseFile();
      if (path != null) await _openFile(path);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _openManualPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _error = '请输入日志文件路径。');
      return;
    }
    await _openFile(path);
  }

  Future<void> _openFile(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPath = path;
      _logs = const [];
      _logKeys = const [];
      _query = '';
      _matches = const [];
      _currentMatch = -1;
      _pathController.text = path;
      _searchController.clear();
    });
    try {
      final logs = await _parser.parseFile(path, isEncrypted: _encrypted);
      final history = await _historyStore.add(path);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _logKeys = List.generate(logs.length, (_) => GlobalKey());
        _history = history;
        _error = logs.isEmpty ? '文件不存在或没有可显示的日志内容。' : null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = '读取日志失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    if (_selectedPath case final path?) await _openFile(path);
  }

  Future<void> _clearHistory() async {
    final confirmed = await confirmDeletion(
      context,
      title: '确认清空日志历史？',
      message: '将删除全部日志文件访问记录，不会删除本地日志文件。',
      confirmLabel: '清空历史',
    );
    if (!confirmed) return;
    await _historyStore.clear();
    if (mounted) setState(() => _history = const []);
  }

  void _search() {
    final query = _searchController.text.trim();
    final matches = _findLoggerMatches(_logs, query);
    setState(() {
      _query = query;
      _matches = matches;
      _currentMatch = matches.isEmpty ? -1 : 0;
    });
    _scrollToMatch();
  }

  void _previousMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatch = (_currentMatch - 1 + _matches.length) % _matches.length;
    });
    _scrollToMatch();
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    setState(() => _currentMatch = (_currentMatch + 1) % _matches.length);
    _scrollToMatch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _matches = const [];
      _currentMatch = -1;
    });
  }

  void _scrollToMatch() {
    if (_currentMatch < 0 || _currentMatch >= _matches.length) return;
    final logIndex = _matches[_currentMatch].logIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemContext = _logKeys[logIndex].currentContext;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 180),
          alignment: .2,
        );
      } else if (_scrollController.hasClients && _logs.length > 1) {
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          (max * logIndex / (_logs.length - 1)).clamp(0, max),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.pagePadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WorkbenchPageHeader(title: '日志'),
        const SizedBox(height: 20),
        Expanded(
          child: WorkbenchPanel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showHistory = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHistory) ...[
                      SizedBox(
                        width: 260,
                        child: _LoggerHistory(
                          history: _history,
                          selectedPath: _selectedPath,
                          onOpen: _openFile,
                          onClear: _clearHistory,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LoggerToolbar(
                            encrypted: _encrypted,
                            loading: _loading,
                            selectedPath: _selectedPath,
                            compactHistory: showHistory ? null : _history,
                            onEncryptedChanged: (value) async {
                              setState(() => _encrypted = value);
                              await _reload();
                            },
                            onPickFile: _pickFile,
                            onReload: _reload,
                            onOpenHistory: _openFile,
                            onClearHistory: _clearHistory,
                          ),
                          _LoggerPathInput(
                            controller: _pathController,
                            onSubmit: _openManualPath,
                          ),
                          _LoggerSearchPanel(
                            controller: _searchController,
                            enabled: !_loading && _logs.isNotEmpty,
                            query: _query,
                            current: _currentMatch < 0 ? 0 : _currentMatch + 1,
                            total: _matches.length,
                            onSearch: _search,
                            onPrevious: _previousMatch,
                            onNext: _nextMatch,
                            onClear: _clearSearch,
                          ),
                          Expanded(
                            child: _LoggerContent(
                              logs: _logs,
                              keys: _logKeys,
                              controller: _scrollController,
                              matches: _matches,
                              currentMatch: _currentMatch,
                              selectedPath: _selectedPath,
                              loading: _loading,
                              error: _error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoggerSearchMatch {
  const _LoggerSearchMatch({
    required this.logIndex,
    required this.start,
    required this.end,
  });

  final int logIndex;
  final int start;
  final int end;
}

List<_LoggerSearchMatch> _findLoggerMatches(List<String> logs, String query) {
  if (query.isEmpty) return const [];
  final lowerQuery = query.toLowerCase();
  final matches = <_LoggerSearchMatch>[];
  for (var logIndex = 0; logIndex < logs.length; logIndex++) {
    final lowerLog = logs[logIndex].toLowerCase();
    var offset = 0;
    while (offset < lowerLog.length) {
      final start = lowerLog.indexOf(lowerQuery, offset);
      if (start < 0) break;
      final end = start + query.length;
      matches.add(
        _LoggerSearchMatch(logIndex: logIndex, start: start, end: end),
      );
      offset = end;
    }
  }
  return matches;
}

class _LoggerToolbar extends StatelessWidget {
  const _LoggerToolbar({
    required this.encrypted,
    required this.loading,
    required this.selectedPath,
    required this.compactHistory,
    required this.onEncryptedChanged,
    required this.onPickFile,
    required this.onReload,
    required this.onOpenHistory,
    required this.onClearHistory,
  });

  final bool encrypted;
  final bool loading;
  final String? selectedPath;
  final List<String>? compactHistory;
  final ValueChanged<bool> onEncryptedChanged;
  final VoidCallback onPickFile;
  final VoidCallback onReload;
  final ValueChanged<String> onOpenHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加密日志'),
            Switch.adaptive(
              value: encrypted,
              onChanged: loading ? null : onEncryptedChanged,
            ),
          ],
        ),
        if (compactHistory != null)
          PopupMenuButton<String>(
            tooltip: '历史文件',
            enabled: compactHistory!.isNotEmpty,
            icon: const Icon(Icons.history),
            onSelected: (value) => value == '__clear_history__'
                ? onClearHistory()
                : onOpenHistory(value),
            itemBuilder: (context) => [
              ...compactHistory!.map(
                (path) =>
                    PopupMenuItem(value: path, child: Text(logFileName(path))),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '__clear_history__',
                child: Text('清空历史'),
              ),
            ],
          ),
        IconButton.filledTonal(
          tooltip: '重新读取',
          onPressed: selectedPath != null && !loading ? onReload : null,
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: loading ? null : onPickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择日志文件'),
        ),
      ],
    ),
  );
}

class _LoggerPathInput extends StatelessWidget {
  const _LoggerPathInput({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '日志文件路径',
              hintText: '输入路径，或点击“选择日志文件”',
              prefixIcon: Icon(Icons.description_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonal(onPressed: onSubmit, child: const Text('打开')),
      ],
    ),
  );
}

class _LoggerSearchPanel extends StatelessWidget {
  const _LoggerSearchPanel({
    required this.controller,
    required this.enabled,
    required this.query,
    required this.current,
    required this.total,
    required this.onSearch,
    required this.onPrevious,
    required this.onNext,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool enabled;
  final String query;
  final int current;
  final int total;
  final VoidCallback onSearch;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: '搜索日志',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 8),
        Text(query.isEmpty ? '未搜索' : '$current / $total'),
        IconButton(
          tooltip: '上一个结果',
          onPressed: total > 0 ? onPrevious : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: '下一个结果',
          onPressed: total > 0 ? onNext : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: '清除搜索',
          onPressed: query.isNotEmpty || controller.text.isNotEmpty
              ? onClear
              : null,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _LoggerHistory extends StatelessWidget {
  const _LoggerHistory({
    required this.history,
    required this.selectedPath,
    required this.onOpen,
    required this.onClear,
  });

  final List<String> history;
  final String? selectedPath;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      children: [
        ListTile(
          title: const Text(
            '历史文件',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: IconButton(
            tooltip: '清空历史',
            onPressed: history.isEmpty ? null : onClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
        if (history.isEmpty)
          Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '选择过的日志会显示在这里。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final path = history[index];
                return ListTile(
                  selected: path == selectedPath,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(
                    logFileName(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onOpen(path),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _LoggerContent extends StatelessWidget {
  const _LoggerContent({
    required this.logs,
    required this.keys,
    required this.controller,
    required this.matches,
    required this.currentMatch,
    required this.selectedPath,
    required this.loading,
    required this.error,
  });

  final List<String> logs;
  final List<GlobalKey> keys;
  final ScrollController controller;
  final List<_LoggerSearchMatch> matches;
  final int currentMatch;
  final String? selectedPath;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return _LoggerMessage(icon: Icons.error_outline, text: error!);
    }
    if (selectedPath == null) {
      return const _LoggerMessage(
        icon: Icons.folder_open,
        text: '选择一个日志文件开始查看。',
      );
    }
    final matchesByLog = <int, List<(int, _LoggerSearchMatch)>>{};
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      matchesByLog.putIfAbsent(match.logIndex, () => []).add((index, match));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            '${logFileName(selectedPath!)} · ${logs.length} 条日志',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(logs.length, (index) {
                return Container(
                  key: keys[index],
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: SelectableText.rich(
                    TextSpan(
                      children: _loggerSpans(
                        logs[index],
                        matchesByLog[index] ?? const [],
                        currentMatch,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 13,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

List<TextSpan> _loggerSpans(
  String log,
  List<(int, _LoggerSearchMatch)> matches,
  int currentMatch,
) {
  if (matches.isEmpty) return [TextSpan(text: log)];
  final spans = <TextSpan>[];
  var offset = 0;
  for (final indexed in matches) {
    final match = indexed.$2;
    if (match.start > offset) {
      spans.add(TextSpan(text: log.substring(offset, match.start)));
    }
    spans.add(
      TextSpan(
        text: log.substring(match.start, match.end),
        style: TextStyle(
          fontWeight: indexed.$1 == currentMatch
              ? FontWeight.w700
              : FontWeight.w500,
          color: const Color(0xff20242a),
          backgroundColor: indexed.$1 == currentMatch
              ? const Color(0xffffc857)
              : const Color(0xfffff3a3),
        ),
      ),
    );
    offset = match.end;
  }
  if (offset < log.length) spans.add(TextSpan(text: log.substring(offset)));
  return spans;
}

class _LoggerMessage extends StatelessWidget {
  const _LoggerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
