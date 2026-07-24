import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      _ = LauncherRouteBridge.handle(url: url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if LauncherRouteBridge.handle(url: url) {
      return true
    }

    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let sharedLauncherRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SharedLauncherBridge"
    ) {
      SharedLauncherBridge.register(with: sharedLauncherRegistrar.messenger())
    }
    if let launcherRouteRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LauncherRouteBridge"
    ) {
      LauncherRouteBridge.register(with: launcherRouteRegistrar.messenger())
    }
  }
}
