#!/bin/sh
# Builds Periodical, replaces /Applications/Periodical.app, and relaunches it.
set -eu
cd "$(dirname "$0")/.."

./scripts/bundle.sh
pkill -x Periodical 2>/dev/null || true
rm -rf /Applications/Periodical.app
cp -R build/Periodical.app /Applications/
open /Applications/Periodical.app
echo "Installed /Applications/Periodical.app"
