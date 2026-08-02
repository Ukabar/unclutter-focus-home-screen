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
      orElse: () => AppDefaults.defaultThemeChoice,
    );
  }
}

enum AppAccentChoice {
  dusk('dusk', 'Dusk', Color(0xFFD3A5FF)),
  quietBlue('quietBlue', 'Quiet Blue', Color(0xFF7FB6FF)),
  sage('sage', 'Sage', Color(0xFF92A98E)),
  warmGray('warmGray', 'Warm Gray', Color(0xFFB6AEA5));

  const AppAccentChoice(this.storageValue, this.label, this.color);

  final String storageValue;
  final String label;
  final Color color;

  static AppAccentChoice fromStorage(String? value) {
    return values.firstWhere(
      (AppAccentChoice choice) => choice.storageValue == value,
      orElse: () => AppDefaults.defaultAccentChoice,
    );
  }
}

enum WidgetStyleSetting {
  disabled('disabled', 'Coming soon', false);

  const WidgetStyleSetting(this.storageValue, this.label, this.enabled);

  final String storageValue;
  final String label;
  final bool enabled;

  static WidgetStyleSetting fromStorage(String? value) {
    return values.firstWhere(
      (WidgetStyleSetting style) => style.storageValue == value,
      orElse: () => AppDefaults.defaultWidgetStyle,
    );
  }
}

enum PrivacySetting {
  localOnly('localOnly', 'Local only');

  const PrivacySetting(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static PrivacySetting fromStorage(String? value) {
    return values.firstWhere(
      (PrivacySetting privacy) => privacy.storageValue == value,
      orElse: () => AppDefaults.defaultPrivacy,
    );
  }
}

class AppDefaults {
  const AppDefaults._();

  static const int settingsSchemaVersion = 1;
  static const AppThemeChoice defaultThemeChoice = AppThemeChoice.dark;
  static const AppAccentChoice defaultAccentChoice = AppAccentChoice.dusk;
  static const WidgetStyleSetting defaultWidgetStyle =
      WidgetStyleSetting.disabled;
  static const PrivacySetting defaultPrivacy = PrivacySetting.localOnly;
  static const String aboutDisplayName = 'Stillscreen: Focus Launcher';
  static const String bundleIdentifier = 'com.zyverio.focuslauncher';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '3';

  static const AppSettings settings = AppSettings(
    themeChoice: defaultThemeChoice,
    accentChoice: defaultAccentChoice,
    widgetStyle: defaultWidgetStyle,
    privacy: defaultPrivacy,
  );
}

@Deprecated('Use AppDefaults.')
class DefaultSettings {
  const DefaultSettings._();

  static const AppThemeChoice themeChoice = AppDefaults.defaultThemeChoice;
  static const AppAccentChoice accentChoice = AppDefaults.defaultAccentChoice;
  static const WidgetStyleSetting widgetStyle = AppDefaults.defaultWidgetStyle;
  static const PrivacySetting privacy = AppDefaults.defaultPrivacy;
  static const String aboutDisplayName = AppDefaults.aboutDisplayName;
  static const AppAppearanceSettings appearance = AppAppearanceSettings(
    themeChoice: themeChoice,
    accentChoice: accentChoice,
  );
}

class AppSettings {
  const AppSettings({
    required this.themeChoice,
    required this.accentChoice,
    required this.widgetStyle,
    required this.privacy,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      themeChoice: AppThemeChoice.fromStorage(json['themeMode'] as String?),
      accentChoice: AppAccentChoice.fromStorage(json['accentColor'] as String?),
      widgetStyle: WidgetStyleSetting.fromStorage(
        json['widgetStyle'] as String?,
      ),
      privacy: PrivacySetting.fromStorage(json['privacyMode'] as String?),
    );
  }

  final AppThemeChoice themeChoice;
  final AppAccentChoice accentChoice;
  final WidgetStyleSetting widgetStyle;
  final PrivacySetting privacy;

  ThemeMode get themeMode => themeChoice.themeMode;

  AppSettings copyWith({
    AppThemeChoice? themeChoice,
    AppAccentChoice? accentChoice,
    WidgetStyleSetting? widgetStyle,
    PrivacySetting? privacy,
  }) {
    return AppSettings(
      themeChoice: themeChoice ?? this.themeChoice,
      accentChoice: accentChoice ?? this.accentChoice,
      widgetStyle: widgetStyle ?? this.widgetStyle,
      privacy: privacy ?? this.privacy,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'themeMode': themeChoice.storageValue,
      'accentColor': accentChoice.storageValue,
      'widgetStyle': widgetStyle.storageValue,
      'privacyMode': privacy.storageValue,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themeChoice == themeChoice &&
        other.accentChoice == accentChoice &&
        other.widgetStyle == widgetStyle &&
        other.privacy == privacy;
  }

  @override
  int get hashCode =>
      Object.hash(themeChoice, accentChoice, widgetStyle, privacy);
}

class AppAppearanceSettings {
  const AppAppearanceSettings({
    required this.themeChoice,
    required this.accentChoice,
  });

  const AppAppearanceSettings.defaults()
    : themeChoice = AppDefaults.defaultThemeChoice,
      accentChoice = AppDefaults.defaultAccentChoice;

  factory AppAppearanceSettings.fromSettings(AppSettings settings) {
    return AppAppearanceSettings(
      themeChoice: settings.themeChoice,
      accentChoice: settings.accentChoice,
    );
  }

  final AppThemeChoice themeChoice;
  final AppAccentChoice accentChoice;
}

class SettingsRepository {
  const SettingsRepository();

  static const String schemaVersionKey =
      'stillscreen_settings_schema_version_v1';
  static const String themeKey = 'stillscreen_theme_choice_v1';
  static const String accentKey = 'stillscreen_accent_choice_v1';
  static const String widgetStyleKey = 'stillscreen_widget_style_v1';
  static const String privacyKey = 'stillscreen_privacy_mode_v1';

  static const List<String> _legacyThemeKeys = <String>[
    'theme',
    'themeMode',
    'selectedTheme',
  ];
  static const List<String> _legacyAccentKeys = <String>[
    'accent',
    'accentColor',
  ];
  static const List<String> _legacyWidgetStyleKeys = <String>['widgetStyle'];
  static const List<String> _legacyPrivacyKeys = <String>['privacyMode'];

  Future<AppSettings> loadSettings() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await migrateLegacySettings(preferences);

    final AppSettings settings = AppSettings(
      themeChoice: AppThemeChoice.fromStorage(preferences.getString(themeKey)),
      accentChoice: AppAccentChoice.fromStorage(
        preferences.getString(accentKey),
      ),
      widgetStyle: WidgetStyleSetting.fromStorage(
        preferences.getString(widgetStyleKey),
      ),
      privacy: PrivacySetting.fromStorage(preferences.getString(privacyKey)),
    );

    await saveSettings(settings);
    return settings;
  }

  Future<void> saveSettings(AppSettings settings) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      schemaVersionKey,
      AppDefaults.settingsSchemaVersion,
    );
    await preferences.setString(themeKey, settings.themeChoice.storageValue);
    await preferences.setString(accentKey, settings.accentChoice.storageValue);
    await preferences.setString(
      widgetStyleKey,
      settings.widgetStyle.storageValue,
    );
    await preferences.setString(privacyKey, settings.privacy.storageValue);
  }

  Future<AppSettings> resetSettings() async {
    await saveSettings(AppDefaults.settings);
    return AppDefaults.settings;
  }

  Future<void> migrateLegacySettings([SharedPreferences? preferences]) async {
    final SharedPreferences prefs =
        preferences ?? await SharedPreferences.getInstance();
    if ((prefs.getInt(schemaVersionKey) ?? 0) >=
        AppDefaults.settingsSchemaVersion) {
      return;
    }

    final String? legacyTheme = _firstExistingString(prefs, _legacyThemeKeys);
    final String? legacyAccent = _firstExistingString(prefs, _legacyAccentKeys);
    final String? legacyWidgetStyle = _firstExistingString(
      prefs,
      _legacyWidgetStyleKeys,
    );
    final String? legacyPrivacy = _firstExistingString(
      prefs,
      _legacyPrivacyKeys,
    );

    final AppSettings migrated = AppSettings(
      themeChoice: AppThemeChoice.fromStorage(
        prefs.getString(themeKey) ?? legacyTheme,
      ),
      accentChoice: AppAccentChoice.fromStorage(
        prefs.getString(accentKey) ?? legacyAccent,
      ),
      widgetStyle: WidgetStyleSetting.fromStorage(
        prefs.getString(widgetStyleKey) ?? legacyWidgetStyle,
      ),
      privacy: PrivacySetting.fromStorage(
        prefs.getString(privacyKey) ?? legacyPrivacy,
      ),
    );

    await saveSettings(migrated);
    for (final String key in <String>[
      ..._legacyThemeKeys,
      ..._legacyAccentKeys,
      ..._legacyWidgetStyleKeys,
      ..._legacyPrivacyKeys,
    ]) {
      if (key != themeKey &&
          key != accentKey &&
          key != widgetStyleKey &&
          key != privacyKey) {
        await prefs.remove(key);
      }
    }
  }

  String? _firstExistingString(
    SharedPreferences preferences,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final String? value = preferences.getString(key);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

class AppSettingsStore {
  const AppSettingsStore({this.repository = const SettingsRepository()});

  final SettingsRepository repository;

  Future<AppAppearanceSettings> load() async {
    return AppAppearanceSettings.fromSettings(await repository.loadSettings());
  }

  Future<AppSettings> loadSettings() => repository.loadSettings();

  Future<AppAppearanceSettings> resetToDefaults() async {
    return AppAppearanceSettings.fromSettings(await repository.resetSettings());
  }

  Future<AppSettings> resetSettings() => repository.resetSettings();

  Future<void> saveThemeChoice(AppThemeChoice choice) async {
    final AppSettings settings = await repository.loadSettings();
    await repository.saveSettings(settings.copyWith(themeChoice: choice));
  }

  Future<void> saveAccentChoice(AppAccentChoice choice) async {
    final AppSettings settings = await repository.loadSettings();
    await repository.saveSettings(settings.copyWith(accentChoice: choice));
  }
}
