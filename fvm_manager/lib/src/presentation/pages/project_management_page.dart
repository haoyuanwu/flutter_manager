part of '../home_page.dart';

class _ProjectManagement extends ConsumerWidget {
  const _ProjectManagement({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              FilledButton.icon(
                onPressed: state.loading ? null : controller.addManagedProject,
                icon: const Icon(Icons.add),
                label: const Text('添加项目'),
              ),
              if (selected != null) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: '用外部工具打开项目',
                  icon: const Icon(Icons.open_in_new),
                  onSelected: (value) {
                    switch (value) {
                      case 'folder':
                        controller.openProjectFolder();
                      case 'android_studio':
                        controller.openInAndroidStudio();
                      case 'vscode':
                        controller.openInVSCode();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'folder',
                      child: ListTile(
                        leading: Icon(Icons.folder_open),
                        title: Text('打开项目文件夹'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'android_studio',
                      child: ListTile(
                        leading: Icon(Icons.android),
                        title: Text('用 Android Studio 打开'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'vscode',
                      child: ListTile(
                        leading: Icon(Icons.code),
                        title: Text('用 VS Code 打开'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 260, child: _ProjectList(state: state)),
                const SizedBox(width: 16),
                Expanded(
                  child: selected == null
                      ? const Card(
                          child: Center(child: Text('请添加或选择一个 Flutter 项目')),
                        )
                      : _ProjectDetail(state: state, project: selected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectList extends ConsumerWidget {
  const _ProjectList({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: state.managedProjects.isEmpty
        ? const Center(
            child: Padding(padding: EdgeInsets.all(20), child: Text('还没有项目记录')),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.managedProjects.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final project = state.managedProjects[index];
              final selected = project.path == state.selectedManagedProjectPath;
              return ListTile(
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
                title: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  !project.pathExists
                      ? '目录不存在'
                      : project.fvmVersion == null
                      ? '默认 Flutter'
                      : 'FVM ${project.fvmVersion}',
                ),
                onTap: () => ref
                    .read(fvmControllerProvider.notifier)
                    .selectManagedProject(project.path),
              );
            },
          ),
  );
}

class _ProjectDetail extends ConsumerWidget {
  const _ProjectDetail({required this.state, required this.project});

  final FvmState state;
  final FlutterProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    if (!project.pathExists) {
      return Card(
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
                '${project.name} 的目录不存在',
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
                    onPressed: () => controller.relocateManagedProject(project),
                    icon: const Icon(Icons.drive_file_move_outline),
                    label: const Text('重新定位'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.removeManagedProject(project.path),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除记录'),
                  ),
                ],
              ),
            ],
          ),
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
                          project.name,
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
                            : () =>
                                  controller.removeManagedProject(project.path),
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
                      Chip(
                        avatar: const Icon(Icons.flutter_dash, size: 18),
                        label: Text(project.fvmVersion ?? '系统 Flutter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '常用命令',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                                    labelText: '运行设备',
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
                                        '正在检测设备…',
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
                                    labelText: '运行设备',
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
                                  onChanged: state.commandRunning
                                      ? null
                                      : controller.selectDevice,
                                )
                              : InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '运行设备',
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
                          tooltip: '刷新设备列表',
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
                        onPressed: state.commandRunning
                            ? null
                            : controller.runManagedProject,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Flutter Run'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            state.commandRunning &&
                                state.activeCommand == '运行项目'
                            ? controller.hotReloadManagedProject
                            : null,
                        icon: const Icon(Icons.bolt),
                        label: const Text('热重载'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            state.commandRunning &&
                                state.activeCommand == '运行项目'
                            ? controller.hotRestartManagedProject
                            : null,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('热重启'),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.commandRunning
                            ? null
                            : controller.projectPubGet,
                        icon: const Icon(Icons.download),
                        label: const Text('Pub Get'),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.commandRunning
                            ? null
                            : controller.projectClean,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clean'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '构建产物',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                          onChanged: state.commandRunning
                              ? null
                              : (value) {
                                  if (value != null) {
                                    controller.selectProjectBuildTarget(value);
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
                          onChanged: state.commandRunning
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
                              onSelected: state.commandRunning
                                  ? null
                                  : (_) =>
                                        controller.toggleAndroidFlavor(flavor),
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
                            onChanged: state.commandRunning
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
                            onChanged: state.commandRunning
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
                      OutlinedButton.icon(
                        onPressed: state.commandRunning
                            ? null
                            : controller.openBuildOutput,
                        icon: const Icon(Icons.folder_open),
                        label: Text(switch (state.projectBuildTarget) {
                          ProjectBuildTarget.apk => '打开 APK 目录',
                          ProjectBuildTarget.appbundle => '打开 AAB 目录',
                          ProjectBuildTarget.ios => '打开 iOS 构建目录',
                          ProjectBuildTarget.macos => '打开 macOS 构建目录',
                          ProjectBuildTarget.windows => '打开 Windows 构建目录',
                        }),
                      ),
                      if (state.projectBuildTarget ==
                          ProjectBuildTarget.macos) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: state.commandRunning
                              ? null
                              : controller.packageMacosDmg,
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('打包成 DMG'),
                        ),
                      ],
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showPackageGuide(
                          context,
                          state.projectBuildTarget,
                        ),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('打包指南'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: state.commandRunning || targets.isEmpty
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (project.hasAndroid &&
              (state.projectBuildTarget == ProjectBuildTarget.apk ||
                  state.projectBuildTarget ==
                      ProjectBuildTarget.appbundle)) ...[
            _BuglySettings(project: project, state: state),
            const SizedBox(height: 12),
          ],
          if (state.projectBuildTarget == ProjectBuildTarget.apk ||
              state.projectBuildTarget == ProjectBuildTarget.appbundle) ...[
            _CustomCommandEditor(project: project, state: state),
            const SizedBox(height: 12),
          ],
          _CommandConsole(state: state),
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
                (
                  'Inno Setup',
                  '下载 Inno Setup，创建安装脚本将整个 Release 目录打包为安装程序 .exe',
                ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
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
              onChanged: widget.state.commandRunning
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
                    onPressed: widget.state.commandRunning
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
        ),
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '构建后上传 Bugly 符号表',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                '仅用于 APK Release；每个选中渠道构建成功后自动执行 Java 上传工具。',
              ),
              value: config.enabled,
              onChanged: state.commandRunning
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
                onChanged: (value) => controller.updateBuglyConfig(
                  config.copyWith(jarPath: value),
                ),
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
        ),
      ),
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

class _CommandConsole extends ConsumerWidget {
  const _CommandConsole({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    color: const Color(0xff101820),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                state.commandRunning ? '正在执行：${state.activeCommand}' : '命令输出',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (state.commandRunning)
                TextButton.icon(
                  onPressed: ref
                      .read(fvmControllerProvider.notifier)
                      .stopProjectCommand,
                  icon: const Icon(Icons.stop, color: Colors.redAccent),
                  label: const Text(
                    '停止',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              IconButton(
                tooltip: '清空输出',
                onPressed: ref
                    .read(fvmControllerProvider.notifier)
                    .clearCommandLog,
                icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                state.commandLog.isEmpty ? '等待执行命令…' : state.commandLog,
                style: const TextStyle(
                  color: Color(0xffc9d1d9),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
