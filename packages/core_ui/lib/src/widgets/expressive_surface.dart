import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Shared expressive surface used by dashboard and service modules.
///
/// Color comes from the active Material color scheme, so wallpaper-derived
/// palettes and light/dark themes remain the single source of truth.
class ExpressiveSurface extends StatelessWidget {
  const ExpressiveSurface({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: color ?? colors.surfaceContainerHigh,
      borderRadius: Radii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Consistent tonal icon container for expressive headers and cards.
class ExpressiveIconBadge extends StatelessWidget {
  const ExpressiveIconBadge({
    required this.icon,
    this.accent,
    this.size = 44,
    this.iconSize = 24,
    super.key,
  });

  final IconData icon;
  final Color? accent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color foreground = accent ?? colors.onPrimaryContainer;
    final Color background = accent == null
        ? colors.primaryContainer
        : foreground.withValues(alpha: 0.16);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
