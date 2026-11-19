import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'dashboard_widget_kind.dart';

/// Shared chrome for every dashboard widget: a single calm surface card with
/// an accent-tinted icon badge, optional trailing pill/text, and the body.
///
/// Live sections share the same frame, with distinct tonal surfaces so the
/// summary tiles and their matching sections are easy to recognise.
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({
    required this.kind,
    required this.accent,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final DashboardWidgetKind kind;

  /// Role colour for this widget - used for the icon badge only.
  final Color accent;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final (Color surface, Color ink) = dashboardSectionColors(cs, kind);
    return Material(
      color: surface,
      borderRadius: const BorderRadiusDirectional.only(
        topStart: Radius.circular(28),
        topEnd: Radius.circular(36),
        bottomStart: Radius.circular(28),
        bottomEnd: Radius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(kind.icon, size: 24, color: accent),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      kind.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: Insets.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Pairs the summary tile and main card, using the active wallpaper palette.
(Color, Color) dashboardSectionColors(ColorScheme scheme, DashboardWidgetKind kind) =>
    switch (kind) {
      DashboardWidgetKind.streams =>
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      DashboardWidgetKind.downloads =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
      DashboardWidgetKind.upcoming =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

/// Previews stay compact, with the full live list one tap away.
class DashboardDisclosure extends StatefulWidget {
  const DashboardDisclosure({
    required this.previewCount,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int previewCount;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<DashboardDisclosure> createState() => _DashboardDisclosureState();
}

class _DashboardDisclosureState extends State<DashboardDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool canExpand = widget.itemCount > widget.previewCount;
    final int visibleCount =
        _expanded || !canExpand ? widget.itemCount : widget.previewCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < visibleCount; index++) ...<Widget>[
                widget.itemBuilder(context, index),
                const SizedBox(height: Insets.xs),
              ],
            ],
          ),
        ),
        if (canExpand)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? 'Show less' : 'View all ${widget.itemCount}'),
          ),
      ],
    );
  }
}

/// Small tonal metadata pill, matching the module screens.
class DashboardPill extends StatelessWidget {
  const DashboardPill({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Quiet single-line body used when a configured widget has nothing to show.
class DashboardIdleRow extends StatelessWidget {
  const DashboardIdleRow({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Compact inline error state with a retry action; the widget stays visible.
class DashboardErrorRow extends StatelessWidget {
  const DashboardErrorRow({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            'Could not load',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
