#!/usr/bin/env python3
"""Genera un manifiesto coherente con los artefactos ya publicados.

Windows/Linux/Android corresponden al commit que acaba de compilarse.
macOS conserva el build anterior si sólo se reutilizó un DMG viejo.
iOS conserva el build efectivo publicado por TestFlight (flujo separado).
"""
import argparse
import datetime as dt
import json
from pathlib import Path

BASE_URL = "https://www.barlytics.com.co/downloads/"
PLAY_URL = "https://play.google.com/store/apps/details?id=com.mcode.barlytics"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--windows-sha", required=True)
    parser.add_argument("--linux-sha", required=True)
    parser.add_argument("--macos-sha", default="")
    parser.add_argument("--previous", default="")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    previous = {}
    if args.previous and Path(args.previous).is_file():
        try:
            previous = json.loads(Path(args.previous).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    old_platforms = previous.get("platforms", {})
    if not isinstance(old_platforms, dict):
        old_platforms = {}

    mandatory = False
    # Only the release pipeline can set mandatory; don't force old clients
    # if no policy was explicitly configured.
    import os
    mandatory = os.environ.get("BARLYTICS_UPDATE_MANDATORY", "false").lower() == "true"

    macos = {"enabled": False}
    prior_macos = old_platforms.get("macos")
    if (args.macos_sha and isinstance(prior_macos, dict)
            and prior_macos.get("sha256", "").lower() == args.macos_sha.lower()
            and prior_macos.get("enabled") is True
            and prior_macos.get("url") == BASE_URL + "BarLytics-macOS.dmg"):
        # Never label an OLD DMG as a NEW build.
        macos = prior_macos.copy()

    ios = {"enabled": False}
    previous_ios = old_platforms.get("ios")
    if (isinstance(previous_ios, dict)
            and previous_ios.get("enabled") is True
            and previous_ios.get("url", "").startswith("https://")
            and int(previous_ios.get("build", 0)) > 0):
        ios = previous_ios.copy()

    manifest = {
        "version": args.version,
        "build": args.build,
        "mandatory": mandatory,
        "releaseNotes": "Mejoras y correcciones de BarLytics",
        "publishedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "platforms": {
            "windows": {
                "version": args.version, "build": args.build,
                "url": BASE_URL + "BarLytics-Windows-Setup.exe",
                "sha256": args.windows_sha, "enabled": True,
            },
            "linux": {
                "version": args.version, "build": args.build,
                "url": BASE_URL + "barlytics-linux-amd64.deb",
                "sha256": args.linux_sha, "enabled": True,
            },
            "macos": macos,
            "android": {
                "version": args.version, "build": args.build,
                "url": PLAY_URL, "enabled": True,
                "releaseNotes": "Disponible en Google Play - pruebas internas para usuarios autorizados.",
            },
            "ios": ios,
        },
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
