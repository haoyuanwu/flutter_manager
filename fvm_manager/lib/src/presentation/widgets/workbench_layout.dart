import 'package:flutter/material.dart';

class WorkbenchPageHeader extends StatelessWidget {
  const WorkbenchPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.breakpoint = 900,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    if (actions.isEmpty) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < breakpoint;
        final toolbar = Wrap(
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: actions,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 12), toolbar],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: heading),
            const SizedBox(width: 24),
            Expanded(
              flex: actions.length > 2 ? 4 : 2,
              child: Align(alignment: Alignment.topRight, child: toolbar),
            ),
          ],
        );
      },
    );
  }
}

class WorkbenchSplitSections extends StatelessWidget {
  const WorkbenchSplitSections({
    super.key,
    required this.leading,
    required this.trailing,
    this.breakpoint = 920,
    this.equalHeight = false,
  });

  final Widget leading;
  final Widget trailing;
  final double breakpoint;
  final bool equalHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [leading, const SizedBox(height: 16), trailing],
        );
      }
      final row = Row(
        crossAxisAlignment: equalHeight
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          Expanded(child: leading),
          const SizedBox(width: 16),
          Expanded(child: trailing),
        ],
      );
      return equalHeight ? IntrinsicHeight(child: row) : row;
    },
  );
}

class WorkbenchSectionHeading extends StatelessWidget {
  const WorkbenchSectionHeading({
    super.key,
    required this.title,
    required this.icon,
    this.color,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class WorkbenchScrollPage extends StatelessWidget {
  const WorkbenchScrollPage({
    super.key,
    required this.child,
    this.maxWidth = 1120,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: false,
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}
