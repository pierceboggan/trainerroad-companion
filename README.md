# TrainerRoad Menu Bar

A lightweight macOS menu bar app that shows your TrainerRoad training data at a glance — today's workout, weekly schedule, and fitness metrics.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

## Features

- 🚴 **Menu bar icon** — lives in the menu bar with no Dock icon
- 📅 **Today's workout** — planned TSS and completion status (✅ / ⏳ / 🛌)
- 📋 **Weekly schedule** — Mon–Sun grid with per-day TSS and progress
- 📊 **Progress bar** — visual TSS completion percentage for the week
- ✅ **Compliance** — tracks completed vs planned workouts
- 💪 **Training Load** — CTL (fitness), ATL (fatigue), TSB (form) from full history
- 🟢🟡🔴 **Form indicator** — Fresh / Neutral / Tired at a glance
- 🔥 **Streak** — consecutive days with completed rides
- 🔗 **Deep links** — open TrainerRoad Calendar or Career page directly
- 🔄 **Auto-refresh** — updates every 15 minutes

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ (ships with Xcode 15+)

## Build & Run

```bash
# Build
swift build

# Run
swift run TrainerRoadMenuBar
```

The bicycle icon (🚴) will appear in your menu bar. Click it to see your training data.

## Configuration

The username defaults to `pierceboggan`. To change it, edit the default parameter in `Sources/TrainerRoadMenuBar/TrainerRoadService.swift`:

```swift
init(username: String = "your-username") {
```

## How It Works

Uses the public TrainerRoad TSS API:

```
https://www.trainerroad.com/app/api/tss/{username}
```

**Completion detection** uses actual recorded ride TSS (`TssTrainerRoad + TssOther`) rather than the `HasRides` flag, which can include scheduled-but-not-ridden workouts.

**Training Load** is calculated using exponentially weighted moving averages:
- **CTL (Fitness)** — 42-day chronic training load
- **ATL (Fatigue)** — 7-day acute training load
- **TSB (Form)** — CTL minus ATL; positive = fresh, negative = fatigued

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open TrainerRoad Calendar |
| ⌘R | Refresh data |
| ⌘Q | Quit |

## Project Structure

```
Package.swift                         # SPM manifest
Sources/TrainerRoadMenuBar/
├── main.swift                        # Entry point (menu-bar-only mode)
├── AppDelegate.swift                 # NSStatusItem + menu construction
├── TrainerRoadService.swift          # API client, queries, CTL/ATL/TSB
└── Models.swift                      # Codable response types
```

## License

MIT
