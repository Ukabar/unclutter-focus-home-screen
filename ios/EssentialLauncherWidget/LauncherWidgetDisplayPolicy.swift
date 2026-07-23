import WidgetKit

enum LauncherWidgetDisplayPolicy {
  static func supports(_ family: WidgetFamily) -> Bool {
    switch family {
    case .systemMedium, .systemLarge:
      return true
    default:
      return false
    }
  }

  static func displayLimit(for family: WidgetFamily) -> Int {
    switch family {
    case .systemMedium:
      return 6
    case .systemLarge:
      return 12
    default:
      return 0
    }
  }

  static func selectedEntries(
    from entries: [SharedLauncherEntry],
    family: WidgetFamily
  ) -> [SharedLauncherEntry] {
    Array(entries.prefix(displayLimit(for: family)))
  }
}
