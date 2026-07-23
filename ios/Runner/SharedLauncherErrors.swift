import Foundation

enum SharedLauncherBridgeError: Error {
  case appGroupUnavailable
  case invalidPayload
  case sharedWriteFailed
  case sharedReadFailed
  case widgetReloadFailed
  case unsupportedSchemaVersion

  var code: String {
    switch self {
    case .appGroupUnavailable:
      return "APP_GROUP_UNAVAILABLE"
    case .invalidPayload:
      return "INVALID_PAYLOAD"
    case .sharedWriteFailed:
      return "SHARED_WRITE_FAILED"
    case .sharedReadFailed:
      return "SHARED_READ_FAILED"
    case .widgetReloadFailed:
      return "WIDGET_RELOAD_FAILED"
    case .unsupportedSchemaVersion:
      return "UNSUPPORTED_SCHEMA_VERSION"
    }
  }

  var message: String {
    switch self {
    case .appGroupUnavailable:
      return "The App Group container is unavailable."
    case .invalidPayload:
      return "The shared launcher payload is invalid."
    case .sharedWriteFailed:
      return "The shared launcher payload could not be written."
    case .sharedReadFailed:
      return "The shared launcher payload could not be read."
    case .widgetReloadFailed:
      return "Launcher widget timelines could not be reloaded."
    case .unsupportedSchemaVersion:
      return "The shared launcher schema version is unsupported."
    }
  }
}
