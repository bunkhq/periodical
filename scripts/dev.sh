#!/bin/sh
# Debug loop: rebuilds Periodical as a separate dev app, quits any running dev copy, wipes the dev copy's
# schedule and preferences so first-run setup shows again, and launches the fresh build from build/.
# The dev build uses bundle id app.periodical.Periodical.dev and ~/Library/Application Support/Periodical Dev,
# so the installed app's schedule and preferences are never touched.
#
#   ./scripts/dev.sh                 fresh start (first-run setup)
#   ./scripts/dev.sh --seed <dir>    start from the data in <dir>: timeblocks.json, settings.json, and
#                                    preferences.plist, each if present (e.g. a 0.3 install to test upgrading)
set -eu
SEED=""
if [ "${1:-}" = "--seed" ]; then SEED="$2"; fi
cd "$(dirname "$0")/.."

DEV_ID=app.periodical.Periodical.dev
DATA="$HOME/Library/Application Support/Periodical Dev"

BUNDLE_ID="$DEV_ID" ./scripts/bundle.sh
# Quit dev builds only (from any checkout), never the installed /Applications copy.
pkill -f '/build/Periodical\.app/Contents/MacOS/Periodical' 2>/dev/null || true
sleep 0.5

rm -f "$DATA/timeblocks.json" "$DATA/settings.json" "$DATA"/*.v1-backup.json
defaults delete "$DEV_ID" 2>/dev/null || true
if [ -n "$SEED" ]; then
    mkdir -p "$DATA"
    for f in timeblocks.json settings.json; do
        if [ -f "$SEED/$f" ]; then cp "$SEED/$f" "$DATA/$f"; fi
    done
    if [ -f "$SEED/preferences.plist" ]; then defaults import "$DEV_ID" "$SEED/preferences.plist"; fi
fi
# Keep the launch-at-login item pointed at the installed app rather than registering this build.
defaults write "$DEV_ID" loginItemConfigured -bool true

open build/Periodical.app
echo "Reset and launched build/Periodical.app (dev data: $DATA)"
