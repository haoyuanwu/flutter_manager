part of '../home_page.dart';

class _ProjectManagement extends ConsumerStatefulWidget {
  const _ProjectManagement({
    required this.state,
    required this.onOpenDistribution,
  });

  final FvmState state;
  final ValueChanged<String> onOpenDistribution;

  @override
  ConsumerState<_ProjectManagement> createState() => _ProjectManagementState();
}

class _ProjectManagementState extends ConsumerState<_ProjectManagement> {
  bool _projectListCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(fvmControllerProvider.notifier);
    final selected = state.managedProjects
        .where((project) => project.path == state.selectedManagedProjectPath)
        .firstOrNull;
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
                      '项目管理',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('管理本地 Flutter 项目并执行常用开发、构建命令。'),
                  ],
                ),
              ),

              if (selected != null) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: '选择打开 Flutter 项目的工具',
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '打开 Flutter 项目',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'android_studio_flutter':
                        controller.openInAndroidStudio();
                      case 'vscode':
                        controller.openInVSCode();
                      case 'folder':
                        controller.openProjectFolder();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'android_studio_flutter',
                      child: ListTile(
                        leading: Icon(Icons.android),
                        title: Text('Android Studio 打开 Flutter 项目'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'vscode',
                      child: ListTile(
                        leading: Icon(Icons.code),
                        title: Text('VS Code 打开 Flutter 项目'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'folder',
                      child: ListTile(
                        leading: Icon(Icons.folder_open),
                        title: Text('在文件夹中打开'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (selected.hasAndroid ||
                    selected.hasIos ||
                    selected.hasMacos ||
                    selected.hasWindows) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: '选择原生平台及对应开发工具',
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.developer_mode, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '打开原生项目',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'xcode_ios':
                          controller.openIosProjectInXcode();
                        case 'xcode_macos':
                          controller.openMacosProjectInXcode();
                        case 'android_studio_native':
                          controller.openAndroidProjectInAndroidStudio();
                        case 'visual_studio_windows':
                          controller.openWindowsProjectInVisualStudio();
                      }
                    },
                    itemBuilder: (_) => [
                      if (selected.hasAndroid)
                        const PopupMenuItem(
                          value: 'android_studio_native',
                          child: ListTile(
                            leading: Icon(Icons.android),
                            title: Text('Android · Android Studio'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (selected.hasIos)
                        const PopupMenuItem(
                          value: 'xcode_ios',
                          child: ListTile(
                            leading: Icon(Icons.phone_iphone),
                            title: Text('iOS · Xcode'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (selected.hasMacos)
                        const PopupMenuItem(
                          value: 'xcode_macos',
                          child: ListTile(
                            leading: Icon(Icons.desktop_mac_outlined),
                            title: Text('macOS · Xcode'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (selected.hasWindows)
                        PopupMenuItem(
                          value: 'visual_studio_windows',
                          enabled: Platform.isWindows,
                          child: const ListTile(
                            leading: Icon(Icons.window),
                            title: Text('Windows · Visual Studio'),
                            subtitle: Text('仅可在 Windows 系统打开'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ],

              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FilledButton.icon(
                  onPressed: state.loading
                      ? null
                      : controller.addManagedProject,
                  icon: const Icon(Icons.add),
                  label: const Text('添加项目'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final automaticallyCollapsed = constraints.maxWidth < 860;
                final collapsed =
                    automaticallyCollapsed || _projectListCollapsed;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: collapsed ? 56 : 260,
                      child: collapsed
                          ? _CollapsedProjectList(
                              key: const ValueKey('collapsed-project-list'),
                              state: state,
                              canExpand: !automaticallyCollapsed,
                              onExpand: () =>
                                  setState(() => _projectListCollapsed = false),
                            )
                          : _ProjectList(
                              key: const ValueKey('expanded-project-list'),
                              state: state,
                              onCollapse: () =>
                                  setState(() => _projectListCollapsed = true),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: selected == null
                          ? state.consoleTabs.isEmpty
                                ? const Card(
                                    child: Center(
                                      child: Text('请添加或选择一个 Flutter 项目'),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: _CommandConsole(state: state),
                                  )
                          : _ProjectDetail(
                              state: state,
                              project: selected,
                              onOpenDistribution: widget.onOpenDistribution,
                            ),
                    ),
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

class _ProjectList extends ConsumerStatefulWidget {
  const _ProjectList({
    super.key,
    required this.state,
    required this.onCollapse,
  });

  final FvmState state;
  final VoidCallback onCollapse;

  @override
  ConsumerState<_ProjectList> createState() => _ProjectListState();
}

class _ProjectListState extends ConsumerState<_ProjectList> {
  String? _selectedTag;

  List<FlutterProject> get _filteredProjects {
    if (_selectedTag == null) return widget.state.managedProjects;
    return widget.state.managedProjects
        .where((p) => p.tags.contains(_selectedTag))
        .toList();
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final project in widget.state.managedProjects) {
      tags.addAll(project.tags);
    }
    return tags.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final allTags = _allTags;
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              if (allTags.isNotEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _TagFilterChip(
                          label: '全部',
                          selected: _selectedTag == null,
                          onSelected: () => setState(() => _selectedTag = null),
                        ),
                        ...allTags.map(
                          (tag) => _TagFilterChip(
                            label: tag,
                            selected: _selectedTag == tag,
                            onSelected: () => setState(
                              () => _selectedTag = _selectedTag == tag
                                  ? null
                                  : tag,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                tooltip: '收起项目列表',
                onPressed: widget.onCollapse,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _filteredProjects.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _selectedTag != null
                            ? '没有标签为 "$_selectedTag" 的项目'
                            : '还没有项目记录',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredProjects.length,
                    itemBuilder: (context, index) {
                      final project = _filteredProjects[index];
                      final selected =
                          project.path ==
                          widget.state.selectedManagedProjectPath;
                      return GestureDetector(
                        key: ValueKey(project.path),
                        onSecondaryTapUp: (details) => _showProjectContextMenu(
                          context,
                          project,
                          details.globalPosition,
                        ),
                        child: ListTile(
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: .45),
                          leading: Icon(
                            project.pathExists
                                ? Icons.folder_outlined
                                : Icons.folder_off_outlined,
                            color: project.pathExists ? null : Colors.red,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (project.tags.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                ...project.tags
                                    .take(2)
                                    .map(
                                      (tag) => Padding(
                                        padding: const EdgeInsets.only(left: 2),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              if (project.alias.trim().isNotEmpty) project.name,
                              if (!project.pathExists)
                                '目录不存在'
                              else if (project.fvmVersion == null)
                                '默认 Flutter'
                              else
                                'FVM ${project.fvmVersion}',
                            ].join(' · '),
                          ),
                          trailing: _ProjectMoreMenu(project: project),
                          onTap: () => ref
                              .read(fvmControllerProvider.notifier)
                              .selectManagedProject(project.path),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showProjectContextMenu(
    BuildContext context,
    FlutterProject project,
    Offset position,
  ) {
    final controller = ref.read(fvmControllerProvider.notifier);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: ListTile(
            leading: Icon(Icons.folder_open),
            title: Text('打开项目'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'vscode',
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('在 VS Code 中打开'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'android_studio',
          child: ListTile(
            leading: Icon(Icons.android),
            title: Text('在 Android Studio 中打开'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'folder',
          child: ListTile(
            leading: Icon(Icons.folder),
            title: Text('打开项目文件夹'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('备注名称'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'tags',
          child: ListTile(
            leading: Icon(Icons.label_outline),
            title: Text('管理标签'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('移除项目', style: TextStyle(color: Colors.red)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((action) {
      if (action == null || !context.mounted) return;
      _handleProjectAction(context, controller, project, action);
    });
  }
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    ),
  );
}

class _CollapsedProjectList extends ConsumerWidget {
  const _CollapsedProjectList({
    super.key,
    required this.state,
    required this.canExpand,
    required this.onExpand,
  });

  final FvmState state;
  final bool canExpand;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Column(
      children: [
        if (canExpand)
          IconButton(
            tooltip: '展开项目列表',
            onPressed: onExpand,
            icon: const Icon(Icons.chevron_right),
          ),
        PopupMenuButton<String>(
          tooltip: '选择项目',
          enabled: state.managedProjects.isNotEmpty,
          icon: const Icon(Icons.folder_copy_outlined),
          onSelected: ref
              .read(fvmControllerProvider.notifier)
              .selectManagedProject,
          itemBuilder: (context) => state.managedProjects
              .map(
                (project) => PopupMenuItem(
                  value: project.path,
                  child: Row(
                    children: [
                      Icon(
                        project.pathExists
                            ? Icons.folder_outlined
                            : Icons.folder_off_outlined,
                        color: project.pathExists ? null : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          project.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (project.path == state.selectedManagedProjectPath)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _ProjectMoreMenu extends ConsumerWidget {
  const _ProjectMoreMenu({required this.project});

  final FlutterProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: '更多项目操作',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) => _handleProjectAction(
      context,
      ref.read(fvmControllerProvider.notifier),
      project,
      action,
    ),
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: 'rename',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('备注名称'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'tags',
        child: ListTile(
          leading: Icon(Icons.label_outline),
          title: Text('管理标签'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'run',
        child: ListTile(
          leading: Icon(Icons.play_arrow),
          title: Text('运行项目'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'pub_get',
        child: ListTile(
          leading: Icon(Icons.download),
          title: Text('Pub Get'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'clean',
        child: ListTile(
          leading: Icon(Icons.cleaning_services_outlined),
          title: Text('Clean'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'folder',
        child: ListTile(
          leading: Icon(Icons.folder_open),
          title: Text('打开项目文件夹'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'android_studio',
        child: ListTile(
          leading: Icon(Icons.android),
          title: Text('Android Studio 打开 Flutter 项目'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: 'vscode',
        child: ListTile(
          leading: Icon(Icons.code),
          title: Text('VS Code 打开 Flutter 项目'),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete_outline, color: Colors.red),
          title: Text('移除项目', style: TextStyle(color: Colors.red)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );
}

Future<void> _handleProjectAction(
  BuildContext context,
  FvmController controller,
  FlutterProject project,
  String action,
) async {
  switch (action) {
    case 'rename':
      await _showProjectAliasDialog(context, controller, project);
      return;
    case 'tags':
      await _showTagManagementDialog(context, controller, project);
      return;
    case 'run':
      await controller.selectManagedProject(project.path);
      await controller.runManagedProject();
      return;
    case 'pub_get':
      await controller.selectManagedProject(project.path);
      await controller.projectPubGet();
      return;
    case 'clean':
      await controller.selectManagedProject(project.path);
      await controller.projectClean();
      return;
    case 'folder':
      await controller.openProjectFolderAt(project.path);
      return;
    case 'android_studio':
      await controller.openInAndroidStudioAt(project.path);
      return;
    case 'vscode':
      await controller.openInVSCodeAt(project.path);
      return;
    case 'delete':
      await _confirmRemoveManagedProject(context, controller, project);
      return;
  }
}

Future<void> _showProjectAliasDialog(
  BuildContext context,
  FvmController controller,
  FlutterProject project,
) async {
  final alias = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _ProjectAliasDialog(project: project),
  );
  if (alias != null) await controller.renameManagedProject(project.path, alias);
}

Future<void> _showTagManagementDialog(
  BuildContext context,
  FvmController controller,
  FlutterProject project,
) async {
  final tags = await showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => _TagManagementDialog(project: project),
  );
  if (tags != null) {
    await controller.updateProjectTags(project.path, tags);
  }
}

class _TagManagementDialog extends StatefulWidget {
  const _TagManagementDialog({required this.project});

  final FlutterProject project;

  @override
  State<_TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<_TagManagementDialog> {
  late List<String> _tags;
  final _tagController = TextEditingController();

  static const _presetTags = ['工作', '个人', '实验', '生产', '测试', '重要', '待维护'];

  @override
  void initState() {
    super.initState();
    _tags = [...widget.project.tags];
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty || _tags.contains(normalized)) return;
    setState(() => _tags.add(normalized));
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('管理项目标签'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('预设标签：'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetTags.map((tag) {
              final isSelected = _tags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _addTag(tag);
                  } else {
                    _removeTag(tag);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('自定义标签：'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    hintText: '输入标签名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _addTag,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _addTag(_tagController.text),
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('已选标签：'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _tags),
        child: const Text('保存'),
      ),
    ],
  );
}

class _ProjectAliasDialog extends StatefulWidget {
  const _ProjectAliasDialog({required this.project});

  final FlutterProject project;

  @override
  State<_ProjectAliasDialog> createState() => _ProjectAliasDialogState();
}

class _ProjectAliasDialogState extends State<_ProjectAliasDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    final pathSegments = project.path
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    final defaultAlias = project.alias.trim().isNotEmpty
        ? project.alias
        : pathSegments.isEmpty
        ? project.name
        : pathSegments.last;
    _controller = TextEditingController(text: defaultAlias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('设置项目备注名称'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '备注名称',
          hintText: widget.project.name,
          helperText: '仅保存在 Flutter Manager 中，不会修改项目文件。留空可恢复原名。',
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('保存'),
      ),
    ],
  );
}

class _ProjectDetail extends ConsumerWidget {
  const _ProjectDetail({
    required this.state,
    required this.project,
    required this.onOpenDistribution,
  });

  final FvmState state;
  final FlutterProject project;
  final ValueChanged<String> onOpenDistribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    if (!project.pathExists) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_off_outlined,
                      size: 52,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${project.displayName} 的目录不存在',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(project.path),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              controller.relocateManagedProject(project),
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: const Text('重新定位'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _confirmRemoveManagedProject(
                            context,
                            controller,
                            project,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除记录'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (state.consoleTabs.isNotEmpty) _CommandConsole(state: state),
          ],
        ),
      );
    }
    final targets = _availableTargets(project);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '刷新项目信息',
                        onPressed: state.loading
                            ? null
                            : controller.refreshManagedProject,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: '移除记录（不会删除文件）',
                        onPressed: state.commandRunning
                            ? null
                            : () => _confirmRemoveManagedProject(
                                context,
                                controller,
                                project,
                              ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  SelectableText(
                    project.path,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (project.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(project.description!),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (project.hasAndroid)
                        const Chip(
                          avatar: Icon(Icons.android, size: 18),
                          label: Text('Android'),
                        ),
                      if (project.hasIos) const Chip(label: Text('iOS')),
                      if (project.hasWindows)
                        const Chip(label: Text('Windows')),
                      if (project.hasMacos) const Chip(label: Text('macOS')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProjectFvmSelector(
                    project: project,
                    state: state,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProjectVersionSettings(project: project, state: state),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '运行与调试',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '在新窗口中打开',
                        onPressed: controller.openSelectedProjectConsole,
                        icon: const Icon(Icons.open_in_new, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 320,
                          child: state.devicesLoading
                              ? InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '运行设备（自动监听）',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: Row(
                                    children: const [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '正在连接设备监听…',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                )
                              : state.devices.isNotEmpty
                              ? DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: state.selectedDeviceId,
                                  decoration: const InputDecoration(
                                    labelText: '运行设备（自动监听）',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('自动选择'),
                                    ),
                                    ...state.devices.map(
                                      (d) => DropdownMenuItem(
                                        value: d['id'],
                                        child: Text(
                                          '${d['name']}  (${d['platform']})',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      controller.selectedTaskActive('run')
                                      ? null
                                      : controller.selectDevice,
                                )
                              : InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '运行设备（自动监听）',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  child: const Text(
                                    '未检测到已连接设备',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '重新连接设备监听',
                          onPressed: state.commandRunning
                              ? null
                              : controller.loadDevices,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: controller.selectedTaskActive('run')
                            ? null
                            : controller.runManagedProject,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Flutter Run'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.selectedTaskActive('run')
                            ? controller.hotReloadManagedProject
                            : null,
                        icon: const Icon(Icons.bolt),
                        label: const Text('热重载'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.selectedTaskActive('run')
                            ? controller.hotRestartManagedProject
                            : null,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('热重启'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.selectedTaskActive('run')
                            ? controller.rerunManagedProject
                            : null,
                        icon: const Icon(Icons.replay),
                        label: const Text('Rerun'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            controller.selectedTaskActive('operation') ||
                                controller.selectedTaskActive('build')
                            ? null
                            : controller.projectPubGet,
                        icon: const Icon(Icons.download),
                        label: const Text('Pub Get'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            controller.selectedTaskActive('operation') ||
                                controller.selectedTaskActive('build')
                            ? null
                            : controller.projectClean,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clean'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.openProjectDevTools,
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('DevTools'),
                      ),
                      if (state.consoleTabs.isEmpty &&
                          !state.showMainWindowConsole &&
                          !controller.selectedProjectBuildConsoleVisible)
                        _CommandStopButton(
                          tasks: controller.activeTasksForSelectedProject,
                          controller: controller,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CollapsibleProjectSection(
            key: ValueKey('build-section-${project.path}'),
            title: '构建与打包',
            subtitle: '构建平台、模式、渠道、产物目录及打包操作',
            icon: Icons.inventory_2_outlined,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '构建产物',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ProjectBuildTarget>(
                            isExpanded: true,
                            initialValue:
                                targets.contains(state.projectBuildTarget)
                                ? state.projectBuildTarget
                                : targets.firstOrNull,
                            decoration: const InputDecoration(
                              labelText: '构建平台',
                              border: OutlineInputBorder(),
                            ),
                            items: targets
                                .map(
                                  (target) => DropdownMenuItem(
                                    value: target,
                                    child: Text(_targetLabel(target)),
                                  ),
                                )
                                .toList(),
                            onChanged: controller.selectedTaskActive('build')
                                ? null
                                : (value) {
                                    if (value != null) {
                                      controller.selectProjectBuildTarget(
                                        value,
                                      );
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ProjectBuildMode>(
                            isExpanded: true,
                            initialValue: state.projectBuildMode,
                            decoration: const InputDecoration(
                              labelText: '构建模式',
                              border: OutlineInputBorder(),
                            ),
                            items: ProjectBuildMode.values
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(mode.name),
                                  ),
                                )
                                .toList(),
                            onChanged: controller.selectedTaskActive('build')
                                ? null
                                : (value) {
                                    if (value != null) {
                                      controller.selectProjectBuildMode(value);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (project.androidFlavors.isNotEmpty &&
                        (state.projectBuildTarget == ProjectBuildTarget.apk ||
                            state.projectBuildTarget ==
                                ProjectBuildTarget.appbundle)) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Android 渠道（可多选）',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.selectedAndroidFlavors.isEmpty
                                ? '未选择时构建默认渠道'
                                : '已选择 ${state.selectedAndroidFlavors.length} 个',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: project.androidFlavors
                            .map(
                              (flavor) => FilterChip(
                                label: Text(flavor),
                                selected: state.selectedAndroidFlavors.contains(
                                  flavor,
                                ),
                                onSelected:
                                    controller.selectedTaskActive('build')
                                    ? null
                                    : (_) => controller.toggleAndroidFlavor(
                                        flavor,
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (project.hasAndroid &&
                        (state.projectBuildTarget == ProjectBuildTarget.apk ||
                            state.projectBuildTarget ==
                                ProjectBuildTarget.appbundle)) ...[
                      const SizedBox(height: 10),
                      Text(
                        '检测到 Build Types：${project.androidBuildTypes.join(', ')}'
                        '${project.androidFlavors.isEmpty ? '；未检测到 Product Flavors' : ''}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('构建前执行 Clean + Pub Get'),
                              value: state.cleanBeforeBuild,
                              onChanged: controller.selectedTaskActive('build')
                                  ? null
                                  : controller.setCleanBeforeBuild,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: state.androidTargetPlatform,
                              decoration: const InputDecoration(
                                labelText: 'Android 目标架构',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'android-arm64',
                                  child: Text('arm64-v8a'),
                                ),
                                DropdownMenuItem(
                                  value: 'android-arm',
                                  child: Text('armeabi-v7a'),
                                ),
                                DropdownMenuItem(
                                  value: 'android-arm,android-arm64',
                                  child: Text('32 位 + 64 位'),
                                ),
                                DropdownMenuItem(
                                  value: 'android-x64',
                                  child: Text('x86_64'),
                                ),
                              ],
                              onChanged: controller.selectedTaskActive('build')
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        controller.setAndroidTargetPlatform(
                                          value,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Tooltip(
                          message: switch (state.projectBuildTarget) {
                            ProjectBuildTarget.apk => '打开 APK 目录',
                            ProjectBuildTarget.appbundle => '打开 AAB 目录',
                            ProjectBuildTarget.ios => '打开 iOS 构建目录',
                            ProjectBuildTarget.macos => '打开 macOS 构建目录',
                            ProjectBuildTarget.windows => '打开 Windows 构建目录',
                          },
                          child: IconButton.outlined(
                            key: const ValueKey('open-build-output-button'),
                            onPressed: controller.selectedTaskActive('build')
                                ? null
                                : controller.openBuildOutput,
                            icon: const Icon(Icons.folder_open, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '清理项目 build 目录',
                          child: IconButton.outlined(
                            onPressed:
                                state.loading ||
                                    controller.selectedTaskActive('build')
                                ? null
                                : () => _confirmClearProjectBuildDirectory(
                                    context,
                                    controller,
                                    project,
                                  ),
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                        if (state.projectBuildTarget ==
                            ProjectBuildTarget.macos) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: '打包成 DMG',
                            child: IconButton.outlined(
                              onPressed: controller.selectedTaskActive('build')
                                  ? null
                                  : controller.packageMacosDmg,
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                        if (state.projectBuildTarget ==
                            ProjectBuildTarget.windows) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: '生成安装包（Inno Setup）',
                            child: IconButton.outlined(
                              onPressed:
                                  state.loading ||
                                      controller.selectedTaskActive('build')
                                  ? null
                                  : () => unawaited(
                                      _packageWindowsInstaller(
                                        context,
                                        controller,
                                      ),
                                    ),
                              icon: const Icon(
                                Icons.install_desktop_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '打开构建产物中心',
                          child: IconButton.outlined(
                            onPressed: () => onOpenDistribution(project.path),
                            icon: const Icon(
                              Icons.cloud_upload_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '打包指南',
                          child: IconButton.outlined(
                            onPressed: () => _showPackageGuide(
                              context,
                              state.projectBuildTarget,
                            ),
                            icon: const Icon(Icons.menu_book, size: 18),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              controller.selectedTaskActive('build') ||
                                  targets.isEmpty
                              ? null
                              : controller.buildManagedProject,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: Text(
                            state.selectedAndroidFlavors.length > 1
                                ? '连续构建 ${state.selectedAndroidFlavors.length} 个渠道'
                                : project.bugly.enabled
                                ? '构建并上传 Bugly'
                                : '开始构建',
                          ),
                        ),
                      ],
                    ),
                    if (project.hasAndroid &&
                        (state.projectBuildTarget == ProjectBuildTarget.apk ||
                            state.projectBuildTarget ==
                                ProjectBuildTarget.appbundle)) ...[
                      const Divider(height: 32),
                      _BuglySettings(project: project, state: state),
                    ],
                    if (state.projectBuildTarget == ProjectBuildTarget.apk ||
                        state.projectBuildTarget ==
                            ProjectBuildTarget.appbundle) ...[
                      const Divider(height: 32),
                      _CustomCommandEditor(project: project, state: state),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.consoleTabs.isNotEmpty ||
              state.showMainWindowConsole ||
              controller.selectedProjectBuildConsoleVisible)
            _RevealOnMount(child: _CommandConsole(state: state)),
        ],
      ),
    );
  }

  static List<ProjectBuildTarget> _availableTargets(FlutterProject project) => [
    if (project.hasAndroid) ...[
      ProjectBuildTarget.apk,
      ProjectBuildTarget.appbundle,
    ],
    if (project.hasIos && Platform.isMacOS) ProjectBuildTarget.ios,
    if (project.hasMacos && Platform.isMacOS) ProjectBuildTarget.macos,
    if (project.hasWindows && Platform.isWindows) ProjectBuildTarget.windows,
  ];

  static String _targetLabel(ProjectBuildTarget target) => switch (target) {
    ProjectBuildTarget.apk => 'Android APK',
    ProjectBuildTarget.appbundle => 'Android App Bundle',
    ProjectBuildTarget.ios => 'iOS',
    ProjectBuildTarget.macos => 'macOS',
    ProjectBuildTarget.windows => 'Windows',
  };

  static Future<void> _confirmClearProjectBuildDirectory(
    BuildContext context,
    FvmController controller,
    FlutterProject project,
  ) async {
    final confirmed = await confirmDeletion(
      context,
      title: '确认清理 build 目录？',
      message:
          '将删除项目中的 build 目录，此操作不可撤销。\n\n'
          '${project.path}${Platform.pathSeparator}build',
      confirmLabel: '确认清理',
    );
    if (confirmed) await controller.clearProjectBuildDirectory();
  }

  static void _showPackageGuide(
    BuildContext context,
    ProjectBuildTarget target,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_targetLabel(target)} 打包指南'),
        content: SingleChildScrollView(
          child: switch (target) {
            ProjectBuildTarget.apk ||
            ProjectBuildTarget.appbundle => const _PackageGuideContent(
              steps: [
                (
                  '产物位置',
                  'build/app/outputs/flutter-apk/ (APK) 或 flutter-aab/ (AAB)',
                ),
                (
                  '签名',
                  '正式发布需配置签名密钥：在 android/app/build.gradle 中设置 signingConfigs',
                ),
                (
                  'Play Store',
                  'AAB 格式上传 Google Play Console；APK 可直接分发或上传其他应用市场',
                ),
                ('加固', '可使用 360加固保 / 梆梆安全 等工具对 APK 进行加固后再分发'),
              ],
            ),
            ProjectBuildTarget.ios => const _PackageGuideContent(
              steps: [
                ('产物位置', 'build/ios/archive/ 目录下'),
                (
                  'Xcode 签名',
                  '需在 Xcode 中配置 Team、Bundle Identifier、Provisioning Profile',
                ),
                (
                  '打包 IPA',
                  'Xcode → Product → Archive → Distribute App → 选择分发方式',
                ),
                (
                  'TestFlight',
                  '导出为 App Store Connect 格式，上传后可在 TestFlight 分发测试',
                ),
                ('Ad Hoc', '导出为 Ad Hoc 格式，生成 .ipa 文件，通过蒲公英/Fir 等平台分发'),
              ],
            ),
            ProjectBuildTarget.macos => const _PackageGuideContent(
              steps: [
                ('产物位置', 'build/macos/Build/Products/Release/ 目录下，为 .app 包'),
                ('打包 DMG', '可使用本工具的「打包成 DMG」按钮，或手动用 hdiutil 命令'),
                ('签名公证', '正式分发需进行代码签名和 Apple 公证：codesign + notarytool'),
                ('拖拽安装', 'DMG 内放入 Applications 快捷方式，用户拖拽即可安装'),
                ('Homebrew Cask', '可提交至 homebrew-cask 供用户 brew install 安装'),
              ],
            ),
            ProjectBuildTarget.windows => const _PackageGuideContent(
              steps: [
                (
                  '产物位置',
                  'build/windows/x64/runner/Release/ 目录下，含 .exe 和 DLL 文件',
                ),
                ('Inno Setup', '安装 Inno Setup 后，可使用本工具的「生成安装包」按钮生成 setup.exe'),
                ('NSIS', '或使用 NSIS (Nullsoft Scriptable Install System) 创建安装包'),
                ('MSIX', 'Windows 10+ 推荐 MSIX 格式，可上传 Microsoft Store'),
                ('直接压缩', '最简单方式：将 Release 目录压缩为 .zip 分发'),
              ],
            ),
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmRemoveManagedProject(
  BuildContext context,
  FvmController controller,
  FlutterProject project,
) async {
  final confirmed = await confirmDeletion(
    context,
    title: '确认删除项目记录？',
    message:
        '将从项目管理列表中删除“${project.displayName}”。\n\n'
        '不会删除项目目录或其中的任何文件。\n${project.path}',
    confirmLabel: '删除记录',
  );
  if (confirmed) await controller.removeManagedProject(project.path);
}

Future<void> _packageWindowsInstaller(
  BuildContext context,
  FvmController controller,
) async {
  try {
    await controller.packageWindowsInstaller(rethrowInnoCompilerNotFound: true);
  } on InnoCompilerNotFoundException {
    if (!context.mounted) return;
    final compilerPath = await _showInnoCompilerPickerDialog(context);
    if (compilerPath == null || compilerPath.isEmpty) return;
    await controller.setInnoCompilerPath(compilerPath);
    await controller.packageWindowsInstaller(innoCompilerPath: compilerPath);
  }
}

Future<String?> _showInnoCompilerPickerDialog(BuildContext context) {
  const downloadUrl = 'https://jrsoftware.org/isdl.php#v6';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.install_desktop_outlined),
      title: const Text('指定 Inno Setup 编译器'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('未找到 Inno Setup 编译器 ISCC.exe，请手动选择文件后继续打包。'),
            const SizedBox(height: 12),
            const Text('示例路径：'),
            const SizedBox(height: 6),
            for (final path in InnoCompilerNotFoundException.examplePaths)
              SelectableText(path),
            const SizedBox(height: 12),
            const Text('下载地址：'),
            const SizedBox(height: 6),
            const SelectableText(downloadUrl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        TextButton.icon(
          onPressed: () => unawaited(_openExternalUrl(downloadUrl)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开下载页'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final selected = await openFile(
              acceptedTypeGroups: const [
                XTypeGroup(label: 'Inno Setup 编译器', extensions: ['exe']),
              ],
              confirmButtonText: '选择 ISCC.exe',
            );
            if (selected == null || !dialogContext.mounted) return;
            Navigator.pop(dialogContext, selected.path);
          },
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('浏览选择'),
        ),
      ],
    ),
  );
}

class _ProjectFvmSelector extends StatelessWidget {
  const _ProjectFvmSelector({
    required this.project,
    required this.state,
    required this.controller,
  });

  final FlutterProject project;
  final FvmState state;
  final FvmController controller;

  @override
  Widget build(BuildContext context) {
    final configuredVersion = project.fvmVersion?.trim();
    final matchingSdk = state.installed
        .where(
          (sdk) =>
              sdk.name == configuredVersion ||
              sdk.flutterVersion == configuredVersion,
        )
        .firstOrNull;
    final selectedValue = configuredVersion == null || configuredVersion.isEmpty
        ? ''
        : matchingSdk?.name ?? configuredVersion;
    final installedNames = state.installed.map((sdk) => sdk.name).toSet();
    final missingConfiguredVersion =
        selectedValue.isNotEmpty && !installedNames.contains(selectedValue);
    final disabled =
        !state.fvmInstalled || state.loading || state.commandRunning;

    final statusText = !state.fvmInstalled
        ? '未检测到 FVM，请先完成环境配置'
        : state.installed.isEmpty
        ? '尚无已安装的 Flutter SDK'
        : missingConfiguredVersion
        ? '已配置 Flutter $configuredVersion，但本机未安装'
        : matchingSdk == null
        ? '未配置 .fvmrc，当前使用全局 Flutter'
        : 'Flutter ${matchingSdk.flutterVersion}  ·  Dart ${matchingSdk.dartVersion}';
    final warning =
        !state.fvmInstalled ||
        state.installed.isEmpty ||
        missingConfiguredVersion;

    final selector = Container(
      height: 40,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: warning
              ? Colors.orange.withValues(alpha: .65)
              : const Color(0xffd8dee4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flutter_dash,
            size: 18,
            color: disabled ? Colors.black38 : const Color(0xff087ea4),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                isDense: true,
                menuMaxHeight: 300,
                borderRadius: BorderRadius.circular(10),
                iconSize: 20,
                style: TextStyle(
                  fontSize: 13,
                  color: disabled ? Colors.black38 : Colors.black87,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('使用全局 Flutter'),
                  ),
                  if (missingConfiguredVersion)
                    DropdownMenuItem(
                      value: selectedValue,
                      enabled: false,
                      child: Text('Flutter $configuredVersion（未安装）'),
                    ),
                  ...state.installed.map(
                    (sdk) => DropdownMenuItem(
                      value: sdk.name,
                      child: Text(
                        '${sdk.name}  ·  Flutter ${sdk.flutterVersion}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: disabled
                    ? null
                    : (version) async {
                        if (version == null || version == selectedValue) return;
                        final confirmed = await _confirmProjectFvmChange(
                          context,
                          project: project,
                          currentVersion: configuredVersion,
                          targetVersion: version,
                          installed: state.installed,
                        );
                        if (!confirmed || !context.mounted) return;
                        await controller.setManagedProjectFvmVersion(
                          project.path,
                          version,
                        );
                      },
              ),
            ),
          ),
          if (state.loading) ...[
            const SizedBox(width: 6),
            const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );

    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '项目 Flutter',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          statusText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: warning ? Colors.orange.shade800 : Colors.black54,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff7f9fb),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe4e8ec)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 660) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [description, const SizedBox(height: 8), selector],
            );
          }
          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: selector),
            ],
          );
        },
      ),
    );
  }
}

Future<bool> _confirmProjectFvmChange(
  BuildContext context, {
  required FlutterProject project,
  required String? currentVersion,
  required String targetVersion,
  required List<InstalledSdk> installed,
}) async {
  String displayVersion(String? version) {
    if (version == null || version.isEmpty) return '未配置（使用全局 Flutter）';
    final sdk = installed
        .where((item) => item.name == version || item.flutterVersion == version)
        .firstOrNull;
    return sdk == null
        ? 'Flutter $version'
        : '${sdk.name} · Flutter ${sdk.flutterVersion}';
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.swap_horiz_rounded, color: Colors.orange),
      title: Text(
        targetVersion.isEmpty ? '确认移除项目 FVM 配置？' : '确认切换 Flutter 版本？',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('项目：${project.displayName}'),
            const SizedBox(height: 12),
            Text('当前：${displayVersion(currentVersion)}'),
            const SizedBox(height: 6),
            Text('切换为：${displayVersion(targetVersion)}'),
            const SizedBox(height: 14),
            const Text(
              '确认后将修改项目的 .fvmrc；不会自动执行 Pub Get、Clean 或构建。',
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(targetVersion.isEmpty ? '确认移除' : '确认切换'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _ProjectVersionSettings extends ConsumerStatefulWidget {
  const _ProjectVersionSettings({required this.project, required this.state});

  final FlutterProject project;
  final FvmState state;

  @override
  ConsumerState<_ProjectVersionSettings> createState() =>
      _ProjectVersionSettingsState();
}

class _CollapsibleProjectSection extends StatefulWidget {
  const _CollapsibleProjectSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  State<_CollapsibleProjectSection> createState() =>
      _CollapsibleProjectSectionState();
}

class _CollapsibleProjectSectionState
    extends State<_CollapsibleProjectSection> {
  bool _expanded = false;
  final _contentKey = GlobalKey();

  void _toggle() {
    final expanding = !_expanded;
    setState(() => _expanded = expanding);
    if (expanding) _revealAfterLayout(_contentKey);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: ListTile(
          leading: Icon(widget.icon),
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(widget.subtitle),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: _toggle,
        ),
      ),
      Offstage(
        offstage: !_expanded,
        child: TickerMode(
          enabled: _expanded,
          child: KeyedSubtree(key: _contentKey, child: widget.child),
        ),
      ),
    ],
  );
}

class _RevealOnMount extends StatefulWidget {
  const _RevealOnMount({required this.child});

  final Widget child;

  @override
  State<_RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<_RevealOnMount> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealAfterLayout(_key);
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

void _revealAfterLayout(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.08,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  });
}

class _ProjectVersionSettingsState
    extends ConsumerState<_ProjectVersionSettings> {
  late final TextEditingController _versionController;
  late final TextEditingController _buildNoController;

  @override
  void initState() {
    super.initState();
    _versionController = TextEditingController(
      text: widget.project.bugly.version,
    );
    _buildNoController = TextEditingController(
      text: widget.project.bugly.buildNo,
    );
  }

  @override
  void didUpdateWidget(covariant _ProjectVersionSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.path != widget.project.path ||
        oldWidget.project.bugly.version != widget.project.bugly.version) {
      _versionController.text = widget.project.bugly.version;
    }
    if (oldWidget.project.path != widget.project.path ||
        oldWidget.project.bugly.buildNo != widget.project.bugly.buildNo) {
      _buildNoController.text = widget.project.bugly.buildNo;
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    _buildNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '打包版本',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            '保存后修改项目 pubspec.yaml；Android 若写死版本号，也会同步对应 Gradle 配置。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  key: const ValueKey('project-build-version-field'),
                  controller: _versionController,
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    hintText: '1.2.3',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  key: const ValueKey('project-build-number-field'),
                  controller: _buildNoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Build No',
                    hintText: '1',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: widget.state.loading || widget.state.commandRunning
                    ? null
                    : () => ref
                          .read(fvmControllerProvider.notifier)
                          .updateProjectBuildVersion(
                            _versionController.text,
                            _buildNoController.text,
                          ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存版本'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PackageGuideContent extends StatelessWidget {
  const _PackageGuideContent({required this.steps});
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: steps
        .map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.$2,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _CustomCommandEditor extends ConsumerStatefulWidget {
  const _CustomCommandEditor({required this.project, required this.state});

  final FlutterProject project;
  final FvmState state;

  @override
  ConsumerState<_CustomCommandEditor> createState() =>
      _CustomCommandEditorState();
}

class _CustomCommandEditorState extends ConsumerState<_CustomCommandEditor> {
  static const _template = '''
await runCommand('flutter', [
  'build', 'apk', '--release', '--flavor', '{flavor}',
  '--target-platform', '{targetPlatform}',
]);
''';

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.project.customCommandCode.isEmpty
          ? _template
          : widget.project.customCommandCode,
    );
  }

  @override
  void didUpdateWidget(covariant _CustomCommandEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.path != widget.project.path) {
      _controller.text = widget.project.customCommandCode.isEmpty
          ? _template
          : widget.project.customCommandCode;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(fvmControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '使用自定义 runCommand 工作流',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('只解析并执行 runCommand("命令", [...]) 代码块。'),
          value: widget.project.useCustomCommands,
          onChanged: controller.selectedTaskActive('workflow')
              ? null
              : controller.setUseCustomCommands,
        ),
        if (widget.project.useCustomCommands) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 18,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '执行代码',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            r'占位符：{flavor}、${flavor}、{version}、{buildNo}、{bundleId}、{projectPath}、{targetPlatform}',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    controller.saveCustomCommandCode(_controller.text),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存工作流'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: controller.selectedTaskActive('workflow')
                    ? null
                    : () async {
                        await controller.saveCustomCommandCode(
                          _controller.text,
                        );
                        await controller.runCustomBuildWorkflow();
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('执行自定义工作流'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BuglySettings extends ConsumerWidget {
  const _BuglySettings({required this.project, required this.state});

  final FlutterProject project;
  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final config = project.bugly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '构建后上传 Bugly 符号表',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('仅用于 APK Release；每个选中渠道构建成功后自动执行 Java 上传工具。'),
          value: config.enabled,
          onChanged: controller.selectedTaskActive('build')
              ? null
              : (value) => controller.updateBuglyConfig(
                  config.copyWith(enabled: value),
                ),
        ),
        if (config.enabled) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('bugly-jar-${config.jarPath}'),
            initialValue: config.jarPath,
            decoration: InputDecoration(
              labelText: 'Bugly 上传工具 JAR',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '选择 JAR',
                onPressed: controller.chooseBuglyJar,
                icon: const Icon(Icons.folder_open),
              ),
            ),
            onChanged: (value) =>
                controller.updateBuglyConfig(config.copyWith(jarPath: value)),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _BuglyField(
                    width: width,
                    label: 'App ID',
                    value: config.appId,
                    onChanged: (value) => controller.updateBuglyConfig(
                      config.copyWith(appId: value),
                    ),
                  ),
                  _BuglyField(
                    width: width,
                    label: 'App Key',
                    value: config.appKey,
                    obscureText: true,
                    onChanged: (value) => controller.updateBuglyConfig(
                      config.copyWith(appKey: value),
                    ),
                  ),
                  _BuglyField(
                    width: width,
                    label: 'Bundle ID',
                    value: config.bundleId,
                    onChanged: (value) => controller.updateBuglyConfig(
                      config.copyWith(bundleId: value),
                    ),
                  ),
                  _BuglyField(
                    width: width,
                    label: 'Version',
                    value: config.version,
                    onChanged: (value) => controller.updateBuglyConfig(
                      config.copyWith(version: value),
                    ),
                  ),
                  _BuglyField(
                    width: width,
                    label: 'Build No',
                    value: config.buildNo,
                    onChanged: (value) => controller.updateBuglyConfig(
                      config.copyWith(buildNo: value),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: controller.refreshBuglyFromProject,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('从项目读取'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '配置会保存在本机项目记录中；命令日志不会显示 App Key。',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.saveBuglyConfig,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存配置'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BuglyField extends StatelessWidget {
  const _BuglyField({
    required this.width,
    required this.label,
    required this.value,
    required this.onChanged,
    this.obscureText = false,
  });

  final double width;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextFormField(
      key: ValueKey('$label:$value'),
      initialValue: value,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    ),
  );
}

class _CommandStopButton extends StatelessWidget {
  const _CommandStopButton({required this.tasks, required this.controller});

  final List<({String id, String label})> tasks;
  final FvmController controller;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('结束运行'),
      );
    }
    if (tasks.length == 1) {
      return OutlinedButton.icon(
        onPressed: () => _confirmStopCommand(context, controller, tasks.single),
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('结束运行'),
      );
    }
    return PopupMenuButton<String>(
      tooltip: '选择要结束的命令',
      onSelected: (taskId) {
        final task = tasks.firstWhere((item) => item.id == taskId);
        _confirmStopCommand(context, controller, task);
      },
      itemBuilder: (_) => tasks
          .map(
            (task) => PopupMenuItem<String>(
              value: task.id,
              child: ListTile(
                leading: const Icon(Icons.terminal, size: 20),
                title: Text(task.label),
                subtitle: const Text('选择后仍需确认'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_circle_outlined, size: 18),
            SizedBox(width: 8),
            Text('结束运行'),
            Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmStopCommand(
  BuildContext context,
  FvmController controller,
  ({String id, String label}) task,
) async {
  final confirmed = await confirmDeletion(
    context,
    title: '确认结束运行？',
    message: '将停止“${task.label}”。正在执行的操作会立即中断。',
    confirmLabel: '结束运行',
  );
  if (confirmed) await controller.stopProjectCommand(task.id);
}

class _CommandConsole extends ConsumerStatefulWidget {
  const _CommandConsole({required this.state});

  final FvmState state;

  @override
  ConsumerState<_CommandConsole> createState() => _CommandConsoleState();
}

class _CommandConsoleState extends ConsumerState<_CommandConsole> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchRevealKey = GlobalKey();
  final _logViewportKey = GlobalKey();
  final _logTextKey = GlobalKey();
  List<TextRange> _matches = const [];
  String _searchQuery = '';
  int _currentMatch = -1;
  bool _showSearch = false;
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _CommandConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    final projectChanged =
        oldWidget.state.selectedManagedProjectPath !=
        widget.state.selectedManagedProjectPath;
    final tabChanged =
        oldWidget.state.selectedConsoleTabId !=
        widget.state.selectedConsoleTabId;
    if (oldWidget.state.commandLog != widget.state.commandLog || tabChanged) {
      _refreshMatches(preserveCurrent: !tabChanged);
      if (_stickToBottom || projectChanged || tabChanged) _scrollToBottom();
    }
    if (projectChanged || tabChanged) _stickToBottom = true;
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
      _openSearch();
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
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _openSearch() {
    if (!_showSearch) setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealAfterLayout(_searchRevealKey);
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _matches = const [];
      _currentMatch = -1;
    });
  }

  void _refreshMatches({bool preserveCurrent = false}) {
    final query = _searchController.text;
    final log = widget.state.commandLog;
    final matches = findConsoleMatches(log, query);
    final nextIndex =
        preserveCurrent &&
            query == _searchQuery &&
            _currentMatch < matches.length
        ? _currentMatch
        : -1;
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _matches = matches;
        _currentMatch = nextIndex;
      });
    }
  }

  void _submitSearch() {
    if (_searchController.text != _searchQuery) _refreshMatches();
    _nextMatch();
  }

  void _previousMatch() {
    if (_matches.isEmpty) return;
    setState(() {
      _currentMatch = _currentMatch < 0
          ? _matches.length - 1
          : (_currentMatch - 1 + _matches.length) % _matches.length;
    });
    _scrollToCurrentMatch();
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    setState(() => _currentMatch = (_currentMatch + 1) % _matches.length);
    _scrollToCurrentMatch();
  }

  void _scrollToCurrentMatch() {
    if (_currentMatch < 0 ||
        _currentMatch >= _matches.length ||
        widget.state.commandLog.isEmpty) {
      return;
    }
    _stickToBottom = false;
    revealConsoleMatch(
      textKey: _logTextKey,
      viewportKey: _logViewportKey,
      scrollController: _scrollController,
      match: _matches[_currentMatch],
    );
  }

  List<TextSpan> _consoleSpans(String text) {
    if (_matches.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    var offset = 0;
    for (var index = 0; index < _matches.length; index++) {
      final match = _matches[index];
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: const Color(0xff101820),
            fontWeight: index == _currentMatch
                ? FontWeight.w700
                : FontWeight.w500,
            backgroundColor: index == _currentMatch
                ? const Color(0xffffc857)
                : const Color(0xfffff3a3),
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(fvmControllerProvider.notifier);
    final tasks = controller.activeTasksForSelectedProject;
    final hasRunTask = tasks.any((t) => t.id.startsWith('run::'));
    return Card(
      color: const Color(0xff101820),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tasks.isEmpty ? '命令输出' : '正在执行 ${tasks.length} 个任务',
                  style: const TextStyle(
                    color: Color(0xfff0f6fc),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (hasRunTask) ...[
                  IconButton(
                    tooltip: '清空并重新运行',
                    onPressed: controller.rerunManagedProject,
                    icon: const Icon(Icons.replay, color: Color(0xff9fb0c2)),
                  ),
                ],
                IconButton(
                  tooltip: '搜索日志 (⌘F)',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search, color: Color(0xff9fb0c2)),
                ),
                IconButton(
                  tooltip: '在新窗口中打开当前标签',
                  onPressed: () {
                    final tabId = widget.state.selectedConsoleTabId;
                    if (tabId != null) {
                      controller.openConsoleTabWindow(tabId);
                    } else {
                      controller.openSelectedProjectConsole();
                    }
                  },
                  icon: const Icon(Icons.open_in_new, color: Color(0xff9fb0c2)),
                ),
                IconButton(
                  tooltip: '清空当前标签输出',
                  onPressed: () => _confirmClearCommandLog(controller),
                  icon: const Icon(
                    Icons.delete_sweep,
                    color: Color(0xff9fb0c2),
                  ),
                ),
              ],
            ),
            if (widget.state.consoleTabs.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ConsoleTabBar(state: widget.state, controller: controller),
            ],
            if (_showSearch) ...[
              const SizedBox(height: 8),
              KeyedSubtree(
                key: _searchRevealKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('command-console-search-field'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(color: Color(0xfff0f6fc)),
                        decoration: const InputDecoration(
                          hintText: '搜索打印内容',
                          hintStyle: TextStyle(color: Color(0xff7f8fa3)),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xff9fb0c2),
                          ),
                          filled: true,
                          fillColor: Color(0xff1b2733),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _refreshMatches(),
                        onEditingComplete: () {},
                        onSubmitted: (_) => _submitSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${_matches.length} 处 · '
                      '${_currentMatch + 1}/${_matches.length}',
                      style: const TextStyle(color: Color(0xff9fb0c2)),
                    ),
                    IconButton(
                      tooltip: '上一个结果',
                      onPressed: _matches.isEmpty ? null : _previousMatch,
                      icon: const Icon(Icons.keyboard_arrow_up),
                      color: const Color(0xffd7e0ea),
                    ),
                    IconButton(
                      tooltip: '下一个结果',
                      onPressed: _matches.isEmpty ? null : _nextMatch,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      color: const Color(0xffd7e0ea),
                    ),
                    IconButton(
                      tooltip: '关闭搜索',
                      onPressed: _closeSearch,
                      icon: const Icon(Icons.close),
                      color: const Color(0xffd7e0ea),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: Colors.white24),
            SizedBox(
              key: _logViewportKey,
              height: 360,
              width: double.infinity,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('command-console-output-scroll'),
                  controller: _scrollController,
                  child: SelectableText.rich(
                    TextSpan(
                      children: _consoleSpans(
                        widget.state.commandLog.isEmpty
                            ? '等待执行命令…'
                            : widget.state.commandLog,
                      ),
                    ),
                    key: _logTextKey,
                    style: const TextStyle(
                      color: Color(0xffd7e0ea),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCommandLog(FvmController controller) async {
    final confirmed = await confirmDeletion(
      context,
      title: '确认清空命令输出？',
      message: '将清空当前选中打印台标签中的输出内容，此操作不可撤销。',
      confirmLabel: '清空输出',
    );
    if (confirmed) controller.clearCommandLog();
  }
}

class _ConsoleTabBar extends StatefulWidget {
  const _ConsoleTabBar({required this.state, required this.controller});

  // 深色打印台专用配色，保证标签文字对比度。
  static const _bg = Color(0xff0d141c);
  static const _tabIdle = Color(0xff1b2733);
  static const _tabActive = Color(0xff1f4f8a);
  static const _borderIdle = Color(0xff2f3d4c);
  static const _borderActive = Color(0xff4c9aed);
  static const _textActive = Color(0xfff0f6fc);
  static const _textIdle = Color(0xff9fb0c2);
  static const _running = Color(0xff3fb950);
  static const _closeIdle = Color(0xff7f8fa3);

  final FvmState state;
  final FvmController controller;

  @override
  State<_ConsoleTabBar> createState() => _ConsoleTabBarState();
}

class _ConsoleTabBarState extends State<_ConsoleTabBar> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ConsoleTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedConsoleTabId !=
            oldWidget.state.selectedConsoleTabId &&
        widget.state.consoleTabs.lastOrNull?.id ==
            widget.state.selectedConsoleTabId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tabs = state.consoleTabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _ConsoleTabBar._bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, top: 3, bottom: 9),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.separated(
          key: const ValueKey('console-tabs-horizontal-scroll'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final tab = tabs[index];
            final selected = tab.id == state.selectedConsoleTabId;
            final projectName =
                state.managedProjects
                    .where((project) => project.path == tab.projectPath)
                    .firstOrNull
                    ?.displayName ??
                tab.projectPath.split(Platform.pathSeparator).last;
            return _ConsoleTabChip(
              key: ValueKey(tab.id),
              title: '$projectName · ${tab.title}',
              running: tab.running,
              selected: selected,
              onSelect: () => widget.controller.selectConsoleTab(tab.id),
              onClose: () => widget.controller.closeConsoleTab(tab.id),
            );
          },
        ),
      ),
    );
  }
}

class _ConsoleTabChip extends StatefulWidget {
  const _ConsoleTabChip({
    super.key,
    required this.title,
    required this.running,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final String title;
  final bool running;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  State<_ConsoleTabChip> createState() => _ConsoleTabChipState();
}

class _ConsoleTabChipState extends State<_ConsoleTabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final background = selected
        ? _ConsoleTabBar._tabActive
        : _hovered
        ? const Color(0xff243241)
        : _ConsoleTabBar._tabIdle;
    final borderColor = selected
        ? _ConsoleTabBar._borderActive
        : _hovered
        ? const Color(0xff44586c)
        : _ConsoleTabBar._borderIdle;
    final textColor = selected
        ? _ConsoleTabBar._textActive
        : _ConsoleTabBar._textIdle;
    final closeColor = selected || _hovered
        ? _ConsoleTabBar._textActive
        : _ConsoleTabBar._closeIdle;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: widget.running
                        ? _ConsoleTabBar._running
                        : _ConsoleTabBar._closeIdle,
                    shape: BoxShape.circle,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Tooltip(
                    message: widget.title,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: widget.running ? '停止命令并关闭标签' : '关闭标签',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, size: 13, color: closeColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
