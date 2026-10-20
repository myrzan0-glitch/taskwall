# TaskWall

**Your to-do list, right on your wallpaper.**

TaskWall is a minimal task tracker that puts your tasks on your phone's lock screen and home screen wallpaper. Every time you pick up your phone, you see what needs doing, with no app to open and no widget to set up.

> Inspired by [WallDone – To-Do on Wallpaper](https://apps.apple.com/no/app/walldone-to-do-on-wallpaper/id6738863967).

---

## Why

To-do apps fail quietly: you write the list, close the app, and forget it exists. TaskWall keeps the list where your eyes already are. You glance at your phone dozens of times a day, and each glance doubles as a reminder.

## Features

### Core
- **Quick task capture**: add a task in one tap and one line of text.
- **Wallpaper generation**: render your current tasks onto a wallpaper image sized for your device.
- **Lock screen and home screen**: use the same wallpaper on both screens or a different one on each.
- **Check off and refresh**: mark tasks done and regenerate the wallpaper so it always shows what's left.
- **Progress indicator**: an optional "3 of 7 done" counter or progress bar on the wallpaper.

### Customization
- **Backgrounds**: solid colors, gradients, built-in images, or a photo from your library.
- **Typography**: choice of font, size, weight and text color.
- **Layout**: position the list (top, center, bottom) and keep it clear of the clock, widgets and dock.
- **Styles**: plain list, checklist with boxes, or a card behind the text for readability.
- **Light / dark variants**: generate a matching pair for system appearance.

### Organization
- **Lists**: keep separate lists (e.g. *Today*, *Work*, *Personal*) and choose which one goes on the wallpaper.
- **Priorities**: pin or highlight the most important tasks so they render first.
- **Reorder**: drag to reorder; the wallpaper follows the list order.
- **Daily reset (optional)**: clear completed tasks at the start of each day.

### Automation
- **Shortcuts integration**: a "Generate TaskWall Wallpaper" action so a Shortcuts automation can refresh the wallpaper automatically (e.g. every morning or whenever a task changes).

### Privacy
- **Local-first**: tasks are stored on the device. No account, no tracking, no server.

---

## How it works

1. **Add tasks** in the app.
2. **Style** the wallpaper with a background, font and layout.
3. **Generate** the wallpaper. TaskWall renders an image at your screen's exact resolution.
4. **Apply** it by saving to Photos and setting it as your wallpaper, or let a Shortcuts automation apply it for you.
5. **Complete tasks** and regenerate. The wallpaper always reflects your current list.

```
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  Task list    │ ───▶ │  Renderer     │ ───▶ │  Wallpaper    │
│  (local data) │      │  (theme +     │      │  image (PNG)  │
│               │      │   layout)     │      │  → Photos /   │
└───────────────┘      └───────────────┘      │    Shortcuts  │
                                              └───────────────┘
```

> **Platform note:** iOS does not let third-party apps change the wallpaper directly. TaskWall produces the image, and the user (or a Shortcuts automation using the built-in *Set Wallpaper* action) applies it.

---

## Roadmap

- [ ] Task list: add, edit, delete, complete, reorder
- [ ] Wallpaper renderer with device-accurate sizing and safe areas
- [ ] Theme editor (background, font, colors, layout)
- [ ] Save to Photos
- [ ] Shortcuts / App Intents action for automatic refresh
- [ ] Multiple lists and priorities
- [ ] Daily reset of completed tasks
- [ ] Lock screen widget showing remaining task count
- [ ] Recurring tasks
- [ ] iCloud sync (opt-in)
- [ ] Localization

---

## Getting started

> The project is in its early stages. Build and run instructions will be added once the app is scaffolded.

```bash
git clone https://github.com/myrzan0-glitch/taskwall.git
cd taskwall
```

## Contributing

Issues and pull requests are welcome. Please open an issue to discuss larger changes before starting work.

## License

License to be decided.
