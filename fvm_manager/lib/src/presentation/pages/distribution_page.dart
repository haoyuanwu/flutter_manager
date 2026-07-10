part of '../home_page.dart';

enum _ArtifactSort { newest, largest, name }

class _DistributionPage extends ConsumerStatefulWidget {
  const _DistributionPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_DistributionPage> createState() => _DistributionPageState();
}

class _DistributionPageState extends ConsumerState<_DistributionPage> {
  List<DistributionArtifact> _artifacts = const [];
  String? _selectedArtifactPath;
  String? _scannedProjectPath;
  String? _platformFilter;
  DistributionArtifactType? _typeFilter;
  final TextEditingController _searchController = TextEditingController();
  _ArtifactSort _sort = _ArtifactSort.newest;
  BuildHistorySnapshot _history = const BuildHistorySnapshot();
  bool _historyLoading = false;
  bool _loading = false;
  late final BuildDirectoryWatcher _watcher;

  DistributionArtifact? get _selectedArtifact => _artifacts
      .where((artifact) => artifact.path == _selectedArtifactPath)
      .firstOrNull;

  List<DistributionArtifact> get _filteredArtifacts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _artifacts
        .where(
          (artifact) =>
              (_platformFilter == null ||
                  artifact.platformLabel == _platformFilter) &&
              (_typeFilter == null || artifact.type == _typeFilter) &&
              (query.isEmpty || artifact.name.toLowerCase().contains(query)),
        )
        .toList();
    switch (_sort) {
      case _ArtifactSort.newest:
        filtered.sort((a, b) => b.modified.compareTo(a.modified));
      case _ArtifactSort.largest:
        filtered.sort((a, b) => b.size.compareTo(a.size));
      case _ArtifactSort.name:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _watcher = ref.read(buildDirectoryWatcherProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scan();
      _loadHistory();
      _startWatching();
    });
  }

  @override
  void didUpdateWidget(_DistributionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedManagedProjectPath !=
        widget.state.selectedManagedProjectPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scan();
        _loadHistory();
        _startWatching();
      });
    }
  }

  @override
  void dispose() {
    _watcher.stop();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (!mounted) return;
    final projectPath = widget.state.selectedManagedProjectPath;
    if (projectPath == null) {
      setState(() {
        _artifacts = const [];
        _selectedArtifactPath = null;
        _scannedProjectPath = null;
        _platformFilter = null;
        _typeFilter = null;
      });
      return;
    }
    setState(() {
      final projectChanged = _scannedProjectPath != projectPath;
      _loading = true;
      _scannedProjectPath = projectPath;
      if (projectChanged) {
        _platformFilter = null;
        _typeFilter = null;
        _sort = _ArtifactSort.newest;
        _searchController.clear();
      }
    });
    try {
      final artifacts = await ref
          .read(distributionServiceProvider)
          .scanArtifacts(projectPath);
      if (!mounted || widget.state.selectedManagedProjectPath != projectPath) {
        return;
      }
      setState(() {
        _artifacts = artifacts;
        _selectedArtifactPath =
            artifacts
                .where((item) => item.path == _selectedArtifactPath)
                .firstOrNull
                ?.path ??
            artifacts.firstOrNull?.path;
      });
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    } finally {
      if (mounted && _scannedProjectPath == projectPath) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final history = await ref.read(buildHistoryRepositoryProvider).load();
      if (mounted) setState(() => _history = history);
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_scan(), _loadHistory()]);
  }

  void _startWatching() {
    final projectPath = widget.state.selectedManagedProjectPath;
    if (projectPath == null) {
      _watcher.stop();
      return;
    }
    _watcher.watch(projectPath, _silentScan);
  }

  /// Silent re-scan triggered by the build directory watcher. Does not flash
  /// the full-screen loading indicator — only updates the artifact list.
  Future<void> _silentScan() async {
    if (!mounted) return;
    final projectPath = widget.state.selectedManagedProjectPath;
    if (projectPath == null) return;
    try {
      final artifacts = await ref
          .read(distributionServiceProvider)
          .scanArtifacts(projectPath);
      if (!mounted || widget.state.selectedManagedProjectPath != projectPath) {
        return;
      }
      setState(() {
        _artifacts = artifacts;
        _selectedArtifactPath =
            artifacts
                .where((item) => item.path == _selectedArtifactPath)
                .firstOrNull
                ?.path ??
            artifacts.firstOrNull?.path;
      });
    } catch (_) {
      // Silent refresh — ignore transient errors.
    }
  }

  void _setPlatformFilter(String? platform) {
    setState(() {
      _platformFilter = platform;
      _selectFirstVisibleArtifact();
    });
  }

  void _setTypeFilter(DistributionArtifactType? type) {
    setState(() {
      _typeFilter = type;
      _selectFirstVisibleArtifact();
    });
  }

  void _setSort(_ArtifactSort sort) {
    setState(() {
      _sort = sort;
      _selectFirstVisibleArtifact();
    });
  }

  void _setSearch(String _) {
    setState(_selectFirstVisibleArtifact);
  }

  void _selectFirstVisibleArtifact() {
    final visible = _filteredArtifacts;
    if (!visible.any((item) => item.path == _selectedArtifactPath)) {
      _selectedArtifactPath = visible.firstOrNull?.path;
    }
  }

  Future<void> _copyArtifactPath(DistributionArtifact artifact) async {
    await Clipboard.setData(ClipboardData(text: artifact.path));
    if (!mounted) return;
    ref.read(fvmControllerProvider.notifier).showStatus('已复制产物路径');
  }

  Future<void> _revealArtifact(String path) async {
    try {
      await ref.read(localProjectServiceProvider).revealFile(path);
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }

  Future<void> _chooseArtifact() async {
    try {
      final artifact = await ref
          .read(distributionServiceProvider)
          .chooseArtifact();
      if (artifact == null || !mounted) return;
      setState(() {
        _artifacts = [
          artifact,
          ..._artifacts.where((item) => item.path != artifact.path),
        ];
        _selectedArtifactPath = artifact.path;
      });
      ref
          .read(fvmControllerProvider.notifier)
          .showStatus('已选择安装包：${artifact.name}');
    } catch (error) {
      ref.read(fvmControllerProvider.notifier).showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final projects = state.managedProjects.where(
      (project) => project.pathExists,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '构建产物中心',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('集中查看、筛选和分发项目的最终安装包。'),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _chooseArtifact,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('添加本地产物'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '重新扫描构建产物',
                onPressed: _loading || _historyLoading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ArtifactToolbar(
            projects: projects.toList(growable: false),
            selectedProjectPath: state.selectedManagedProjectPath,
            artifacts: _artifacts,
            visibleCount: _filteredArtifacts.length,
            loading: _loading,
            searchController: _searchController,
            platform: _platformFilter,
            type: _typeFilter,
            sort: _sort,
            onProjectChanged: (path) {
              if (path == null) return;
              unawaited(
                ref
                    .read(fvmControllerProvider.notifier)
                    .selectManagedProject(path),
              );
            },
            onSearchChanged: _setSearch,
            onPlatformChanged: _setPlatformFilter,
            onTypeChanged: _setTypeFilter,
            onSortChanged: _setSort,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final artifacts = _ArtifactsPanel(
                  artifacts: _filteredArtifacts,
                  selectedPath: _selectedArtifactPath,
                  loading: _loading,
                  hasProject: state.selectedManagedProjectPath != null,
                  filteredEmpty:
                      _artifacts.isNotEmpty && _filteredArtifacts.isEmpty,
                  onSelected: (path) =>
                      setState(() => _selectedArtifactPath = path),
                  onReveal: (path) => unawaited(_revealArtifact(path)),
                  compact: isNarrow,
                );
                final platforms = _DistributionPlatforms(
                  artifact: _selectedArtifact,
                  compact: isNarrow,
                  embedded: true,
                );
                final details = _SelectedArtifactCard(
                  artifact: _selectedArtifact,
                  onCopyPath: _selectedArtifact == null
                      ? null
                      : () => _copyArtifactPath(_selectedArtifact!),
                  onReveal: _selectedArtifact == null
                      ? null
                      : () => _revealArtifact(_selectedArtifact!.path),
                  embedded: true,
                );
                final inspector = _ArtifactInspector(
                  details: details,
                  distribution: platforms,
                  history: _BuildHistoryView(
                    snapshot: _history,
                    projectPath: state.selectedManagedProjectPath,
                    loading: _historyLoading,
                    onReveal: (path) => unawaited(_revealArtifact(path)),
                  ),
                  historyCount: state.selectedManagedProjectPath == null
                      ? 0
                      : _history
                            .sessionsForProject(
                              state.selectedManagedProjectPath!,
                            )
                            .length,
                );
                if (isNarrow) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: _filteredArtifacts.isEmpty ? 120 : 220,
                          child: artifacts,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(height: 460, child: inspector),
                      ],
                    ),
                  );
                }
                // 宽度足够时，左右布局，各自独立滚动
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: artifacts),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: inspector),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactToolbar extends StatelessWidget {
  const _ArtifactToolbar({
    required this.projects,
    required this.selectedProjectPath,
    required this.artifacts,
    required this.visibleCount,
    required this.loading,
    required this.searchController,
    required this.platform,
    required this.type,
    required this.sort,
    required this.onProjectChanged,
    required this.onSearchChanged,
    required this.onPlatformChanged,
    required this.onTypeChanged,
    required this.onSortChanged,
  });

  final List<FlutterProject> projects;
  final String? selectedProjectPath;
  final List<DistributionArtifact> artifacts;
  final int visibleCount;
  final bool loading;
  final TextEditingController searchController;
  final String? platform;
  final DistributionArtifactType? type;
  final _ArtifactSort sort;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<DistributionArtifactType?> onTypeChanged;
  final ValueChanged<_ArtifactSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final platforms =
        artifacts.map((artifact) => artifact.platformLabel).toSet().toList()
          ..sort();
    final types = artifacts.map((artifact) => artifact.type).toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final totalSize = artifacts.fold<int>(
      0,
      (sum, artifact) => sum + artifact.size,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            final projectField = DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  projects.any((project) => project.path == selectedProjectPath)
                  ? selectedProjectPath
                  : null,
              decoration: const InputDecoration(
                labelText: '项目',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.workspaces_outline),
                isDense: true,
              ),
              items: projects
                  .map(
                    (project) => DropdownMenuItem(
                      value: project.path,
                      child: Text(
                        project.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onProjectChanged,
            );
            final searchField = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: '搜索产物',
                hintText: '输入文件名',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            );
            final sortField = DropdownButtonFormField<_ArtifactSort>(
              initialValue: sort,
              decoration: const InputDecoration(
                labelText: '排序',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: _ArtifactSort.newest,
                  child: Text('最新优先'),
                ),
                DropdownMenuItem(
                  value: _ArtifactSort.largest,
                  child: Text('体积最大'),
                ),
                DropdownMenuItem(value: _ArtifactSort.name, child: Text('文件名')),
              ],
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (narrow) ...[
                  projectField,
                  const SizedBox(height: 10),
                  searchField,
                  const SizedBox(height: 10),
                  sortField,
                ] else
                  Row(
                    children: [
                      Expanded(flex: 4, child: projectField),
                      const SizedBox(width: 10),
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 10),
                      SizedBox(width: 150, child: sortField),
                    ],
                  ),
                if (artifacts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _CompactFilterChip(
                        label: '全部平台',
                        selected: platform == null,
                        onSelected: () => onPlatformChanged(null),
                      ),
                      for (final item in platforms)
                        _CompactFilterChip(
                          label: item,
                          selected: platform == item,
                          onSelected: () => onPlatformChanged(item),
                        ),
                      const SizedBox(width: 4),
                      _CompactFilterChip(
                        label: '全部格式',
                        selected: type == null,
                        onSelected: () => onTypeChanged(null),
                      ),
                      for (final item in types)
                        _CompactFilterChip(
                          label: item.name.toUpperCase(),
                          selected: type == item,
                          onSelected: () => onTypeChanged(item),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _ArtifactSummary(
                      icon: loading ? Icons.sync : Icons.inventory_2_outlined,
                      text: loading
                          ? '正在扫描'
                          : '显示 $visibleCount / ${artifacts.length} 个产物',
                    ),
                    _ArtifactSummary(
                      icon: Icons.storage_outlined,
                      text: '总大小 ${_formatArtifactSize(totalSize)}',
                    ),
                    if (artifacts.firstOrNull case final latest?)
                      _ArtifactSummary(
                        icon: Icons.schedule_outlined,
                        text: '最近 ${_formatArtifactTime(latest.modified)}',
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selected: selected,
    onSelected: (_) => onSelected(),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _ArtifactSummary extends StatelessWidget {
  const _ArtifactSummary({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.black45),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ],
  );
}

class _SelectedArtifactCard extends StatelessWidget {
  const _SelectedArtifactCard({
    required this.artifact,
    required this.onCopyPath,
    required this.onReveal,
    this.embedded = false,
  });

  final DistributionArtifact? artifact;
  final VoidCallback? onCopyPath;
  final VoidCallback? onReveal;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final artifact = this.artifact;
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (artifact == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    '请从左侧选择一个产物',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else ...[
              _ArtifactTypeBadge(artifact: artifact),
              const SizedBox(height: 12),
              Text(
                artifact.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _ArtifactInfoRow(label: '平台', value: artifact.platformLabel),
              _ArtifactInfoRow(label: '格式', value: artifact.typeLabel),
              _ArtifactInfoRow(
                label: '大小',
                value: _formatArtifactSize(artifact.size),
              ),
              _ArtifactInfoRow(
                label: '时间',
                value: _formatArtifactTime(artifact.modified),
              ),
              const Divider(height: 24),
              const Text(
                '文件路径',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(
                artifact.path,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCopyPath,
                    icon: const Icon(Icons.copy_outlined, size: 17),
                    label: const Text('复制路径'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReveal,
                    icon: const Icon(Icons.folder_open_outlined, size: 17),
                    label: const Text('文件位置'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (embedded) return content;
    return Card(margin: EdgeInsets.zero, child: content);
  }
}

class _ArtifactInfoRow extends StatelessWidget {
  const _ArtifactInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _ArtifactTypeBadge extends StatelessWidget {
  const _ArtifactTypeBadge({required this.artifact});

  final DistributionArtifact artifact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _artifactColor(artifact.type).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      '${artifact.platformLabel}  ${artifact.typeLabel}',
      style: TextStyle(
        color: _artifactColor(artifact.type),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ArtifactInspector extends StatelessWidget {
  const _ArtifactInspector({
    required this.details,
    required this.distribution,
    required this.history,
    required this.historyCount,
  });

  final Widget details;
  final Widget distribution;
  final Widget history;
  final int historyCount;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.info_outline, size: 18), text: '产物详情'),
              const Tab(
                icon: Icon(Icons.cloud_upload_outlined, size: 18),
                text: '分发上传',
              ),
              Tab(
                icon: const Icon(Icons.history, size: 18),
                text: historyCount == 0 ? '构建历史' : '历史 $historyCount',
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(children: [details, distribution, history]),
          ),
        ],
      ),
    ),
  );
}

class _BuildHistoryView extends StatelessWidget {
  const _BuildHistoryView({
    required this.snapshot,
    required this.projectPath,
    required this.loading,
    required this.onReveal,
  });

  final BuildHistorySnapshot snapshot;
  final String? projectPath;
  final bool loading;
  final ValueChanged<String> onReveal;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final path = projectPath;
    if (path == null) {
      return const Center(
        child: Text('请先选择项目', style: TextStyle(color: Colors.black54)),
      );
    }
    final sessions = snapshot.sessionsForProject(path);
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '尚无构建历史\n从项目详情执行一次标准 Build 后会自动记录。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final artifacts = snapshot.artifactsForSession(session.id);
        final color = _buildStatusColor(session.status);
        return Card(
          margin: EdgeInsets.zero,
          color: index == 0 ? const Color(0xfffbfdff) : null,
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            leading: Icon(_buildStatusIcon(session.status), color: color),
            title: Text(
              session.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_formatArtifactTime(session.startedAt)} · '
              '${_buildStatusLabel(session.status)}',
              style: TextStyle(fontSize: 11, color: color),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              _HistoryInfoLine(label: '目标', value: session.target),
              _HistoryInfoLine(label: '模式', value: session.mode),
              if (session.flavors.isNotEmpty)
                _HistoryInfoLine(
                  label: 'Flavor',
                  value: session.flavors.join('、'),
                ),
              if (session.flutterVersion case final version?)
                _HistoryInfoLine(label: 'Flutter', value: version),
              _HistoryInfoLine(label: '耗时', value: _buildDuration(session)),
              if (session.exitCode case final code?)
                _HistoryInfoLine(label: '退出码', value: '$code'),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '命令',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 5),
              for (final command in session.commands)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    command,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '关联产物 (${artifacts.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (artifacts.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '本次构建未发现新的最终安装包',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                )
              else
                for (final artifact in artifacts)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      artifact.exists
                          ? Icons.inventory_2_outlined
                          : Icons.link_off_outlined,
                      size: 18,
                      color: artifact.exists ? Colors.blueGrey : Colors.orange,
                    ),
                    title: Text(
                      artifact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      artifact.exists
                          ? '${artifact.platform} · ${artifact.type.toUpperCase()} · ${_formatArtifactSize(artifact.size)}'
                          : '文件已丢失',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: IconButton(
                      tooltip: artifact.exists ? '在文件管理器中显示' : '文件已丢失',
                      onPressed: artifact.exists
                          ? () => onReveal(artifact.path)
                          : null,
                      icon: const Icon(Icons.folder_open_outlined, size: 17),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryInfoLine extends StatelessWidget {
  const _HistoryInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
      ],
    ),
  );
}

String _buildStatusLabel(BuildSessionStatus status) => switch (status) {
  BuildSessionStatus.running => '构建中',
  BuildSessionStatus.success => '成功',
  BuildSessionStatus.failed => '失败',
  BuildSessionStatus.stopped => '已停止',
  BuildSessionStatus.interrupted => '异常中断',
};

IconData _buildStatusIcon(BuildSessionStatus status) => switch (status) {
  BuildSessionStatus.running => Icons.sync,
  BuildSessionStatus.success => Icons.check_circle_outline,
  BuildSessionStatus.failed => Icons.error_outline,
  BuildSessionStatus.stopped => Icons.stop_circle_outlined,
  BuildSessionStatus.interrupted => Icons.power_settings_new_outlined,
};

Color _buildStatusColor(BuildSessionStatus status) => switch (status) {
  BuildSessionStatus.running => Colors.blue,
  BuildSessionStatus.success => Colors.green,
  BuildSessionStatus.failed => Colors.red,
  BuildSessionStatus.stopped => Colors.orange,
  BuildSessionStatus.interrupted => Colors.deepOrange,
};

String _buildDuration(BuildSession session) {
  final finishedAt = session.finishedAt;
  if (finishedAt == null) {
    return session.status == BuildSessionStatus.running ? '进行中' : '-';
  }
  final duration = finishedAt.difference(session.startedAt);
  if (duration.inHours > 0) {
    return '${duration.inHours}小时 ${duration.inMinutes.remainder(60)}分';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}分 ${duration.inSeconds.remainder(60)}秒';
  }
  return '${duration.inSeconds}秒';
}

class _ArtifactsPanel extends StatelessWidget {
  const _ArtifactsPanel({
    required this.artifacts,
    required this.selectedPath,
    required this.loading,
    required this.hasProject,
    required this.filteredEmpty,
    required this.onSelected,
    required this.onReveal,
    this.compact = false,
  });

  final List<DistributionArtifact> artifacts;
  final String? selectedPath;
  final bool loading;
  final bool hasProject;
  final bool filteredEmpty;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onReveal;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            compact ? 12 : 16,
            18,
            compact ? 8 : 12,
          ),
          child: Row(
            children: [
              Text(
                '构建产物',
                style: TextStyle(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (artifacts.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '(${artifacts.length})',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : artifacts.isEmpty
              ? Center(
                  child: Text(
                    filteredEmpty
                        ? '没有符合当前搜索或筛选条件的产物'
                        : hasProject
                        ? '尚未找到最终安装包'
                        : '请先选择项目',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
                  itemCount: artifacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artifact = artifacts[index];
                    final selected = selectedPath == artifact.path;
                    if (compact) {
                      return ListTile(
                        dense: true,
                        selected: selected,
                        selectedTileColor: const Color(0xffeef8ff),
                        leading: _ArtifactFileIcon(
                          artifact: artifact,
                          compact: true,
                        ),
                        title: Text(
                          artifact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${artifact.platformLabel} · ${_formatArtifactSize(artifact.size)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xff087ea4),
                                size: 18,
                              ),
                            IconButton(
                              tooltip: '在文件管理器中显示',
                              onPressed: () => onReveal(artifact.path),
                              icon: const Icon(Icons.folder_open, size: 17),
                              iconSize: 17,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => onSelected(artifact.path),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    }
                    return ListTile(
                      selected: selected,
                      selectedTileColor: const Color(0xffeef8ff),
                      leading: _ArtifactFileIcon(artifact: artifact),
                      title: Text(
                        artifact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${artifact.platformLabel} · ${artifact.typeLabel} · '
                        '${_formatArtifactSize(artifact.size)} · '
                        '${_formatArtifactTime(artifact.modified)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xff087ea4),
                              size: 20,
                            ),
                          IconButton(
                            tooltip: '在文件管理器中显示',
                            onPressed: () => onReveal(artifact.path),
                            icon: const Icon(Icons.folder_open, size: 19),
                          ),
                        ],
                      ),
                      onTap: () => onSelected(artifact.path),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _ArtifactFileIcon extends StatelessWidget {
  const _ArtifactFileIcon({required this.artifact, this.compact = false});

  final DistributionArtifact artifact;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _artifactColor(artifact.type);
    final size = compact ? 34.0 : 42.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Icon(
        _artifactIcon(artifact.type),
        color: color,
        size: compact ? 18 : 22,
      ),
    );
  }
}

class _DistributionPlatforms extends ConsumerWidget {
  const _DistributionPlatforms({
    required this.artifact,
    this.compact = false,
    this.embedded = false,
  });

  final DistributionArtifact? artifact;
  final bool compact;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(distributionServiceProvider);
    final controller = ref.read(fvmControllerProvider.notifier);
    final state = ref.watch(fvmControllerProvider);
    final project = state.managedProjects
        .where((p) => p.path == state.selectedManagedProjectPath)
        .firstOrNull;

    Future<void> run(Future<void> Function() action, String message) async {
      try {
        await action();
        controller.showStatus(message);
      } catch (error) {
        controller.showError(error);
      }
    }

    final content = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (artifact == null) ...[
              const Text(
                '请先选择一个产物，再选择分发渠道。',
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: compact ? 8 : 12),
            ],
            _PgyerTile(
              artifact: artifact,
              project: project,
              state: state,
              compact: compact,
            ),
            _FirTile(
              artifact: artifact,
              project: project,
              state: state,
              compact: compact,
            ),
            const SizedBox(height: 4),
            Text(
              '打开平台',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlatformActionChip(
                  icon: Icons.apple,
                  label: 'App Store',
                  onPressed: () =>
                      run(service.openAppStoreConnect, '已打开 App Store Connect'),
                ),
                _PlatformActionChip(
                  icon: Icons.local_shipping_outlined,
                  label: 'Transporter',
                  onPressed: Platform.isMacOS
                      ? () => run(
                          () => service.openTransporter(artifact),
                          '已打开 Transporter',
                        )
                      : null,
                ),
                _PlatformActionChip(
                  icon: Icons.android,
                  label: 'Google Play',
                  onPressed: () => run(
                    service.openGooglePlayConsole,
                    '已打开 Google Play Console',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (embedded) return content;
    return Card(margin: EdgeInsets.zero, child: content);
  }
}

class _PgyerTile extends ConsumerWidget {
  const _PgyerTile({
    required this.artifact,
    required this.project,
    required this.state,
    this.compact = false,
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final env = ref.read(pubEnvironmentServiceProvider);
    final pgyerConfig = project?.pgyer ?? const PgyerConfig();
    final hasProjectKey = pgyerConfig.apiKey.isNotEmpty;
    final hasGlobalKey = env.globalPgyerApiKey.isNotEmpty;
    final hasApiKey = hasProjectKey || hasGlobalKey;
    final keySource = hasProjectKey ? '项目配置' : (hasGlobalKey ? '全局配置' : '');
    final isUploading =
        state.pgyerUploadProgress > 0 && state.pgyerUploadProgress < 1.0;
    final hasResult = state.pgyerUploadResult != null;
    final storedDownloadUrl = pgyerConfig.buildShortcutUrl.isEmpty
        ? null
        : 'https://www.pgyer.com/${pgyerConfig.buildShortcutUrl}';
    final downloadUrl = state.pgyerUploadResult ?? storedDownloadUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: compact ? 18 : 21),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Text(
                      '蒲公英',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: compact ? 16 : 18),
                    tooltip: '配置蒲公英 API',
                    onPressed: () => _showPgyerConfigDialog(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              SizedBox(height: compact ? 3 : 5),
              if (hasApiKey)
                Text(
                  'API Key: ${hasProjectKey ? pgyerConfig.apiKey.substring(0, 8) : env.globalPgyerApiKey.substring(0, 8)}... ($keySource)',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: compact ? 12 : null,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未配置 API Key',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '请在设置页面配置全局 API Key，或点击右侧齿轮为当前项目配置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('去设置页面配置'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请点击左侧导航栏的"设置"菜单，配置全局 API Key'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              if (isUploading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: state.pgyerUploadProgress),
                const SizedBox(height: 4),
                Text(
                  state.pgyerUploadPhase,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              if (hasResult) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '上传完成',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: artifact == null || !hasApiKey || isUploading
                      ? null
                      : () => controller.uploadToPgyer(artifact!.path),
                  child: Text(
                    isUploading
                        ? '上传中...'
                        : artifact == null
                        ? '请选择文件'
                        : hasApiKey
                        ? '上传到蒲公英'
                        : '请先配置 API Key',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPgyerConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _PgyerConfigDialog(project: project),
    );
  }

  Future<void> _openUrl(String url) async {
    await _openExternalUrl(url);
  }
}

class _PgyerConfigDialog extends ConsumerStatefulWidget {
  const _PgyerConfigDialog({required this.project});

  final FlutterProject? project;

  @override
  ConsumerState<_PgyerConfigDialog> createState() => _PgyerConfigDialogState();
}

class _PgyerConfigDialogState extends ConsumerState<_PgyerConfigDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _passwordController;
  late final TextEditingController _descriptionController;
  late PgyerInstallType _installType;

  @override
  void initState() {
    super.initState();
    final config = widget.project?.pgyer ?? const PgyerConfig();
    _apiKeyController = TextEditingController(text: config.apiKey);
    _passwordController = TextEditingController(text: config.installPassword);
    _descriptionController = TextEditingController(
      text: config.updateDescription,
    );
    _installType = config.installType;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('蒲公英配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '在蒲公英官网获取',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '如何获取 API Key',
                  onPressed: () => _showPgyerApiKeyHelp(context, ref),
                  icon: const Icon(Icons.help_outline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PgyerInstallType>(
              initialValue: _installType,
              decoration: const InputDecoration(
                labelText: '安装方式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PgyerInstallType.public,
                  child: Text('公开安装'),
                ),
                DropdownMenuItem(
                  value: PgyerInstallType.password,
                  child: Text('密码安装'),
                ),
                DropdownMenuItem(
                  value: PgyerInstallType.invite,
                  child: Text('邀请安装'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _installType = value);
                }
              },
            ),
            if (_installType == PgyerInstallType.password) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '安装密码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '版本更新描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final config = PgyerConfig(
      apiKey: _apiKeyController.text.trim(),
      installType: _installType,
      installPassword: _passwordController.text,
      updateDescription: _descriptionController.text.trim(),
      buildShortcutUrl: widget.project?.pgyer.buildShortcutUrl ?? '',
    );
    ref.read(fvmControllerProvider.notifier).updatePgyerConfig(config);
    Navigator.pop(context);
  }
}

class _FirTile extends ConsumerWidget {
  const _FirTile({
    required this.artifact,
    required this.project,
    required this.state,
    this.compact = false,
  });

  final DistributionArtifact? artifact;
  final FlutterProject? project;
  final FvmState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final env = ref.read(pubEnvironmentServiceProvider);
    final firConfig = project?.fir ?? const FirConfig();
    final hasProjectToken = firConfig.apiToken.isNotEmpty;
    final hasGlobalToken = env.globalFirApiToken.isNotEmpty;
    final hasApiToken = hasProjectToken || hasGlobalToken;
    final tokenSource = hasProjectToken
        ? '项目配置'
        : (hasGlobalToken ? '全局配置' : '');
    final isUploading =
        state.firUploadProgress > 0 && state.firUploadProgress < 1.0;
    final hasResult = state.firUploadResult != null;
    final storedDownloadUrl = firConfig.shortCode.isEmpty
        ? null
        : 'https://fir.xcxwo.com/${firConfig.shortCode}';
    final downloadUrl = state.firUploadResult ?? storedDownloadUrl;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff7f9fb),
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          border: Border.all(color: const Color(0xffe4e8ec)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, size: compact ? 18 : 21),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: Text(
                      'fir.im',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, size: compact ? 16 : 18),
                    tooltip: '配置 fir.im',
                    onPressed: () => _showFirConfigDialog(context, ref),
                    padding: EdgeInsets.zero,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 32, minHeight: 32)
                        : null,
                  ),
                  if (downloadUrl != null)
                    TextButton.icon(
                      onPressed: () => _openUrl(downloadUrl),
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('打开下载页'),
                    ),
                ],
              ),
              SizedBox(height: compact ? 3 : 5),
              if (hasApiToken)
                Text(
                  'API Token: ${hasProjectToken ? firConfig.apiToken.substring(0, 8) : env.globalFirApiToken.substring(0, 8)}... ($tokenSource)',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: compact ? 12 : null,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未配置 API Token',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: compact ? 13 : null,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '请在设置页面配置全局 API Token，或点击右侧齿轮为当前项目配置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              if (isUploading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: state.firUploadProgress),
                const SizedBox(height: 4),
                Text(
                  state.firUploadPhase,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              if (hasResult) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '上传完成',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: artifact == null || !hasApiToken || isUploading
                      ? null
                      : () => controller.uploadToFir(artifact!.path),
                  child: Text(
                    isUploading
                        ? '上传中...'
                        : artifact == null
                        ? '请选择文件'
                        : hasApiToken
                        ? '上传到 fir.im'
                        : '请先配置 API Token',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFirConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _FirConfigDialog(project: project),
    );
  }

  Future<void> _openUrl(String url) async {
    await _openExternalUrl(url);
  }
}

Future<void> _openExternalUrl(String url) async {
  late final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('cmd.exe', [
      '/c',
      'start',
      '',
      url,
    ], runInShell: true);
  } else if (Platform.isMacOS) {
    result = await Process.run('open', [url]);
  } else {
    result = await Process.run('xdg-open', [url]);
  }
  if (result.exitCode != 0) {
    throw Exception('无法打开页面：$url');
  }
}

class _FirConfigDialog extends ConsumerStatefulWidget {
  const _FirConfigDialog({required this.project});

  final FlutterProject? project;

  @override
  ConsumerState<_FirConfigDialog> createState() => _FirConfigDialogState();
}

class _FirConfigDialogState extends ConsumerState<_FirConfigDialog> {
  late final TextEditingController _apiTokenController;
  late final TextEditingController _appNameController;
  late final TextEditingController _bundleIdController;
  late final TextEditingController _changelogController;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    final config = project?.fir ?? const FirConfig();
    _apiTokenController = TextEditingController(text: config.apiToken);
    _appNameController = TextEditingController(
      text: config.appName.isNotEmpty
          ? config.appName
          : project?.displayName ?? '',
    );
    _bundleIdController = TextEditingController(
      text: config.bundleId.isNotEmpty
          ? config.bundleId
          : project?.bugly.bundleId ?? '',
    );
    _changelogController = TextEditingController(text: config.changelog);
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    _appNameController.dispose();
    _bundleIdController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('fir.im 配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _apiTokenController,
              decoration: InputDecoration(
                labelText: 'API Token',
                hintText: '在 fir.im 个人设置中获取',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '如何获取 API Token',
                  onPressed: () => _showFirApiTokenHelp(context, ref),
                  icon: const Icon(Icons.help_outline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: '应用名称（可选）',
                hintText: '默认使用项目名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bundleIdController,
              decoration: const InputDecoration(
                labelText: 'Bundle ID（可选）',
                hintText: '默认使用项目的 Bundle ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _changelogController,
              decoration: const InputDecoration(
                labelText: '更新日志（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  void _save() {
    final config = FirConfig(
      apiToken: _apiTokenController.text.trim(),
      appName: _appNameController.text.trim(),
      bundleId: _bundleIdController.text.trim(),
      changelog: _changelogController.text.trim(),
      shortCode: widget.project?.fir.shortCode ?? '',
    );
    ref.read(fvmControllerProvider.notifier).updateFirConfig(config);
    Navigator.pop(context);
  }
}

class _PlatformActionChip extends StatelessWidget {
  const _PlatformActionChip({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    onPressed: onPressed,
    backgroundColor: const Color(0xfff7f9fb),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0xffe4e8ec)),
    ),
  );
}

String _formatArtifactSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String _formatArtifactTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

IconData _artifactIcon(DistributionArtifactType type) => switch (type) {
  DistributionArtifactType.apk || DistributionArtifactType.aab => Icons.android,
  DistributionArtifactType.ipa => Icons.apple,
  DistributionArtifactType.hap => Icons.phone_android_outlined,
  DistributionArtifactType.dmg ||
  DistributionArtifactType.pkg => Icons.laptop_mac_outlined,
  DistributionArtifactType.msix ||
  DistributionArtifactType.exe => Icons.window_outlined,
  DistributionArtifactType.zip => Icons.archive_outlined,
};

Color _artifactColor(DistributionArtifactType type) => switch (type) {
  DistributionArtifactType.apk ||
  DistributionArtifactType.aab => const Color(0xff2e7d32),
  DistributionArtifactType.ipa => const Color(0xff455a64),
  DistributionArtifactType.hap => const Color(0xffc62828),
  DistributionArtifactType.dmg ||
  DistributionArtifactType.pkg => const Color(0xff5e35b1),
  DistributionArtifactType.msix ||
  DistributionArtifactType.exe => const Color(0xff1565c0),
  DistributionArtifactType.zip => const Color(0xffef6c00),
};

Future<void> _showPgyerApiKeyHelp(BuildContext context, WidgetRef ref) =>
    _showDistributionCredentialHelp(
      context: context,
      title: '如何获取蒲公英 API Key',
      icon: Icons.cloud_upload_outlined,
      steps: const [
        '1. 登录蒲公英开发者平台。',
        '2. 进入账号设置中的“API 信息”页面。',
        '3. 找到 API Key 并复制到当前输入框。',
        '4. 请勿填写 User Key；上传接口使用的是 API Key。',
      ],
      onOpenPage: ref.read(distributionServiceProvider).openPgyerApiSettings,
    );

Future<void> _showFirApiTokenHelp(BuildContext context, WidgetRef ref) =>
    _showDistributionCredentialHelp(
      context: context,
      title: '如何获取 fir.im API Token',
      icon: Icons.rocket_launch_outlined,
      steps: const [
        '1. 登录 fir.im 开发者平台。',
        '2. 打开个人设置中的“API Token”页面。',
        '3. 复制 API Token，并粘贴到当前输入框。',
        '4. Token 属于敏感信息，请勿提交到项目代码仓库。',
      ],
      onOpenPage: ref.read(distributionServiceProvider).openFirApiTokenSettings,
    );

Future<void> _showDistributionCredentialHelp({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<String> steps,
  required Future<void> Function() onOpenPage,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: Icon(icon),
    title: Text(title),
    content: SizedBox(
      width: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps) ...[Text(step), const SizedBox(height: 9)],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('知道了'),
      ),
      FilledButton.icon(
        onPressed: () async {
          Navigator.pop(dialogContext);
          await onOpenPage();
        },
        icon: const Icon(Icons.open_in_new),
        label: const Text('打开获取页面'),
      ),
    ],
  ),
);
