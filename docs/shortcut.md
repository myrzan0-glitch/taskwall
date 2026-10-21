# The TaskWall shortcut

The app is called Task on Wallpaper; its shortcut keeps the name **TaskWall**, which the app runs by name.

iOS only lets the Shortcuts app change the wallpaper. Task on Wallpaper provides the image; a small shortcut sets it. The shortcut ships inside the app as a signed file, and people add it from setup step 1 ("Add the TaskWall shortcut").

The signed file is at `iosApp/TaskWall/Resources/TaskWall.shortcut`. If it's ever missing, step 1 falls back to a short guide for building the shortcut by hand, so setup always works.

The file names the app's development team in its App Intent action. If the app is ever signed by a different team, export the shortcut again from a phone running that build.

## Build it

On an iPhone with Task on Wallpaper installed, create a shortcut named **TaskWall** with two actions:

1. **Make Wallpaper** (from the Task on Wallpaper app). It returns today's wallpaper as a PNG and runs without opening the app.
2. **Set Wallpaper Photo**
   - Photo: *Wallpaper* (the output of step 1)
   - Wallpaper: **Lock Screen**
   - Show Preview: **off**
   - Crop to Subject: **off**

Keep the name exactly **TaskWall**. The app runs it by name (`ShortcutLinks.shortcutName`).

## Add the automation

iOS doesn't let apps create automations, so setup step 2 ("Update when you close the app") walks people through it. In Shortcuts' **Automation** tab: **App › Task on Wallpaper › Is Closed** (deselect Is Opened), **Run Immediately**, then pick the TaskWall shortcut. This makes a finished task reach the Lock Screen as soon as the person leaves the app.

There's no daily automation: the app can't see or change one, so its time couldn't be kept in step with the app. On a day the app isn't opened, the wallpaper stays as it was until the next close.

The first run may ask whether Task on Wallpaper can set the wallpaper; choose Always Allow.

The app can't see automations, so it works out the close automation from what happens: it records when it goes to the background (`TaskWallStore.recordAppClosed`), and a shortcut run within two minutes of that marks **When I Close the App** as **On** in Settings. Either can be recorded first: the shortcut can finish before the app hears that it closed.

The app stays open in the background while the shortcut runs, and both save to the same file, so every change the app makes starts from what's saved there rather than from its own copy. Otherwise the app's "closed" record would overwrite the shortcut's run, and the app would show the Lock Screen as out of date although the wallpaper was set.

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

Shared shortcuts arrive without automations, so step 2 guides people through adding the close automation.

## How the app knows it worked

Each time the shortcut runs **Make Wallpaper**, the app records the time and a fingerprint of what the wallpaper shows (`TaskWallStore.recordWallpaperUpdate`). Setup step 3 ("Run a quick test") completes when the first run is recorded. The Tasks screen compares the fingerprint with the current tasks: "Lock Screen is up to date", "Updates when you close the app" (close automation working), or "Lock Screen is out of date" with an Update Now button.

The test opens `shortcuts://x-callback-url/run-shortcut?name=TaskWall&x-success=taskwall://shortcut-ran`, so Shortcuts sends people back to the app when it's done.

## Troubleshooting

- **"Task on Wallpaper couldn't make the wallpaper":** open the app once so it saves the screen size, then run the shortcut again.
- **The automation asks before running:** edit it in Shortcuts and choose **Run Immediately**.
- **Settings still says "Waiting for first run":** close the app once (swipe up to the Home Screen); the close automation should run within a few seconds.
- **The wallpaper didn't change:** check that Set Wallpaper targets the Lock Screen and Show Preview is off.
