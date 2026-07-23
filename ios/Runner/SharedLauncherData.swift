import Foundation

struct SharedLauncherPayload: Codable {
  let schemaVersion: Int
  let updatedAt: String
  let entries: [SharedLauncherEntry]

  enum CodingKeys: String, CodingKey {
    case schemaVersion
    case updatedAt
    case entries
  }
}

struct SharedLauncherEntry: Codable {
  let id: String
  let name: String
  let launchUrl: String

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case launchUrl
  }
}

struct SharedLauncherDecodeResult {
  let payload: SharedLauncherPayload
  let warning: String?
}

enum SharedLauncherValidationError: Error {
  case corruptData
  case unsupportedSchemaVersion
}

enum SharedLauncherDataCodec {
  static func decode(_ rawPayload: String) throws -> SharedLauncherDecodeResult {
    guard let data = rawPayload.data(using: .utf8) else {
      throw SharedLauncherValidationError.corruptData
    }

    let decodedPayload: SharedLauncherPayload
    do {
      decodedPayload = try JSONDecoder().decode(SharedLauncherPayload.self, from: data)
    } catch {
      throw SharedLauncherValidationError.corruptData
    }

    guard decodedPayload.schemaVersion == SharedLauncherConstants.currentSchemaVersion else {
      throw SharedLauncherValidationError.unsupportedSchemaVersion
    }

    guard isValidTimestamp(decodedPayload.updatedAt) else {
      throw SharedLauncherValidationError.corruptData
    }

    var seenIds = Set<String>()
    var sanitizedEntries: [SharedLauncherEntry] = []
    var skippedEntries = 0

    for entry in decodedPayload.entries {
      if sanitizedEntries.count >= SharedLauncherConstants.maximumEntries ||
        !isValid(entry: entry) ||
        seenIds.contains(entry.id) {
        skippedEntries += 1
        continue
      }

      seenIds.insert(entry.id)
      sanitizedEntries.append(entry)
    }

    let payload = SharedLauncherPayload(
      schemaVersion: decodedPayload.schemaVersion,
      updatedAt: decodedPayload.updatedAt,
      entries: sanitizedEntries
    )
    let warning = skippedEntries == 0 ? nil : "\(skippedEntries) shared entries were skipped."

    return SharedLauncherDecodeResult(payload: payload, warning: warning)
  }

  private static func isValid(entry: SharedLauncherEntry) -> Bool {
    guard !entry.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      entry.id.count <= SharedLauncherConstants.maximumIdentifierLength,
      !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      entry.name.count <= SharedLauncherConstants.maximumNameLength,
      entry.launchUrl.count <= SharedLauncherConstants.maximumLaunchURLLength,
      let url = URL(string: entry.launchUrl),
      let scheme = url.scheme?.lowercased(),
      !scheme.isEmpty else {
      return false
    }

    let blockedSchemes: Set<String> = ["about", "data", "file", "javascript", "vbscript"]
    if blockedSchemes.contains(scheme) {
      return false
    }

    if (scheme == "http" || scheme == "https") && (url.host ?? "").isEmpty {
      return false
    }

    return true
  }

  private static func isValidTimestamp(_ value: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if formatter.date(from: value) != nil {
      return true
    }

    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value) != nil
  }
}

final class SharedLauncherStore {
  func checkAvailability() -> Bool {
    UserDefaults(suiteName: SharedLauncherConstants.appGroupIdentifier) != nil
  }

  func write(rawPayload: String) throws {
    _ = try SharedLauncherDataCodec.decode(rawPayload)

    guard let defaults = UserDefaults(suiteName: SharedLauncherConstants.appGroupIdentifier) else {
      throw SharedLauncherBridgeError.appGroupUnavailable
    }

    defaults.set(rawPayload, forKey: SharedLauncherConstants.storageKey)
    if !defaults.synchronize() {
      throw SharedLauncherBridgeError.sharedWriteFailed
    }
  }

  func read() throws -> String? {
    guard let defaults = UserDefaults(suiteName: SharedLauncherConstants.appGroupIdentifier) else {
      throw SharedLauncherBridgeError.appGroupUnavailable
    }

    return defaults.string(forKey: SharedLauncherConstants.storageKey)
  }
}
