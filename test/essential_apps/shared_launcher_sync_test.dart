import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/persistence/launcher_entry_store.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/shared/shared_launcher_bridge.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/shared/shared_launcher_contract.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/shared/shared_launcher_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository preserves local save when shared write fails', () async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final LauncherEntryRepository repository = LauncherEntryRepository(
      store: store,
      sharedSynchronizer: SharedLauncherSynchronizer(
        bridge: FakeSharedLauncherBridge(failWrite: true),
      ),
    );

    final LauncherEntry maps = LauncherEntry.fromUserInput(
      name: 'Maps',
      launchUrl: 'maps:',
    );

    await expectLater(
      repository.addEntry(maps),
      throwsA(
        isA<SharedLauncherSyncException>().having(
          (SharedLauncherSyncException error) => error.entries,
          'entries',
          <LauncherEntry>[maps],
        ),
      ),
    );
    expect(store.value, contains('maps:'));
  });

  test(
    'repository does not reload widget when delete changes nothing',
    () async {
      final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
      final FakeSharedLauncherBridge bridge = FakeSharedLauncherBridge();
      final LauncherEntryRepository repository = LauncherEntryRepository(
        store: store,
        sharedSynchronizer: SharedLauncherSynchronizer(bridge: bridge),
      );

      await repository.deleteEntry('missing-entry');

      expect(bridge.writtenPayloads, isEmpty);
      expect(bridge.reloadCount, 0);
    },
  );

  test(
    'repository writes shared data and reloads after local save succeeds',
    () async {
      final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
      final FakeSharedLauncherBridge bridge = FakeSharedLauncherBridge();
      final LauncherEntryRepository repository = LauncherEntryRepository(
        store: store,
        sharedSynchronizer: SharedLauncherSynchronizer(bridge: bridge),
      );

      await repository.addEntry(
        LauncherEntry.fromUserInput(name: 'Mail', launchUrl: 'mailto:'),
      );

      expect(bridge.writtenPayloads, hasLength(1));
      expect(bridge.reloadCount, 1);
      expect(
        SharedLauncherContract.decode(bridge.writtenPayloads.single)!.entries,
        hasLength(1),
      );
    },
  );

  test('migration sync is idempotent and preserves local ordering', () async {
    final MemoryLauncherEntryStore store = MemoryLauncherEntryStore();
    final FakeSharedLauncherBridge bridge = FakeSharedLauncherBridge();
    final LauncherEntryRepository localRepository = LauncherEntryRepository(
      store: store,
    );

    await localRepository.addEntry(
      LauncherEntry.fromUserInput(name: 'Maps', launchUrl: 'maps:'),
    );
    await localRepository.addEntry(
      LauncherEntry.fromUserInput(name: 'Mail', launchUrl: 'mailto:'),
    );

    final LauncherEntryRepository syncingRepository = LauncherEntryRepository(
      store: store,
      sharedSynchronizer: SharedLauncherSynchronizer(bridge: bridge),
    );

    await syncingRepository.syncCurrentEntries();
    await syncingRepository.syncCurrentEntries();

    expect(bridge.writtenPayloads, hasLength(2));
    for (final String payload in bridge.writtenPayloads) {
      final SharedLauncherContract contract = SharedLauncherContract.decode(
        payload,
      )!;
      expect(
        contract.entries.map((SharedLauncherEntry entry) => entry.name),
        <String>['Maps', 'Mail'],
      );
    }
  });

  test('structured native bridge errors are mapped by synchronizer', () async {
    final SharedLauncherSynchronizer synchronizer = SharedLauncherSynchronizer(
      bridge: FakeSharedLauncherBridge(
        errorCode: SharedLauncherBridgeErrorCode.appGroupUnavailable,
      ),
    );

    await expectLater(
      synchronizer.syncEntries(<LauncherEntry>[]),
      throwsA(
        isA<SharedLauncherSyncFailure>().having(
          (SharedLauncherSyncFailure error) => error.code,
          'code',
          SharedLauncherBridgeErrorCode.appGroupUnavailable,
        ),
      ),
    );
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

class FakeSharedLauncherBridge implements SharedLauncherBridge {
  FakeSharedLauncherBridge({this.failWrite = false, this.errorCode});

  final bool failWrite;
  final SharedLauncherBridgeErrorCode? errorCode;
  final List<String> writtenPayloads = <String>[];
  int reloadCount = 0;

  @override
  Future<SharedLauncherBridgeResult> writeSharedLauncherData(
    String payload,
  ) async {
    if (failWrite || errorCode != null) {
      throw SharedLauncherBridgeException(
        code: errorCode ?? SharedLauncherBridgeErrorCode.sharedWriteFailed,
        message: 'native failure',
      );
    }

    writtenPayloads.add(payload);
    return const SharedLauncherBridgeResult();
  }

  @override
  Future<SharedLauncherBridgeResult> reloadLauncherWidgets() async {
    reloadCount++;
    return const SharedLauncherBridgeResult();
  }

  @override
  Future<SharedLauncherBridgeResult> checkSharedContainerAvailability() async {
    return const SharedLauncherBridgeResult();
  }

  @override
  Future<SharedLauncherBridgeResult> readSharedLauncherData() async {
    return SharedLauncherBridgeResult(
      payload: writtenPayloads.isEmpty ? null : writtenPayloads.last,
    );
  }
}
