import 'package:flutter/material.dart';

import 'bottom_nav.dart';

/// Standard clearance for content that scrolls underneath floating navigation.
/// Use [bottomPadding] on a scrollable's existing padding rather than adding
/// a separate footer or guessing the pill's height in each service.
abstract final class ExpressiveNavigationClearance {
  static const double floating = 112;
  static const double standard = 16;

  static double bottomPadding(BuildContext context) {
    final bool isFloating =
        Theme.of(context).extension<AtriumNavigationStyle>()?.floating ?? false;
    return isFloating ? floating : standard;
  }

  static EdgeInsets listPadding(BuildContext context, {double horizontal = 16, double top = 16}) =>
      EdgeInsets.fromLTRB(horizontal, top, horizontal, bottomPadding(context));
}

/// Standard page layout: floating navigation overlays content, while
/// full-width navigation occupies its own row.
class ExpressiveNavigationLayout extends StatelessWidget {
  const ExpressiveNavigationLayout({
    required this.content,
    required this.navigation,
    super.key,
  });

  final Widget content;
  final Widget navigation;

  @override
  Widget build(BuildContext context) {
    final bool floating =
        Theme.of(context).extension<AtriumNavigationStyle>()?.floating ?? false;
    if (!floating) {
      return Column(
        children: <Widget>[
          Expanded(child: content),
          navigation,
        ],
      );
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: content),
        Positioned(left: 0, right: 0, bottom: 0, child: navigation),
      ],
    );
  }
}
