# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native SwiftUI + AppKit menu bar app, macOS 14+). Not one of web/ios/android/adaptive.

## Users
Anyone whose day runs on a school bell schedule: students and teachers/staff equally. They glance at the menu bar between and during classes to know how long the current period has left and what comes next.

## Product Purpose
Periodical puts a colored countdown for the current (or next) timeblock in the macOS menu bar. Clicking it opens today's timeline; blocks can be added, edited, and arranged across rotating schedules. Success is never having to think about the bell schedule: one glance answers "how long until the bell?"

## Positioning
A bell schedule that lives in the menu bar and understands how schools actually run: A/B rotations, weekday-specific schedules (late-start Wednesday), one-off swapped days, days off and snow days, and natural-language times ("quarter to 3", "45 minutes after").

## Operating Context
Used all day on a school or personal Mac, mostly as a passive glance at the menu bar; occasionally opened to check the day or edit blocks. Setup happens once at the start of a term. Distributed as an unsigned DMG via GitHub Releases (bunkhq/periodical), launches at login, updates manually.

## Capabilities and Constraints
- Menu bar item: hourglass glyph + countdown, optionally the block name, optionally filled with the block's color.
- Panel: weekday circles, current block shown large with a progress bar, upcoming blocks as colored bars, Add Block flow, Settings (Schedule, Days off, Reminders, General), onboarding setup.
- Blocks carry a user-chosen color from a 30-swatch palette (Sources/Periodical/Palette.swift).
- App icon is drawn by scripts/make-icon.swift into AppIcon.icns at bundle time; assets/icon.svg is the README image.

## Brand Commitments
- Name: Periodical.
- The user's reference folder of app icons (friendly character marks, single bold color fields, soft dimensional finish) is the binding aesthetic reference for branding. Both character and non-character marks are in scope.
- The in-app hourglass glyph and stacked color blocks are available motifs, not requirements.

## Evidence on Hand
No testimonials, user counts, or press. Do not invent any.

## Product Principles
- One glance is enough: the most important information reads at menu bar size.
- Fits how schools really schedule, not an idealized week.
- Quiet by default: never checks, nags, or phones home on its own.
- Color belongs to the user's blocks; the chrome stays neutral.
