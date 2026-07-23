# Essential Launcher Widget

Phase 4 adds one native iOS WidgetKit extension for a calm, text-based launcher.
It does not add onboarding, profiles, analytics, App Intents, Control Center
controls, Screen Time integration, subscriptions, or Android widgets.

## Implemented In Source

- Widget target name: `EssentialLauncherWidget`
- Extension bundle identifier:
  `com.zyverio.focuslauncher.EssentialLauncherWidget`
- Widget kind: `EssentialLauncherWidget`
- App Group identifier: `group.com.zyverio.focuslauncher`
- Internal route scheme: `focuslauncher`
- Route format: `focuslauncher://launch?id=<stable-entry-id>`
- Empty-state setup route: `focuslauncher://setup`
- Deployment target: iOS 14.0

The widget target is added to `ios/Runner.xcodeproj/project.pbxproj`, embedded
in the Runner app, and given its own App Group entitlement file. This target
configuration still requires macOS/Xcode validation.

## Supported Families

- `.systemSmall`: not supported in Phase 4. Multiple useful launcher tap
  targets are too constrained for a reliable text-list experience.
- `.systemMedium`: supported, first 6 valid entries.
- `.systemLarge`: supported, first 12 valid entries.

Overflow behavior: preserve the user's order and display the first entries up
to the family limit. No sorting, promotion, or availability-based rearranging is
performed.

## Timeline Policy

The provider uses a single timeline entry with `.atEnd`. Launcher data is local
and mostly static, so updates rely on the main app calling
`WidgetCenter.shared.reloadTimelines(ofKind: "EssentialLauncherWidget")` after a
successful App Group write. There is no polling and no scheduled frequent
refresh.

## Shared Data Read Flow

1. The widget opens App Group `UserDefaults`.
2. It reads `shared_launcher_data_v1`.
3. It decodes the Phase 3 schema version `1` contract.
4. It preserves entry order.
5. It filters malformed entries through the shared Swift decoder.
6. It selects entries for the active widget family using deterministic limits.

Missing data renders the setup empty state. App Group unavailable, corrupt data,
or unsupported schema renders a safe refresh message. The widget does not show
synthetic preview entries in production.

## Tap Routing

Widget rows use internal routes instead of exposing third-party launch URLs:

```text
focuslauncher://launch?id=<stable-entry-id>
```

The main Flutter app handles the route by:

- parsing and validating the route
- rejecting missing or malformed identifiers
- ignoring duplicate delivery in a short window
- loading the local canonical launcher list
- finding the stable entry identifier
- reusing Phase 2 URL validation
- opening the target with `url_launcher`
- showing a user-facing fallback if the target cannot be opened

This design centralizes validation in the main app. Tradeoff: tapping a widget
entry may briefly open the main app before the target app opens.

## Accessibility

Each visible row is a `Link` with:

- a meaningful label: `Open <name>`
- a clear hint
- a full-row content shape
- minimum row height
- one-line truncation for long names
- system typography and colors

The layout supports light and dark appearance through system colors. WidgetKit
limits dynamic resizing compared with full app UI, so physical-device testing
with Larger Text, Bold Text, and Increased Contrast remains required.

## Manual Xcode And Apple Steps

Required before release:

- Register the main app bundle identifier `com.zyverio.focuslauncher`.
- Register `com.zyverio.focuslauncher.EssentialLauncherWidget` as an App
  Extension identifier.
- Register `group.com.zyverio.focuslauncher` and enable it for both the app and
  extension.
- Refresh provisioning profiles for Runner and the extension.
- Open the workspace in Xcode and verify the extension target, embed phase,
  entitlements, signing team, and shared schemes.
- Build `Runner` for an iOS simulator and physical iPhone.
- Confirm the archive embeds `EssentialLauncherWidget.appex`.

## Codemagic Requirements

`codemagic.yaml` contains an `ios-app-store` workflow for a signed Flutter iOS
release with the Widget Extension embedded.

Codemagic must provide:

- signing certificate
- Runner provisioning profile with the App Group
- Widget Extension provisioning profile with the same App Group
- matching bundle identifiers in App Store Connect

Useful archive check on macOS CI:

```sh
find build/ios/archive -name "EssentialLauncherWidget.appex" -print
```

Do not commit certificates, provisioning profiles, API keys, or real secrets.

## Manual iPhone Test Matrix

Required tests not performed in this Windows environment:

- Install the app, configure one or more shortcuts, and add the widget.
- Verify widget gallery name and description.
- Test medium and large families with empty, one, maximum, and overflow entries.
- Verify order, long names, invalid-entry filtering, and all-invalid entries.
- Test light mode, dark mode, Increased Contrast, Bold Text, Larger Text, and
  tinted/system widget rendering where available.
- Add, edit, remove, reorder, remove all, and re-add shortcuts.
- Restart the app/device and remove/re-add the widget.
- Tap valid entries from cold, warm, and background app states.
- Tap deleted old-timeline entries and invalid target URLs.
- Verify fallback when the target app cannot be opened.
- Test missing App Group, corrupt payload, unsupported schema, and widget refresh
  delay behavior.

## App Store Positioning

Acceptable wording: minimalist Home Screen widget, text-based app shortcuts,
essential app organizer, low-distraction widget companion.

Avoid claims that the app replaces iOS Home Screen, changes the default
launcher, scans installed apps, blocks all distractions, or guarantees every
shortcut works.

## Unverified Native Behavior

Because this work was performed on Windows, these remain unverified:

- Swift compilation
- Xcode scheme correctness
- entitlements and signing
- widget gallery appearance
- embedded `.appex` archive output
- physical iPhone behavior
