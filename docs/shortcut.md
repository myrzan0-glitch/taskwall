# The Wallist shortcut

The app and its shortcut are both called **Wallist**; the app runs the shortcut by name. It sets the wallpaper on both the Lock Screen and the Home Screen.

iOS only lets the Shortcuts app change the wallpaper. Wallist provides the image; a small shortcut sets it. The shortcut ships inside the app as a signed file, and people add it from setup step 1 ("Add the Wallist shortcut").

The signed file is at `iosApp/TaskWall/Resources/Wallist.shortcut`. If it's ever missing, step 1 falls back to a short guide for building the shortcut by hand, so setup always works.

The file names the app's development team in its App Intent action. If the app is ever signed by a different team, export the shortcut again from a phone running that build.

## Build it

On an iPhone with Wallist installed, create a shortcut named **Wallist**:

1. **Get Wallpaper Mode** (Wallist). Returns `both` (Lock Screen and Home Screen) or `lock` (Lock Screen only), so the app can change which screens are set without anyone adding the shortcut again.
2. **Make Wallpaper** (Wallist). Returns today's wallpaper as a PNG and runs without opening the app.
3. **If** *Wallpaper Mode* **is** `lock`:
   - **Set Wallpaper Photo**: Photo *Wallpaper*, Wallpaper **Lock Screen** only.
4. **Otherwise**:
   - **Set Wallpaper Photo**: Photo *Wallpaper*, Wallpaper **Lock Screen** and **Home Screen**.
5. **End If**
6. **Confirm Wallpaper Set** (Wallist). It only runs if Set Wallpaper worked, so the app shows the Lock Screen as up to date only once it is.

In both Set Wallpaper Photo actions, open the options and turn off:
- **Show Preview**
- **Blur** (otherwise the Home Screen shows a blurred copy)
- **Crop to Subject**. Leaving it on makes iOS zoom in on the task list. If it already looks off, turn it on and off again, so the shortcut saves the setting: the earlier shipped file left it out, and iOS then cropped.

Keep the name exactly **Wallist**. The app runs it by name (`ShortcutLinks.shortcutName`).

Older shortcuts without the first and last steps still work: until a shortcut has run Confirm Wallpaper Set, the app counts a wallpaper as set when Make Wallpaper hands it over.

## Add the automation

iOS doesn't let apps create automations, so setup step 2 ("Update when you close the app") walks people through it. In Shortcuts' **Automation** tab: **App › Wallist › Is Closed** (deselect Is Opened), **Run Immediately**, then pick the Wallist shortcut. This makes a finished task reach the Lock Screen as soon as the person leaves the app.

There's no daily automation: the app can't see or change one, so its time couldn't be kept in step with the app. On a day the app isn't opened, the wallpaper stays as it was until the next close.

The first run may ask whether Wallist can set the wallpaper; choose Always Allow.

The app can't see automations, so it works out the close automation from what happens: it records when it goes to the background (`TaskWallStore.recordAppClosed`), and a shortcut run within two minutes of that marks **When I Close the App** as **On** in Settings. Either can be recorded first: the shortcut can finish before the app hears that it closed.

The app stays open in the background while the shortcut runs, and both save to the same file, so every change the app makes starts from what's saved there rather than from its own copy. Otherwise the app's "closed" record would overwrite the shortcut's run, and the app would show the Lock Screen as out of date although the wallpaper was set.

## Ship it in the app

Shortcuts only imports signed files, and signing needs Apple's tools, so export the file from the iPhone where you built it:

1. In Shortcuts, long-press **Wallist › Share**.
2. Tap **Options** and choose **Anyone**. (This signs the file so any iPhone can import it.)
3. Choose **Save to Files** and AirDrop or copy the file to your Mac.
4. Name it exactly `Wallist.shortcut` and put it in `iosApp/TaskWall/Resources/`.
5. Rebuild in Xcode (the synchronized Resources folder picks the file up).

If you have an unsigned shortcut file instead, sign it on a Mac:

```bash
shortcuts sign --mode anyone --input Wallist-unsigned.shortcut --output iosApp/TaskWall/Resources/Wallist.shortcut
```

With the file in place, step 1's **Add** opens the share sheet; people choose **Shortcuts** and tap **Add Shortcut** there. The step is marked done only after they finish the share sheet or tap **I've Added It**, not on the first tap.

Shared shortcuts arrive without automations, so step 2 guides people through adding the close automation.

## How the app knows it worked

Each time the shortcut runs **Make Wallpaper**, the app records the time and a fingerprint of what the wallpaper shows (`TaskWallStore.recordWallpaperUpdate`). Setup step 3 ("Run a quick test") completes when the first run is recorded. The Tasks screen compares the fingerprint with the current tasks: "Lock Screen is up to date", "Updates when you close the app" (close automation working), or "Lock Screen is out of date" with an Update Now button.

The test opens `shortcuts://x-callback-url/run-shortcut?name=Wallist&x-success=taskwall://shortcut-ran`, so Shortcuts sends people back to the app when it's done.

## Troubleshooting

- **"Wallist couldn't make the wallpaper":** open the app once so it saves the screen size, then run the shortcut again.
- **The automation asks before running:** edit it in Shortcuts and choose **Run Immediately**.
- **Settings still says "Waiting for first run":** close the app once (swipe up to the Home Screen); the close automation should run within a few seconds.
- **The wallpaper didn't change:** check that Set Wallpaper targets the Lock Screen and Home Screen and Show Preview is off.
- **The Home Screen is blurred:** open Set Wallpaper Photo's options in the shortcut and turn **Blur** off.
