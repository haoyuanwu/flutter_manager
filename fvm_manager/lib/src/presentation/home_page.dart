import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/project_models.dart';
import '../data/log_service.dart';
import '../data/pub_environment_service.dart';
import 'providers.dart';

part 'pages/environment_guide_page.dart';
part 'pages/overview_page.dart';
part 'pages/project_configuration_page.dart';
part 'pages/project_management_page.dart';
part 'pages/log_page.dart';
part 'pages/versions_page.dart';
part 'widgets/navigation.dart';
part 'widgets/status_widgets.dart';
part 'widgets/top_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _page = 0;
  final Set<String> _promptedMissingProjects = {};
  bool _promptedMissingFvm = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(fvmControllerProvider.notifier).initialize);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fvmControllerProvider);
    ref.listen<String?>(
      fvmControllerProvider.select((value) => value.updateNotice),
      (previous, next) {
        if (next == null || next == previous) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                content: Row(
                  children: [
                    const Icon(Icons.new_releases, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text(next)),
                  ],
                ),
              ),
            );
        });
      },
    );
    ref.listen<FvmState>(fvmControllerProvider, (previous, next) {
      if (_promptedMissingFvm ||
          next.loading ||
          next.fvmInstalled ||
          previous?.loading != true) {
        return;
      }
      _promptedMissingFvm = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMissingFvmDialog();
      });
    });
    ref.listen<List<FlutterProject>>(
      fvmControllerProvider.select((value) => value.managedProjects),
      (previous, projects) {
        final missing = projects
            .where(
              (project) =>
                  !project.pathExists &&
                  !_promptedMissingProjects.contains(project.path),
            )
            .firstOrNull;
        if (missing == null) return;
        _promptedMissingProjects.add(missing.path);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMissingProjectDialog(missing);
        });
      },
    );
    return Scaffold(
      body: state.loading && state.fvmVersion == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 16),
                  Text('正在初始化…', style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : Row(
              children: [
                _Sidebar(
                  selected: _page,
                  showFvmUpdate: state.hasFvmUpdate,
                  showFlutterUpdate: state.hasFlutterUpdate,
                  onIgnoreFvmUpdate: ref
                      .read(fvmControllerProvider.notifier)
                      .ignoreFvmUpdate,
                  onIgnoreFlutterUpdate: ref
                      .read(fvmControllerProvider.notifier)
                      .ignoreFlutterUpdate,
                  onSelected: (value) => setState(() => _page = value),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(state: state),
                      if (state.activeVersion != null)
                        LinearProgressIndicator(value: state.downloadProgress),
                      if (state.activeVersion != null)
                        _DownloadStatusBar(state: state),
                      if (state.errorMessage != null)
                        _MessageBar(message: state.errorMessage!, error: true),
                      if (state.statusMessage != null &&
                          state.errorMessage == null)
                        _MessageBar(message: state.statusMessage!),
                      Expanded(
                        child: switch (_page) {
                          0 => _Overview(state: state),
                          1 => _Versions(state: state),
                          2 => _ProjectManagement(state: state),
                          3 => _ProjectConfiguration(
                            state: state,
                            onAddProject: _openProjectManagerAndAdd,
                          ),
                          4 => const _LogPage(),
                          _ => _EnvironmentGuide(state: state),
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showMissingFvmDialog() async {
    final controller = ref.read(fvmControllerProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.hub_outlined, color: Colors.orange),
        title: const Text('未检测到 FVM'),
        content: const SizedBox(
          width: 430,
          child: Text(
            '你可以通过 Dart Pub 安装 FVM；如果已经安装但应用没有识别到，'
            '请选择包含 fvm 可执行文件的目录，例如 ~/.pub-cache/bin 或 /opt/homebrew/bin。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后处理'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.selectLocalFvmDirectory();
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('选择本地 FVM'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.installFvm();
            },
            icon: const Icon(Icons.download),
            label: const Text('安装 FVM'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMissingProjectDialog(FlutterProject project) async {
    final controller = ref.read(fvmControllerProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.folder_off_outlined, color: Colors.red),
        title: const Text('项目目录不存在'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('项目：${project.displayName}'),
            const SizedBox(height: 8),
            SelectableText(project.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后处理'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.removeManagedProject(project.path);
            },
            child: const Text('删除记录'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.relocateManagedProject(project);
            },
            child: const Text('重新定位'),
          ),
        ],
      ),
    );
  }

  void _openProjectManagerAndAdd() {
    setState(() => _page = 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(fvmControllerProvider.notifier).addManagedProject();
      }
    });
  }
}
