# The TaskWall shortcut

iOS only lets the Shortcuts app change the wallpaper. TaskWall provides the image; a small shortcut sets it. The shortcut ships inside the app as a signed file, and people add it from setup step 1 ("Add the TaskWall shortcut").

The signed file is at `iosApp/TaskWall/Resources/TaskWall.shortcut`. If it's ever missing, step 1 falls back to a short guide for building the shortcut by hand, so setup always works.

The file names TaskWall's development team in its App Intent action. If the app is ever signed by a different team, export the shortcut again from a phone running that build.

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

## Ship it in the app

Shortcuts only imports signed files, and signing needs Apple's tools, so export the file from the iPhone where you built it:

1. In Shortcuts, long-press **TaskWall › Share**.
2. Tap **Options** and choose **Anyone**. (This signs the file so any iPhone can import it.)
3. Choose **Save to Files** and AirDrop or copy the file to your Mac.
4. Name it exactly `TaskWall.shortcut` and put it in `iosApp/TaskWall/Resources/`.
5. Rebuild in Xcode (the synchronized Resources folder picks the file up).

If you have an unsigned shortcut file instead, sign it on a Mac:

```bash
shortcuts sign --mode anyone --input TaskWall-unsigned.shortcut --output iosApp/TaskWall/Resources/TaskWall.shortcut
```

With the file in place, step 1's **Add** opens the share sheet; people choose **Shortcuts** and tap **Add Shortcut** there. The step is marked done only after they finish the share sheet or tap **I've Added It**, not on the first tap.

Shared shortcuts arrive without their automations, so step 2 sends people to Shortcuts to add the daily one and allow running when locked.

## How the app knows it worked

Each time the shortcut runs **Make TaskWall Wallpaper**, TaskWall records the time (`TaskWallStore.recordWallpaperUpdate`). The Tasks screen shows "Lock Screen is up to date", and onboarding step 3 ("Run a quick test") completes when the first run is recorded.

The test opens `shortcuts://x-callback-url/run-shortcut?name=TaskWall&x-success=taskwall://shortcut-ran`, so Shortcuts sends people back to TaskWall when it's done.

## Troubleshooting

- **"TaskWall couldn't make the wallpaper":** open TaskWall once so it saves the screen size, then run the shortcut again.
- **The automation asks before running:** turn on Allow Running When Locked for that automation.
- **The wallpaper didn't change:** check that Set Wallpaper targets the Lock Screen and Show Preview is off.
