<img src="assets/icon.svg" width="64" height="64" alt="">

# Periodical

A macOS menu bar app for your bell schedule. The menu bar shows a colored countdown for the
current (or next) timeblock; click it to browse each weekday's blocks and add new ones.

## Install

Download `Periodical-<version>.dmg` from [Releases](https://github.com/bunkhq/periodical/releases),
open it, and drag Periodical into Applications. The app is unsigned, so the first launch needs
right-click → **Open** (or System Settings → Privacy & Security → **Open Anyway**).

Periodical launches at login by default; toggle it from the right-click menu.

To update, right-click the menu bar item → **Check for Updates…**. If a newer release exists, Periodical
downloads it, replaces itself, and reopens. It never checks on its own.

## Build

Requires macOS 14+ and the Swift toolchain (Command Line Tools are enough).

```sh
./scripts/bundle.sh          # builds build/Periodical.app
./scripts/install.sh         # builds, copies to /Applications, relaunches
VERSION=0.4.0 ./scripts/dmg.sh   # builds build/Periodical-0.4.0.dmg and .zip (attach both to the release)
./scripts/dev.sh             # debug loop: rebuild as a separate dev app, reset its own data, relaunch build/ (installed app untouched)
./scripts/dev.sh --seed DIR  # same, but start from the data in DIR (e.g. a 0.3 install, to test upgrading)
swift test                   # time parser + schedule tests
PERIODICAL_SNAPSHOT_DIR=/tmp/snaps swift run   # debug only: renders panel states with sample data to PNGs
```

## Usage

- On first launch, a short setup asks how your week works: one schedule every day, or a few
  (A/B days that take turns, or schedules tied to weekdays such as a late start every Wednesday).
  Rerun it any time from Settings.
- Click the menu bar item to open today's timeline: the running block is shown large with a progress bar,
  later blocks show how long until they start, and blocks that have ended fold away.
  Right-click the menu bar item for Take Today Off, Settings, menu bar options, Launch at Login, Check for Updates, and Quit.
- Pick a day with the weekday circles (or ← →). Click a block to edit it: name, color, the schedules it's on,
  and its times, either shared or one row per schedule. Right-click it to duplicate or delete.
  Deleting can be undone with **Undo** or ⌘Z.
- **Add Block** walks through name → which schedules it's on (which days, with one schedule) → whether the times are the same
  on each → start and end (once, or once per schedule, with the schedule named at the top) → color.
  The name field autocompletes blocks you already have (Return or Tab fills it in). Return on an existing
  name asks whether to add new times to it (keeps its color, skips the color step, and starts on the
  schedules it isn't on yet) or make a separate block: ↑/↓ to choose, Return to continue, Esc to go back
  to the name. Blocks with the same name share a color.
- The calendar button changes one day without touching the rest: run it as a different schedule,
  change its times for that day only, or take it off.
  Times accept `9am`, `14:31`, `noon`, `five past noon`, `quarter to 3`, `in 30 minutes`, etc.
  End times can also count from the start: `45 minutes after`, `after 45 minutes`, `an hour later`, `1h 30m`, or just `45`.
  Bare hours 1–6 without am/pm are read as afternoon (`2:15` → 2:15 PM); use `02:15` or `2:15am` for morning.
- **Settings** (gear button or ⌘,) has four pages, switchable with ⌘1–⌘4: Schedule, Days off (with a
  click-the-first-and-last-day calendar), Reminders (with a test button), and General (with a live menu bar preview).
  - **Reminders** post a notification 1–10 minutes before the running block ends (a chime plays if notifications are off).
  - **Days off** pause countdowns for a day or a range, for snow days and breaks. The menu bar shows "Off".
  - **Rotation** sets up A/B (up to six) schedules, each with an optional name, then blocks can repeat on
    schedules instead of weekdays. Two styles:
    - *Alternate daily*: each school day takes the next letter; weekends and days off are skipped.
      Set which letter today is if the count drifts.
    - *Set by weekday*: each weekday always has the same letter, e.g. A on Mon, Tue, Thu, Fri and B on Wed.
- Keyboard: Return = next/save, Esc = back out / close, ⌘N = add, ⌘, = settings, ⌘Z = undo delete, ⌘Q = quit.

Upgrading from 0.3 or earlier converts your blocks once, on first launch: weekdays with the same lineup of
blocks become one schedule (several lineups become a by-weekday rotation), and blocks with the same name become
one block with its times on each schedule. The original file is kept as `timeblocks.v1-backup.json`, and a note
in the panel says what changed.

Timeblocks are saved to `~/Library/Application Support/Periodical/timeblocks.json`; days off and the rotation to
`settings.json` beside it.
