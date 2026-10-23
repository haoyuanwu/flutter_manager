import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/distribution_service.dart';
import '../domain/project_models.dart';
import 'providers.dart';

Future<String?> showProjectApkPicker(
  BuildContext context, {
  required List<FlutterProject> projects,
  String? initialProjectPath,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ProjectApkPicker(
    projects: projects,
    initialProjectPath: initialProjectPath,
  ),
);

class _ProjectApkPicker extends ConsumerStatefulWidget {
  const _ProjectApkPicker({required this.projects, this.initialProjectPath});
  final List<FlutterProject> projects;
  final String? initialProjectPath;
  @override
  ConsumerState<_ProjectApkPicker> createState() => _ProjectApkPickerState();
}

class _ProjectApkPickerState extends ConsumerState<_ProjectApkPicker> {
  String? _project;
  String? _selected;
  List<DistributionArtifact> _apks = [];
  String? _error;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _project =
        widget.projects
            .where((p) => p.path == widget.initialProjectPath)
            .firstOrNull
            ?.path ??
        widget.projects.firstOrNull?.path;
    _scan();
  }

  Future<void> _scan() async {
    final project = _project;
    if (project == null) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _selected = null;
      _error = null;
    });
    try {
      final items = await ref
          .read(distributionServiceProvider)
          .scanArtifacts(project);
      if (mounted && request == _request) {
        setState(() {
          _apks = items
              .where((item) => item.type == DistributionArtifactType.apk)
              .toList();
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = '扫描失败：$error');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择项目已构建的 APK'),
    content: SizedBox(
      width: 720,
      height: (MediaQuery.sizeOf(context).height * .55).clamp(180, 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_project),
                  initialValue: _project,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '项目'),
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project.path,
                        child: Text(
                          project.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _project = value);
                    _scan();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _scan,
                tooltip: '重新扫描安装包',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '扫描项目 build 目录，展示可用于签名的 APK（${_loading ? '扫描中' : _apks.length}）。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _apks.isEmpty
                ? const Center(child: Text('未发现已构建的 APK，请先构建或选择其他项目。'))
                : ListView.separated(
                    itemCount: _apks.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final apk = _apks[index];
                      final selected = apk.path == _selected;
                      return Semantics(
                        selected: selected,
                        child: ListTile(
                          key: ValueKey('project-apk-${apk.path}'),
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          leading: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.android_outlined,
                          ),
                          title: Text(apk.name),
                          subtitle: Text(
                            '${(apk.size / 1048576).toStringAsFixed(1)} MB · ${apk.modified.toLocal().toString().split('.').first}\n${apk.path}',
                          ),
                          onTap: () => setState(() => _selected = apk.path),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('use-project-apk'),
        onPressed: _selected == null || _loading
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('使用此 APK'),
      ),
    ],
  );
}

Future<bool> confirmSigningSourceHandling(
  BuildContext context,
  WidgetRef ref,
  int count,
) async {
  final preferences = ref.read(signingPreferencesProvider);
  if (preferences.rememberChoice) return preferences.replaceSource;
  var remember = false;
  final choice = await showDialog<({bool replace, bool remember})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('签名完成，如何处理源文件？'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count 个 APK 已签名并通过校验。\n保留原文件：签名包留在输出目录。\n覆盖源文件：使用签名包替换源 APK，替换前自动保存 .bak 备份。',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                key: const ValueKey('remember-signing-source-choice'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('以后不再提示，记住本次选择'),
                value: remember,
                onChanged: (value) => setState(() => remember = value ?? false),
              ),
              Text(
                '可在“设置 → APK 签名”中重新开启提示或修改选择。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            key: const ValueKey('keep-signing-source'),
            onPressed: () =>
                Navigator.pop(context, (replace: false, remember: remember)),
            child: const Text('保留原文件'),
          ),
          FilledButton(
            key: const ValueKey('replace-signing-source'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () =>
                Navigator.pop(context, (replace: true, remember: remember)),
            child: const Text('覆盖源文件'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) {
    return false; // Closing the dialog is never consent to replace.
  }
  try {
    await ref
        .read(signingPreferencesProvider.notifier)
        .update(rememberChoice: choice.remember, replaceSource: choice.replace);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('本次选择已生效，但无法记住设置：$error')));
    }
  }
  return choice.replace;
}
