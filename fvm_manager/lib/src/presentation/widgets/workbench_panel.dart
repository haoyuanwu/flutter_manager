import 'package:flutter/material.dart';

class WorkbenchPanel extends StatefulWidget {
  const WorkbenchPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  State<WorkbenchPanel> createState() => _WorkbenchPanelState();
}

class _WorkbenchPanelState extends State<WorkbenchPanel> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: duration,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _focused ? colors.primary : colors.outlineVariant,
          ),
          boxShadow: colors.brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: colors.onSurface.withValues(alpha: .035),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: widget.title == null
              ? Padding(padding: widget.padding, child: widget.child)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              widget.title!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      ),
                    ),
                    Padding(padding: widget.padding, child: widget.child),
                  ],
                ),
        ),
      ),
    );
  }
}

class WorkbenchSection extends StatelessWidget {
  const WorkbenchSection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .6),
          ),
        ),
      ),
      child: child,
    ),
  );
}
