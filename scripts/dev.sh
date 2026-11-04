#!/bin/sh
# Debug loop: rebuilds Periodical, quits any running copy, wipes its saved schedule and preferences
# so first-run setup shows again, and launches the fresh build from build/.
# This deletes your real schedule. Back up ~/Library/Application Support/Periodical first if you need it.
#
#   ./scripts/dev.sh                 fresh start (first-run setup)
#   ./scripts/dev.sh --seed <dir>    start from the data in <dir>: timeblocks.json, settings.json, and
#                                    preferences.plist, each if present (e.g. a 0.3 install to test upgrading)
set -eu
SEED=""
if [ "${1:-}" = "--seed" ]; then SEED="$2"; fi
cd "$(dirname "$0")/.."

./scripts/bundle.sh
pkill -x Periodical 2>/dev/null || true
sleep 0.5

DATA="$HOME/Library/Application Support/Periodical"
rm -f "$DATA/timeblocks.json" "$DATA/settings.json"
defaults delete app.periodical.Periodical 2>/dev/null || true
if [ -n "$SEED" ]; then
    mkdir -p "$DATA"
    for f in timeblocks.json settings.json; do
        if [ -f "$SEED/$f" ]; then cp "$SEED/$f" "$DATA/$f"; fi
    done
    rm -f "$DATA"/*.v1-backup.json
    if [ -f "$SEED/preferences.plist" ]; then defaults import app.periodical.Periodical "$SEED/preferences.plist"; fi
fi
# Keep the launch-at-login item pointed at the installed app rather than re-registering this build.
defaults write app.periodical.Periodical loginItemConfigured -bool true

open build/Periodical.app
echo "Reset and launched build/Periodical.app"
