import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF62756B);

  static ThemeData light() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: _seedColor);

    return _themeFrom(colorScheme);
  }

  static ThemeData dark() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return _themeFrom(colorScheme);
  }

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: Typography.material2021().black.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      focusColor: colorScheme.primary.withValues(alpha: 0.18),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );
  }
}
