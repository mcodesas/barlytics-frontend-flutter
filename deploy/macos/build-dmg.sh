#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/BarLytics.app"
OUT_DIR="$PROJECT_ROOT/build/installers/macos"
STAGE_DIR="$PROJECT_ROOT/build/macos-dmg-stage"
OUTPUT="$OUT_DIR/BarLytics-macOS.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: no se encontro BarLytics.app en $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$OUT_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/BarLytics.app"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$OUTPUT"
hdiutil create \
  -volname "BarLytics" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT"

rm -rf "$STAGE_DIR"
echo "DMG macOS generado: $OUTPUT"
