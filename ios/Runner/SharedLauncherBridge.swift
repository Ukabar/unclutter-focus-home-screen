import Flutter
import Foundation
import WidgetKit

final class SharedLauncherBridge {
  private let store: SharedLauncherStore

  private init(store: SharedLauncherStore = SharedLauncherStore()) {
    self.store = store
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.zyverio.focuslauncher/shared_launcher_data",
      binaryMessenger: messenger
    )
    let bridge = SharedLauncherBridge()

    channel.setMethodCallHandler { call, result in
      bridge.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "writeSharedLauncherData":
        let payload = try payloadArgument(from: call.arguments)
        try store.write(rawPayload: payload)
        result(["ok": true])
      case "readSharedLauncherData":
        if let payload = try store.read() {
          result(["payload": payload])
        } else {
          result([String: Any]())
        }
      case "reloadLauncherWidgets":
        WidgetCenter.shared.reloadTimelines(ofKind: SharedLauncherConstants.widgetKind)
        result(["ok": true])
      case "checkSharedContainerAvailability":
        result(["available": store.checkAvailability()])
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as SharedLauncherBridgeError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch SharedLauncherValidationError.unsupportedSchemaVersion {
      let error = SharedLauncherBridgeError.unsupportedSchemaVersion
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      let bridgeError = SharedLauncherBridgeError.invalidPayload
      result(FlutterError(code: bridgeError.code, message: bridgeError.message, details: nil))
    }
  }

  private func payloadArgument(from arguments: Any?) throws -> String {
    guard let arguments = arguments as? [String: Any],
      let payload = arguments["payload"] as? String,
      !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SharedLauncherBridgeError.invalidPayload
    }

    return payload
  }
}
