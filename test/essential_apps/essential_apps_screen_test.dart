import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/app/app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/app_catalog_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/catalog_app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    final TestFlutterView view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;

    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('new install opens onboarding', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Stillscreen'), findsOneWidget);
    expect(find.text('Pick Essential Apps'), findsNothing);
  });

  testWidgets('finish onboarding opens app picker without bottom navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    for (int index = 0; index < 4; index++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Pick Essential Apps'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.byKey(const Key('selection-continue-button')), findsOneWidget);
  });

  testWidgets('skip onboarding opens app picker', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Pick Essential Apps'), findsOneWidget);
    expect(find.text('0 / 12 selected'), findsOneWidget);
  });

  testWidgets('completed onboarding with empty selection opens app picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_onboarding_complete_v1': true,
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Pick Essential Apps'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('completed onboarding with saved apps opens home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_onboarding_complete_v1': true,
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Essential apps'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pick Essential Apps'), findsNothing);
  });

  testWidgets('initial picker continue saves apps and survives restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_onboarding_complete_v1': true,
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selection-continue-button')));
    await tester.pumpAndSettle();

    expect(store.value, contains('maps:'));
    expect(find.text('Home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Pick Essential Apps'), findsNothing);
  });

  testWidgets('reset returns to app picker when selection becomes empty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_onboarding_complete_v1': true,
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_startupApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Pick Essential Apps'), findsOneWidget);
    expect(find.text('0 / 12 selected'), findsOneWidget);
  });

  testWidgets('shows empty state and adds a curated app', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Choose what deserves a place here.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty-add-app-button')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with 1 app'), findsOneWidget);
    await tester.tap(find.byKey(const Key('selection-continue-button')));
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
    expect(find.text('1 / 12 selected'), findsOneWidget);
    expect(find.text('Continue with 1 app'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.check_mark_circled_solid), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'mail',
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(find.text('Mail'), findsOneWidget);
  });

  testWidgets('app picker shows empty search state', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('empty-add-app-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'not a real app',
    );
    await tester.pumpAndSettle();

    expect(find.text('No apps found'), findsOneWidget);
    expect(
      find.text('Try a different name or add a custom app.'),
      findsOneWidget,
    );
    expect(find.text('Add Custom App'), findsOneWidget);
  });

  testWidgets('app picker removes selected apps before continuing', (
    tester,
  ) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );
    final LauncherEntryRepository repository = LauncherEntryRepository(
      store: store,
    );
    await repository.addEntry(maps);

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12 selected'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byIcon(CupertinoIcons.check_mark_circled_solid).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('0 / 12 selected'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('app picker prevents selecting beyond the limit', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntryRepository repository = LauncherEntryRepository(
      store: store,
    );
    for (int index = 1; index <= 12; index++) {
      await repository.addEntry(
        LauncherEntry.fromUserInput(
          name: 'App $index',
          launchUrl: 'app$index:',
          category: 'Work',
        ),
      );
    }

    await tester.pumpWidget(
      StillscreenFocusLauncherApp(
        launcherEntryRepository: repository,
        appCatalogRepository: const LargeCatalogRepository(),
        showOnboarding: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.text('12 / 12 selected'), findsOneWidget);
    expect(find.text('Limit reached'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('catalog-search-field')), '13');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App 13'));
    await tester.pumpAndSettle();

    expect(find.text('You can keep up to 12 apps.'), findsOneWidget);
    expect(find.text('12 / 12 selected'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('selection-continue-button')));
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

    await tester.tap(find.text('Apps'));
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
        showOnboarding: false,
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
    showOnboarding: false,
  );
}

StillscreenFocusLauncherApp _startupApp({
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

class LargeCatalogRepository implements AppCatalogRepository {
  const LargeCatalogRepository();

  @override
  Future<CatalogLoadResult> loadCatalog() async {
    return CatalogLoadResult(
      apps: List<CatalogApp>.generate(13, (int index) {
        final int appNumber = index + 1;
        final LauncherEntry entry = LauncherEntry.fromUserInput(
          name: 'App $appNumber',
          launchUrl: 'app$appNumber:',
          category: 'Work',
        );
        return CatalogApp(
          id: entry.id,
          name: entry.name,
          launchUrl: entry.launchUrl,
          category: entry.category,
        );
      }),
    );
  }
}
