import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/core/settings/app_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first install creates default settings', () async {
    const SettingsRepository repository = SettingsRepository();

    final AppSettings settings = await repository.loadSettings();
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    expect(settings.themeChoice, AppThemeChoice.dark);
    expect(settings.accentChoice, AppAccentChoice.dusk);
    expect(settings.widgetStyle, WidgetStyleSetting.disabled);
    expect(settings.privacy, PrivacySetting.localOnly);
    expect(preferences.getString(SettingsRepository.themeKey), 'dark');
    expect(preferences.getString(SettingsRepository.accentKey), 'dusk');
  });

  test('saved settings persist and restore', () async {
    const SettingsRepository repository = SettingsRepository();

    await repository.saveSettings(
      AppDefaults.settings.copyWith(
        themeChoice: AppThemeChoice.light,
        accentChoice: AppAccentChoice.sage,
      ),
    );

    final AppSettings settings = await repository.loadSettings();

    expect(settings.themeChoice, AppThemeChoice.light);
    expect(settings.accentChoice, AppAccentChoice.sage);
  });

  test('unknown stored values fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsRepository.themeKey: 'neon',
      SettingsRepository.accentKey: 'laser',
      SettingsRepository.widgetStyleKey: 'floating',
      SettingsRepository.privacyKey: 'cloud',
    });
    const SettingsRepository repository = SettingsRepository();

    final AppSettings settings = await repository.loadSettings();

    expect(settings, AppDefaults.settings);
  });

  test('legacy keys migrate once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'themeMode': 'light',
      'accentColor': 'warmGray',
    });
    const SettingsRepository repository = SettingsRepository();

    final AppSettings settings = await repository.loadSettings();
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    expect(settings.themeChoice, AppThemeChoice.light);
    expect(settings.accentChoice, AppAccentChoice.warmGray);
    expect(
      preferences.getInt(SettingsRepository.schemaVersionKey),
      AppDefaults.settingsSchemaVersion,
    );
    expect(preferences.getString('themeMode'), isNull);
    expect(preferences.getString('accentColor'), isNull);
  });

  test('reset restores defaults', () async {
    const SettingsRepository repository = SettingsRepository();
    await repository.saveSettings(
      AppDefaults.settings.copyWith(
        themeChoice: AppThemeChoice.system,
        accentChoice: AppAccentChoice.quietBlue,
      ),
    );

    final AppSettings settings = await repository.resetSettings();

    expect(settings, AppDefaults.settings);
  });
}
