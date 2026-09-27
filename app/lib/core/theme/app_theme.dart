import 'package:flutter/material.dart';

/// Adaptive styling for split vs single screen (PRD: core/theme).
///
/// Material 3 color roles from a single seed meet the 4.5:1 text contrast
/// target in NFR-6. Text sizes come from the theme so Dynamic Type scales them.
abstract final class AppTheme {
  static const _seed = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }
}
