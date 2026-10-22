import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_dependency_service.dart';
import '../domain/models.dart';
import '../domain/project_dependency.dart';
import 'providers.dart';
import 'widgets/pub_package_picker.dart';
import 'widgets/workbench_panel.dart';

Future<void> showProjectDependenciesDialog(
  BuildContext context,
  FvmState state,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProjectDependenciesDialog(
    initialProjectPath: state.selectedManagedProjectPath,
  ),
);

class ProjectDependenciesDialog extends ConsumerStatefulWidget {
  const ProjectDependenciesDialog({super.key, this.initialProjectPath});
  final String? initialProjectPath;

  @override
  ConsumerState<ProjectDependenciesDialog> createState() =>
      _ProjectDependenciesDialogState();
}

class _ProjectDependenciesDialogState
    extends ConsumerState<ProjectDependenciesDialog> {
  final _filterController = TextEditingController();
  String? _projectPath;
  ProjectDependencySnapshot? _snapshot;
  List<ProjectDependency> _additions = [];
  final Set<String> _removals = {};
  bool _loading = true;
  bool _saving = false;
  bool _pubGetPending = false;
  int _loadGeneration = 0;
  int _selectionRevision = 0;
  String? _error;

  bool get _dirty => _additions.isNotEmpty || _removals.isNotEmpty;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final projects = ref
        .read(fvmControllerProvider)
        .managedProjects
        .where((project) => project.pathExists)
        .toList();
    _projectPath =
        projects.any((project) => project.path == widget.initialProjectPath)
        ? widget.initialProjectPath
        : projects.firstOrNull?.path;
    _load();
  }

  Future<void> _load() async {
    final path = _projectPath;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _snapshot = null;
      _error = null;
      _additions = [];
      _removals.clear();
      _pubGetPending = false;
      _filterController.clear();
    });
    try {
      if (path == null) throw StateError('请先添加一个有效的 Flutter 项目');
      final snapshot = await ref
          .read(projectDependencyServiceProvider)
          .load(path);
      if (mounted && generation == _loadGeneration) {
        setState(() => _snapshot = snapshot);
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty && !_pubGetPending) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('切换或重新读取项目？'),
            content: Text(
              _dirty ? '未保存的依赖变更将被丢弃。' : '依赖已保存，但该项目的 Pub Get 尚未完成。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _switchProject(String? path) async {
    if (path == null || path == _projectPath || _saving) return;
    final confirmed = await _confirmDiscard();
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _selectionRevision++);
      return;
    }
    setState(() => _projectPath = path);
    await _load();
  }

  Future<void> _reload() async {
    if (await _confirmDiscard() && mounted) await _load();
  }

  Future<void> _save() async {
    final snapshot = _snapshot;
    if (snapshot == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(fvmControllerProvider.notifier)
          .updateProjectDependencies(
            snapshot,
            additions: List.of(_additions),
            removals: Set.of(_removals),
          );
      if (!mounted) return;
      setState(() {
        _snapshot = saved;
        _additions = [];
        _removals.clear();
        _pubGetPending = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('依赖已保存，Pub Get 已完成')));
    } on DependencySyncException catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = error.snapshot;
        _additions = [];
        _removals.clear();
        _pubGetPending = true;
        _error = error.toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _stop() async {
    if (!_saving) return;
    final path = _projectPath;
    if (path == null) return;
    try {
      await ref.read(fvmControllerProvider.notifier).stopDependencySync(path);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Widget _installed() {
    final dependencies = _snapshot?.dependencies ?? [];
    final query = _filterController.text.trim().toLowerCase();
    final filtered = dependencies
        .where(
          (dependency) => '${dependency.name} ${dependency.description}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
    return WorkbenchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已添加依赖 · ${dependencies.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '重新读取 pubspec.yaml',
                  onPressed: _saving || _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _filterController,
              enabled: !_saving && !_loading,
              decoration: const InputDecoration(
                hintText: '筛选已添加依赖',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(child: Text(query.isEmpty ? '暂无已添加依赖' : '没有匹配的依赖'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dependency = filtered[index];
                      final removed = _removals.contains(dependency.key);
                      final colors = Theme.of(context).colorScheme;
                      return ListTile(
                        key: ValueKey('installed-dependency-${dependency.key}'),
                        title: Text(
                          dependency.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            decoration: removed
                                ? TextDecoration.lineThrough
                                : null,
                            color: removed ? colors.error : colors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${dependency.development ? '开发依赖' : '常规依赖'} · ${dependency.description}${removed ? ' · 待删除' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: !dependency.removable
                              ? 'Flutter SDK 核心依赖不能删除'
                              : removed
                              ? '撤销删除 ${dependency.name}'
                              : '删除 ${dependency.name}',
                          onPressed: _saving || !dependency.removable
                              ? null
                              : () => setState(() {
                                  if (removed) {
                                    _removals.remove(dependency.key);
                                    _additions = _additions
                                        .where(
                                          (item) =>
                                              item.name != dependency.name,
                                        )
                                        .toList();
                                  } else {
                                    _removals.add(dependency.key);
                                  }
                                }),
                          icon: Icon(
                            !dependency.removable
                                ? Icons.lock_outline
                                : removed
                                ? Icons.undo
                                : Icons.delete_outline,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _search() => WorkbenchPanel(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PubPackagePicker(
        key: ValueKey('manage-dependencies-picker-$_projectPath'),
        selected: _additions,
        existingNames: {
          for (final dependency
              in _snapshot?.dependencies ?? <InstalledProjectDependency>[])
            if (!_removals.contains(dependency.key)) dependency.name,
        },
        enabled: !_loading && !_saving && _snapshot != null,
        onChanged: (value) => setState(() => _additions = value),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final projects = ref
        .watch(fvmControllerProvider.select((state) => state.managedProjects))
        .where((project) => project.pathExists)
        .toList();
    final valid = _additions.every(
      (item) => ProjectDependency.validateConstraint(item.constraint) == null,
    );
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 1120,
          height: math.min(
            840,
            math.max(360, MediaQuery.sizeOf(context).height - 80),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '管理项目依赖',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'dependency-project-$_projectPath-$_selectionRevision',
                  ),
                  initialValue:
                      projects.any((project) => project.path == _projectPath)
                      ? _projectPath
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '项目',
                    prefixIcon: Icon(Icons.workspaces_outline),
                  ),
                  items: [
                    for (final project in projects)
                      DropdownMenuItem(
                        value: project.path,
                        child: Text(
                          '${project.displayName} · ${project.path}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving ? null : _switchProject,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: SingleChildScrollView(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 820) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _installed()),
                            const SizedBox(width: 16),
                            Expanded(child: _search()),
                          ],
                        );
                      }
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: '已添加依赖'),
                                Tab(text: '搜索添加'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                children: [_installed(), _search()],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _saving
                            ? '正在保存并执行 Pub Get…'
                            : '待添加 ${_additions.length} · 待删除 ${_removals.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_saving) ...[
                      OutlinedButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('停止'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('save-project-dependencies'),
                      onPressed:
                          !_saving &&
                              !_loading &&
                              _snapshot != null &&
                              valid &&
                              (_dirty || _pubGetPending)
                          ? _save
                          : null,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _pubGetPending && !_dirty
                            ? '重试 Pub Get'
                            : '保存并 Pub Get',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
