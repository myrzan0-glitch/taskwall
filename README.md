# TaskWall

**See your to-dos on your lock screen.**

TaskWall is an iPhone task tracker that turns your to-do list into a wallpaper. Every time you pick up your phone, you see what needs doing, with no app to open and no widget to set up.

> Inspired by [WallDone – To-Do on Wallpaper](https://apps.apple.com/no/app/walldone-to-do-on-wallpaper/id6738863967).

---

## Why

To-do apps fail quietly: you write the list, close the app, and forget it exists. TaskWall keeps the list where your eyes already are. You glance at your phone dozens of times a day, and each glance doubles as a reminder. The wallpaper should also look good enough that you want to keep it there.

## Features

### Wallpaper generation
- **Tasks to wallpaper**: render your current tasks onto an image at your iPhone's exact screen resolution.
- **Lock screen first**: the layout stays clear of the clock, lock screen widgets and notifications.
- **Refresh on change**: check off tasks and regenerate, so the wallpaper always shows what's left.

### Task management
- **Priorities**: high-priority tasks are highlighted and rendered first.
- **Categories**: group tasks (e.g. *Work*, *Study*, *Personal*) and choose which ones appear on the wallpaper.
- **Due dates**: show what's due today, flag what's overdue.
- **Quick capture**: add, edit, reorder and complete tasks in a tap.

### Design and customization
- **Pre-made themes**: a gallery of ready-to-use styles.
- **Custom themes**: build your own with background, font, text color and accents.
- **Photo backgrounds**: use any image from your photo library.
- **Multiple layouts**: a **vertical list** or a **table view**.
- **Dark and light modes**: both the app and the generated wallpapers follow system appearance.

### Automation
- **Shortcuts integration**: a "Generate TaskWall Wallpaper" action, so an iOS Shortcuts automation can create and set the wallpaper automatically (e.g. every morning, or when you open the app).

---

## How it works

1. **Add tasks** with optional priority, category and due date.
2. **Pick a theme** (or design one) and choose a layout.
3. **Generate** the wallpaper.
4. **Apply** it by saving to Photos and setting it as your wallpaper, or let a Shortcuts automation do it.
5. **Complete tasks** and regenerate. The wallpaper always reflects your current list.

```
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  Tasks        │ ───▶ │  Renderer     │ ───▶ │  Wallpaper    │
│  (priority,   │      │  (theme +     │      │  image        │
│   category,   │      │   layout:     │      │  → Photos /   │
│   due date)   │      │   list/table) │      │    Shortcuts  │
└───────────────┘      └───────────────┘      └───────────────┘
```

> **Platform note:** iOS does not let third-party apps change the wallpaper directly. TaskWall produces the image, and the user (or a Shortcuts automation using the built-in *Set Wallpaper* action) applies it.

---

## Reference: WallDone

The product benchmark this project is modelled on, as listed on the App Store (Norway) in October 2026:

| | |
|---|---|
| **Name** | WallDone: To-Do on Wallpaper (subtitle: *See Your To Do on Lock Screen*) |
| **Category** | Productivity, Lifestyle |
| **Platform** | iPhone only, iOS 26.0 or later |
| **Version** | 1.1.0 (March 2026), first released October 2025 |
| **Languages** | English, French, Spanish, Turkish |
| **Pricing** | Free with in-app purchases for premium features: monthly (19 kr), annual (129 kr) or one-time lifetime purchase (249 kr) |
| **Privacy label** | Data not linked to you: usage data (product interaction) and diagnostics (crash data) for analytics |

Its listed features are wallpaper generation, smart task management (priorities, categories, due dates), custom and pre-made themes, photo backgrounds, list and table layouts, dark and light modes, and Shortcuts integration. TaskWall's [Features](#features) cover the same set.

---

## Roadmap

- [ ] Task list: add, edit, delete, complete, reorder
- [ ] Priorities, categories and due dates
- [ ] Wallpaper renderer with device-accurate sizing and lock screen safe areas
- [ ] Vertical list and table layouts
- [ ] Pre-made theme gallery
- [ ] Custom theme editor (background, font, colors)
- [ ] Photo backgrounds from the photo library
- [ ] Dark and light modes
- [ ] Save to Photos
- [ ] Shortcuts / App Intents action for automatic wallpaper refresh
- [ ] Localization (English, French, Spanish, Turkish to start)
- [ ] Free vs. premium feature split

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
