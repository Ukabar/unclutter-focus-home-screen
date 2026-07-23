import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryLauncherEntryStore store;
  late LauncherEntryRepository repository;

  setUp(() {
    store = MemoryLauncherEntryStore();
    repository = LauncherEntryRepository(store: store);
  });

  test('add, edit, remove, reorder, and reload persist entries', () async {
    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );
    final LauncherEntry mail = LauncherEntry.fromUserInput(
      name: 'Mail',
      launchUrl: 'mailto:',
    );

    await repository.addEntry(maps);
    await repository.addEntry(mail);

    final LauncherEntry renamedMaps = maps.copyWith(name: 'Apple Maps');
    await repository.updateEntry(renamedMaps);
    await repository.reorderEntries(1, 0);
    await repository.deleteEntry(renamedMaps.id);

    final LauncherLoadResult result = await LauncherEntryRepository(
      store: store,
    ).loadEntries();

    expect(result.entries, <LauncherEntry>[mail]);
    expect(result.warning, isNull);
  });

  test('duplicate launch URLs are rejected', () async {
    await repository.addEntry(
      LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'),
    );

    expect(
      () => repository.addEntry(
        LauncherEntry.fromUserInput(name: 'Maps again', launchUrl: 'MAPS:'),
      ),
      throwsA(isA<DuplicateLauncherEntryException>()),
    );
  });

  test('invalid entries are rejected before persistence', () async {
    expect(
      () => repository.addEntry(
        const LauncherEntry(id: 'bad', name: '', launchUrl: 'maps:'),
      ),
      throwsA(isA<LauncherEntryException>()),
    );
  });

  test('corrupt stored data falls back safely', () async {
    store.value = 'not json';

    final LauncherLoadResult result = await repository.loadEntries();

    expect(result.entries, isEmpty);
    expect(result.warning, 'Saved launcher data is corrupt.');
  });

  test('unsupported schema version falls back safely', () async {
    store.value = '{"schemaVersion":99,"entries":[]}';

    final LauncherLoadResult result = await repository.loadEntries();

    expect(result.entries, isEmpty);
    expect(result.warning, 'Saved launcher data uses an unsupported version.');
  });

  test('invalid and duplicate stored entries are skipped', () async {
    store.value = '''
{
  "schemaVersion": 1,
  "entries": [
    {"id":"a","name":"Maps","launchUrl":"maps:"},
    {"id":"a","name":"Duplicate id","launchUrl":"sms:"},
    {"id":"b","name":"Duplicate url","launchUrl":"MAPS:"},
    {"id":"c","name":"","launchUrl":"mailto:"}
  ]
}
''';

    final LauncherLoadResult result = await repository.loadEntries();

    expect(result.entries, hasLength(1));
    expect(result.entries.single.name, 'Maps');
    expect(result.warning, '3 saved entries were skipped.');
  });
}

class MemoryLauncherEntryStore implements LauncherEntryStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
