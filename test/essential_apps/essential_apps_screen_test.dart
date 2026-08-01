import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/app/app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/app_catalog_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/catalog_app.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/widgets/entry_form_dialog.dart';
import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_target_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -220),
    );
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
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();
    expect(find.text('Reset Stillscreen?'), findsOneWidget);
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    expect(find.text('Pick Essential Apps'), findsOneWidget);
    expect(find.text('0 / 12 selected'), findsOneWidget);
  });

  testWidgets('reset can be cancelled without clearing selected apps', (
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
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      (await LauncherEntryRepository(store: store).loadEntries()).entries,
      hasLength(1),
    );
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('settings theme button opens selector and applies choice', (
    tester,
  ) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsWidgets);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsWidgets);

    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsWidgets);
  });

  testWidgets('first install uses default dark theme and dusk accent', (
    tester,
  ) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Dusk'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(find.text('Stillscreen: Focus Launcher'), findsOneWidget);
  });

  testWidgets('saved settings are not replaced by defaults', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_theme_choice_v1': 'light',
      'stillscreen_accent_choice_v1': 'sage',
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Sage'), findsOneWidget);
    expect(find.text('Dark'), findsNothing);
    expect(find.text('Dusk'), findsNothing);
  });

  testWidgets('reset restores default settings', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'stillscreen_theme_choice_v1': 'light',
      'stillscreen_accent_choice_v1': 'sage',
    });
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('stillscreen_theme_choice_v1'), 'dark');
    expect(preferences.getString('stillscreen_accent_choice_v1'), 'dusk');
  });

  testWidgets('settings accent color button applies choice', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accent Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sage'));
    await tester.pumpAndSettle();

    expect(find.text('Sage'), findsOneWidget);
  });

  testWidgets('settings privacy and about buttons open content', (
    tester,
  ) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    await LauncherEntryRepository(
      store: store,
    ).addEntry(LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'));

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No tracking'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('com.zyverio.focuslauncher'), findsOneWidget);
    expect(find.text('Licenses'), findsOneWidget);
  });

  testWidgets('shows empty state and adds a curated app', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Choose what deserves a place here.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-first-app-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -220),
    );
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

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12 selected'), findsWidgets);
    expect(find.text('Continue with 1 app'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.check_mark_circled_solid), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('catalog-search-field')),
      'mail',
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mail'), findsOneWidget);
  });

  testWidgets('app picker shows empty search state', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-first-app-button')));
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

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12 selected'), findsWidgets);

    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byIcon(CupertinoIcons.check_mark_circled_solid).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('0 / 12 selected'), findsWidgets);
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

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-app-button')));
    await tester.pumpAndSettle();
    expect(find.text('12 / 12 selected'), findsWidgets);
    expect(find.text('Limit reached'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('catalog-search-field')), '13');
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('App 13'));
    await tester.pumpAndSettle();

    expect(find.text('You can keep up to 12 apps.'), findsOneWidget);
    expect(find.text('12 / 12 selected'), findsWidgets);
  });

  testWidgets('manually adds a custom scheme', (tester) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();

    await tester.pumpWidget(_testApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-first-app-button')));
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

    await tester.tap(find.byKey(const Key('add-first-app-button')));
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

  testWidgets('manual entry exposes a test launch action', (tester) async {
    final FakeLauncherTargetOpener opener = FakeLauncherTargetOpener(
      result: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () {
                  showDialog<LauncherEntry>(
                    context: context,
                    builder: (BuildContext context) {
                      return EntryFormDialog(targetOpener: opener);
                    },
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry-name-field')),
      'Journal',
    );
    await tester.enterText(find.byKey(const Key('entry-url-field')), 'dayone:');
    await tester.tap(find.byKey(const Key('entry-test-launch-button')));
    await tester.pumpAndSettle();

    expect(opener.openedUrls, <String>['dayone:']);
    expect(
      find.text(
        'This link could not be opened. Check that the app is installed and supports this URL.',
      ),
      findsOneWidget,
    );
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

    await tester.tap(find.byKey(Key('actions-${mail.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('move-up-${mail.id}')));
    await tester.pumpAndSettle();
    expect((await repository.loadEntries()).entries.first.name, 'Mail');

    await tester.tap(find.byKey(Key('actions-${mail.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('edit-${mail.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('entry-name-field')), 'Email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);

    await tester.tap(find.byKey(Key('actions-${mail.id}')));
    await tester.pumpAndSettle();
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

  testWidgets('app row handles compact, tablet, and long names', (
    tester,
  ) async {
    final TestFlutterView view = tester.view;
    view.devicePixelRatio = 3;

    for (final Size logicalSize in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
      await LauncherEntryRepository(store: store).addEntry(
        LauncherEntry.fromUserInput(
          name: 'A very long focus application name that should truncate',
          launchUrl: 'longfocus:',
        ),
      );
      view.physicalSize = logicalSize * view.devicePixelRatio;

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            textScaler: const TextScaler.linear(1.6),
          ),
          child: _testApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('A very long focus application name that should truncate'),
        findsOneWidget,
      );
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

class FakeLauncherTargetOpener implements LauncherTargetOpener {
  FakeLauncherTargetOpener({required this.result});

  final bool result;
  final List<String> openedUrls = <String>[];

  @override
  Future<bool> open(String launchUrl) async {
    openedUrls.add(launchUrl);
    return result;
  }
}
