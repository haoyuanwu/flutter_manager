part of '../home_page.dart';

class _ProjectConfiguration extends ConsumerWidget {
  const _ProjectConfiguration({
    required this.state,
    required this.onAddProject,
  });

  final FvmState state;
  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(fvmControllerProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '项目 FVM 配置',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('为本地 Flutter 项目选择独立的 SDK 版本。'),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. 选择 Flutter 项目',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (state.managedProjects.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue:
                          state.managedProjects.any(
                            (p) => p.path == state.projectPath,
                          )
                          ? state.projectPath
                          : null,
                      decoration: const InputDecoration(
                        labelText: '从已添加项目中选择',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: state.managedProjects
                          .where((p) => p.pathExists)
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.path,
                              child: Text(p.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: state.loading
                          ? null
                          : (value) {
                              if (value != null) {
                                controller.chooseProjectPath(value);
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '或手动选择本地目录：',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.loading ? null : onAddProject,
                          icon: const Icon(Icons.add),
                          label: const Text('选择目录'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xfff5f7fa),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xffd8dee4),
                              ),
                            ),
                            child: SelectableText(
                              state.projectPath ?? '尚未选择项目目录',
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: state.loading ? null : onAddProject,
                          icon: const Icon(Icons.add),
                          label: const Text('选择目录'),
                        ),
                      ],
                    ),
                  ],
                  if (state.projectPath != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.projectVersion == null
                          ? '当前状态：尚未配置 FVM'
                          : '当前版本：Flutter ${state.projectVersion}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. 设置项目使用版本',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (state.installed.isEmpty)
                    const Text('尚无已安装的 Flutter SDK，请先在“Flutter 版本”页面下载。')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: state.projectTargetVersion,
                      decoration: const InputDecoration(
                        labelText: 'Flutter SDK',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flutter_dash),
                      ),
                      items: state.installed
                          .map(
                            (sdk) => DropdownMenuItem(
                              value: sdk.name,
                              child: Text(
                                '${sdk.name}  ·  Flutter ${sdk.flutterVersion}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: state.loading
                          ? null
                          : controller.selectProjectVersion,
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          state.loading ||
                              !state.fvmInstalled ||
                              state.projectPath == null ||
                              state.projectTargetVersion == null
                          ? null
                          : controller.applyProjectVersion,
                      icon: const Icon(Icons.check),
                      label: const Text('应用到项目'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '应用后将写入项目的 .fvmrc；不会自动执行 flutter pub get。',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
