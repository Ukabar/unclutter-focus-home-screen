import Foundation

enum LauncherWidgetContentState {
  case configured([SharedLauncherEntry])
  case empty
  case unavailable
  case corrupt
  case unsupportedVersion

  var entries: [SharedLauncherEntry] {
    switch self {
    case .configured(let entries):
      return entries
    case .empty, .unavailable, .corrupt, .unsupportedVersion:
      return []
    }
  }

  var isActionableEmptyState: Bool {
    switch self {
    case .empty, .unavailable, .corrupt, .unsupportedVersion:
      return true
    case .configured:
      return false
    }
  }
}

struct LauncherWidgetDataReader {
  private let store: SharedLauncherStore

  init(store: SharedLauncherStore = SharedLauncherStore()) {
    self.store = store
  }

  func load() -> LauncherWidgetContentState {
    do {
      guard let rawPayload = try store.read(),
        !rawPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .empty
      }

      let result = try SharedLauncherDataCodec.decode(rawPayload)
      if result.payload.entries.isEmpty {
        return .empty
      }

      return .configured(result.payload.entries)
    } catch SharedLauncherValidationError.unsupportedSchemaVersion {
      return .unsupportedVersion
    } catch SharedLauncherBridgeError.appGroupUnavailable {
      return .unavailable
    } catch {
      return .corrupt
    }
  }
}
