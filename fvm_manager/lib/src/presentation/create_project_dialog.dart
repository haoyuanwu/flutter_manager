import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/project_creation_options.dart';
import '../domain/project_dependency.dart';
import '../domain/project_models.dart';
import 'providers.dart';
import 'widgets/pub_package_picker.dart';

Future<void> showCreateProjectDialog(BuildContext context, FvmState state) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateProjectDialog(state: state),
    );

class CreateProjectDialog extends ConsumerStatefulWidget {
  const CreateProjectDialog({super.key, required this.state});
  final FvmState state;

  @override
  ConsumerState<CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<CreateProjectDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'flutter_app');
  final _folder = TextEditingController(text: 'flutter_app');
  final _parent = TextEditingController();
  final _description = TextEditingController(text: 'A new Flutter project.');
  final _organization = TextEditingController(text: 'com.example');
  final _alias = TextEditingController();
  final _version = TextEditingController(text: '1.0.0');
  final _build = TextEditingController(text: '1');
  final _sample = TextEditingController();
  final _logScroll = ScrollController();
  int _step = 0;
  FlutterProjectTemplate _template = FlutterProjectTemplate.app;
  FlutterAppStarter _starter = FlutterAppStarter.standard;
  final _platforms = <String>{
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
  };
  String _sdkDirectory = '';
  String _androidLanguage = 'kotlin';
  bool _pinSdk = true;
  bool _pubGet = true;
  bool _offline = false;
  bool _folderEdited = false;
  bool _creating = false;
  bool _stopping = false;
  String _log = '';
  String? _error;
  FlutterProject? _createdProject;
  List<ProjectDependency> _dependencies = [];

  List<InstalledSdk> get _sdks {
    final seen = <String>{};
    return widget.state.installed
        .where((sdk) => sdk.directory.isNotEmpty && seen.add(sdk.directory))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final selected = widget.state.managedProjects
        .where((p) => p.path == widget.state.selectedManagedProjectPath)
        .firstOrNull;
    final recent = selected ?? widget.state.managedProjects.firstOrNull;
    final recentParent = recent == null ? null : Directory(recent.path).parent;
    _parent.text = recentParent != null && recentParent.existsSync()
        ? recentParent.path
        : Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ??
              Directory.current.path;
    var suggestion = 'flutter_app';
    for (
      var index = 2;
      FileSystemEntity.typeSync(
            '${_parent.text}${Platform.pathSeparator}$suggestion',
          ) !=
          FileSystemEntityType.notFound;
      index++
    ) {
      suggestion = 'flutter_app_$index';
    }
    _name.text = suggestion;
    _folder.text = suggestion;
    final preferred =
        _sdks
            .where((sdk) => sdk.name == widget.state.globalVersion)
            .firstOrNull ??
        _sdks.firstOrNull;
    _sdkDirectory = preferred?.directory ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _folder,
      _parent,
      _description,
      _organization,
      _alias,
      _version,
      _build,
      _sample,
    ]) {
      controller.dispose();
    }
    _logScroll.dispose();
    super.dispose();
  }

  ProjectCreationOptions _options({bool skipDependencies = false}) {
    final sdk = _sdks
        .where((sdk) => sdk.directory == _sdkDirectory)
        .firstOrNull;
    return ProjectCreationOptions(
      name: _name.text.trim(),
      directoryName: _folder.text.trim(),
      parentDirectory: _parent.text.trim(),
      alias: _alias.text,
      description: _description.text.trim(),
      organization: _organization.text.trim(),
      template: _template,
      platforms: _platforms.toList(),
      androidLanguage: _androidLanguage,
      starter: _starter,
      sampleId: _sample.text,
      pubGet: _pubGet,
      offline: _offline,
      version: _version.text.trim(),
      buildNumber: _build.text.trim(),
      sdkDirectory: sdk?.directory,
      sdkVersion: sdk?.name,
      pinSdk: _pinSdk,
      dependencies: skipDependencies ? const [] : _dependencies,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canEdit = !_creating && _createdProject == null;
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !_creating,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 760,
          height: (size.height - 64).clamp(320, 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
                child: Row(
                  children: [
                    const Icon(Icons.create_new_folder_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '创建 Flutter 项目',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _step == 0 ? '1 / 2 · 项目配置' : '2 / 2 · 添加依赖（可选）',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _creating
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: IndexedStack(
                  index: _step,
                  sizing: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      key: const ValueKey('create-project-configuration'),
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _form,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _pair(
                              TextFormField(
                                key: const ValueKey('create-project-name'),
                                controller: _name,
                                enabled: canEdit,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: '项目名称',
                                  hintText: 'flutter_app',
                                ),
                                validator: ProjectCreationOptions.validateName,
                                onChanged: (value) {
                                  setState(() {
                                    if (!_folderEdited) _folder.text = value;
                                  });
                                },
                              ),
                              TextFormField(
                                controller: _alias,
                                enabled: canEdit,
                                decoration: const InputDecoration(
                                  labelText: '备注名称（可选）',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('create-project-parent'),
                              controller: _parent,
                              enabled: canEdit,
                              decoration: InputDecoration(
                                labelText: '保存位置',
                                suffixIcon: IconButton(
                                  tooltip: '选择保存位置',
                                  onPressed: canEdit ? _chooseParent : null,
                                  icon: const Icon(Icons.folder_open),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? '请选择保存位置'
                                  : null,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('create-project-folder'),
                              controller: _folder,
                              enabled: canEdit,
                              decoration: const InputDecoration(
                                labelText: '项目文件夹',
                              ),
                              validator:
                                  ProjectCreationOptions.validateDirectoryName,
                              onChanged: (_) =>
                                  setState(() => _folderEdited = true),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              '${_parent.text}${Platform.pathSeparator}${_folder.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _pair(
                              DropdownButtonFormField<String>(
                                initialValue: _sdkDirectory,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Flutter SDK',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('系统默认 Flutter'),
                                  ),
                                  ..._sdks.map(
                                    (sdk) => DropdownMenuItem(
                                      value: sdk.directory,
                                      child: Text(
                                        '${sdk.name} · Flutter ${sdk.flutterVersion}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: canEdit
                                    ? (value) => setState(
                                        () => _sdkDirectory = value ?? '',
                                      )
                                    : null,
                              ),
                              DropdownButtonFormField<FlutterProjectTemplate>(
                                key: const ValueKey('create-project-template'),
                                initialValue: _template,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '项目模板',
                                ),
                                items: FlutterProjectTemplate.values
                                    .map(
                                      (template) => DropdownMenuItem(
                                        value: template,
                                        child: Text(template.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: canEdit ? _changeTemplate : null,
                              ),
                            ),
                            if (_sdkDirectory.isNotEmpty)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('固定所选 Flutter 版本（FVM）'),
                                value: _pinSdk,
                                onChanged: canEdit
                                    ? (value) =>
                                          setState(() => _pinSdk = value!)
                                    : null,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            const SizedBox(height: 16),
                            _pair(
                              TextFormField(
                                controller: _organization,
                                enabled: canEdit,
                                decoration: const InputDecoration(
                                  labelText: '组织标识',
                                  hintText: 'com.example',
                                ),
                                validator:
                                    ProjectCreationOptions.validateOrganization,
                              ),
                              TextFormField(
                                controller: _description,
                                enabled: canEdit,
                                decoration: const InputDecoration(
                                  labelText: '项目描述',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? '请填写项目描述'
                                    : null,
                              ),
                            ),
                            if (_template.supportsPlatforms) ...[
                              const SizedBox(height: 20),
                              const Text(
                                '目标平台',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final entry in const {
                                    'android': 'Android',
                                    'ios': 'iOS',
                                    'web': 'Web',
                                    'windows': 'Windows',
                                    'macos': 'macOS',
                                    'linux': 'Linux',
                                    'darwin': 'iOS + macOS（共享）',
                                  }.entries)
                                    if ((entry.key != 'darwin' ||
                                            _template ==
                                                FlutterProjectTemplate
                                                    .plugin) &&
                                        (entry.key != 'web' ||
                                            _template !=
                                                FlutterProjectTemplate
                                                    .pluginFfi))
                                      FilterChip(
                                        label: Text(entry.value),
                                        selected: _platforms.contains(
                                          entry.key,
                                        ),
                                        onSelected: canEdit
                                            ? (selected) => _togglePlatform(
                                                entry.key,
                                                selected,
                                              )
                                            : null,
                                      ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 8),
                              title: const Text(
                                '高级设置',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                _pair(
                                  TextFormField(
                                    controller: _version,
                                    enabled: canEdit,
                                    decoration: const InputDecoration(
                                      labelText: '初始版本',
                                    ),
                                    validator: (value) =>
                                        RegExp(
                                          r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
                                        ).hasMatch(value?.trim() ?? '')
                                        ? null
                                        : '例如 1.0.0',
                                  ),
                                  TextFormField(
                                    controller: _build,
                                    enabled: canEdit,
                                    decoration: const InputDecoration(
                                      labelText: 'Build No',
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) =>
                                        RegExp(
                                          r'^[1-9]\d*$',
                                        ).hasMatch(value?.trim() ?? '')
                                        ? null
                                        : '请输入正整数',
                                  ),
                                ),
                                if (_template.supportsAndroidLanguage &&
                                    (_template ==
                                            FlutterProjectTemplate.module ||
                                        _platforms.contains('android'))) ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    initialValue: _androidLanguage,
                                    decoration: const InputDecoration(
                                      labelText: 'Android 原生语言',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'kotlin',
                                        child: Text('Kotlin'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'java',
                                        child: Text('Java'),
                                      ),
                                    ],
                                    onChanged: canEdit
                                        ? (value) => setState(
                                            () => _androidLanguage = value!,
                                          )
                                        : null,
                                  ),
                                ],
                                if (_template ==
                                    FlutterProjectTemplate.app) ...[
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<FlutterAppStarter>(
                                    key: const ValueKey(
                                      'create-project-starter',
                                    ),
                                    initialValue: _starter,
                                    decoration: const InputDecoration(
                                      labelText: '初始内容',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: FlutterAppStarter.standard,
                                        child: Text('默认计数器应用'),
                                      ),
                                      DropdownMenuItem(
                                        value: FlutterAppStarter.empty,
                                        child: Text('空白应用'),
                                      ),
                                      DropdownMenuItem(
                                        value: FlutterAppStarter.sample,
                                        child: Text('Flutter 官方示例'),
                                      ),
                                    ],
                                    onChanged: canEdit
                                        ? (value) =>
                                              setState(() => _starter = value!)
                                        : null,
                                  ),
                                  if (_starter == FlutterAppStarter.sample) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _sample,
                                      enabled: canEdit,
                                      decoration: const InputDecoration(
                                        labelText: '示例 ID',
                                        hintText:
                                            'widgets.SingleChildScrollView.1',
                                      ),
                                      validator: (value) =>
                                          RegExp(
                                            r'^[a-zA-Z0-9_.-]+$',
                                          ).hasMatch(value?.trim() ?? '')
                                          ? null
                                          : '请填写官方示例 ID',
                                    ),
                                  ],
                                ],
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('创建后获取依赖'),
                                  value: _pubGet,
                                  onChanged: canEdit
                                      ? (value) =>
                                            setState(() => _pubGet = value!)
                                      : null,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('离线获取依赖'),
                                  value: _offline,
                                  onChanged: canEdit && _pubGet
                                      ? (value) =>
                                            setState(() => _offline = value!)
                                      : null,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      key: const ValueKey('create-project-dependencies'),
                      padding: const EdgeInsets.all(24),
                      child: PubPackagePicker(
                        selected: _dependencies,
                        enabled: canEdit && _step == 1,
                        onChanged: (dependencies) =>
                            setState(() => _dependencies = dependencies),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const ValueKey('create-project-error'),
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ),
              ],
              if (_log.isNotEmpty) ...[
                Container(
                  height: size.height < 700 ? 90 : 150,
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    controller: _logScroll,
                    child: SelectableText(
                      _log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _creating
                          ? (_stopping ? null : _stop)
                          : () => Navigator.pop(context),
                      child: Text(
                        _creating ? (_stopping ? '停止中…' : '停止创建') : '取消',
                      ),
                    ),
                    if (_step == 1 && _createdProject == null)
                      TextButton.icon(
                        key: const ValueKey('create-project-back'),
                        onPressed: canEdit
                            ? () => setState(() => _step = 0)
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('上一步'),
                      ),
                    if (_step == 1 && _createdProject == null)
                      TextButton(
                        onPressed: _creating
                            ? null
                            : () => _submit(skipDependencies: true),
                        child: const Text('跳过依赖，直接创建'),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('create-project-submit'),
                      onPressed: _creating ? null : _submit,
                      icon: _creating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.create_new_folder_outlined,
                              size: 18,
                            ),
                      label: Text(
                        _creating
                            ? '创建中…'
                            : _createdProject != null
                            ? '加入项目管理'
                            : _step == 0
                            ? '直接创建'
                            : '创建并加入',
                      ),
                    ),
                    if (_step == 0 && _createdProject == null)
                      FilledButton.icon(
                        key: const ValueKey('create-project-next'),
                        onPressed: canEdit ? _next : null,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('下一步：添加依赖'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 540
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
  );

  void _next() {
    if (!_form.currentState!.validate()) return;
    try {
      _options(skipDependencies: true).validate();
      FocusScope.of(context).unfocus();
      setState(() {
        _step = 1;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  void _changeTemplate(FlutterProjectTemplate? template) {
    if (template == null) return;
    setState(() {
      _template = template;
      if (template != FlutterProjectTemplate.plugin &&
          _platforms.remove('darwin')) {
        _platforms.addAll(['ios', 'macos']);
      }
      if (template == FlutterProjectTemplate.pluginFfi) {
        _platforms.remove('web');
      }
    });
  }

  void _togglePlatform(String platform, bool selected) => setState(() {
    if (selected) {
      _platforms.add(platform);
      if (platform == 'darwin') _platforms.removeAll(['ios', 'macos']);
      if (platform == 'ios' || platform == 'macos') _platforms.remove('darwin');
    } else {
      _platforms.remove(platform);
    }
  });

  Future<void> _chooseParent() async {
    try {
      final path = await getDirectoryPath(confirmButtonText: '在此创建项目');
      if (path != null && mounted) setState(() => _parent.text = path);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _appendOutput(String output) {
    if (!mounted) return;
    setState(() {
      _log += output;
      if (_log.length > 48000) _log = _log.substring(_log.length - 48000);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    try {
      await ref.read(flutterProjectCreationServiceProvider).cancel();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _stopping = false;
        });
      }
    }
  }

  Future<void> _submit({bool skipDependencies = false}) async {
    if (_createdProject == null && !_form.currentState!.validate()) {
      setState(() => _step = 0);
      return;
    }
    try {
      if (_createdProject == null) {
        _options(skipDependencies: skipDependencies).validate();
      }
      setState(() {
        _creating = true;
        _stopping = false;
        _error = null;
      });
      if (_createdProject == null) {
        _log = '';
        _createdProject = await ref
            .read(flutterProjectCreationServiceProvider)
            .create(
              _options(skipDependencies: skipDependencies),
              onOutput: _appendOutput,
            );
      }
      await ref
          .read(fvmControllerProvider.notifier)
          .registerCreatedProject(_createdProject!);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst(
            RegExp(r'^(Exception|Invalid argument\(s\)):\s*'),
            '',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
          _stopping = false;
        });
      }
    }
  }
}
