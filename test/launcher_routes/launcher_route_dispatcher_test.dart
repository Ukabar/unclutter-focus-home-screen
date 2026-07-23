import 'dart:async';

import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_route.dart';
import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_route_dispatcher.dart';
import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_route_source.dart';
import 'package:stillscreen_focus_launcher/features/launcher_routes/launcher_target_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens valid custom-scheme target by stable identifier', () async {
    final TestHarness harness = await TestHarness.withEntries(<LauncherEntry>[
      LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'),
    ]);
    final String route = LauncherRoute.launchUri(
      harness.entries.single.id,
    ).toString();

    final LauncherRouteDispatchResult result = (await harness.dispatcher
        .dispatchRawRoute(route))!;

    expect(result.status, LauncherRouteDispatchStatus.opened);
    expect(harness.opener.openedUrls, <String>['maps:']);
  });

  test('opens valid https fallback target', () async {
    final TestHarness harness = await TestHarness.withEntries(<LauncherEntry>[
      LauncherEntry.fromUserInput(
        name: 'Calendar',
        launchUrl: 'https://example.com/calendar',
      ),
    ]);

    final LauncherRouteDispatchResult result = (await harness.dispatcher
        .dispatchRawRoute(
          LauncherRoute.launchUri(harness.entries.single.id).toString(),
        ))!;

    expect(result.status, LauncherRouteDispatchStatus.opened);
    expect(harness.opener.openedUrls.single, 'https://example.com/calendar');
  });

  test('reports deleted-entry routes without launching', () async {
    final TestHarness harness = await TestHarness.withEntries(
      <LauncherEntry>[],
    );

    final LauncherRouteDispatchResult result = (await harness.dispatcher
        .dispatchRawRoute(
          LauncherRoute.launchUri('entry-deleted').toString(),
        ))!;

    expect(result.status, LauncherRouteDispatchStatus.entryNotFound);
    expect(harness.opener.openedUrls, isEmpty);
    expect(result.userMessage, contains('no longer in your list'));
  });

  test('rejects unsafe target URL loaded from storage', () async {
    final TestHarness harness = TestHarness(
      repository: UnsafeLauncherEntryRepository(),
    );

    final LauncherRouteDispatchResult result = (await harness.dispatcher
        .dispatchRawRoute(LauncherRoute.launchUri('entry-unsafe').toString()))!;

    expect(result.status, LauncherRouteDispatchStatus.unsafeTargetRejected);
    expect(harness.opener.openedUrls, isEmpty);
  });

  test('reports target launch failure', () async {
    final TestHarness harness = await TestHarness.withEntries(<LauncherEntry>[
      LauncherEntry.fromUserInput(name: 'Mail', launchUrl: 'mailto:'),
    ], openResult: false);

    final LauncherRouteDispatchResult result = (await harness.dispatcher
        .dispatchRawRoute(
          LauncherRoute.launchUri(harness.entries.single.id).toString(),
        ))!;

    expect(result.status, LauncherRouteDispatchStatus.targetLaunchFailed);
    expect(result.userMessage, contains('could not be opened'));
  });

  test('prevents duplicate route delivery within a short window', () async {
    DateTime now = DateTime.utc(2026, 7, 23);
    final TestHarness harness = await TestHarness.withEntries(<LauncherEntry>[
      LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'),
    ], now: () => now);
    final String route = LauncherRoute.launchUri(
      harness.entries.single.id,
    ).toString();

    expect(
      (await harness.dispatcher.dispatchRawRoute(route))!.status,
      LauncherRouteDispatchStatus.opened,
    );
    expect(
      (await harness.dispatcher.dispatchRawRoute(route))!.status,
      LauncherRouteDispatchStatus.duplicateIgnored,
    );

    now = now.add(const Duration(seconds: 3));
    expect(
      (await harness.dispatcher.dispatchRawRoute(route))!.status,
      LauncherRouteDispatchStatus.opened,
    );
    expect(harness.opener.openedUrls, <String>['maps:', 'maps:']);
  });

  test('dispatches cold-start and warm routes from source', () async {
    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );
    final FakeLauncherRouteSource source = FakeLauncherRouteSource(
      initialRoute: LauncherRoute.launchUri(maps.id).toString(),
    );
    final TestHarness harness = await TestHarness.withEntries(<LauncherEntry>[
      maps,
    ], source: source);

    final Future<void> expectation = expectLater(
      harness.dispatcher.results.map(
        (LauncherRouteDispatchResult result) => result.status,
      ),
      emitsInOrder(<LauncherRouteDispatchStatus>[
        LauncherRouteDispatchStatus.opened,
        LauncherRouteDispatchStatus.setupRequested,
      ]),
    );

    await harness.dispatcher.start();
    source.add(LauncherRoute.setupUri().toString());
    await expectation;
  });
}

class TestHarness {
  TestHarness({
    required this.repository,
    FakeLauncherRouteSource? source,
    FakeLauncherTargetOpener? opener,
    DateTime Function()? now,
  }) : source = source ?? FakeLauncherRouteSource(),
       opener = opener ?? FakeLauncherTargetOpener() {
    dispatcher = LauncherRouteDispatcher(
      launcherEntryRepository: repository,
      routeSource: this.source,
      targetOpener: this.opener,
      now: now,
    );
  }

  static Future<TestHarness> withEntries(
    List<LauncherEntry> entries, {
    bool openResult = true,
    FakeLauncherRouteSource? source,
    DateTime Function()? now,
  }) async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntryRepository repository = LauncherEntryRepository(
      store: store,
    );
    await repository.saveEntries(entries);
    final TestHarness harness = TestHarness(
      repository: repository,
      source: source,
      opener: FakeLauncherTargetOpener(openResult: openResult),
      now: now,
    );
    harness.entries = entries;
    return harness;
  }

  final LauncherEntryRepository repository;
  final FakeLauncherRouteSource source;
  final FakeLauncherTargetOpener opener;
  late final LauncherRouteDispatcher dispatcher;
  List<LauncherEntry> entries = <LauncherEntry>[];
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

class UnsafeLauncherEntryRepository extends LauncherEntryRepository {
  UnsafeLauncherEntryRepository() : super(store: MemoryLauncherEntryStore());

  @override
  Future<LauncherLoadResult> loadEntries() async {
    return const LauncherLoadResult(
      entries: <LauncherEntry>[
        LauncherEntry(
          id: 'entry-unsafe',
          name: 'Unsafe',
          launchUrl: 'javascript:alert(1)',
        ),
      ],
    );
  }
}

class FakeLauncherRouteSource implements LauncherRouteSource {
  FakeLauncherRouteSource({this.initialRoute});

  final String? initialRoute;
  final StreamController<String> _routes = StreamController<String>.broadcast();

  @override
  Future<String?> takeInitialRoute() async => initialRoute;

  @override
  Stream<String> get routes => _routes.stream;

  void add(String route) {
    _routes.add(route);
  }
}

class FakeLauncherTargetOpener implements LauncherTargetOpener {
  FakeLauncherTargetOpener({this.openResult = true});

  final bool openResult;
  final List<String> openedUrls = <String>[];

  @override
  Future<bool> open(String launchUrl) async {
    openedUrls.add(launchUrl);
    return openResult;
  }
}
