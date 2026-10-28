import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'bottom_nav.dart';

/// Shared destination style for the app shell and service screens.
class ExpressiveDestination {
  const ExpressiveDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class ExpressiveDestinationBar extends StatelessWidget {
  const ExpressiveDestinationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ExpressiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool floating =
        Theme.of(context).extension<AtriumNavigationStyle>()?.floating ?? false;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          floating ? Insets.md : 0,
          floating ? Insets.sm : 0,
          floating ? Insets.md : 0,
          floating ? Insets.sm : 0,
        ),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: floating ? Radii.chip : BorderRadius.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: <Widget>[
                for (int index = 0; index < destinations.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: index == selectedIndex
                            ? colors.secondaryContainer
                            : Colors.transparent,
                        borderRadius: Radii.chip,
                        child: InkWell(
                          borderRadius: Radii.chip,
                          onTap: () => onSelected(index),
                          child: SizedBox(
                            height: 64,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  destinations[index].icon,
                                  size: 22,
                                  color: index == selectedIndex
                                      ? colors.onSecondaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  destinations[index].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: index == selectedIndex
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: index == selectedIndex
                                        ? colors.onSecondaryContainer
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
