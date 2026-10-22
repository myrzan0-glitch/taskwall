# Wallist

**Your to-dos, on your Lock Screen.**

Wallist turns today's tasks into a Lock Screen wallpaper and keeps it up to date by itself. Write your tasks, pick a colour or any photo, and every time you pick up your phone you see what's left.

It is free: no ads, no account, no tracking. People who want to can leave a tip.

> Design: [Wallist design canvas](https://claude.ai/artifact/QFPVzTH5F5R1ddi22NJiXs)

---

## Features

- **Tasks:** title, notes, priority (Low / Med / High), due date and time. Shown as Today (due today, then undated), Upcoming and Past, the last two grouped by date.
- **Wallpaper:** list or table layout with an optional progress bar, in five colour themes or on any photo from your library.
- **Readable on any photo:** Auto measures the photo behind the task list and picks black or white text plus the lightest backdrop that keeps it readable (none, soft shade or frosted glass). People can reframe the photo and override Auto.
- **Automatic updates:** a Shortcuts automation refreshes the wallpaper when you close the app. Onboarding walks through the few taps iOS requires.
- **Siri and Shortcuts:** "Make Wallpaper" and "Add Task" work with no setup.
- **Tip jar:** three one-time tips through the App Store that unlock nothing.
- **Native iOS 27 design:** Liquid Glass tab bar, toolbars and sheets, SF Pro, Dynamic Type and Dark Mode, with [Hugeicons](https://hugeicons.com) (free stroke-rounded set, MIT) for icons.

## How it works

iOS doesn't let apps change the wallpaper, so Wallist works with the Shortcuts app:

```
Wallist ──saves──▶ App Group container ◀──reads── "Make Wallpaper" (App Intent, runs in background)
                         (tasks + photo)                        │ returns PNG
                                                                ▼
                                       Shortcuts: "Set Wallpaper" (Lock and Home Screen, no preview)
                                       triggered when the app closes
```

The person adds the published Wallist shortcut once, allows it to run when locked, and runs a test. See [docs/shortcut.md](docs/shortcut.md).

---

## Architecture

Wallist is a Kotlin Multiplatform project, so an Android app can reuse everything that isn't UI.

| Part | What's in it | Language |
|---|---|---|
| `shared/` | Tasks and storage, the Today / Upcoming / Past grouping and overdue rules, what goes on the wallpaper, the photo readability rule (contrast measurement, text colour, backdrop), wallpaper themes and geometry, tip product IDs | Kotlin (common) |
| `iosApp/` | SwiftUI screens with native Liquid Glass components, wallpaper drawing and rendering, photo picking, App Intents for Shortcuts and Siri, StoreKit tips | Swift |
| `androidApp/` (later) | Jetpack Compose screens reusing `shared/` | Kotlin |

Design choices:

- **Native UI on each platform.** Liquid Glass, the system tab bar, sheets and App Intents only exist in SwiftUI/UIKit, so screens are written per platform. Compose Multiplatform could be added later for shared screens.
- **The shared code never reads the clock.** "Today" and the current time are passed in, which keeps the rules deterministic and easy to test.
- **One JSON file.** `TaskWallStore` keeps everything in a single file. On iOS it lives in an App Group so the app and its background shortcut share it. The platform supplies the file through the `TextFileStore` interface.
- **Swift-friendly API.** Kotlin types avoid names that clash with Swift (`TaskItem`, not `Task`; `WallpaperLayout`, not `Layout`), and data classes offer `with…` helpers because Kotlin's `copy()` reaches Swift with every argument required.

## Project layout

```
shared/src/commonMain/kotlin/app/taskwall/shared/
  TaskItem.kt, CalendarDay.kt        task model and dates without time zones
  TaskQueries.kt                     sections, sorting, today's progress
  TaskWallStore.kt, AppState.kt      saved state, settings, actions
  WallpaperComposer.kt               which tasks the wallpaper shows
  LegibilityAnalyzer.kt, Contrast.kt readability rule for photos
  WallpaperAppearance.kt             themes and resolved colours
  WallpaperGeometry.kt               Lock Screen safe areas
  TipJar.kt, SampleData.kt, Formatting.kt
shared/src/commonTest/               unit tests (53): dates, sorting, store, every user flow
iosApp/
  TaskWall.xcodeproj                 the Xcode project (generated from project.yml, committed)
  project.yml                        XcodeGen spec: app, unit tests, UI tests
  scripts/test.sh                    runs the iOS tests on a simulator
  TaskWallTests/                     unit tests: AppModel flows, rendering, photo analysis, bridge
  TaskWallUITests/                   XCUITests: onboarding, tasks, search, wallpaper, settings
  TaskWall/App/                      app entry, AppModel, Kotlin bridge, App Group storage
  TaskWall/Views/                    Tasks, Wallpaper, Settings, Tips, Onboarding, Search
  TaskWall/Rendering/                WallpaperCanvas, renderer, photo storage and analysis
  TaskWall/Intents/                  App Intents and App Shortcuts
  TaskWall/Resources/                asset catalog (Hugeicons, colours), StoreKit test file
docs/shortcut.md                     how to build and publish the Wallist shortcut
```

---

## Building

### Shared module (any OS)

Requires JDK 17 or newer.

```bash
./gradlew :shared:jvmTest
```

### iOS app (macOS)

Requires Xcode 26 or newer (iOS 26 SDK; the app targets iOS 26 and is designed for iOS 27). Open `iosApp/TaskWall.xcodeproj` and press ⌘R.

Everything day to day happens in Xcode, with no Terminal needed:

- **Get the latest changes:** Integrate › Pull (⌥⌘X).
- **Try a branch:** Source Control navigator (⌘2) › Branches, then right-click a branch › Checkout.
- **Run the tests:** Product › Test (⌘U).

The project uses Xcode 16+ synchronized folders, so added or removed files appear without any extra step. It's generated from `iosApp/project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen); only after editing that file, run `cd iosApp && xcodegen` and commit the result. CI fails if the committed project and `project.yml` disagree.

Building the app runs `iosApp/scripts/build-shared.sh` first, which compiles the Kotlin code into the `Shared` framework with Gradle. The first build downloads the Kotlin/Native toolchain (about 1 GB). The scheme uses `Resources/TaskWall.storekit`, so tips work in the simulator without App Store Connect.

If Xcode reports **"Command PhaseScriptExecution failed with a nonzero exit code"**, the Kotlin build failed. Open the Report navigator (⌘9), select the build and expand **Build Kotlin shared framework** to see why. The usual causes:

- **No Java:** run `brew install --cask temurin` and restart Xcode.
- **Wrong developer directory:** run `sudo xcode-select -s /Applications/Xcode.app`.
- **Files missing after a pull:** close and reopen the project (File › Close Project, then open it again).

### Running the tests

```bash
./gradlew :shared:jvmTest        # shared rules, any OS
iosApp/scripts/test.sh unit      # iOS unit tests (about a minute after the first build)
iosApp/scripts/test.sh ui        # XCUITests, walks through every screen
iosApp/scripts/test.sh           # both
```

The script picks the iPhone 17 Pro simulator, or the first iPhone installed (`SIMULATOR="iPhone 16" iosApp/scripts/test.sh` to choose). In Xcode, ⌘U runs the same tests. The UI tests launch the app with `-uiTesting`, so they never touch your real tasks. CI runs all of this on every push: `.github/workflows/shared.yml` (Linux) and `.github/workflows/ios.yml` (macOS).

### Before shipping, replace the placeholders

| Placeholder | Where |
|---|---|
| Bundle ID `app.taskwall` and App Group `group.app.taskwall` | `iosApp/project.yml`, `TaskWall.entitlements`, `App/AppGroup.swift` |
| App Store ID: the Rate row stays hidden until `reviewURL` is set | `Views/Settings/SettingsView.swift` |
| Tip product IDs and prices | App Store Connect, matching `shared/.../TipJar.kt` |
| App icon | `Resources/Assets.xcassets/AppIcon.appiconset` (placeholder) |

### TestFlight

1. In App Store Connect, create the app (Apps → + → New App) with bundle ID `app.taskwall`. The app is listed as Wallist, which is also the name under the icon and the name of the shortcut. The code, Xcode project and bundle ID keep the name TaskWall.
2. In Xcode, pick **Any iOS Device (arm64)**, then **Product → Archive**, then **Distribute App → TestFlight & App Store → Upload**.
3. When processing finishes (Apple emails you), add testers under TestFlight → Internal Testing and install the TestFlight app.

**Or with Xcode Cloud:** its workflow must start on `main` (Edit Workflow → Start Conditions → Source Branch), with an Archive action and a TestFlight post-action. `iosApp/ci_scripts/ci_post_clone.sh` installs the Java that the Kotlin build needs, and Xcode Cloud numbers the builds itself.

The privacy policy is `docs/privacy.html`, served by GitHub Pages (Settings → Pages → Deploy from a branch → `main`, `/docs`) at https://myrzan0-glitch.github.io/taskwall/privacy.html.

Raise `CURRENT_PROJECT_VERSION` in `iosApp/project.yml` before each upload: every build needs a higher number. CI builds a Release archive on every push, so archive problems show up before you try. `Resources/PrivacyInfo.xcprivacy` declares no tracking and no data collection.

### Before you submit

- **The App Store name is Wallist.** "TaskWall" was taken; it remains the name of the code and the Xcode project.
- **Wallpaper apps are a crowded category.** App Review guideline 4.3(b) may reject apps that look like others, so the listing should lead with what's different: a real task manager whose Lock Screen updates itself, for free.

## Android (planned)

1. Add the Android Gradle plugin and an `androidTarget()` to `shared/build.gradle.kts`.
2. Create `androidApp/` with Jetpack Compose and implement `TextFileStore` with app-private storage.
3. Draw the wallpaper with Compose and set it directly with `WallpaperManager.setBitmap(…, FLAG_LOCK)`. Android allows that, so no Shortcuts step is needed there; schedule daily updates with WorkManager.
4. Reuse the shared rules unchanged: `TaskWallStore`, `WallpaperComposer`, `LegibilityAnalyzer` and `WallpaperGeometry`.

## Credits

- Icons: [Hugeicons](https://hugeicons.com) free stroke-rounded set, MIT licence.
- Tip jar photo: [Unsplash](https://unsplash.com) (Unsplash licence).
