# Shared Launcher Contract

Phase 3 added the data boundary between the Flutter app and a read-only iOS
Widget Extension. Phase 4 uses this contract from `EssentialLauncherWidget`.

## Identifiers

- Main bundle identifier: `com.example.dumbphonehomescreen`
- App Group identifier: `group.com.example.dumbphonehomescreen`
- Shared storage key: `shared_launcher_data_v1`
- MethodChannel: `com.example.dumbphonehomescreen/shared_launcher_data`

The App Group identifier is derived from the inspected bundle identifier using
the `group.<bundle-id>` convention.

## JSON Schema

Schema version: `1`

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-07-23T00:00:00.000Z",
  "entries": [
    {
      "id": "entry-maps",
      "name": "Maps",
      "launchUrl": "maps:"
    }
  ]
}
```

Required top-level fields:

- `schemaVersion`: integer, currently `1`
- `updatedAt`: ISO-8601 timestamp string
- `entries`: ordered array

Required entry fields:

- `id`: stable non-empty string
- `name`: non-empty display name, maximum 60 characters
- `launchUrl`: validated URL string, maximum 512 characters

Optional fields: none.

Unknown fields are ignored. Missing top-level fields, invalid timestamps,
unsupported schema versions, invalid JSON, and unexpected top-level types are
treated as corrupt or unsupported data. Malformed entries are filtered without
crashing. Entry order is preserved after filtering. Duplicate entry identifiers
keep the first occurrence and skip later entries. Empty `entries` is valid.

Maximum recommended entries: 24.

## Ownership

The Flutter app is the only writer. The future Widget Extension must be
read-only. There is no widget-to-app mutation, conflict resolution, cloud sync,
profile sync, or background polling in Phase 3.

## Write Flow

1. The repository saves the canonical launcher list to the existing local
   `shared_preferences` storage.
2. Dart generates the shared v1 JSON contract from the saved ordered list.
3. Dart validates the encoded JSON by decoding it back through the contract.
4. The iOS MethodChannel writes the complete JSON string to App Group
   `UserDefaults`.
5. Widget timelines are reloaded only after a successful shared write.

Local Phase 2 storage remains authoritative. If local persistence succeeds but
App Group synchronization fails, the main app keeps the saved list, surfaces a
brief warning, and can retry on the next mutation or startup sync.

## Atomic Write Strategy

The shared payload is encoded as one complete JSON string and written to App
Group `UserDefaults` under a single key. No partially built JSON is published,
no temporary files are created, and timeline reload is requested only after the
write returns successfully.

## Bridge Methods

- `writeSharedLauncherData`: accepts `{ "payload": "<json>" }`
- `readSharedLauncherData`: returns `{ "payload": "<json>" }` when present
- `reloadLauncherWidgets`: requests
  `WidgetCenter.shared.reloadTimelines(ofKind: "EssentialLauncherWidget")`
- `checkSharedContainerAvailability`: returns whether App Group defaults open

Structured error codes:

- `APP_GROUP_UNAVAILABLE`
- `INVALID_PAYLOAD`
- `SHARED_WRITE_FAILED`
- `SHARED_READ_FAILED`
- `WIDGET_RELOAD_FAILED`
- `UNSUPPORTED_SCHEMA_VERSION`
- `UNKNOWN`

## Migration

Existing Phase 2 data remains in local `shared_preferences` JSON:

```json
{
  "schemaVersion": 1,
  "entries": []
}
```

On app load, if a non-empty local list exists, the repository performs an
idempotent shared sync. Re-running this sync overwrites the same shared key with
a complete payload and does not duplicate or delete local entries.

## Native Configuration

Configured in source:

- `ios/Runner/Runner.entitlements` contains
  `group.com.example.dumbphonehomescreen`
- Runner Debug, Release, and Profile build settings point to
  `Runner/Runner.entitlements`
- Swift shared contract, storage, and bridge files are added to the Runner
  target

Manual Apple/Xcode steps still required on macOS:

- Register or replace the placeholder bundle identifier with a developer-owned
  reverse-DNS identifier.
- Enable the App Groups capability for the main app target.
- Register `group.com.example.dumbphonehomescreen`, or the equivalent App Group
  after renaming the bundle identifier, in the Apple Developer portal.
- Add the same App Group to the Widget Extension target.
- Regenerate or refresh provisioning profiles for Debug, Release, and Profile
  signing.
- Build and run on macOS/Xcode and a real iOS device or simulator.

## Widget Integration

The widget reuses the Swift contract and reads the string stored at
`shared_launcher_data_v1` from App Group `UserDefaults`. The widget kind is
`EssentialLauncherWidget`.

## Known Limitations

- Native iOS compilation, signing, provisioning, and App Group behavior are not
  validated on Windows.
- Widget behavior still requires macOS/Xcode and physical-device validation.
- URL validation confirms format and blocks unsafe schemes; it cannot prove that
  a target third-party app is installed.
- The current bundle identifier is still the Flutter placeholder
  `com.example.dumbphonehomescreen` and must be replaced before release.
