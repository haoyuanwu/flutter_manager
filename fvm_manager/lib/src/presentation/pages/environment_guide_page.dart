part of '../home_page.dart';

class _EnvironmentGuide extends ConsumerWidget {
  const _EnvironmentGuide({required this.state});

  final FvmState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = Platform.isWindows;
    final controller = ref.read(fvmControllerProvider.notifier);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '环境配置',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('配置 Dart Pub 与 Flutter SDK 下载源。'),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pub 下载源',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: state.mirrorId,
                          decoration: const InputDecoration(
                            labelText: '选择下载源',
                            border: OutlineInputBorder(),
                          ),
                          items: PubEnvironmentService.mirrors
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: state.loading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    controller.setMirror(value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: state.loading
                            ? null
                            : controller.testAllMirrors,
                        icon: const Icon(Icons.speed),
                        label: const Text('测试连通性'),
                      ),
                    ],
                  ),
                  if (state.mirrorTestResults.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PubEnvironmentService.mirrors.map((m) {
                        final ms = state.mirrorTestResults[m.id];
                        final testing =
                            ms == null &&
                            state.mirrorTestResults.length <
                                PubEnvironmentService.mirrors.length;
                        return Chip(
                          avatar: ms == null
                              ? (testing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.help_outline, size: 18))
                              : Icon(
                                  ms < 0 ? Icons.close : Icons.check,
                                  size: 18,
                                  color: ms < 0 ? Colors.red : Colors.green,
                                ),
                          label: Text(
                            ms == null
                                ? m.name
                                : ms < 0
                                ? '${m.name}  超时'
                                : '${m.name}  ${ms}ms',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f8fa),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffe1e4e8)),
                    ),
                    child: Builder(
                      builder: (context) {
                        final current = PubEnvironmentService.mirrors
                            .where((m) => m.id == state.mirrorId)
                            .firstOrNull;
                        if (current == null || current.pubUrl == null) {
                          return const Text(
                            '使用官方默认源：pub.dev + storage.googleapis.com',
                            style: TextStyle(color: Colors.black54),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前生效地址',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _MirrorUrl('PUB_HOSTED_URL', current.pubUrl!),
                            const SizedBox(height: 2),
                            _MirrorUrl(
                              'FLUTTER_STORAGE_BASE_URL',
                              current.storageUrl ?? '',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '设置会持久化，并立即用于本工具启动的 FVM、Dart、Flutter 命令。新终端或其他应用需重新启动后读取系统环境。',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '手动配置说明',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            windows ? 'Windows 配置指南' : 'macOS 配置指南',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          _GuideStep(
            number: '1',
            title: '确认 Dart 可用',
            command: 'dart --version',
            detail: '如果命令不可用，请先安装 Flutter，或将 Flutter 的 bin 目录加入 PATH。',
          ),
          _GuideStep(
            number: '2',
            title: '安装 FVM',
            command: 'dart pub global activate fvm',
            detail: '使用 Dart Pub 安装最新版 FVM。',
          ),
          _GuideStep(
            number: '3',
            title: '添加 FVM 到 PATH',
            command: windows
                ? r'%LOCALAPPDATA%\Pub\Cache\bin'
                : r'export PATH="$HOME/.pub-cache/bin:$PATH"',
            detail: windows
                ? '打开“系统属性 → 环境变量”，将上面的目录添加到用户 Path，然后重启终端和本应用。'
                : '把命令写入 ~/.zshrc（或对应 shell 配置文件），然后执行 source ~/.zshrc。',
          ),
          _GuideStep(
            number: '4',
            title: '让全局 Flutter 生效',
            command: windows
                ? r'%USERPROFILE%\fvm\default\bin'
                : r'export PATH="$HOME/fvm/default/bin:$PATH"',
            detail:
                '将 FVM 的 default/bin 放在其他 Flutter 路径之前，之后本工具切换全局版本会立即作用于新终端。',
          ),
          const _GuideStep(
            number: '5',
            title: '验证配置',
            command: 'fvm --version\nflutter --version',
            detail: '两个命令都能输出版本号即配置完成。',
          ),
        ],
      ),
    );
  }
}

class _MirrorUrl extends StatelessWidget {
  const _MirrorUrl(this.name, this.url);
  final String name;
  final String url;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 220,
        child: SelectableText(
          name,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      Expanded(
        child: SelectableText(
          url,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xff087ea4),
          ),
        ),
      ),
    ],
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.command,
    required this.detail,
  });
  final String number;
  final String title;
  final String command;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(number)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff101820),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      command,
                      style: const TextStyle(
                        color: Color(0xff9cdcfe),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
