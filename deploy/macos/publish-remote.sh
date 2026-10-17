#!/usr/bin/env bash
# Ejecutado en el VPS vía SSH por deploy-dmg-vps.sh.
set -euo pipefail

STAGE="${1:?Falta nombre de archivo temporal}"
VERSION="${2:?Falta versión}"
BUILD="${3:?Falta build}"
EXPECTED_SHA="${4:?Falta SHA256}"

[[ "$STAGE" =~ ^barlytics-macos-[0-9]+-[0-9]+$ ]]
[[ "$VERSION" =~ ^[0-9A-Za-z.+-]+$ ]]
[[ "$BUILD" =~ ^[0-9]+$ ]]
[[ "$EXPECTED_SHA" =~ ^[a-fA-F0-9]{64}$ ]]

cd /opt/barlytics
SOURCE="/tmp/${STAGE}.dmg"
test -s "$SOURCE"
echo "$EXPECTED_SHA  $SOURCE" | sha256sum --check --status

COMPOSE=(docker compose --env-file .env -f docker-compose.prod.yml)
CONTAINER="$("${COMPOSE[@]}" ps -q frontend)"
test -n "$CONTAINER"
docker exec "$CONTAINER" test -s /usr/share/nginx/html/downloads/latest.json
command -v python3 >/dev/null

PERSIST="/opt/barlytics/downloads/macos"
mkdir -p "$PERSIST"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; rm -f "$SOURCE"' EXIT

# Conservar en disco del VPS para recuperación tras sustituir el contenedor.
docker cp "$CONTAINER:/usr/share/nginx/html/downloads/latest.json" "$WORK/latest.json"
python3 - "$WORK/latest.json" "$VERSION" "$BUILD" "$EXPECTED_SHA" <<'PY'
import json
import sys
from pathlib import Path

filename, version, build, sha = sys.argv[1:]
path = Path(filename)
manifest = json.loads(path.read_text(encoding="utf-8"))
platforms = manifest.setdefault("platforms", {})
platforms["macos"] = {
    "version": version,
    "build": int(build),
    "url": "https://www.barlytics.com.co/downloads/BarLytics-macOS.dmg",
    "sha256": sha,
    "enabled": True,
}
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
assert json.loads(path.read_text(encoding="utf-8"))["platforms"]["macos"]["sha256"] == sha
PY

install -m 0644 "$SOURCE" "$PERSIST/BarLytics-macOS.dmg.new"
mv -f "$PERSIST/BarLytics-macOS.dmg.new" "$PERSIST/BarLytics-macOS.dmg"
install -m 0644 "$WORK/latest.json" "$PERSIST/latest.json"

# Cambiar solo el instalador macOS y su entrada en el manifiesto.
# La app Flutter web, backend, Windows, Linux, Android y iOS permanecen intactos.
docker cp "$PERSIST/BarLytics-macOS.dmg" "$CONTAINER:/usr/share/nginx/html/downloads/BarLytics-macOS.dmg.new"
docker exec "$CONTAINER" mv -f /usr/share/nginx/html/downloads/BarLytics-macOS.dmg.new /usr/share/nginx/html/downloads/BarLytics-macOS.dmg

docker cp "$PERSIST/latest.json" "$CONTAINER:/usr/share/nginx/html/downloads/latest.json.new"
docker exec "$CONTAINER" mv -f /usr/share/nginx/html/downloads/latest.json.new /usr/share/nginx/html/downloads/latest.json

docker exec "$CONTAINER" test -s /usr/share/nginx/html/downloads/BarLytics-macOS.dmg
docker exec "$CONTAINER" test -s /usr/share/nginx/html/downloads/latest.json
RUN_SHA="$(docker exec "$CONTAINER" sha256sum /usr/share/nginx/html/downloads/BarLytics-macOS.dmg | awk '{print $1}')"
test "$EXPECTED_SHA" = "$RUN_SHA"
docker exec "$CONTAINER" wget -q --spider http://127.0.0.1/downloads/BarLytics-macOS.dmg
docker exec "$CONTAINER" wget -q -O /dev/null http://127.0.0.1/healthz
echo "Solo macOS publicado. Frontend existente healthy; SHA256=$RUN_SHA."
