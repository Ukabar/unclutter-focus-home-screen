import Flutter
import Foundation

final class LauncherRouteBridge {
  private static let channelName = "com.example.dumbphonehomescreen/launcher_routes"
  private static var channel: FlutterMethodChannel?
  private static var pendingInitialRoute: String?

  static func register(with messenger: FlutterBinaryMessenger) {
    let routeChannel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel = routeChannel

    routeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "takeInitialLauncherRoute":
        result(takeInitialRoute())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func handle(url: URL) -> Bool {
    guard url.scheme?.lowercased() == SharedLauncherConstants.internalRouteScheme else {
      return false
    }

    let route = url.absoluteString
    if let channel {
      channel.invokeMethod("launcherRouteOpened", arguments: ["route": route])
    } else if pendingInitialRoute == nil {
      pendingInitialRoute = route
    }

    return true
  }

  private static func takeInitialRoute() -> String? {
    let route = pendingInitialRoute
    pendingInitialRoute = nil
    return route
  }
}
