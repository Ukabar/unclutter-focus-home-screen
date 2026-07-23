import 'package:stillscreen_focus_launcher/app/app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/app_catalog_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/catalog_app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    final TestFlutterView view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('shows empty state and adds a curated app', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Choose what deserves a place here.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty-add-app-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();

    expect(find.text('Maps'), findsOneWidget);
    expect(store.value, contains('maps:'));
  });

  testWidgets('searches catalog and marks duplicates as selected', (
    tester,
  ) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );
    await LauncherEntryRepository(store: store).addEntry(maps);

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'mail',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mail'), findsOneWidget);
  });

  testWidgets('manually adds a custom scheme', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('empty-add-app-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry-name-field')),
      'Journal',
    );
    await tester.enterText(find.byKey(const Key('entry-url-field')), 'dayone:');
    await tester.tap(find.byKey(const Key('entry-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsOneWidget);
    expect(store.value, contains('dayone:'));
  });

  testWidgets('manual entry validates unsafe URLs', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('empty-add-app-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-entry-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-name-field')), 'Unsafe');
    await tester.enterText(
      find.byKey(const Key('entry-url-field')),
      'javascript:alert(1)',
    );
    await tester.tap(find.byKey(const Key('entry-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('That URL scheme is not supported.'), findsOneWidget);
    expect(store.value, isNull);
  });

  testWidgets('edits, removes, and reorders selected entries', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );
    final LauncherEntry mail = LauncherEntry.fromUserInput(
      name: 'Mail',
      launchUrl: 'mailto:',
    );
    final LauncherEntryRepository repository = LauncherEntryRepository(
      store: store,
    );
    await repository.addEntry(maps);
    await repository.addEntry(mail);

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('move-up-${mail.id}')));
    await tester.pumpAndSettle();
    expect((await repository.loadEntries()).entries.first.name, 'Mail');

    await tester.tap(find.byKey(Key('edit-${mail.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-name-field')), 'Email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);

    await tester.tap(find.byKey(Key('delete-${mail.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsNothing);
    expect((await repository.loadEntries()).entries, hasLength(1));
  });

  testWidgets('shows recoverable corrupt storage and repository failures', (
    tester,
  ) async {
    final MemoryLauncherEntryStore corruptStore = MemoryLauncherEntryStore()
      ..value = 'not json';

    await tester.pumpWidget(_testApp(store: corruptStore));
    await tester.pumpAndSettle();

    expect(find.text('Saved launcher data is corrupt.'), findsOneWidget);

    await tester.pumpWidget(
      StillscreenFocusLauncherApp(
        launcherEntryRepository: LauncherEntryRepository(
          store: FailingLauncherEntryStore(),
        ),
        appCatalogRepository: const StaticCatalogRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The list could not be loaded.'), findsOneWidget);
  });

  testWidgets('screen fits common iPhone sizes with large text', (
    tester,
  ) async {
    final TestFlutterView view = tester.view;
    view.devicePixelRatio = 3;

    for (final Size logicalSize in <Size>[
      const Size(375, 667),
      const Size(393, 852),
      const Size(430, 932),
    ]) {
      view.physicalSize = logicalSize * view.devicePixelRatio;

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            textScaler: const TextScaler.linear(1.6),
          ),
          child: _testApp(store: MemoryLauncherEntryStore()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Essential apps'), findsOneWidget);
    }
  });
}

StillscreenFocusLauncherApp _testApp({
  required MemoryLauncherEntryStore store,
}) {
  return StillscreenFocusLauncherApp(
    launcherEntryRepository: LauncherEntryRepository(store: store),
    appCatalogRepository: const StaticCatalogRepository(),
  );
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

class FailingLauncherEntryStore implements LauncherEntryStore {
  @override
  Future<String?> read() async {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> write(String value) async {
    throw StateError('storage unavailable');
  }
}

class StaticCatalogRepository implements AppCatalogRepository {
  const StaticCatalogRepository();

  @override
  Future<CatalogLoadResult> loadCatalog() async {
    return CatalogLoadResult(
      apps: <CatalogApp>[
        CatalogApp(
          id: LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:').id,
          name: 'Maps',
          launchUrl: 'maps:',
          category: 'Navigation',
        ),
        CatalogApp(
          id: LauncherEntry.fromUserInput(
            name: 'Mail',
            launchUrl: 'mailto:',
          ).id,
          name: 'Mail',
          launchUrl: 'mailto:',
          category: 'Communication',
        ),
      ],
    );
  }
}
