part of '../home_page.dart';

class _Sidebar extends StatefulWidget {
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
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _coreExpanded = true;
  bool _toolsExpanded = true;
  bool _systemExpanded = true;

  @override
  void didUpdateWidget(covariant _Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    final selected = widget.selected;
    if (selected <= 3) {
      _coreExpanded = true;
    } else if (selected <= 7 || selected == 11) {
      _toolsExpanded = true;
    } else {
      _systemExpanded = true;
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      widget.onSelected(0);
      return true;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      widget.onSelected(1);
      return true;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      widget.onSelected(2);
      return true;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      widget.onSelected(3);
      return true;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      widget.onSelected(4);
      return true;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      widget.onSelected(5);
      return true;
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      widget.onSelected(6);
      return true;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      widget.onSelected(8);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Material(
      color: AppPalette.of(context).sidebarBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.showFvmUpdate)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: _UpdateDot(
                        key: const ValueKey('fvm-update-dot-logo'),
                        onTap: widget.onIgnoreFvmUpdate,
                      ),
                    ),
                ],
              ),
              title: const Text(
                'Flutter Manager',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '开发 · 构建 · 分发',
                style: TextStyle(
                  fontSize: 11,
                  color: AppPalette.of(context).sidebarText,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              horizontalTitleGap: 10,
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView(
                  key: const ValueKey('sidebar-navigation-list'),
                  primary: false,
                  padding: EdgeInsets.zero,
                  children: [
                    _NavGroupHeader(
                      title: '核心',
                      icon: Icons.dashboard_outlined,
                      expanded: _coreExpanded,
                      onTap: () =>
                          setState(() => _coreExpanded = !_coreExpanded),
                    ),
                    if (_coreExpanded) ...[
                      _NavItem(
                        icon: Icons.dashboard_outlined,
                        label: '概览',
                        shortcut: '⌘1',
                        selected: widget.selected == 0,
                        onTap: () => widget.onSelected(0),
                      ),
                      _NavItem(
                        icon: Icons.health_and_safety_outlined,
                        label: '环境诊断',
                        shortcut: '⌘2',
                        selected: widget.selected == 1,
                        onTap: () => widget.onSelected(1),
                      ),
                      _NavItem(
                        icon: Icons.layers_outlined,
                        label: 'Flutter 版本',
                        shortcut: '⌘3',
                        selected: widget.selected == 2,
                        showDot: widget.showFlutterUpdate,
                        onIgnoreUpdate: widget.onIgnoreFlutterUpdate,
                        onTap: () => widget.onSelected(2),
                      ),
                      _NavItem(
                        icon: Icons.workspaces_outline,
                        label: '项目管理',
                        shortcut: '⌘4',
                        selected: widget.selected == 3,
                        onTap: () => widget.onSelected(3),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _NavGroupHeader(
                      title: '工具',
                      icon: Icons.build_outlined,
                      expanded: _toolsExpanded,
                      onTap: () =>
                          setState(() => _toolsExpanded = !_toolsExpanded),
                    ),
                    if (_toolsExpanded) ...[
                      _NavItem(
                        icon: Icons.inventory_2_outlined,
                        label: '产物中心',
                        shortcut: '⌘5',
                        selected: widget.selected == 4,
                        onTap: () => widget.onSelected(4),
                      ),
                      _NavItem(
                        icon: Icons.app_shortcut_outlined,
                        label: 'APK 签名',
                        shortcut: '⌘6',
                        selected: widget.selected == 5,
                        onTap: () => widget.onSelected(5),
                      ),
                      _NavItem(
                        icon: Icons.install_mobile_outlined,
                        label: 'APK 安装',
                        selected: widget.selected == 11,
                        onTap: () => widget.onSelected(11),
                      ),
                      _NavItem(
                        icon: Icons.verified_outlined,
                        label: '应用签名',
                        shortcut: '⌘7',
                        selected: widget.selected == 6,
                        onTap: () => widget.onSelected(6),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _NavGroupHeader(
                      title: '系统',
                      icon: Icons.settings_outlined,
                      expanded: _systemExpanded,
                      onTap: () =>
                          setState(() => _systemExpanded = !_systemExpanded),
                    ),
                    if (_systemExpanded) ...[
                      _NavItem(
                        icon: Icons.terminal,
                        label: '环境配置',
                        shortcut: '⌘9',
                        selected: widget.selected == 8,
                        onTap: () => widget.onSelected(8),
                      ),
                      _NavItem(
                        icon: Icons.smart_toy_outlined,
                        label: 'MCP 服务',
                        selected: widget.selected == 9,
                        onTap: () => widget.onSelected(9),
                      ),
                      _NavItem(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        selected: widget.selected == 10,
                        onTap: () => widget.onSelected(10),
                      ),
                      _NavItem(
                        icon: Icons.emoji_food_beverage_outlined,
                        label: '请我喝个茶',
                        selected: widget.selected == 12,
                        onTap: () => widget.onSelected(12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 12),
              child: Row(
                children: [
                  Icon(
                    Platform.isWindows
                        ? Icons.window
                        : Icons.desktop_mac_outlined,
                    size: 14,
                    color: AppPalette.of(context).sidebarIcon,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Platform.isWindows ? 'Windows 工作空间' : 'macOS 工作空间',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppPalette.of(context).sidebarText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavGroupHeader extends StatelessWidget {
  const _NavGroupHeader({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: AppPalette.of(context).sidebarGroupTitle,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.sidebarGroup.copyWith(
                  color: AppPalette.of(context).sidebarGroupTitle,
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? .5 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppAnimations.fast,
              child: Icon(
                Icons.expand_more,
                size: 18,
                color: AppPalette.of(context).sidebarGroupTitle,
              ),
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
    this.shortcut,
    this.showDot = false,
    this.onIgnoreUpdate,
  });
  final IconData icon;
  final String label;
  final String? shortcut;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;
  final VoidCallback? onIgnoreUpdate;

  @override
  Widget build(BuildContext context) {
    final displayShortcut = shortcut?.replaceFirst(
      '⌘',
      Platform.isMacOS ? '⌘' : 'Ctrl+',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          waitDuration: const Duration(seconds: 3),
          message: displayShortcut == null
              ? label
              : '$label · $displayShortcut',
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected
                  ? AppPalette.of(context).sidebarSelected
                  : Colors.transparent,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selected
                    ? AppPalette.of(
                        context,
                      ).sidebarIndicator.withValues(alpha: .28)
                    : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              hoverColor: Colors.white.withValues(alpha: .08),
              focusColor: AppPalette.of(
                context,
              ).sidebarIndicator.withValues(alpha: .22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppPalette.of(context).sidebarIndicator
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      icon,
                      size: 19,
                      color: selected
                          ? AppPalette.of(context).sidebarIconSelected
                          : AppPalette.of(context).sidebarIcon,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sidebarItem.copyWith(
                          color: selected
                              ? AppPalette.of(context).sidebarTextSelected
                              : AppPalette.of(context).sidebarText,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (showDot) ...[
                      _UpdateDot(
                        key: const ValueKey('flutter-update-dot-nav'),
                        onTap: onIgnoreUpdate,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (displayShortcut != null)
                      ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayShortcut,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppPalette.of(context).sidebarGroupTitle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
