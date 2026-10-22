import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_manager/src/data/build_directory_watcher.dart';
import 'package:flutter_manager/src/data/environment_diagnostics_service.dart';
import 'package:flutter_manager/src/domain/build_history_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../data/apk_signing_service.dart';
import '../data/apk_install_service.dart';
import '../data/signing_info_service.dart';
import '../domain/models.dart';
import '../domain/project_models.dart';
import '../data/log_service.dart';
import '../data/flutter_startup_lock_service.dart';
import '../data/distribution_service.dart';
import '../data/external_opener.dart';
import '../data/local_project_service.dart';
import '../data/mcp_ai_setup_service.dart';
import '../data/pub_environment_service.dart';
import 'confirm_dialog.dart';
import 'create_project_dialog.dart';
import 'project_dependencies_dialog.dart';
import 'console_search.dart';
import 'widgets/flutter_startup_lock_button.dart';
import 'widgets/workbench_panel.dart';
import 'widgets/workbench_layout.dart';
import 'providers.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

part 'pages/environment_guide_page.dart';
part 'pages/environment_diagnostics_page.dart';
part 'pages/distribution_page.dart';
part 'pages/overview_page.dart';
part 'pages/project_management_page.dart';
part 'pages/apk_signing_page.dart';
part 'pages/apk_install_page.dart';
part 'pages/signing_info_page.dart';
part 'pages/log_page.dart';
part 'pages/mcp_server_page.dart';
part 'pages/settings_page.dart';
part 'pages/support_page.dart';
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
  int _diagnosticsRunSeed = 0;
  EnvironmentDiagnosticReport? _diagnosticsReport;
  final Set<String> _promptedMissingProjects = {};
  bool _promptedMissingFvm = false;
  MethodChannel? _dragDropChannel;

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(fvmControllerProvider.notifier).initialize);
    _setupDragDropChannel();
  }

  void _setupDragDropChannel() {
    _dragDropChannel = const MethodChannel('fvm_manager/drag_drop');
    _dragDropChannel?.setMethodCallHandler((call) async {
      if (call.method == 'onPathDropped') {
        final path = call.arguments as String?;
        if (path != null && mounted) {
          await ref
              .read(fvmControllerProvider.notifier)
              .addProjectByDragDrop(path);
        }
      }
    });
  }

  @override
  void dispose() {
    _dragDropChannel?.setMethodCallHandler(null);
    super.dispose();
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
      body: Stack(
        children: [
          Positioned.fill(
            child: state.loading && state.fvmVersion == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '正在初始化…',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _TopBar(state: state),
                            if (state.activeVersion != null)
                              LinearProgressIndicator(
                                value: state.downloadProgress,
                              ),
                            if (state.activeVersion != null)
                              _DownloadStatusBar(state: state),
                            Expanded(
                              child: switch (_page) {
                                0 => _Overview(
                                  state: state,
                                  onNavigate: (page) =>
                                      setState(() => _page = page),
                                ),
                                1 => _EnvironmentDiagnosticsPage(
                                  state: state,
                                  refreshToken: _diagnosticsRunSeed,
                                  initialReport: _diagnosticsReport,
                                  onReportChanged: (report) =>
                                      _diagnosticsReport = report,
                                ),
                                2 => _Versions(state: state),
                                3 => _ProjectManagement(
                                  state: state,
                                  onOpenDistribution: _openDistribution,
                                ),
                                4 => _DistributionPage(state: state),
                                5 => const _ApkSigningPage(),
                                6 => _SigningInfoPage(state: state),
                                7 => const _LogPage(),
                                8 => _EnvironmentGuide(state: state),
                                9 => _McpServerPage(state: state),
                                10 => _SettingsPage(state: state),
                                12 => const _SupportPage(),
                                _ => const _ApkInstallPage(),
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (state.errorMessage != null)
            Positioned(
              top: 72,
              right: 24,
              child: _MessageBar(
                key: ValueKey('error:${state.errorMessage}'),
                message: state.errorMessage!,
                error: true,
                onDiagnosticsTap: _openDiagnostics,
                onMcpTap: () => setState(() => _page = 9),
              ),
            )
          else if (state.statusMessage != null)
            Positioned(
              top: 72,
              right: 24,
              child: _MessageBar(
                key: ValueKey('status:${state.statusMessage}'),
                message: state.statusMessage!,
              ),
            ),
        ],
      ),
    );
  }

  void _openDistribution(String projectPath) {
    final controller = ref.read(fvmControllerProvider.notifier);
    if (ref.read(fvmControllerProvider).selectedManagedProjectPath !=
        projectPath) {
      unawaited(controller.selectManagedProject(projectPath));
    }
    setState(() => _page = 4);
  }

  void _openDiagnostics() {
    setState(() {
      _page = 1;
      _diagnosticsRunSeed++;
    });
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
            '点击“安装 FVM”可由软件自动选择当前系统可用的安装方式；如果已经安装但应用没有识别到，'
            '可以选择 FVM 文件夹，或直接选择 fvm 程序文件。Windows 常见程序目录：'
            'C:\\Users\\<用户名>\\AppData\\Local\\Pub\\Cache\\bin。'
            'D:\\fvm 这类 Flutter SDK 缓存也可选择，软件会尝试定位对应程序。',
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
            label: const Text('选择文件夹'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.selectLocalFvmDirectory(chooseFile: true);
            },
            icon: const Icon(Icons.insert_drive_file_outlined),
            label: const Text('选择程序文件'),
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _confirmRemoveManagedProject(context, controller, project);
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
}
