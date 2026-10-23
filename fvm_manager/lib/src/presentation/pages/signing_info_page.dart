part of '../home_page.dart';

class _SigningInfoPage extends ConsumerStatefulWidget {
  const _SigningInfoPage({required this.state, required this.onOpenSettings});

  final FvmState state;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<_SigningInfoPage> createState() => _SigningInfoPageState();
}

class _SigningInfoPageState extends ConsumerState<_SigningInfoPage> {
  SigningInfo? _signingInfo;
  bool _loading = false;
  String? _error;
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

  Future<void> _selectProjectApk(String projectPath) async {
    final path = await showProjectApkPicker(
      context,
      projects: widget.state.managedProjects,
      initialProjectPath: projectPath,
    );
    if (path != null && mounted) await _extractFromApk(path);
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
          WorkbenchPageHeader(
            title: '应用签名',
            subtitle: '查看 APK 或 JKS 文件的签名证书信息，包括 SHA1、SHA256、MD5 等。',
            actions: [
              IconButton(
                key: const ValueKey('signing-info-settings'),
                tooltip: '签名后的源文件处理设置',
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),

          WorkbenchSplitSections(
            equalHeight: true,
            leading: _buildKeystoreSource(),
            trailing: _buildApkSource(projects),
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

  Widget _buildKeystoreSource() => WorkbenchPanel(
    key: const ValueKey('signing-keystore-source'),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkbenchSectionHeading(
          title: '密钥库证书',
          icon: Icons.key_outlined,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(height: 8),
        Text(
          '读取 JKS / Keystore 的证书信息；可先填写密码，再选择文件。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          enabled: !_loading,
          decoration: AppInputDecorations.defaultInput(
            labelText: 'Keystore 密码（可选）',
            hintText: '默认为 changeit',
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
          onSubmitted: (_) {
            if (!_loading && _jksPathController.text.isNotEmpty) {
              _extractFromJks(_jksPathController.text);
            }
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('signing-select-keystore'),
          style: _sourceButtonStyle,
          onPressed: _loading ? null : _selectJksFile,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('选择 JKS / Keystore'),
        ),
        if (_jksPathController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            _jksPathController.text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  // Both APK actions share bounds; appearance communicates their priority.
  ButtonStyle get _sourceButtonStyle => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 44)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildApkSource(List<FlutterProject> projects) => WorkbenchPanel(
    key: const ValueKey('signing-apk-source'),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkbenchSectionHeading(
          title: 'APK 安装包证书',
          icon: Icons.android_outlined,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 8),
        Text(
          '选择本地 APK，或读取已管理项目最近一次构建的 APK。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('signing-select-apk'),
          style: _sourceButtonStyle,
          onPressed: _loading ? null : _selectApkFile,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('选择 APK 文件'),
        ),
        const SizedBox(height: 12),
        MenuAnchor(
          menuChildren: [
            for (final project in projects)
              MenuItemButton(
                onPressed: () => _selectProjectApk(project.path),
                leadingIcon: const Icon(Icons.folder_outlined, size: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.displayName),
                    Text(
                      project.fvmVersion ?? '默认 Flutter',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
          builder: (context, menu, child) => OutlinedButton.icon(
            key: const ValueKey('signing-project-apk'),
            style: _sourceButtonStyle,
            onPressed: _loading || projects.isEmpty
                ? null
                : () => menu.isOpen ? menu.close() : menu.open(),
            icon: const Icon(Icons.folder_copy_outlined, size: 18),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('从项目获取 APK'),
                SizedBox(width: 4),
                Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        if (projects.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '暂无 Android 项目，请先在项目管理中添加。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

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
