#!/usr/bin/env bash
# Tras procesar una build TestFlight, publicar actualización y conservar metadatos.
set -euo pipefail
test -n "$VPS_HOST"
test -n "$VPS_USER"
test -n "$IOS_VERSION"
test -n "$IOS_BUILD_NUMBER"
if [ -z "$IOS_UPDATE_URL" ]; then IOS_UPDATE_URL="https://apps.apple.com/app/testflight/id899247664"; fi
[[ "$IOS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$IOS_BUILD_NUMBER" =~ ^[0-9]+$ ]]
[[ "$IOS_UPDATE_URL" == https://* ]]
test -n "$VPS_SSH_PRIVATE_KEY"
test -n "$VPS_KNOWN_HOSTS"
mkdir -p ~/.ssh
printf '%s\n' "$VPS_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
printf '%s\n' "$VPS_KNOWN_HOSTS" > ~/.ssh/known_hosts
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/known_hosts
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  "$VPS_USER@$VPS_HOST" \
  "bash -s -- '$IOS_VERSION' '$IOS_BUILD_NUMBER' '$IOS_UPDATE_URL'" <<'REMOTE'
set -euo pipefail
VERSION="$1"
BUILD="$2"
URL="$3"
cd /opt/barlytics
mkdir -p /opt/barlytics/downloads/ios
CONTAINER="$(docker compose --env-file .env -f docker-compose.prod.yml ps -q frontend)"
test -n "$CONTAINER"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
docker cp "$CONTAINER:/usr/share/nginx/html/downloads/latest.json" "$WORK/latest.json"
python3 - "$WORK/latest.json" "$VERSION" "$BUILD" "$URL" \
  "/opt/barlytics/downloads/ios/last-release.json" <<'PY'
import json, sys
from pathlib import Path
manifest_path, version, build, url, persist = sys.argv[1:]
p=Path(manifest_path)
manifest=json.loads(p.read_text(encoding="utf-8"))
old=manifest.get("platforms",{}).get("ios",{})
if old.get("version")==version and int(old.get("build",0))>int(build):
    print("Ya existe una build iOS posterior; se conserva.")
else:
    release={
        "version":version, "build":int(build), "url":url,
        "enabled":True, "mandatory":False, "channel":"testflight",
        "releaseNotes":"Actualización de BarLytics en TestFlight. Abre TestFlight para instalarla.",
    }
    manifest.setdefault("platforms",{})["ios"]=release
    p.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    Path(persist).write_text(json.dumps(release,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
PY
docker cp "$WORK/latest.json" "$CONTAINER:/usr/share/nginx/html/downloads/latest.json.new"
docker exec "$CONTAINER" mv -f \
  /usr/share/nginx/html/downloads/latest.json.new \
  /usr/share/nginx/html/downloads/latest.json
docker exec "$CONTAINER" wget -q -O /dev/null \
  http://127.0.0.1/downloads/latest.json
echo "TestFlight en latest.json: $VERSION+$BUILD"
REMOTE
