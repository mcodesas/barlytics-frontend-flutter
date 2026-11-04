#!/usr/bin/env bash
# Solo publica el DMG de macOS: no recrea servicios ni cambia tags Docker.
set -euo pipefail

FILE="build/installers/macos/BarLytics-macOS.dmg"
test -s "$FILE"

VERSION="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+)\+([0-9]+).*/\1/p' pubspec.yaml | head -n1)"
BUILD="$(bash deploy/update/release-build.sh)"
test -n "$VERSION"
[[ "$BUILD" =~ ^[0-9]+$ ]]
SHA="$(sha256sum "$FILE" | awk '{print $1}')"

: "${VPS_HOST:?Falta VPS_HOST}"
: "${VPS_USER:?Falta VPS_USER}"

STAGE="barlytics-macos-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
SSH=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -i "$HOME/.ssh/id_ed25519")
SCP=(scp -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -i "$HOME/.ssh/id_ed25519")

echo "Enviando únicamente el DMG de macOS al VPS..."
"${SCP[@]}" "$FILE" "${VPS_USER}@${VPS_HOST}:/tmp/${STAGE}.dmg"
"${SSH[@]}" "${VPS_USER}@${VPS_HOST}" \
  "bash -s -- '${STAGE}' '${VERSION}' '${BUILD}' '${SHA}'" \
  < deploy/macos/publish-remote.sh

# Comprobación adicional desde fuera del VPS. No descargar el instalador.
echo "Comprobando acceso público al instalador macOS..."
curl --fail --silent --show-error --location --head --retry 4 --retry-delay 3 \
  "https://www.barlytics.com.co/downloads/BarLytics-macOS.dmg" >/dev/null
echo "macOS disponible por HTTPS. SHA256: $SHA"
