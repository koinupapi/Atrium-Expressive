
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart' hide CorePalette;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'design_tokens.dart';

/// Atrium Expressive's Material 3 theme.
///
/// On Android 12+, wallpaper-derived dynamic colors are used when available.
/// Otherwise, the app falls back to a violet seed color.
/// Light and dark themes share the same color source.
abstract final class AtriumTheme {
  /// Fallback seed when dynamic color is unavailable.
  static const Color seed = Color(0xFF6750A4);

  static ThemeData light(ColorScheme? dynamicScheme, {String? fontFamily}) =>
      _build(
        dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed),
        fontFamily,
      );

  static ThemeData dark(ColorScheme? dynamicScheme, {String? fontFamily}) =>
      _build(
        dynamicScheme ??
            ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
        fontFamily,
      );

  static ThemeData _build(ColorScheme scheme, String? fontFamily) {
    final bool isDark = scheme.brightness == Brightness.dark;

    final flex = isDark
        ? FlexColorScheme.dark(
            colorScheme: scheme,
            fontFamily: fontFamily,
            subThemesData: const FlexSubThemesData(
              defaultRadius: 20.0,
              inputDecoratorIsFilled: false,
              inputDecoratorBorderType: FlexInputBorderType.outline,
            ),
          )
        : FlexColorScheme.light(
            colorScheme: scheme,
            fontFamily: fontFamily,
            subThemesData: const FlexSubThemesData(
              defaultRadius: 20.0,
              inputDecoratorIsFilled: false,
              inputDecoratorBorderType: FlexInputBorderType.outline,
            ),
          );

    final ThemeData baseTheme = flex.toTheme;
    final ColorScheme resolvedScheme = baseTheme.colorScheme;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: resolvedScheme.surface,

      // A stronger expressive navigation selection, shared by the app shell
      // and every service tab bar that uses Material NavigationBar.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: resolvedScheme.surfaceContainer,
        indicatorColor: resolvedScheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? resolvedScheme.onSurface
                : resolvedScheme.onSurfaceVariant,
          ),
        ),
      ),

      // Material 3 Expressive-inspired pill-shaped buttons.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(48, 48),
        ),
      ),

      // Soft, rounded cards.
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: resolvedScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
        margin: EdgeInsets.zero,
      ),

      // Preserve the existing list layout.
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Insets.lg),
      ),

      // Rounded, softly filled text fields.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            resolvedScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
      ),

      // Pill-shaped chips.
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        side: BorderSide.none,
        backgroundColor: resolvedScheme.surfaceContainerHighest,
      ),

      // Floating notifications.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Wraps the app with platform dynamic-color palettes when available.
  static Widget withDynamicColor({
    required Widget Function(ColorScheme? light, ColorScheme? dark) builder,
  }) {
    return _AtriumDynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
          builder(lightDynamic?.harmonized(), darkDynamic?.harmonized()),
    );
  }
}

/// Custom dynamic color builder.
///
/// Bypasses getColorSchemes() because its Android application-context lookup
/// can return non-dynamic colors on Android 14+.
/// Uses getCorePalette() directly instead.
class _AtriumDynamicColorBuilder extends StatefulWidget {
  const _AtriumDynamicColorBuilder({required this.builder});

  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;

  @override
  State<_AtriumDynamicColorBuilder> createState() =>
      _AtriumDynamicColorBuilderState();
}

class _AtriumDynamicColorBuilderState
    extends State<_AtriumDynamicColorBuilder> {
  ColorScheme? _light;
  ColorScheme? _dark;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    try {
      // ignore: deprecated_member_use
      final CorePalette? corePalette =
          await DynamicColorPlugin.getCorePalette();

      if (!mounted) return;

      if (corePalette != null) {
        if (kDebugMode) {
          debugPrint(
            'dynamic_color: Core palette detected (bypassed schemes).',
          );
        }

        setState(() {
          _light = corePalette.toColorScheme();
          _dark = corePalette.toColorScheme(brightness: Brightness.dark);
        });
        return;
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain core palette. $e');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Core palette channel unavailable. $e');
      }
    }

    try {
      final Color? accentColor = await DynamicColorPlugin.getAccentColor();

      if (!mounted) return;

      if (accentColor != null) {
        if (kDebugMode) {
          debugPrint('dynamic_color: Accent color detected.');
        }

        setState(() {
          _light = ColorScheme.fromSeed(seedColor: accentColor);
          _dark = ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          );
        });
        return;
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Failed to obtain accent color. $e');
      }
    } on MissingPluginException catch (e) {
      if (kDebugMode) {
        debugPrint('dynamic_color: Accent color channel unavailable. $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_light, _dark);
  }
}
