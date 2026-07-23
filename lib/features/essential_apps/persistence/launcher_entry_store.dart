import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LauncherEntryStore {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesLauncherEntryStore implements LauncherEntryStore {
  static const String _storageKey = 'essential_launcher_entries_v1';

  @override
  Future<String?> read() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_storageKey);
  }

  @override
  Future<void> write(String value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setString(_storageKey, value);
    if (!saved) {
      throw StateError('SharedPreferences rejected the launcher list update.');
    }
  }
}
