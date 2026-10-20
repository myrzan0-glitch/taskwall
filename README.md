# TaskWall

**Your to-dos, on your Lock Screen.**

TaskWall turns today's tasks into a Lock Screen wallpaper and keeps it up to date by itself. Write your tasks, pick a colour or any photo, and every time you pick up your phone you see what's left.

It is free: no ads, no account, no tracking. People who want to can leave a tip.

> Design: [TaskWall App Design canvas](https://claude.ai/artifact/QFPVzTH5F5R1ddi22NJiXs)

---

## Features

- **Tasks:** title, notes, priority (Low / Med / High), due date and time. Grouped into Overdue, Today, Anytime and Upcoming.
- **Wallpaper:** list or table layout with an optional progress bar, in five colour themes or on any photo from your library.
- **Readable on any photo:** Auto measures the photo behind the task list and picks black or white text plus the lightest backdrop that keeps it readable (none, soft shade or frosted glass). People can reframe the photo and override Auto.
- **Automatic updates:** a Shortcuts automation refreshes the wallpaper every morning and when you close TaskWall. Onboarding walks through the three taps iOS requires.
- **Siri and Shortcuts:** "Make TaskWall Wallpaper" and "Add Task" work with no setup.
- **Tip jar:** three one-time tips through the App Store that unlock nothing.
- **Native iOS 27 design:** Liquid Glass tab bar, toolbars and sheets, SF Pro, Dynamic Type and Dark Mode, with [Hugeicons](https://hugeicons.com) (free stroke-rounded set, MIT) for icons.

## How it works

iOS doesn't let apps change the wallpaper, so TaskWall works with the Shortcuts app:

```
TaskWall app ──saves──▶ App Group container ◀──reads── "Make TaskWall Wallpaper" (App Intent, runs in background)
                         (tasks + photo)                        │ returns PNG
                                                                ▼
                                       Shortcuts: "Set Wallpaper" (Lock Screen, no preview)
                                       triggered every morning and when TaskWall closes
```

The person adds the published TaskWall shortcut once, allows it to run when locked, and runs a test. See [docs/shortcut.md](docs/shortcut.md).

---

## Architecture

TaskWall is a Kotlin Multiplatform project, so an Android app can reuse everything that isn't UI.

| Part | What's in it | Language |
|---|---|---|
| `shared/` | Tasks and storage, the Overdue / Today / Upcoming rules, what goes on the wallpaper, the photo readability rule (contrast measurement, text colour, backdrop), wallpaper themes and geometry, tip product IDs | Kotlin (common) |
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
shared/src/commonTest/               unit tests (31)
iosApp/
  project.yml                        XcodeGen project
  TaskWall/App/                      app entry, AppModel, Kotlin bridge, App Group storage
  TaskWall/Views/                    Tasks, Wallpaper, Settings, Tips, Onboarding, Search
  TaskWall/Rendering/                WallpaperCanvas, renderer, photo storage and analysis
  TaskWall/Intents/                  App Intents and App Shortcuts
  TaskWall/Resources/                asset catalog (Hugeicons, colours), StoreKit test file
docs/shortcut.md                     how to build and publish the TaskWall shortcut
```

---

## Building

### Shared module (any OS)

Requires JDK 17 or newer.

```bash
./gradlew :shared:jvmTest
```

### iOS app (macOS)

Requires Xcode 26 or newer (iOS 26 SDK; the app targets iOS 26 and is designed for iOS 27) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd iosApp
xcodegen          # creates TaskWall.xcodeproj
open TaskWall.xcodeproj
```

Building the app runs `./gradlew :shared:embedAndSignAppleFrameworkForXcode` first, which compiles the Kotlin code into the `Shared` framework. The scheme uses `Resources/TaskWall.storekit`, so tips work in the simulator without App Store Connect.

### Before shipping, replace the placeholders

| Placeholder | Where |
|---|---|
| Bundle ID `app.taskwall` and App Group `group.app.taskwall` | `iosApp/project.yml`, `TaskWall.entitlements`, `App/AppGroup.swift` |
| Shortcut iCloud link `REPLACE_WITH_SHORTCUT_ID` | `App/AppGroup.swift` (`ShortcutLinks.getShortcut`) |
| App Store ID `REPLACE_WITH_APP_ID` and feedback email | `Views/Settings/SettingsView.swift` |
| Tip product IDs and prices | App Store Connect, matching `shared/.../TipJar.kt` |
| App icon | `Resources/Assets.xcassets/AppIcon.appiconset` (placeholder) |

### Before you submit

- **The name "TaskWall" is taken on the App Store.** Pick a different name before submitting.
- **Wallpaper apps are a crowded category.** App Review guideline 4.3(b) may reject apps that look like others, so the listing should lead with what's different: a real task manager whose Lock Screen updates itself, for free.

## Android (planned)

1. Add the Android Gradle plugin and an `androidTarget()` to `shared/build.gradle.kts`.
2. Create `androidApp/` with Jetpack Compose and implement `TextFileStore` with app-private storage.
3. Draw the wallpaper with Compose and set it directly with `WallpaperManager.setBitmap(…, FLAG_LOCK)`. Android allows that, so no Shortcuts step is needed there; schedule daily updates with WorkManager.
4. Reuse the shared rules unchanged: `TaskWallStore`, `WallpaperComposer`, `LegibilityAnalyzer` and `WallpaperGeometry`.

## Credits

- Icons: [Hugeicons](https://hugeicons.com) free stroke-rounded set, MIT licence.
- Tip jar photo: [Unsplash](https://unsplash.com) (Unsplash licence).
