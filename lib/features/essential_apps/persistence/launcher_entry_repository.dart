import 'dart:convert';

import '../models/launcher_entry.dart';
import '../shared/shared_launcher_bridge.dart';
import '../shared/shared_launcher_synchronizer.dart';
import '../validation/launch_url_validator.dart';
import 'launcher_entry_store.dart';

class LauncherLoadResult {
  const LauncherLoadResult({required this.entries, this.warning});

  final List<LauncherEntry> entries;
  final String? warning;
}

class LauncherEntryRepository {
  LauncherEntryRepository({
    required LauncherEntryStore store,
    SharedLauncherSynchronizer? sharedSynchronizer,
  }) : this._(store, sharedSynchronizer);

  LauncherEntryRepository._(this._store, this._sharedSynchronizer);

  static const int _schemaVersion = 1;

  final LauncherEntryStore _store;
  final SharedLauncherSynchronizer? _sharedSynchronizer;

  Future<LauncherLoadResult> loadEntries() async {
    final String? rawData = await _store.read();

    if (rawData == null || rawData.trim().isEmpty) {
      return const LauncherLoadResult(entries: <LauncherEntry>[]);
    }

    try {
      final Object? decoded = jsonDecode(rawData);
      if (decoded is! Map<String, Object?>) {
        return const LauncherLoadResult(
          entries: <LauncherEntry>[],
          warning: 'Saved launcher data could not be read.',
        );
      }

      if (decoded['schemaVersion'] != _schemaVersion) {
        return const LauncherLoadResult(
          entries: <LauncherEntry>[],
          warning: 'Saved launcher data uses an unsupported version.',
        );
      }

      final Object? rawEntries = decoded['entries'];
      if (rawEntries is! List<Object?>) {
        return const LauncherLoadResult(
          entries: <LauncherEntry>[],
          warning: 'Saved launcher entries are missing.',
        );
      }

      final List<LauncherEntry> entries = <LauncherEntry>[];
      final Set<String> seenIds = <String>{};
      final Set<String> seenLaunchUrls = <String>{};
      int skippedEntries = 0;

      for (final Object? rawEntry in rawEntries) {
        final LauncherEntry? entry = LauncherEntry.fromJson(rawEntry);
        if (entry == null) {
          skippedEntries++;
          continue;
        }

        final String duplicateKey = LaunchUrlValidator.duplicateKey(
          entry.launchUrl,
        );
        if (seenIds.contains(entry.id) ||
            seenLaunchUrls.contains(duplicateKey)) {
          skippedEntries++;
          continue;
        }

        seenIds.add(entry.id);
        seenLaunchUrls.add(duplicateKey);
        entries.add(entry);
      }

      return LauncherLoadResult(
        entries: List<LauncherEntry>.unmodifiable(entries),
        warning: skippedEntries == 0
            ? null
            : '$skippedEntries saved entries were skipped.',
      );
    } on FormatException {
      return const LauncherLoadResult(
        entries: <LauncherEntry>[],
        warning: 'Saved launcher data is corrupt.',
      );
    }
  }

  Future<void> saveEntries(List<LauncherEntry> entries) async {
    final Map<String, Object?> data = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'entries': entries.map((LauncherEntry entry) => entry.toJson()).toList(),
    };

    await _store.write(jsonEncode(data));
    await _syncSharedEntries(entries);
  }

  Future<List<LauncherEntry>> addEntry(LauncherEntry entry) async {
    _assertValidEntry(entry);
    final List<LauncherEntry> entries = await _currentEntries();
    _assertNoDuplicate(entries, entry);
    final List<LauncherEntry> nextEntries = <LauncherEntry>[...entries, entry];
    await _saveLocalEntries(nextEntries);
    await _syncSharedEntries(nextEntries);
    return List<LauncherEntry>.unmodifiable(nextEntries);
  }

  Future<List<LauncherEntry>> updateEntry(LauncherEntry entry) async {
    _assertValidEntry(entry);
    final List<LauncherEntry> entries = await _currentEntries();
    final int index = entries.indexWhere(
      (LauncherEntry existing) => existing.id == entry.id,
    );

    if (index == -1) {
      throw const LauncherEntryException('The entry could not be found.');
    }

    _assertNoDuplicate(entries, entry, ignoredEntryId: entry.id);

    if (entries[index] == entry) {
      return List<LauncherEntry>.unmodifiable(entries);
    }

    final List<LauncherEntry> nextEntries = <LauncherEntry>[...entries];
    nextEntries[index] = entry;
    await _saveLocalEntries(nextEntries);
    await _syncSharedEntries(nextEntries);
    return List<LauncherEntry>.unmodifiable(nextEntries);
  }

  Future<List<LauncherEntry>> deleteEntry(String id) async {
    final List<LauncherEntry> entries = await _currentEntries();
    if (!entries.any((LauncherEntry entry) => entry.id == id)) {
      return List<LauncherEntry>.unmodifiable(entries);
    }

    final List<LauncherEntry> nextEntries = entries
        .where((LauncherEntry entry) => entry.id != id)
        .toList();

    await _saveLocalEntries(nextEntries);
    await _syncSharedEntries(nextEntries);
    return List<LauncherEntry>.unmodifiable(nextEntries);
  }

  Future<List<LauncherEntry>> reorderEntries(int oldIndex, int newIndex) async {
    final List<LauncherEntry> entries = await _currentEntries();
    if (oldIndex < 0 ||
        oldIndex >= entries.length ||
        newIndex < 0 ||
        newIndex > entries.length) {
      throw const LauncherEntryException('The new order is invalid.');
    }

    if (oldIndex == newIndex) {
      return List<LauncherEntry>.unmodifiable(entries);
    }

    final List<LauncherEntry> nextEntries = <LauncherEntry>[...entries];
    final LauncherEntry movedEntry = nextEntries.removeAt(oldIndex);
    nextEntries.insert(newIndex, movedEntry);

    await _saveLocalEntries(nextEntries);
    await _syncSharedEntries(nextEntries);
    return List<LauncherEntry>.unmodifiable(nextEntries);
  }

  Future<void> syncCurrentEntries() async {
    await _syncSharedEntries(await _currentEntries());
  }

  Future<void> _saveLocalEntries(List<LauncherEntry> entries) async {
    final Map<String, Object?> data = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'entries': entries.map((LauncherEntry entry) => entry.toJson()).toList(),
    };

    await _store.write(jsonEncode(data));
  }

  Future<void> _syncSharedEntries(List<LauncherEntry> entries) async {
    try {
      await _sharedSynchronizer?.syncEntries(entries);
    } on SharedLauncherSyncFailure catch (error) {
      throw SharedLauncherSyncException(
        code: error.code,
        message: error.message,
        entries: List<LauncherEntry>.unmodifiable(entries),
      );
    }
  }

  Future<List<LauncherEntry>> _currentEntries() async {
    return (await loadEntries()).entries;
  }

  void _assertNoDuplicate(
    List<LauncherEntry> entries,
    LauncherEntry entry, {
    String? ignoredEntryId,
  }) {
    final String duplicateKey = LaunchUrlValidator.duplicateKey(
      entry.launchUrl,
    );
    final bool hasDuplicate = entries.any((LauncherEntry existing) {
      return existing.id != ignoredEntryId &&
          LaunchUrlValidator.duplicateKey(existing.launchUrl) == duplicateKey;
    });

    if (hasDuplicate) {
      throw const DuplicateLauncherEntryException();
    }
  }

  void _assertValidEntry(LauncherEntry entry) {
    if (entry.name.trim().isEmpty ||
        LaunchUrlValidator.validate(entry.launchUrl) != null) {
      throw const LauncherEntryException('The app entry is invalid.');
    }
  }
}

class LauncherEntryException implements Exception {
  const LauncherEntryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuplicateLauncherEntryException extends LauncherEntryException {
  const DuplicateLauncherEntryException()
    : super('That app is already in your list.');
}

class SharedLauncherSyncException extends LauncherEntryException {
  const SharedLauncherSyncException({
    required this.code,
    required this.entries,
    required String message,
  }) : super(message);

  final SharedLauncherBridgeErrorCode code;
  final List<LauncherEntry> entries;
}
