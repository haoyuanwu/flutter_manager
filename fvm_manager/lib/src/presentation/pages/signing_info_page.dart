part of '../home_page.dart';

class _SigningInfoPage extends ConsumerStatefulWidget {
  const _SigningInfoPage({required this.state});

  final FvmState state;

  @override
  ConsumerState<_SigningInfoPage> createState() => _SigningInfoPageState();
}

class _SigningInfoPageState extends ConsumerState<_SigningInfoPage> {
  SigningInfo? _signingInfo;
  bool _loading = false;
  String? _error;
  String? _selectedProjectPath;
  String? _selectedApkPath;
  final _jksPathController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _jksPathController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectJksFile() async {
    try {
      final result = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: 'JKS 文件', extensions: ['jks', 'keystore']),
        ],
      );

      if (result == null) return;

      _jksPathController.text = result.path;
      await _extractFromJks(result.path);
    } catch (e) {
      setState(() {
        _error = '选择文件失败: $e';
      });
    }
  }

  Future<void> _selectApkFile() async {
    try {
      final result = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: 'APK 文件', extensions: ['apk']),
        ],
      );

      if (result == null) return;

      setState(() {
        _selectedApkPath = result.path;
        _selectedProjectPath = null;
      });
      await _extractFromApk(result.path);
    } catch (e) {
      setState(() {
        _error = '选择文件失败: $e';
      });
    }
  }

  Future<void> _extractFromJks(String jksPath) async {
    setState(() {
      _loading = true;
      _error = null;
      _signingInfo = null;
    });

    try {
      final service = ref.read(signingInfoServiceProvider);
      final info = await service.extractFromJks(
        jksPath,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
      );
      setState(() {
        _signingInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '提取签名信息失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _extractFromApk(String apkPath) async {
    setState(() {
      _loading = true;
      _error = null;
      _signingInfo = null;
    });

    try {
      final service = ref.read(signingInfoServiceProvider);
      final info = await service.extractFromApk(apkPath);
      setState(() {
        _signingInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '提取签名信息失败: $e';
        _loading = false;
      });
    }
  }

  void _selectProjectApk(String projectPath) {
    setState(() {
      _selectedProjectPath = projectPath;
      _selectedApkPath = null;
    });

    // 查找项目中的 APK 文件
    final project = widget.state.managedProjects
        .where((p) => p.path == projectPath)
        .firstOrNull;

    if (project != null && project.hasAndroid) {
      final apkDir = Directory(
        '${project.path}${Platform.pathSeparator}build${Platform.pathSeparator}app${Platform.pathSeparator}outputs${Platform.pathSeparator}flutter-apk',
      );

      if (apkDir.existsSync()) {
        final apks = apkDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.apk'))
            .toList();

        if (apks.isNotEmpty) {
          // 按修改时间排序，获取最新的
          apks.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
          _extractFromApk(apks.first.path);
          return;
        }
      }
    }

    setState(() {
      _error = '未找到项目构建的 APK 文件';
    });
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.state.managedProjects
        .where((p) => p.hasAndroid)
        .toList();

    return WorkbenchScrollPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkbenchPageHeader(
            title: '应用签名',
            subtitle: '查看 APK 或 JKS 文件的签名证书信息，包括 SHA1、SHA256、MD5 等。',
          ),
          const SizedBox(height: 20),

          // 输入区域
          WorkbenchPanel(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('选择签名文件', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.lg),

                  // JKS 文件选择
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _jksPathController,
                          decoration: AppInputDecorations.defaultInput(
                            labelText: 'JKS / Keystore 文件路径',
                            hintText: '选择 .jks 或 .keystore 文件',
                            prefixIcon: const Icon(Icons.key),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _selectJksFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择 JKS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // JKS 密码输入
                  TextField(
                    controller: _passwordController,
                    decoration: AppInputDecorations.defaultInput(
                      labelText: 'Keystore 密码（可选）',
                      hintText: '默认为 changeit',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    onSubmitted: (_) {
                      if (_jksPathController.text.isNotEmpty) {
                        _extractFromJks(_jksPathController.text);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 分隔线
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text('或者', style: AppTextStyles.caption),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // APK 文件选择
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _selectApkFile,
                        icon: const Icon(Icons.android),
                        label: const Text('选择 APK 文件'),
                      ),
                      if (projects.isNotEmpty)
                        PopupMenuButton<String>(
                          onSelected: _selectProjectApk,
                          itemBuilder: (context) => projects
                              .map(
                                (project) => PopupMenuItem(
                                  value: project.path,
                                  child: ListTile(
                                    leading: const Icon(Icons.folder_outlined),
                                    title: Text(project.displayName),
                                    subtitle: Text(
                                      project.fvmVersion ?? '默认 Flutter',
                                      style: AppTextStyles.captionSmall,
                                    ),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              )
                              .toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_android, size: 18),
                                const SizedBox(width: 8),
                                const Text('从项目获取 APK'),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 加载状态
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('正在提取签名信息...'),
                    ],
                  ),
                ),
              ),
            ),

          // 错误信息
          if (_error != null)
            Card(
              color: AppPalette.of(context).messageErrorBackground,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppPalette.of(context).messageErrorText,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),
            ),

          // 签名信息展示
          if (_signingInfo != null) _buildSigningInfoCard(_signingInfo!),
        ],
      ),
    );
  }

  Widget _buildSigningInfoCard(SigningInfo info) {
    return WorkbenchPanel(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppColors.success, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('签名信息', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        info.fileName,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: '复制全部信息',
                  onPressed: () => _copyAllInfo(info),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl * 2),

            // 证书信息列表
            _buildInfoSection('基本信息', [
              if (info.certificateAlias != null)
                _buildInfoRow('证书别名', info.certificateAlias!),
              if (info.subject != null)
                _buildInfoRow('使用者 (Subject)', info.subject!),
              if (info.issuer != null)
                _buildInfoRow('颁发者 (Issuer)', info.issuer!),
              if (info.version != null) _buildInfoRow('证书版本', info.version!),
              if (info.serialNumber != null)
                _buildInfoRow('序列号', info.serialNumber!),
            ]),

            if (info.validFrom != null || info.validTo != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildInfoSection('有效期', [
                if (info.validFrom != null)
                  _buildInfoRow('生效时间', info.validFrom!),
                if (info.validTo != null) _buildInfoRow('过期时间', info.validTo!),
              ]),
            ],

            const SizedBox(height: AppSpacing.lg),
            _buildInfoSection('证书指纹', [
              if (info.sha256 != null)
                _buildInfoRow('SHA-256', info.sha256!, copyable: true),
              if (info.sha1 != null)
                _buildInfoRow('SHA-1', info.sha1!, copyable: true),
              if (info.md5 != null)
                _buildInfoRow('MD5', info.md5!, copyable: true),
            ]),

            // 常见用途提示
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppPalette.of(context).surfaceVariant,
                borderRadius: AppRadius.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('常见用途', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.sm),
                  _buildUsageTip('SHA-1', '用于 Google Maps API、Firebase 等服务的配置'),
                  _buildUsageTip(
                    'SHA-256',
                    '用于 App Bundle 签名验证、Play App Signing',
                  ),
                  _buildUsageTip('MD5', '部分第三方 SDK 集成时需要'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppPalette.of(context).textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontFamily: copyable ? 'monospace' : null,
                fontSize: copyable ? 12 : null,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: '复制',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyToClipboard(value),
            ),
        ],
      ),
    );
  }

  Widget _buildUsageTip(String key, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              key,
              style: AppTextStyles.captionSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(description, style: AppTextStyles.captionSmall)),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
    );
  }

  void _copyAllInfo(SigningInfo info) {
    final buffer = StringBuffer();
    buffer.writeln('文件名: ${info.fileName}');
    buffer.writeln('路径: ${info.filePath}');
    if (info.certificateAlias != null) {
      buffer.writeln('证书别名: ${info.certificateAlias}');
    }
    if (info.subject != null) buffer.writeln('使用者: ${info.subject}');
    if (info.issuer != null) buffer.writeln('颁发者: ${info.issuer}');
    if (info.version != null) buffer.writeln('版本: ${info.version}');
    if (info.serialNumber != null) {
      buffer.writeln('序列号: ${info.serialNumber}');
    }
    if (info.validFrom != null) buffer.writeln('生效时间: ${info.validFrom}');
    if (info.validTo != null) buffer.writeln('过期时间: ${info.validTo}');
    buffer.writeln('');
    buffer.writeln('证书指纹:');
    if (info.sha256 != null) buffer.writeln('SHA-256: ${info.sha256}');
    if (info.sha1 != null) buffer.writeln('SHA-1: ${info.sha1}');
    if (info.md5 != null) buffer.writeln('MD5: ${info.md5}');

    _copyToClipboard(buffer.toString());
  }
}
