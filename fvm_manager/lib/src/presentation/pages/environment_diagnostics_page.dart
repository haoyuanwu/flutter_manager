part of '../home_page.dart';

class _EnvironmentDiagnosticsPage extends ConsumerStatefulWidget {
  const _EnvironmentDiagnosticsPage({
    required this.state,
    required this.refreshToken,
    required this.initialReport,
    required this.onReportChanged,
  });

  final FvmState state;
  final int refreshToken;
  final EnvironmentDiagnosticReport? initialReport;
  final ValueChanged<EnvironmentDiagnosticReport> onReportChanged;

  @override
  ConsumerState<_EnvironmentDiagnosticsPage> createState() =>
      _EnvironmentDiagnosticsPageState();
}

class _EnvironmentDiagnosticsPageState
    extends ConsumerState<_EnvironmentDiagnosticsPage> {
  EnvironmentDiagnosticReport? _report;
  bool _running = false;
  bool _repairingNetwork = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    if (_report == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  @override
  void didUpdateWidget(_EnvironmentDiagnosticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final selectedProject = widget.state.managedProjects
        .where(
          (project) => project.path == widget.state.selectedManagedProjectPath,
        )
        .firstOrNull;
    final fvmBlocked =
        report?.items.any(
          (item) =>
              item.category == 'FVM' &&
              item.level == EnvironmentDiagnosticLevel.error,
        ) ??
        !widget.state.fvmInstalled;
    final requiredVersion = selectedProject?.fvmVersion?.trim();
    final missingRequiredVersion =
        requiredVersion != null &&
        requiredVersion.isNotEmpty &&
        !widget.state.installed.any(
          (sdk) =>
              sdk.name == requiredVersion ||
              sdk.flutterVersion == requiredVersion,
        );
    final flutterBlocked =
        !fvmBlocked &&
        (widget.state.installed.isEmpty || missingRequiredVersion);
    final versionToInstall = missingRequiredVersion ? requiredVersion : null;
    final networkBlocked =
        report?.items.any(
          (item) =>
              item.category == '网络' &&
              item.level == EnvironmentDiagnosticLevel.error,
        ) ??
        false;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '环境诊断',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: Text(_running ? '诊断中…' : '开始诊断'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '检查 FVM、Flutter SDK、Flutter Doctor、镜像网络、项目配置、设备、平台工具和 MCP 服务。',
            style: TextStyle(color: Colors.black54),
          ),
          if (report != null) ...[
            const SizedBox(height: 6),
            Text(
              '最近诊断：${_formatTime(report.finishedAt)}',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          if (report == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('点击“开始诊断”检查当前环境。'),
              ),
            )
          else ...[
            if (fvmBlocked) ...[
              _FvmRequiredCard(
                loading: widget.state.loading || _running,
                onInstall: _installFvm,
                onSelectLocal: _selectLocalFvm,
              ),
              const SizedBox(height: 16),
            ],
            if (flutterBlocked) ...[
              _FlutterRequiredCard(
                version: versionToInstall,
                recommendedVersion: widget.state.latestFlutterVersion,
                loading:
                    widget.state.activeVersion != null || widget.state.loading,
                onInstall: () => _installFlutter(versionToInstall),
              ),
              const SizedBox(height: 16),
            ],
            if (networkBlocked) ...[
              _NetworkRepairCard(
                loading: _repairingNetwork || widget.state.loading,
                onRepair: _repairNetwork,
              ),
              const SizedBox(height: 16),
            ],
            _DiagnosticSummary(report: report),
            const SizedBox(height: 16),
            for (final entry in _groupItems(report.items).entries) ...[
              _DiagnosticCategoryCard(category: entry.key, items: entry.value),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _report = EnvironmentDiagnosticReport(
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        items: [],
      );
    });
    try {
      final report = await ref
          .read(environmentDiagnosticsServiceProvider)
          .run(
            state: widget.state,
            onItemAdded: (items) {
              if (mounted) {
                setState(() {
                  _report = EnvironmentDiagnosticReport(
                    startedAt: _report?.startedAt ?? DateTime.now(),
                    finishedAt: DateTime.now(),
                    items: List.from(items),
                  );
                });
              }
            },
          );
      widget.onReportChanged(report);
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) {
        ref.read(fvmControllerProvider.notifier).showError(error);
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _installFvm() async {
    await ref.read(fvmControllerProvider.notifier).installFvm();
    if (mounted) await _run();
  }

  Future<void> _selectLocalFvm() async {
    await ref.read(fvmControllerProvider.notifier).selectLocalFvmDirectory();
    if (mounted) await _run();
  }

  Future<void> _installFlutter(String? version) async {
    await ref
        .read(fvmControllerProvider.notifier)
        .installRequiredFlutterVersion(version);
    if (mounted) await _run();
  }

  Future<void> _repairNetwork() async {
    if (_repairingNetwork) return;
    setState(() => _repairingNetwork = true);
    try {
      await ref
          .read(fvmControllerProvider.notifier)
          .switchToFastestAvailableMirror();
      if (mounted) await _run();
    } finally {
      if (mounted) setState(() => _repairingNetwork = false);
    }
  }

  Map<String, List<DiagnosticItem>> _groupItems(List<DiagnosticItem> items) {
    final grouped = <String, List<DiagnosticItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _FvmRequiredCard extends StatelessWidget {
  const _FvmRequiredCard({
    required this.loading,
    required this.onInstall,
    required this.onSelectLocal,
  });

  final bool loading;
  final VoidCallback onInstall;
  final VoidCallback onSelectLocal;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xfffffbeb),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.orange.shade800, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '需要先完成 FVM 环境',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '运行、构建、Pub Get、Clean、DevTools、Flutter 版本管理等功能都依赖 FVM。'
                  '点击“安装 FVM”可由软件自动完成安装，也可选择已安装好的本地 FVM 目录。',
                  style: TextStyle(color: Colors.orange.shade900, height: 1.45),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: loading ? null : onInstall,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('安装 FVM'),
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : onSelectLocal,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('选择本地 FVM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _FlutterRequiredCard extends StatelessWidget {
  const _FlutterRequiredCard({
    required this.version,
    required this.recommendedVersion,
    required this.loading,
    required this.onInstall,
  });

  final String? version;
  final String? recommendedVersion;
  final bool loading;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final targetVersion = version ?? recommendedVersion;
    return Card(
      color: const Color(0xffeff6ff),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.flutter_dash, color: Color(0xff087ea4), size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    version == null ? '需要安装 Flutter SDK' : '项目所需版本尚未安装',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    version == null
                        ? '安装推荐的 Stable 版本后，软件会在首次安装时自动将它设为全局版本。'
                        : '当前项目需要 Flutter $version，安装完成后即可继续运行和构建。',
                    style: const TextStyle(
                      color: Color(0xff075985),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: loading ? null : onInstall,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      targetVersion == null
                          ? '获取并安装推荐版本'
                          : '安装 Flutter $targetVersion',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkRepairCard extends StatelessWidget {
  const _NetworkRepairCard({required this.loading, required this.onRepair});

  final bool loading;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xfffff7ed),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_find, color: Color(0xffc2410c), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pub 下载源不可用',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  '可以并行测试全部已配置下载源，自动切换到当前可访问且延迟最低的一个。',
                  style: TextStyle(color: Color(0xff9a3412), height: 1.45),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: loading ? null : onRepair,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_outlined),
                  label: Text(loading ? '正在测试…' : '自动选择最快下载源'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DiagnosticSummary extends StatelessWidget {
  const _DiagnosticSummary({required this.report});

  final EnvironmentDiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final duration = report.finishedAt.difference(report.startedAt);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryChip(
          icon: Icons.check_circle,
          color: Colors.green,
          label: '正常 ${report.count(EnvironmentDiagnosticLevel.ok)}',
        ),
        _SummaryChip(
          icon: Icons.warning_amber,
          color: Colors.orange,
          label: '警告 ${report.count(EnvironmentDiagnosticLevel.warning)}',
        ),
        _SummaryChip(
          icon: Icons.error_outline,
          color: Colors.red,
          label: '错误 ${report.count(EnvironmentDiagnosticLevel.error)}',
        ),
        _SummaryChip(
          icon: Icons.info_outline,
          color: Colors.blueGrey,
          label: '信息 ${report.count(EnvironmentDiagnosticLevel.info)}',
        ),
        _SummaryChip(
          icon: Icons.timer_outlined,
          color: Colors.blueGrey,
          label: '${duration.inMilliseconds}ms',
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, color: color, size: 18),
    label: Text(label),
  );
}

class _DiagnosticCategoryCard extends StatelessWidget {
  const _DiagnosticCategoryCard({required this.category, required this.items});

  final String category;
  final List<DiagnosticItem> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final item in items) _DiagnosticItemTile(item: item),
        ],
      ),
    ),
  );
}

class _DiagnosticItemTile extends StatelessWidget {
  const _DiagnosticItemTile({required this.item});

  final DiagnosticItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.level) {
      EnvironmentDiagnosticLevel.ok => (
        Icons.check_circle_outline,
        Colors.green,
      ),
      EnvironmentDiagnosticLevel.warning => (
        Icons.warning_amber_outlined,
        Colors.orange,
      ),
      EnvironmentDiagnosticLevel.error => (Icons.error_outline, Colors.red),
      EnvironmentDiagnosticLevel.info => (Icons.info_outline, Colors.blueGrey),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  item.detail,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (item.suggestion case final suggestion?) ...[
                  const SizedBox(height: 5),
                  Text(
                    '建议：$suggestion',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
                if (item.documentationUrl case final url?) ...[
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    onPressed: () => _openDocumentation(context, url),
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: Text(item.documentationLabel ?? '查看安装说明'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocumentation(BuildContext context, String url) async {
    try {
      await _openExternalUrl(url);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}
