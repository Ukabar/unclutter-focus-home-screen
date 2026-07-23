import Foundation

enum LauncherWidgetRoute {
  static func launchURL(for entryId: String) -> URL? {
    guard isValidEntryId(entryId) else {
      return nil
    }

    var components = URLComponents()
    components.scheme = SharedLauncherConstants.internalRouteScheme
    components.host = "launch"
    components.queryItems = [URLQueryItem(name: "id", value: entryId)]
    return components.url
  }

  static func setupURL() -> URL? {
    var components = URLComponents()
    components.scheme = SharedLauncherConstants.internalRouteScheme
    components.host = "setup"
    return components.url
  }

  private static func isValidEntryId(_ value: String) -> Bool {
    guard !value.isEmpty,
      value.count <= SharedLauncherConstants.maximumIdentifierLength else {
      return false
    }

    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    return value.unicodeScalars.allSatisfy { allowed.contains($0) }
  }
}
