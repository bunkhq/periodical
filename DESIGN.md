---
name: Periodical
description: A bell schedule in the macOS menu bar. Neutral chrome, the user's colored blocks, and Dot, the period with eyes.
colors:
  ink: "#1C1C1E"
  ink-deep: "#0B0B0C"
  panel-light: "#FFFFFF"
  panel-dark: "#1F1F1F"
  label-light: "#000000"
  label-dark: "#FFFFFF"
  now-red: "#FF3B30"
  foreground-on-pale: "#000000D9"
  foreground-on-deep: "#FFFFFF"
  dot-field-top: "#FFE45A"
  dot-field-bottom: "#FFC00C"
  dot-glow: "#FFF6B8"
  dot-rim: "#FFC21A"
  dot-contact: "#9A6200"
  dot-body-light: "#55555C"
  dot-body-mid: "#232326"
  dot-eye-shade: "#E4E4EC"
  block-red: "#FF3A3A"
  block-coral: "#FF6B4A"
  block-orange: "#FF9500"
  block-amber: "#FFB800"
  block-yellow: "#FFD60A"
  block-lime: "#C7D530"
  block-green: "#34C759"
  block-emerald: "#1FA463"
  block-forest: "#0B7A55"
  block-teal: "#00C7BE"
  block-cyan: "#30B0C7"
  block-sky: "#32ADE6"
  block-blue: "#007AFF"
  block-royal-blue: "#3F5EFB"
  block-indigo: "#5856D6"
  block-violet: "#7B4AE2"
  block-purple: "#AF52DE"
  block-orchid: "#D14FC4"
  block-pink: "#FF2D92"
  block-rose: "#FF375F"
  block-raspberry: "#C2185B"
  block-wine: "#7A1F3D"
  block-tan: "#A2845E"
  block-brown: "#6D4C3D"
  block-gray: "#8E8E93"
  block-slate: "#6D7B8D"
  block-graphite: "#48484A"
  block-black: "#1C1C1E"
  block-navy: "#2E3A87"
  block-deep-teal: "#0F4C5C"
typography:
  display:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.1
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.3
  body-small:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.3
  label:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.25
  caption:
    fontFamily: "SF Pro (system), -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "10px"
    fontWeight: 600
    lineHeight: 1.2
  menu-bar-timer:
    fontFamily: "SF Pro (system, monospaced digits)"
    fontSize: "13px"
    fontWeight: 700
    fontFeature: "tnum"
rounded:
  menu-bar-pill: "5px"
  sm: "7px"
  md: "8px"
  lg: "10px"
  panel: "14px"
  capsule: "999px"
spacing:
  hair: "2px"
  xxs: "4px"
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  panel: "14px"
  onboarding: "18px"
  rail: "58px"
components:
  panel:
    backgroundColor: "{colors.panel-light}"
    rounded: "{rounded.panel}"
    padding: "14px"
    width: "320px"
  panel-dark:
    backgroundColor: "{colors.panel-dark}"
    rounded: "{rounded.panel}"
  block-bar:
    backgroundColor: "{colors.block-blue}"
    textColor: "{colors.foreground-on-deep}"
    typography: "{typography.body}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "36px"
  block-focus:
    backgroundColor: "{colors.block-blue}"
    textColor: "{colors.foreground-on-deep}"
    typography: "{typography.display}"
    rounded: "{rounded.lg}"
    padding: "10px 12px 11px"
  button-filled:
    backgroundColor: "{colors.label-light}"
    textColor: "{colors.panel-light}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "32px"
  button-filled-full:
    backgroundColor: "{colors.label-light}"
    textColor: "{colors.panel-light}"
    rounded: "{rounded.lg}"
    padding: "0 16px"
    height: "36px"
  button-outlined:
    textColor: "{colors.label-light}"
    rounded: "{rounded.lg}"
    height: "36px"
  button-outlined-compact:
    textColor: "{colors.label-light}"
    rounded: "{rounded.sm}"
    padding: "0 12px"
    height: "26px"
  icon-button:
    rounded: "{rounded.capsule}"
    size: "26px"
  weekday-circle:
    textColor: "{colors.label-light}"
    rounded: "{rounded.capsule}"
    size: "32px"
  weekday-circle-selected:
    backgroundColor: "{colors.label-light}"
    textColor: "{colors.panel-light}"
    rounded: "{rounded.capsule}"
    size: "32px"
  chip:
    textColor: "{colors.label-light}"
    rounded: "{rounded.capsule}"
    padding: "0 4px"
    height: "28px"
  chip-selected:
    backgroundColor: "{colors.label-light}"
    textColor: "{colors.panel-light}"
    rounded: "{rounded.capsule}"
    height: "28px"
  text-field:
    textColor: "{colors.label-light}"
    rounded: "{rounded.md}"
    padding: "0 10px"
    height: "40px"
  settings-card:
    rounded: "{rounded.lg}"
  menu-bar-pill:
    backgroundColor: "{colors.block-blue}"
    textColor: "{colors.foreground-on-deep}"
    typography: "{typography.menu-bar-timer}"
    rounded: "{rounded.menu-bar-pill}"
    padding: "0 6px"
    height: "20px"
---

# Design System: Periodical

## Overview

**Creative North Star: "The Quiet Bell"**

Periodical is a native macOS menu bar utility, and its interface behaves like one: SF system type, SF Symbols, a 320pt popover bubble with an arrow pointing at its menu bar button, and chrome built entirely from the system label color at stepped opacities. It follows light and dark appearance automatically. Nothing in the chrome carries a hue. The only saturated color on screen is the user's own: each timeblock wears one of 30 swatches, and the running block is shown large, with a live countdown and progress bar, as a solid slab of that color.

The density is glanceable rather than dense. The panel is a single column: header, a row of weekday circles, then a timeline where a 58pt time rail sits to the left of stacked color bars spaced 6pt apart. Selection has one grammar. The chosen item fills with the label color and its text inverts to the panel background. The settings tabs are the only exception: they use a tint.

The brand identity, Dot, sits outside the panel. Dot is the period in "Periodical" made into a character: a glossy ink ball with big white oval eyes glancing up and to the right and a small smile. On the app icon Dot sits on a warm yellow tile with a yellow rim bounce. The wordmark is custom geometric monoline lowercase with Dot as its period. The brand is loud and friendly so that the app chrome can stay quiet.

**Key Characteristics:**
- Native macOS: SF Pro, SF Symbols, continuous-corner rounded rectangles, automatic light and dark appearance.
- Neutral chrome made from the system label color at opacity steps. Hue comes only from user blocks.
- Color bars with automatic white or near-black text chosen by luminance.
- One selection grammar: filled ink with inverted text.
- Monospaced digits for every time and countdown.
- Brand: Dot, a glossy ink character on a yellow tile, with a custom monoline wordmark. Both are drawn assets, never typed.

## Colors

The chrome is achromatic ink on white (light) or near-black (dark). A 30-swatch block palette supplies all on-screen hue, and the brand adds a warm yellow and a glossy ink that live only in the icon and logo assets.

### Primary
- **Block Palette** (the 30 `block-*` tokens, Red through Deep Teal): the user's colors. Each fills its block's bars in the timeline, the menu bar pill, and the swatch grid (6 columns, 30pt circles, 6pt gaps). New blocks get a suggested color by stepping 7 places through the palette, so blocks that sit next to each other in a day differ in hue. Unknown hex values fall back to Gray.

### Secondary
- **Dot Yellow** (`dot-field-top` to `dot-field-bottom`, a vertical gradient): the app icon tile only. It is lit by a soft pale glow (`dot-glow`, 70% opacity, top left) and grounded by a blurred amber contact shadow (`dot-contact`, 50%).
- **Rim Bounce** (`dot-rim`, 0 to 70% at the edge): the yellow light the tile reflects onto Dot's lower right. It appears on the icon only, not on the standalone logo.

### Tertiary
- **Glossy Ink** (`dot-body-light`, then `dot-body-mid`, then `ink-deep`, a radial gradient lit from the top left): Dot's body. It has a soft specular bloom and a sharp 50% white highlight. Pupils are `ink-deep` with a white catchlight. Eyes are white shading to `dot-eye-shade` at the bottom.
- **Now Red** (`now-red`, the system red): the single chrome hue. It is used only for the "Now" line across the timeline and its 7pt dot.

### Neutral
- **Ink** (`ink`): the wordmark letterforms on light grounds, and the Black block swatch.
- **Panel White / Panel Night** (`panel-light`, `panel-dark` = white at 0.12): the bubble's fill in light and dark appearance.
- **Label** (`label-light` / `label-dark`, the system `Color.primary`): all chrome text. Every chrome fill and hairline is this color at a set opacity (see the Opacity Ladder Rule).
- **On-color text** (`foreground-on-deep` white, `foreground-on-pale` black at 85%): text and glyphs on a block color.

### Named Rules
**The Color Belongs to Blocks Rule.** Chrome never takes a hue. Buttons, toggles, chips, weekday circles, cards, and banners are built from the label color and the panel background. The user's block colors are the only saturated fills. The one exception is Now Red on the current-time line.

**The Legible on Any Swatch Rule.** Text on a block color is white while the swatch's relative luminance is 0.30 or less (at least 3:1 contrast). Above 0.30 it switches to black at 85% opacity. This applies everywhere a block color is a ground: timeline bars, the menu bar pill, and the checkmark on a selected swatch. Never hand-pick text color per swatch.

**The Opacity Ladder Rule.** Neutral surfaces are the label color at fixed steps: 0.03 hover tint and resting option card, 0.04 settings card, 0.05 text field and "earlier blocks" row, 0.06 unselected circle and chip and banner, 0.07 ended or skipped block, 0.08 pressed and icon hover. Hairlines are 0.1 to 0.15, outlines 0.35, focus 0.4, the today ring 0.5, and a selected option border 0.6. The bubble stroke is 0.1 in light and 0.18 in dark. Do not introduce gray hex values for chrome.

**The Yellow Stays on the Tile Rule.** The Dot Yellow gradient belongs to the app icon. Panel chrome does not use it. The Yellow and Amber block swatches are user colors, not brand accents.

## Typography

**Display Font:** SF Pro (system font)
**Body Font:** SF Pro (system font)
**Label/Mono Font:** SF Pro with monospaced digits for all times and countdowns

**Character:** This is pure system type, sized in points the way native Mac utilities are. Weight carries the hierarchy more than size: bold for titles and countdowns, medium for block names, semibold for actions.

### Hierarchy
- **Display** (bold, 24pt, monospaced digits): the countdown on the focused block ("36m 19s"). A 12pt medium "left" / "to start" label follows it at 85% opacity, aligned on the first baseline.
- **Headline** (bold, 17pt): screen titles in onboarding and the Add Block flow.
- **Title** (bold, 15pt): panel headers ("Today", "Settings", editor titles).
- **Body** (13pt): block names (medium), setting row titles (regular), button labels (semibold), and the selected weekday letter (bold).
- **Body Small** (12pt regular): trailing times on block bars, empty-state lines, the Undo bar, and chips (semibold when selected).
- **Label** (11pt): header subtitles and setting details (regular, secondary), and block start times on the rail (medium).
- **Caption** (10pt): block end times on the rail (regular, tertiary), rotation letters under the weekday circles (semibold, secondary), and "Now" (bold, red).
- **Menu Bar** (13pt monospaced digit system font): bold timer, regular block name, with an interpunct between them.

### Named Rules
**The Tabular Time Rule.** Every clock time, duration, and countdown uses monospaced digits, so numbers do not jitter as they tick.

**The Drawn Not Typed Rule.** The wordmark and Dot are geometry from `scripts/make-brand.py`. They are never set in SF or any other font, for licensing reasons and because the letterforms are custom. To change them, edit and rerun the script.

## Layout

The panel is a fixed 320pt-wide single column inside a speech-bubble window, with 14pt padding (18pt in onboarding). Sections stack at 12pt. The timeline row is a 58pt right-aligned time rail, a 10pt gutter, and the block bar. Rows stack at 6pt. Breaks and the Now line align to the same rail through an empty rail column. The list scrolls past 400pt and centers on the focused block. Weekday circles share the width equally (32pt circles, 3pt to the caption). Settings rows use 12pt horizontal and 9pt vertical padding, with hairline dividers inset 12pt from the leading edge.

Spacing values in use: 2, 4, 6, 8, 10, 12, 14, and 18. Most component padding is 10 to 12pt.

The brand wordmark sits on a 100-unit x-height grid: 26-unit monoline stroke, circular bowls (radius 37 at the stroke centerline), and letter gaps from 9 to 18 units, adjusted optically per pair. Dot as the period is a 31-unit-radius circle seated on the baseline.

## Elevation & Depth

Inside the panel the interface is flat. Depth comes only from tonal layering on the Opacity Ladder: a card is a 4% label tint on the panel, and pressing darkens it. Block bars respond to the pointer by darkening brightness (-0.03 on hover, -0.08 when pressed), not by lifting. The only shadow is the system window shadow on the bubble panel.

The brand assets are the opposite: they are deliberately dimensional, a "soft dimensional finish". The icon tile has one soft drop shadow, and Dot is a lit glossy sphere with a specular highlight and contact shadow.

### Shadow Vocabulary
- **Panel window** (AppKit `hasShadow`): the system shadow under the bubble. Not drawn by the app.
- **Icon tile** (`drop-shadow(0 10px 12px rgba(0,0,0,0.24))` on the 1024 grid): app icon only.
- **Dot contact** (`dot-contact` at 50%, Gaussian blur 24, under the ball): app icon only.

### Named Rules
**The Flat Panel Rule.** No drop shadows inside the panel. Separate things with the opacity ladder and spacing.

## Shapes

Every rounded rectangle uses continuous (squircle) corners. The radius steps by role: 5pt for the menu bar pill drawn as an image, 7pt for compact outlined buttons in settings, 8pt for text fields and inline filled buttons, 10pt for block bars, cards, banners, and full-width buttons, and 14pt for the panel bubble. The bubble has a 20 by 9pt arrow with a softly rounded tip. Circles and capsules carry choice: weekday circles, color swatches, icon-button hover discs, chips, the segmented settings tabs, the toggle track, the progress bar, and the filled menu bar button.

The hourglass (16 by 20 viewBox, even-odd fill) is the in-app glyph. `TimeIcon` has the sand settled at the bottom and marks upcoming blocks and the idle state. `Active` has the sand at the top and marks the running block. Dot is a perfect circle. The app icon tile is an 824-unit square on a 1024 grid with a 185.4 corner radius.

## Components

### Buttons
- **Shape:** continuous rounded rectangles (8pt inline, 10pt full width, 7pt compact).
- **Filled (primary):** label-color fill with panel-background text, semibold 13pt, 16pt horizontal padding, 32pt tall (36pt at full width). Pressed is 70% opacity; disabled is 25%.
- **Outlined:** clear fill with a 1.5pt outline at 35% label, 36pt tall, full width. It is the panel's "Add Block". Pressed tints 8%. The compact settings variant is 26pt tall with a 1pt outline and semibold 12pt text.
- **Quiet:** plain secondary-color text for Cancel, Back, and Undo. Pressed is 60% opacity.
- **Icon button:** a 26pt SF Symbol hit area, medium 13pt, secondary color, with an 8% circular tint on hover.

### Chips
- **Style:** capsules, 28pt tall (32pt for rotation schedules), 6% label tint, regular text.
- **State:** selected fills with the label color, inverts the text, and goes semibold (12pt) or bold (13pt for rotation schedules). Chips in a row share the width equally.

### Cards / Containers
- **Corner Style:** 10pt continuous.
- **Background:** label tint at 4% (settings card), 6% (banners, Undo bar), or 3 to 7% (option card at rest and selected).
- **Shadow Strategy:** none (Flat Panel Rule).
- **Border:** none on settings cards. Option cards have a 1pt border at 10%, or 1.5pt at 60% when selected, with a filled checkmark circle.
- **Internal Padding:** 12pt. Banners use 12 by 9pt.

### Inputs / Fields
- **Style:** 40pt tall (15pt text), 10pt horizontal padding, 5% label fill, 1pt hairline at 15%, 8pt continuous corners.
- **Focus:** the hairline strengthens to 40%. There is no glow or accent ring.
- **Hints:** time fields show the parsed time, or a secondary nudge ("Try 9am, 14:30, or noon").

### Navigation
- **Weekday circles:** seven 32pt circles (28pt in compact pickers, where the text drops to 11pt) labeled S M T W T F S. Unselected circles are a 6% tint. Selected fills with ink, inverts the text, and goes bold. Today, when not selected, has a 1.5pt ring at 50% and a bold letter. Optional rotation letters sit underneath.
- **Settings tabs:** a capsule segmented control (Schedule, Days off, Reminders, General) in a 1pt capsule outline at 10%. The selected segment gets an 8% capsule fill and semibold 12pt text. It is the one selection that does not invert to ink.
- **Header:** title and subtitle on the left; the day menu (`calendar.badge.clock`) and settings gear as icon buttons on the right. Views change through a route switch inside the same bubble, with easeOut transitions of 0.15 to 0.2s.

### Block Bar (signature)
- **Compact:** 36pt tall, 12pt padding, block color fill, medium 13pt name on the left, and a 12pt trailing time on the right ("in 42 min") at 85% opacity. Ended and skipped blocks lose their color: 7% tint with secondary text.
- **Focus:** the running or next block. It shows the name, then a 14 by 17.5pt hourglass with the 24pt bold countdown, then (while running) a 3pt capsule progress bar. The track is the on-color foreground at 30% and the fill at 100%, with a minimum fill of 3pt.
- **Rail:** start time (11pt medium, secondary) above end time (10pt, tertiary), right-aligned in the 58pt rail. Breaks of 10 minutes or more are labeled on the rail in tertiary 11pt. The Now line is a red 7pt dot and a 1.5pt rule.
- **Interaction:** click to edit; right-click for Edit, Duplicate, and Delete. Delete shows an Undo bar for 8 seconds.

### Menu Bar Pill (signature)
- A 20pt-tall image with 6pt padding: the hourglass (9 by 11.25pt), a 4pt gap, then the 13pt bold monospaced timer and, optionally, " · " and the regular-weight name (truncated at 32 characters). The fill is the block color with 5pt corners. With "Fill with block color" on, the whole status button becomes a capsule of that color instead. When idle, it shows the black template hourglass, plus "Off" in 12pt medium on a day off.

### Toggle Row
- The whole row is the hit target, and its switch is drawn in the app's colors: a 30 by 18pt capsule (label color when on, 15% when off) with a panel-color knob and a 0.15s easeOut slide. The row tints 3% on hover.

### Dot and the Wordmark (brand)
- **Dot:** a 250-unit-radius sphere centered at (530, 540) on a 1024 grid. Two 54 by 70 white oval eyes, each with a 31-radius pupil offset (+15, -7) so Dot glances up and to the right, and a 10-radius catchlight. The smile is a 17-unit round-capped white stroke.
- **Small sizes (`make-icon.swift`):** at 32px and below, Dot scales up 1.16 and the eyes grow 1.12. At 16px and below, the eyes spread apart and grow 1.25 taller, and the pupils, smile, and highlights are dropped.
- **Files:** `icon.svg` (tile and Dot, used in the README), `logo.svg` (Dot alone, for light grounds), `logo-dark.svg` (adds a 32% white edge, brightest at the lower right, so the ball does not sink into dark grounds), and `logo-mono.svg` (a one-color even-odd silhouette for template use).
- **Wordmark:** "periodical" in lowercase geometric monoline. 26-unit stroke on a 100 x-height, round caps and joins, circular bowls, and round tittles. The e's crossbar is optically lighter at 21, and its terminal is a round dot. Dot is the period. `wordmark.svg` uses ink letters with white eyes and ink pupils. `wordmark-dark.svg` uses white letters and a white Dot whose eyes are ringed in ink (3.5) so they read.

## Do's and Don'ts

### Do:
- **Do** take every on-screen hue from the user's block colors. Build chrome from the label color at Opacity Ladder steps.
- **Do** pick on-color text with `Color.foreground(onHex:)`: white at luminance 0.30 or less, otherwise black at 85%.
- **Do** show selection as a label-color fill with text in the panel background color, for circles, chips, toggles, and filled buttons alike.
- **Do** use monospaced digits for every time, countdown, and duration.
- **Do** use continuous corners on the radius steps 5, 7, 8, 10, and 14, and capsules or circles for choices.
- **Do** mark upcoming blocks with the `starting` hourglass and the running block with the `active` hourglass.
- **Do** use `logo.svg` and `wordmark.svg` on light grounds and the `-dark` files on dark grounds. Regenerate them with `python3 scripts/make-brand.py`.
- **Do** keep the icon's simplified sizes at 32px and 16px when changing Dot.

### Don't:
- **Don't** give chrome a hue, including the brand yellow. The only chrome color is Now Red on the current-time line.
- **Don't** add drop shadows inside the panel. Use tonal fills and spacing.
- **Don't** hand-pick text color for a block swatch or add swatches without checking the 0.30 luminance threshold.
- **Don't** retype the wordmark, or draw Dot, in SF or any other font. Both are drawn geometry from `scripts/make-brand.py`.
- **Don't** put Dot on yellow outside the app icon tile, or use the rim bounce on the standalone logo.
- **Don't** introduce custom fonts or gray hex values into the app UI. It is SF and the system label color only.
