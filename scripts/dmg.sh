#!/bin/sh
# Bundles Periodical.app and wraps it in build/Periodical-<version>.dmg with an Applications shortcut.
set -eu
cd "$(dirname "$0")/.."

export VERSION="${VERSION:-0.3.0}"
./scripts/bundle.sh

DMG="build/Periodical-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R build/Periodical.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname Periodical -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG"
