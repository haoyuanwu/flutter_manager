part of '../home_page.dart';

class _ApkInstallPage extends ConsumerStatefulWidget {
  const _ApkInstallPage();

  @override
  ConsumerState<_ApkInstallPage> createState() => _ApkInstallPageState();
}

class _ApkInstallPageState extends ConsumerState<_ApkInstallPage> {
  String? _apkPath;
  String? _deviceId;
  List<AndroidDevice> _devices = const [];
  String? _error;
  String? _success;
  bool _loadingDevices = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDevices());
  }

  Future<void> _pickApk() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(label: 'APK 文件', extensions: ['apk']),
        ],
      );
      if (file == null || !mounted) return;
      setState(() {
        _apkPath = file.path;
        _error = null;
        _success = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '选择 APK 失败：$error');
    }
  }

  Future<void> _refreshDevices() async {
    if (_loadingDevices || _installing) return;
    setState(() {
      _loadingDevices = true;
      _error = null;
    });
    try {
      final devices = await ref.read(apkInstallServiceProvider).listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (!devices.any(
          (device) => device.id == _deviceId && device.available,
        )) {
          _deviceId = null;
        }
        _loadingDevices = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _devices = const [];
        _deviceId = null;
        _loadingDevices = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _install() async {
    final apkPath = _apkPath;
    final deviceId = _deviceId;
    if (apkPath == null || deviceId == null || _installing) return;
    setState(() {
      _installing = true;
      _error = null;
      _success = null;
    });
    try {
      await ref
          .read(apkInstallServiceProvider)
          .install(apkPath: apkPath, deviceId: deviceId);
      if (!mounted) return;
      setState(() => _success = '已成功安装到设备 $deviceId');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _devices.where((device) => device.available).toList();
    return WorkbenchScrollPage(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkbenchPageHeader(
            title: 'APK 安装',
            subtitle: '选择 APK 和已连接的 Android 设备，再点击安装。',
          ),
          const SizedBox(height: 20),
          WorkbenchSection(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. 选择 APK',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _installing ? null : _pickApk,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择 APK 文件'),
                  ),
                  if (_apkPath != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(_apkPath!),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    '2. 选择设备',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('apk-install-device-$_deviceId'),
                          initialValue: _deviceId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '已连接的 Android 设备',
                            border: OutlineInputBorder(),
                          ),
                          hint: Text(_loadingDevices ? '正在读取设备…' : '请选择设备'),
                          items: available
                              .map(
                                (device) => DropdownMenuItem(
                                  value: device.id,
                                  child: Text(
                                    device.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged:
                              _installing ||
                                  _loadingDevices ||
                                  available.isEmpty
                              ? null
                              : (id) => setState(() {
                                  _deviceId = id;
                                  _error = null;
                                  _success = null;
                                }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '刷新设备',
                        onPressed: _loadingDevices || _installing
                            ? null
                            : _refreshDevices,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (!_loadingDevices && available.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '未发现可用设备。请连接 Android 设备并开启 USB 调试，然后刷新。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_devices.any((device) => !device.available)) ...[
                    const SizedBox(height: 8),
                    Text(
                      '不可用设备：${_devices.where((device) => !device.available).map((device) => '${device.id} (${device.status})').join('、')}',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    '3. 安装',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _apkPath == null ||
                            _deviceId == null ||
                            _installing ||
                            _loadingDevices
                        ? null
                        : _install,
                    icon: _installing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.install_mobile),
                    label: Text(_installing ? '正在安装…' : '安装到所选设备'),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            Text(_success!, style: const TextStyle(color: Colors.green)),
          ],
        ],
      ),
    );
  }
}
