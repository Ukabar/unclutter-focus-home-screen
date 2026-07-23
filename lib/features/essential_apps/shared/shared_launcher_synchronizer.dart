import '../models/launcher_entry.dart';
import 'shared_launcher_bridge.dart';
import 'shared_launcher_contract.dart';

class SharedLauncherSynchronizer {
  const SharedLauncherSynchronizer({required SharedLauncherBridge bridge})
    : this._(bridge);

  const SharedLauncherSynchronizer._(this._bridge);

  final SharedLauncherBridge _bridge;

  Future<void> syncEntries(List<LauncherEntry> entries) async {
    final SharedLauncherContract contract =
        SharedLauncherContract.fromLauncherEntries(entries);
    final String payload = contract.encode();

    if (SharedLauncherContract.decode(payload) == null) {
      throw const SharedLauncherSyncFailure(
        code: SharedLauncherBridgeErrorCode.invalidPayload,
        message: 'Shared launcher payload could not be validated.',
      );
    }

    try {
      await _bridge.writeSharedLauncherData(payload);
      await _bridge.reloadLauncherWidgets();
    } on SharedLauncherBridgeException catch (error) {
      throw SharedLauncherSyncFailure(code: error.code, message: error.message);
    }
  }
}

class SharedLauncherSyncFailure implements Exception {
  const SharedLauncherSyncFailure({required this.code, required this.message});

  final SharedLauncherBridgeErrorCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}
