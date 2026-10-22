import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/project_dependency.dart';
import '../providers.dart';

class PubPackagePicker extends ConsumerStatefulWidget {
  const PubPackagePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.existingNames = const {},
  });
  final List<ProjectDependency> selected;
  final ValueChanged<List<ProjectDependency>> onChanged;
  final bool enabled;
  final Set<String> existingNames;

  @override
  ConsumerState<PubPackagePicker> createState() => _PubPackagePickerState();
}

class _PubPackagePickerState extends ConsumerState<PubPackagePicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  CancelToken? _request;
  List<PubPackage> _results = [];
  final _knownPackages = <String, PubPackage>{};
  bool _loading = false;
  bool _searched = false;
  bool _development = false;
  String? _error;

  @override
  void didUpdateWidget(covariant PubPackagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _debounce?.cancel();
      _request?.cancel();
      _loading = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _request?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!widget.enabled) return;
    _debounce?.cancel();
    _request?.cancel();
    final token = CancelToken();
    _request = token;
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(pubPackageServiceProvider)
          .search(query, cancelToken: token);
      if (mounted && identical(_request, token)) {
        setState(() {
          _results = results;
          for (final package in results) {
            _knownPackages[package.name] = package;
          }
          _searched = true;
        });
      }
    } catch (error) {
      if (mounted &&
          identical(_request, token) &&
          !(error is DioException && CancelToken.isCancel(error))) {
        setState(() => _error = '无法搜索 pub.dev，请检查网络后重试');
      }
    } finally {
      if (mounted && identical(_request, token)) {
        setState(() => _loading = false);
      }
    }
  }

  void _add(PubPackage package) {
    if (widget.existingNames.contains(package.name) ||
        widget.selected.any((dependency) => dependency.name == package.name)) {
      return;
    }
    widget.onChanged([
      ...widget.selected,
      ProjectDependency(
        name: package.name,
        constraint: '^${package.version}',
        development: _development,
      ),
    ]);
  }

  void _update(
    ProjectDependency previous, {
    String? constraint,
    bool? development,
  }) {
    widget.onChanged(
      widget.selected
          .map(
            (dependency) => dependency.name == previous.name
                ? ProjectDependency(
                    name: dependency.name,
                    constraint: constraint ?? dependency.constraint,
                    development: development ?? dependency.development,
                  )
                : dependency,
          )
          .toList(),
    );
  }

  void _remove(String name) => widget.onChanged(
    widget.selected.where((item) => item.name != name).toList(),
  );

  Widget _downloads(int? count) => Row(
    children: [
      const Icon(Icons.download_outlined, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          '近 30 天下载：${count ?? '暂无数据'}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('pub-package-search'),
        controller: _query,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: '搜索 pub.dev 包名',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.arrow_forward),
            onPressed: widget.enabled ? _search : null,
          ),
        ),
        onSubmitted: (_) => _search(),
        onChanged: (_) {
          _debounce?.cancel();
          _request?.cancel();
          _debounce = Timer(const Duration(milliseconds: 450), _search);
        },
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('常规依赖')),
            ButtonSegment(value: true, label: Text('开发依赖')),
          ],
          selected: {_development},
          onSelectionChanged: widget.enabled
              ? (value) => setState(() => _development = value.single)
              : null,
        ),
      ),
      if (_loading) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            IconButton(
              tooltip: '重试搜索',
              onPressed: widget.enabled ? _search : null,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ] else if (!_loading && _searched && _results.isEmpty) ...[
        const SizedBox(height: 12),
        const Text('未找到匹配的包'),
      ],
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: (_results.length * 120.0).clamp(120, 360),
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final package = _results[index];
              final added = widget.selected.any(
                (dependency) => dependency.name == package.name,
              );
              final existing = widget.existingNames.contains(package.name);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  '${package.name}  ${package.version}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      package.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _downloads(package.downloadCount30Days),
                  ],
                ),
                onTap: widget.enabled && !added && !existing
                    ? () => _add(package)
                    : null,
                trailing: IconButton(
                  key: ValueKey(
                    '${added ? 'remove-pub-package-result' : 'add-pub-package'}-${package.name}',
                  ),
                  tooltip: existing
                      ? '项目已添加 ${package.name}'
                      : added
                      ? '删除 ${package.name}'
                      : '添加 ${package.name}',
                  onPressed: widget.enabled && !existing
                      ? () => added ? _remove(package.name) : _add(package)
                      : null,
                  icon: Icon(
                    existing
                        ? Icons.check_circle_outline
                        : added
                        ? Icons.delete_outline
                        : Icons.add,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      if (widget.selected.isNotEmpty) ...[
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            '已选择 ${widget.selected.length} 个依赖',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        for (final dependency in widget.selected)
          Padding(
            key: ValueKey('selected-pub-package-${dependency.name}'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final name = Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            dependency.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          _downloads(
                            _knownPackages[dependency.name]
                                ?.downloadCount30Days,
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: dependency.development,
                      onChanged: widget.enabled
                          ? (value) => _update(dependency, development: value)
                          : null,
                    ),
                    const Text('开发'),
                    IconButton(
                      key: ValueKey('remove-pub-package-${dependency.name}'),
                      tooltip: '删除 ${dependency.name}',
                      onPressed: widget.enabled
                          ? () => _remove(dependency.name)
                          : null,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                );
                final version = TextFormField(
                  key: ValueKey('pub-package-version-${dependency.name}'),
                  initialValue: dependency.constraint,
                  enabled: widget.enabled,
                  decoration: InputDecoration(
                    labelText: '版本约束',
                    errorText: ProjectDependency.validateConstraint(
                      dependency.constraint,
                    ),
                  ),
                  onChanged: (value) => _update(dependency, constraint: value),
                );
                return constraints.maxWidth < 540
                    ? Column(
                        children: [name, const SizedBox(height: 8), version],
                      )
                    : Row(
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: 12),
                          SizedBox(width: 150, child: version),
                        ],
                      );
              },
            ),
          ),
      ],
    ],
  );
}
