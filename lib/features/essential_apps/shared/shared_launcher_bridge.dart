import 'package:flutter/services.dart';

class SharedLauncherBridgeResult {
  const SharedLauncherBridgeResult({this.payload});

  final String? payload;
}

abstract interface class SharedLauncherBridge {
  Future<SharedLauncherBridgeResult> writeSharedLauncherData(String payload);

  Future<SharedLauncherBridgeResult> readSharedLauncherData();

  Future<SharedLauncherBridgeResult> reloadLauncherWidgets();

  Future<SharedLauncherBridgeResult> checkSharedContainerAvailability();
}

class MethodChannelSharedLauncherBridge implements SharedLauncherBridge {
  MethodChannelSharedLauncherBridge({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : this._(channel);

  MethodChannelSharedLauncherBridge._(this._channel);

  static const String _channelName =
      'com.zyverio.focuslauncher/shared_launcher_data';

  final MethodChannel _channel;

  @override
  Future<SharedLauncherBridgeResult> writeSharedLauncherData(
    String payload,
  ) async {
    return _invoke(
      'writeSharedLauncherData',
      arguments: <String, Object?>{'payload': payload},
    );
  }

  @override
  Future<SharedLauncherBridgeResult> readSharedLauncherData() {
    return _invoke('readSharedLauncherData');
  }

  @override
  Future<SharedLauncherBridgeResult> reloadLauncherWidgets() {
    return _invoke('reloadLauncherWidgets');
  }

  @override
  Future<SharedLauncherBridgeResult> checkSharedContainerAvailability() {
    return _invoke('checkSharedContainerAvailability');
  }

  Future<SharedLauncherBridgeResult> _invoke(
    String method, {
    Object? arguments,
  }) async {
    try {
      final Object? result = await _channel.invokeMethod<Object?>(
        method,
        arguments,
      );

      if (result is Map<Object?, Object?>) {
        return SharedLauncherBridgeResult(
          payload: result['payload'] as String?,
        );
      }

      return const SharedLauncherBridgeResult();
    } on PlatformException catch (error) {
      throw SharedLauncherBridgeException(
        code: SharedLauncherBridgeErrorCode.fromPlatformCode(error.code),
        message: error.message ?? 'Shared launcher data operation failed.',
      );
    }
  }
}

class SharedLauncherBridgeException implements Exception {
  const SharedLauncherBridgeException({
    required this.code,
    required this.message,
  });

  final SharedLauncherBridgeErrorCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

enum SharedLauncherBridgeErrorCode {
  appGroupUnavailable('APP_GROUP_UNAVAILABLE'),
  invalidPayload('INVALID_PAYLOAD'),
  sharedWriteFailed('SHARED_WRITE_FAILED'),
  sharedReadFailed('SHARED_READ_FAILED'),
  widgetReloadFailed('WIDGET_RELOAD_FAILED'),
  unsupportedSchemaVersion('UNSUPPORTED_SCHEMA_VERSION'),
  unknown('UNKNOWN');

  const SharedLauncherBridgeErrorCode(this.platformCode);

  final String platformCode;

  static SharedLauncherBridgeErrorCode fromPlatformCode(String code) {
    return values.firstWhere(
      (SharedLauncherBridgeErrorCode value) => value.platformCode == code,
      orElse: () => unknown,
    );
  }
}
