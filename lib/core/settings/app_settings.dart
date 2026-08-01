import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeChoice {
  system('system', 'System', ThemeMode.system),
  light('light', 'Light', ThemeMode.light),
  dark('dark', 'Dark', ThemeMode.dark);

  const AppThemeChoice(this.storageValue, this.label, this.themeMode);

  final String storageValue;
  final String label;
  final ThemeMode themeMode;

  static AppThemeChoice fromStorage(String? value) {
    return values.firstWhere(
      (AppThemeChoice choice) => choice.storageValue == value,
      orElse: () => AppThemeChoice.dark,
    );
  }
}

enum AppAccentChoice {
  quietBlue('quietBlue', 'Quiet Blue', Color(0xFF7FB6FF)),
  sage('sage', 'Sage', Color(0xFF92A98E)),
  dusk('dusk', 'Dusk', Color(0xFFD3A5FF));

  const AppAccentChoice(this.storageValue, this.label, this.color);

  final String storageValue;
  final String label;
  final Color color;

  static AppAccentChoice fromStorage(String? value) {
    return values.firstWhere(
      (AppAccentChoice choice) => choice.storageValue == value,
      orElse: () => AppAccentChoice.dusk,
    );
  }
}

enum WidgetStyleSetting {
  comingSoonDisabled('comingSoonDisabled', 'Coming soon', false);

  const WidgetStyleSetting(this.storageValue, this.label, this.enabled);

  final String storageValue;
  final String label;
  final bool enabled;
}

enum PrivacySetting {
  localOnly('localOnly', 'Local only');

  const PrivacySetting(this.storageValue, this.label);

  final String storageValue;
  final String label;
}

class DefaultSettings {
  const DefaultSettings._();

  static const AppThemeChoice themeChoice = AppThemeChoice.dark;
  static const AppAccentChoice accentChoice = AppAccentChoice.dusk;
  static const WidgetStyleSetting widgetStyle =
      WidgetStyleSetting.comingSoonDisabled;
  static const PrivacySetting privacy = PrivacySetting.localOnly;
  static const String aboutDisplayName = 'Stillscreen: Focus Launcher';

  static const AppAppearanceSettings appearance = AppAppearanceSettings(
    themeChoice: themeChoice,
    accentChoice: accentChoice,
  );
}

class AppAppearanceSettings {
  const AppAppearanceSettings({
    required this.themeChoice,
    required this.accentChoice,
  });

  const AppAppearanceSettings.defaults()
    : themeChoice = DefaultSettings.themeChoice,
      accentChoice = DefaultSettings.accentChoice;

  final AppThemeChoice themeChoice;
  final AppAccentChoice accentChoice;
}

class AppSettingsStore {
  const AppSettingsStore();

  static const String _themeKey = 'stillscreen_theme_choice_v1';
  static const String _accentKey = 'stillscreen_accent_choice_v1';

  Future<AppAppearanceSettings> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? storedTheme = preferences.getString(_themeKey);
    final String? storedAccent = preferences.getString(_accentKey);
    final AppThemeChoice themeChoice = storedTheme == null
        ? DefaultSettings.themeChoice
        : AppThemeChoice.fromStorage(storedTheme);
    final AppAccentChoice accentChoice = storedAccent == null
        ? DefaultSettings.accentChoice
        : AppAccentChoice.fromStorage(storedAccent);

    if (storedTheme == null) {
      await preferences.setString(_themeKey, themeChoice.storageValue);
    }
    if (storedAccent == null) {
      await preferences.setString(_accentKey, accentChoice.storageValue);
    }

    return AppAppearanceSettings(
      themeChoice: themeChoice,
      accentChoice: accentChoice,
    );
  }

  Future<AppAppearanceSettings> resetToDefaults() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themeKey,
      DefaultSettings.themeChoice.storageValue,
    );
    await preferences.setString(
      _accentKey,
      DefaultSettings.accentChoice.storageValue,
    );
    return DefaultSettings.appearance;
  }

  Future<void> saveThemeChoice(AppThemeChoice choice) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, choice.storageValue);
  }

  Future<void> saveAccentChoice(AppAccentChoice choice) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accentKey, choice.storageValue);
  }
}
