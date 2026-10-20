# The TaskWall shortcut

iOS only lets the Shortcuts app change the wallpaper. TaskWall provides the image; a small shortcut sets it. You publish this shortcut once, and everyone adds it with one tap during onboarding.

## Build it

On an iPhone with TaskWall installed, create a shortcut named **TaskWall** with two actions:

1. **Make TaskWall Wallpaper** (from the TaskWall app). It returns today's wallpaper as a PNG and runs without opening the app.
2. **Set Wallpaper Photo**
   - Photo: *Wallpaper* (the output of step 1)
   - Wallpaper: **Lock Screen**
   - Show Preview: **off**
   - Crop to Subject: **off**

Keep the name exactly **TaskWall**. The app runs it by name (`ShortcutLinks.shortcutName`).

## Add the automations

In iOS 27, automations live inside the shortcut: open the shortcut, choose **Edit › Automation**, and add:

- **Time of Day:** 07:00, daily. This is the "Every morning" update.
- **App › TaskWall › Is Closed.** This is the "When I close TaskWall" update.

For each one, open **(i) › Privacy** and turn on **Allow Running When Locked** so it runs without asking. The first run may also ask to allow Set Wallpaper; choose Always Allow.

## Publish it

Share the shortcut, choose **Copy iCloud Link**, and put the link in `iosApp/TaskWall/App/AppGroup.swift`:

```swift
static let getShortcut = URL(string: "https://www.icloud.com/shortcuts/<id>")!
```

Shared shortcuts may arrive with their automations turned off, so onboarding step 2 asks people to allow running when locked.

## How the app knows it worked

Each time the shortcut runs **Make TaskWall Wallpaper**, TaskWall records the time (`TaskWallStore.recordWallpaperUpdate`). The Tasks screen shows "Lock Screen is up to date", and onboarding step 3 ("Run a quick test") completes when the first run is recorded.

The test opens `shortcuts://x-callback-url/run-shortcut?name=TaskWall&x-success=taskwall://shortcut-ran`, so Shortcuts sends people back to TaskWall when it's done.

## Troubleshooting

- **"TaskWall couldn't make the wallpaper":** open TaskWall once so it saves the screen size, then run the shortcut again.
- **The automation asks before running:** turn on Allow Running When Locked for that automation.
- **The wallpaper didn't change:** check that Set Wallpaper targets the Lock Screen and Show Preview is off.
