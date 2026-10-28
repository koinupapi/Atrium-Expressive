import 'package:flutter/material.dart';

import '../design_tokens.dart';

enum ExpressiveSurfaceShape { card, hero, feature, pill }

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
    this.shape = ExpressiveSurfaceShape.card,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final ExpressiveSurfaceShape shape;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: color ?? colors.surfaceContainerHigh,
      borderRadius: switch (shape) {
        ExpressiveSurfaceShape.card => Radii.card,
        ExpressiveSurfaceShape.hero => Radii.hero,
        ExpressiveSurfaceShape.feature => Radii.feature,
        ExpressiveSurfaceShape.pill => Radii.round,
      },
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
    this.round = false,
    super.key,
  });

  final IconData icon;
  final Color? accent;
  final double size;
  final double iconSize;
  final bool round;

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
        borderRadius: round ? Radii.round : BorderRadius.circular(Radii.md),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
