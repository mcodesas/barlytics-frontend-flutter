#!/usr/bin/env bash
# Recreate the full iPhone/iPad AppIcon catalog from the official BarLytics logo.
# Run on macOS with: bash scripts/ios/generate-app-icons.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/assets/branding/barlytics_app_icon_1024.png"
CATALOG="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
MASTER="$CATALOG/Icon-App-1024x1024@1x.png"

test -f "$SOURCE" || { echo "Missing official BarLytics app icon: $SOURCE" >&2; exit 1; }
test -f "$CATALOG/Contents.json" || { echo "Missing iOS icon manifest" >&2; exit 1; }
command -v swift >/dev/null || { echo "Swift is required to prepare the opaque Apple icon" >&2; exit 1; }
command -v sips >/dev/null || { echo "sips is required on macOS" >&2; exit 1; }

swift "$ROOT/scripts/ios/render-opaque-icon.swift" "$SOURCE" "$MASTER"

python3 - "$CATALOG" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

catalog = Path(sys.argv[1])
master = catalog / "Icon-App-1024x1024@1x.png"
items = json.loads((catalog / "Contents.json").read_text(encoding="utf-8"))["images"]

def sips_info(path: Path) -> str:
    return subprocess.check_output(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
        text=True,
    )

for item in items:
    name = item.get("filename")
    if not name:
        continue
    dimensions = item["size"].split("x")
    assert len(dimensions) == 2 and dimensions[0] == dimensions[1], item
    scale = float(item["scale"].removesuffix("x"))
    px = round(float(dimensions[0]) * scale)
    assert px > 0, item
    target = catalog / name
    if target != master:
        subprocess.run(
            ["sips", "-z", str(px), str(px), str(master), "--out", str(target)],
            check=True, stdout=subprocess.DEVNULL,
        )
    details = sips_info(target)
    assert f"pixelWidth: {px}" in details, (target, details)
    assert f"pixelHeight: {px}" in details, (target, details)
    assert "hasAlpha: no" in details, (
        f"Apple icon must not have transparency: {target}\n{details}"
    )
    print(f"OK {name}: {px}x{px} RGB (no alpha)")

print(f"Prepared {len([i for i in items if i.get('filename')])} iPhone/iPad icons from official BarLytics art.")
PY
