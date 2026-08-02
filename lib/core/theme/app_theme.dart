import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF05080B);
  static const Color elevatedInk = Color(0xFF111820);
  static const Color card = Color(0xFF18212B);
  static const Color line = Color(0xFF283545);
  static const Color ivory = Color(0xFFF4F0E8);
  static const Color muted = Color(0xFF9BA8B5);
  static const Color accent = Color(0xFFD3A5FF);
  static const Color sage = Color(0xFF92A98E);

  static ThemeData light({Color accentColor = accent}) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );

    return _themeFrom(colorScheme);
  }

  static ThemeData dark({Color accentColor = accent}) {
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: accentColor,
      onPrimary: Color(0xFF001E35),
      secondary: sage,
      onSecondary: Color(0xFF0B1512),
      surface: ink,
      onSurface: ivory,
      surfaceContainerHighest: card,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: Color(0xFF202B38),
      error: Color(0xFFFF8D86),
      onError: Color(0xFF3A0704),
    );

    return _themeFrom(colorScheme);
  }

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      textTheme: Typography.material2021().white.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      focusColor: colorScheme.primary.withValues(alpha: 0.18),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );
  }
}
