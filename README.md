# Dumbphone Homescreen

Dumbphone Homescreen is an iOS-first Flutter app for managing a small local list
of essential app shortcuts for a future text-based Home Screen widget companion.
It does not replace iOS, scan installed applications, or guarantee that every
third-party URL scheme works on every device.

## Current Scope

Phase 4 is implemented as a native iOS WidgetKit source implementation plus the
Flutter deep-link route needed for widget taps. It includes:

- a local ordered essential-app list
- curated local catalog browsing and search
- manual app entry
- add, edit, remove, and reorder actions
- duplicate prevention by launch URL
- local persistence through `shared_preferences`
- schema-versioned JSON storage
- safe fallback for corrupt or unsupported stored data
- a versioned shared launcher JSON contract
- an iOS MethodChannel for App Group shared storage
- a Runner App Group entitlement file
- local-to-shared idempotent synchronization after existing data loads
- structured sync errors that leave local list management usable
- a WidgetKit extension target named `EssentialLauncherWidget`
- medium and large text-based widget layouts
- deterministic widget entry limits
- internal widget tap routes handled by the Flutter app
- URL opening through `url_launcher` after local validation

Phase 4 intentionally does not include onboarding, profiles, monetization,
analytics, remote catalog updates, installed-app detection, App Intents, Control
Center controls, Screen Time integration, or Android widget support.

## Architecture

The project uses a small feature-first structure:

```text
lib/
  app/
    app.dart
  core/
    theme/
      app_theme.dart
  features/
    essential_apps/
      catalog/
      models/
      persistence/
      validation/
      shared/
      widgets/
      essential_apps_screen.dart
  main.dart
```

State management is plain Flutter `StatefulWidget` state. The selected app list
is loaded from a repository and kept as immutable list snapshots in the screen.
No external state-management package is used.

Dependency injection is explicit constructor injection. The app creates the
production repository and catalog loader by default, while tests inject in-memory
stores and catalog repositories.

## Storage

The selected app list is stored as one small JSON document in
`shared_preferences` under the local Phase 2 schema:

```json
{
  "schemaVersion": 1,
  "entries": []
}
```

Unsupported schema versions, corrupt JSON, invalid entries, and duplicates are
handled with a safe empty or filtered fallback and a user-visible warning.

Phase 3 also mirrors the ordered list to the iOS App Group as a separate public
contract for the future widget:

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

See `docs/shared_launcher_contract.md` for the complete shared schema, error
codes, migration behavior, and manual Apple configuration steps.

See `docs/widget_extension.md` for WidgetKit target details, supported
families, tap routing, Codemagic notes, and the required iPhone test matrix.

## Catalog

The curated catalog lives at `assets/catalog/curated_apps.json`. It is a
convenience list, not an installed-app scanner. Entries are validated at load
time; malformed, unsafe, or duplicate catalog entries are skipped.

## iOS Baseline

- Flutter: 3.44.0 stable in the inspected environment
- Dart: 3.12.0 bundled with Flutter
- Native iOS language: Swift
- Main app deployment target: iOS 14.0
- App framework minimum OS version: iOS 14.0
- Current bundle identifier: `com.example.dumbphonehomescreen`
- App Group identifier selected for Phase 3:
  `group.com.example.dumbphonehomescreen`
- Widget extension bundle identifier:
  `com.example.dumbphonehomescreen.EssentialLauncherWidget`
- Widget kind: `EssentialLauncherWidget`
- Internal route scheme: `dumbphonehomescreen`

iOS 14.0 remains the chosen minimum because WidgetKit Home Screen widgets require
iOS 14 or newer. Before release, replace the `com.example...` bundle identifier
with a real developer-owned reverse-DNS identifier.

## Development Commands

```sh
flutter pub get
dart format .
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Known Limitations

- Native iOS builds require macOS and Xcode.
- App Group capability, signing, and provisioning still require Apple Developer
  portal and Xcode verification.
- URL format validation cannot prove that the target app is installed or supports
  the URL.
- Native WidgetKit compilation, signing, widget gallery behavior, and physical
  iPhone behavior still require macOS/Xcode verification.
