# Wallist

**Your to-dos, on your Lock Screen.**

Wallist turns today's tasks into a Lock Screen wallpaper and keeps it up to date by itself. Write your tasks, pick a colour or any photo, and every time you pick up your phone you see what's left.

Tasks are free: no ads, no account, no tracking. Wallist Pro, a subscription or a one-time Lifetime purchase, adds wallpaper fonts.

> Design: [Wallist design canvas](https://claude.ai/artifact/QFPVzTH5F5R1ddi22NJiXs)

---

## Features

- **Tasks:** title, notes, a red Priority flag, due date and time. Today lists overdue, undated and today's tasks; a swipeable week strip shows any other day.
- **Wallpaper:** list or table layout with an optional progress bar, in five colour themes (including the red Signal) or on any photo from your library.
- **Readable on any photo:** Auto measures the photo behind the task list and picks black or white text plus the lightest backdrop that keeps it readable (none, soft shade or frosted glass). People can reframe the photo and override Auto.
- **Automatic updates:** a Shortcuts automation refreshes the wallpaper when you close the app. Onboarding walks through the few taps iOS requires.
- **Siri and Shortcuts:** "Make Wallpaper" and "Add Task" work with no setup.
- **Wallist Pro:** a yearly or monthly subscription, or Lifetime, that unlocks three wallpaper fonts for the task list: Matrix (dot-matrix), Orbit (wide, space-age) and Grace (calligraphic italic). There's no free trial; anyone can try the fonts in the preview, in onboarding and in the Wallpaper sheet. Onboarding offers Pro once, right after showing the person their own Lock Screen, and "Not now" carries on. iOS keeps drawing its own clock.
- **Native iOS 27 design:** dark only, with a Liquid Glass bottom bar (Wallpaper, New Task, Settings), glass toolbars and fitted sheets, SF Pro and Dynamic Type. Icons are filled versions of [Hugeicons](https://hugeicons.com) (MIT).

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
| `shared/` | Tasks and storage, the Today list, week and overdue rules, what goes on the wallpaper, the photo readability rule (contrast measurement, text colour, backdrop), wallpaper themes, fonts and geometry, Pro product IDs | Kotlin (common) |
| `iosApp/` | SwiftUI screens with native Liquid Glass components, wallpaper drawing and rendering, photo picking, App Intents for Shortcuts and Siri, StoreKit subscriptions and Lifetime | Swift |
| `androidApp/` (later) | Jetpack Compose screens reusing `shared/` | Kotlin |

Design choices:

- **Native UI on each platform.** Liquid Glass, sheets and App Intents only exist in SwiftUI/UIKit, so screens are written per platform. Compose Multiplatform could be added later for shared screens.
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
  ProPlan.kt, SampleData.kt, Formatting.kt
shared/src/commonTest/               unit tests (67): dates, sorting, store, every user flow
iosApp/
  TaskWall.xcodeproj                 the Xcode project (generated from project.yml, committed)
  project.yml                        XcodeGen spec: app, unit tests, UI tests
  scripts/test.sh                    runs the iOS tests on a simulator
  TaskWallTests/                     unit tests: AppModel flows, rendering, photo analysis, bridge
  TaskWallUITests/                   XCUITests: onboarding, tasks, wallpaper, settings
  TaskWall/App/                      app entry, AppModel, Kotlin bridge, App Group storage
  TaskWall/Views/                    Tasks, Wallpaper, Settings, Pro, Onboarding
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

Building the app runs `iosApp/scripts/build-shared.sh` first, which compiles the Kotlin code into the `Shared` framework with Gradle. The first build downloads the Kotlin/Native toolchain (about 1 GB). The scheme uses `Resources/TaskWall.storekit`, so Pro can be bought in the simulator without App Store Connect. In TestFlight, until the Pro subscriptions exist in App Store Connect, Start Pro unlocks Pro for free on the tester's device; App Store downloads never do this.

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
| Pro: one subscription group with `app.taskwall.pro.yearly` and `app.taskwall.pro.monthly`, the non-consumable `app.taskwall.pro.lifetime`, their prices and the Terms link in the App Store description | App Store Connect, matching `shared/.../ProPlan.kt` |
| App icon | `Resources/Assets.xcassets/AppIcon.appiconset` (placeholder) |

### TestFlight

1. In App Store Connect, create the app (Apps → + → New App) with bundle ID `app.taskwall`. The app is listed as Wallist, which is also the name under the icon and the name of the shortcut. The code, Xcode project and bundle ID keep the name TaskWall.
2. In Xcode, pick **Any iOS Device (arm64)**, then **Product → Archive**, then **Distribute App → TestFlight & App Store → Upload**.
3. When processing finishes (Apple emails you), add testers under TestFlight → Internal Testing and install the TestFlight app.

**Or from GitHub, automatically:** every push to `main` signs the Release archive that CI builds anyway and uploads it to TestFlight, alongside the tests. Set it up once:

1. **API key:** App Store Connect → Users and Access → Integrations → Team Keys → +, with the App Manager role. Download the `.p8` file (you can only do this once) and note its Key ID and the Issuer ID above the list.
2. **Certificate:** in Xcode → Settings → Accounts → your team → Manage Certificates, add an **Apple Distribution** certificate if there isn't one, then right-click it → Export Certificate, with a password, to a `.p12` file.
3. **Profile:** at developer.apple.com → Certificates, Identifiers & Profiles → Profiles → +, create an **App Store Connect** profile for `app.taskwall` with that certificate, and download it. The App ID needs the App Groups capability with `group.app.taskwall`; Xcode added it when you first signed the app.
4. **Secrets:** in the GitHub repository → Settings → Secrets and variables → Actions, add:

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID` | the Key ID |
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_KEY_P8` | the whole text of the `.p8` file |
   | `DIST_CERTIFICATE_P12` | `base64 -i certificate.p12 \| pbcopy`, then paste |
   | `DIST_CERTIFICATE_PASSWORD` | the `.p12` password |
   | `APPSTORE_PROFILE` | `base64 -i profile.mobileprovision \| pbcopy`, then paste |

Until `ASC_KEY_ID` is set, CI only checks that the archive builds. To upload without pushing, open Actions → iOS app → Run workflow on `main`. Builds are numbered after the workflow run. If TestFlight already has a higher number for this version (for example from Xcode Cloud), add a repository variable `BUILD_NUMBER_OFFSET` (Settings → Secrets and variables → Actions → Variables) to add to it. The certificate and profile expire after a year; then replace those two secrets.

The privacy policy is `docs/privacy.html`, served by GitHub Pages (Settings → Pages → Deploy from a branch → `main`, `/docs`) at https://myrzan0-glitch.github.io/taskwall/privacy.html.

When you upload from Xcode, raise `CURRENT_PROJECT_VERSION` in `iosApp/project.yml` above the last build in TestFlight first: every build needs a higher number. CI builds a Release archive on every push, so archive problems show up before you try. `Resources/PrivacyInfo.xcprivacy` declares no tracking and no data collection.

### Before you submit

- **The App Store name is Wallist.** "TaskWall" was taken; it remains the name of the code and the Xcode project.
- **Wallpaper apps are a crowded category.** App Review guideline 4.3(b) may reject apps that look like others, so the listing should lead with what's different: a real task manager whose Lock Screen updates itself, for free.

## Android (planned)

1. Add the Android Gradle plugin and an `androidTarget()` to `shared/build.gradle.kts`.
2. Create `androidApp/` with Jetpack Compose and implement `TextFileStore` with app-private storage.
3. Draw the wallpaper with Compose and set it directly with `WallpaperManager.setBitmap(…, FLAG_LOCK)`. Android allows that, so no Shortcuts step is needed there; schedule daily updates with WorkManager.
4. Reuse the shared rules unchanged: `TaskWallStore`, `WallpaperComposer`, `LegibilityAnalyzer` and `WallpaperGeometry`.

## Credits

- Icons: [Hugeicons](https://hugeicons.com) free stroke-rounded set, MIT licence, filled for this app.
- Matrix font: [Doto](https://github.com/oliverlalan/Doto) by Óliver Lalan, SIL Open Font License 1.1. Shipped as "Doto Rounded", a static instance at Black weight with roundness 70, with Cyrillic (Russian, Ukrainian, Uzbek, Kazakh) added on Doto's dot grid by `iosApp/scripts/doto_cyrillic.py`.
- Orbit font: [Michroma](https://github.com/googlefonts/Michroma-font) by Vernon Adams, SIL Open Font License 1.1. Its Cyrillic comes from [Unbounded](https://github.com/googlefonts/unbounded) Light (The Unbounded Project Authors, SIL Open Font License 1.1), shipped with only its Cyrillic letters, plus Uzbek Ғ Қ Ҳ and Kazakh Ң built from its own strokes by `iosApp/scripts/unbounded_cyrillic.py`.
- Grace font: [Cormorant Garamond](https://github.com/CatharsisFonts/Cormorant) by Christian Thalmann, SIL Open Font License 1.1. Shipped as the static Medium Italic, kept to Latin and Cyrillic (with Kazakh and Uzbek) by `iosApp/scripts/cormorant_subset.py`.
- Both licences ship with the fonts in `iosApp/TaskWall/Resources/Fonts`.
