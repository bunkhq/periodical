<img src="assets/icon.svg" width="64" height="64" alt="">

# Periodical

A macOS menu bar app for your bell schedule. The menu bar shows a colored countdown for the
current (or next) timeblock; click it to browse each weekday's blocks and add new ones.

## Install

Download `Periodical-<version>.dmg` from [Releases](https://github.com/trelakor/periodical/releases),
open it, and drag Periodical into Applications. The app is unsigned, so the first launch needs
right-click → **Open** (or System Settings → Privacy & Security → **Open Anyway**).

Periodical launches at login by default; toggle it from the right-click menu.

## Build

Requires macOS 14+ and the Swift toolchain (Command Line Tools are enough).

```sh
./scripts/bundle.sh          # builds build/Periodical.app
./scripts/install.sh         # builds, copies to /Applications, relaunches
VERSION=0.2.0 ./scripts/dmg.sh   # builds build/Periodical-0.2.0.dmg
swift test                   # time parser + schedule tests
```

## Usage

- Click the menu bar item to open the schedule. Right-click it for Launch at Login and Quit.
- Pick a day with the weekday circles. Right-click a timeblock to delete it.
- **Add Timeblock** walks through name → start → end → repeat days → color.
  Times accept `9am`, `14:31`, `noon`, `five past noon`, `quarter to 3`, `in 30 minutes`, etc.
  End times can also count from the start: `45 minutes after`, `after 45 minutes`, `an hour later`, `1h 30m`, or just `45`.
  Bare hours 1–6 without am/pm are read as afternoon (`2:15` → 2:15 PM); use `02:15` or `2:15am` for morning.
- Keyboard: Return = next, Esc = back out / close, ⌘N = add, ⌘Q = quit.

Timeblocks are saved to `~/Library/Application Support/Periodical/timeblocks.json`.
