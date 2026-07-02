part of '../home_page.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.showFvmUpdate,
    required this.showFlutterUpdate,
    required this.onIgnoreFvmUpdate,
    required this.onIgnoreFlutterUpdate,
    required this.onSelected,
  });
  final int selected;
  final bool showFvmUpdate;
  final bool showFlutterUpdate;
  final VoidCallback onIgnoreFvmUpdate;
  final VoidCallback onIgnoreFlutterUpdate;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Material(
      color: const Color(0xff101820),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (showFvmUpdate)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: _UpdateDot(
                        key: const ValueKey('fvm-update-dot-logo'),
                        onTap: onIgnoreFvmUpdate,
                      ),
                    ),
                ],
              ),
              title: const Text(
                'Flutter Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Flutter SDK 管理器',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: '概览',
                    selected: selected == 0,
                    onTap: () => onSelected(0),
                  ),
                  _NavItem(
                    icon: Icons.layers_outlined,
                    label: 'Flutter 版本',
                    selected: selected == 1,
                    showDot: showFlutterUpdate,
                    onIgnoreUpdate: onIgnoreFlutterUpdate,
                    onTap: () => onSelected(1),
                  ),
                  _NavItem(
                    icon: Icons.workspaces_outline,
                    label: '项目管理',
                    selected: selected == 2,
                    onTap: () => onSelected(2),
                  ),
                  _NavItem(
                    icon: Icons.folder_copy_outlined,
                    label: '项目 FVM',
                    selected: selected == 3,
                    onTap: () => onSelected(3),
                  ),
                  _NavItem(
                    icon: Icons.article_outlined,
                    label: '日志',
                    selected: selected == 4,
                    onTap: () => onSelected(4),
                  ),
                  _NavItem(
                    icon: Icons.terminal,
                    label: '环境配置',
                    selected: selected == 5,
                    onTap: () => onSelected(5),
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    selected: selected == 6,
                    onTap: () => onSelected(6),
                  ),
                ],
              ),
            ),
            Text(
              Platform.isWindows ? 'Windows' : 'macOS',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
    this.onIgnoreUpdate,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;
  final VoidCallback? onIgnoreUpdate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selected: selected,
      selectedTileColor: const Color(0xff203342),
      leading: Icon(
        icon,
        color: selected ? const Color(0xff55c2ff) : Colors.white60,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: selected ? Colors.white : Colors.white70),
            ),
          ),
          if (showDot)
            _UpdateDot(
              key: const ValueKey('flutter-update-dot-nav'),
              onTap: onIgnoreUpdate,
            ),
        ],
      ),
      onTap: onTap,
    ),
  );
}
