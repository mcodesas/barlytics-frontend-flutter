#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
OUT_DIR="$PROJECT_ROOT/build/installers/linux"
STAGE_DIR="$PROJECT_ROOT/build/linux-deb-stage"
PACKAGE_NAME="barlytics"
EXECUTABLE_NAME="barlytics_frontend"

if [[ ! -x "$BUNDLE_DIR/$EXECUTABLE_NAME" ]]; then
  echo "ERROR: no se encontro el ejecutable Linux en $BUNDLE_DIR/$EXECUTABLE_NAME" >&2
  exit 1
fi

rm -rf "$STAGE_DIR"
mkdir -p \
  "$STAGE_DIR/DEBIAN" \
  "$STAGE_DIR/opt/barlytics" \
  "$STAGE_DIR/usr/bin" \
  "$STAGE_DIR/usr/share/applications" \
  "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps" \
  "$OUT_DIR"

cp -a "$BUNDLE_DIR/." "$STAGE_DIR/opt/barlytics/"
ln -s /opt/barlytics/$EXECUTABLE_NAME "$STAGE_DIR/usr/bin/barlytics"
cp "$PROJECT_ROOT/assets/branding/barlytics_app_icon_1024.png" \
  "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/barlytics.png"

cat > "$STAGE_DIR/DEBIAN/control" <<CONTROL
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: MCode SAS <soporte@barlytics.com.co>
Depends: libgtk-3-0, libglib2.0-0, libstdc++6, libsecret-1-0
Description: BarLytics - Gestion inteligente para tu negocio
 Aplicacion de escritorio de BarLytics para Linux.
CONTROL

cat > "$STAGE_DIR/usr/share/applications/barlytics.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=BarLytics
Comment=Gestion inteligente para tu negocio
Exec=/opt/barlytics/$EXECUTABLE_NAME
Icon=barlytics
Terminal=false
Categories=Office;Utility;
StartupNotify=true
DESKTOP

chmod 0755 "$STAGE_DIR/opt/barlytics/$EXECUTABLE_NAME"
chmod 0755 "$STAGE_DIR/DEBIAN"
chmod g-s "$STAGE_DIR/DEBIAN"
chmod 0644 "$STAGE_DIR/DEBIAN/control"
chmod 0644 "$STAGE_DIR/usr/share/applications/barlytics.desktop"
chmod 0644 "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/barlytics.png"

OUTPUT="$OUT_DIR/barlytics-linux-amd64.deb"
dpkg-deb --build --root-owner-group "$STAGE_DIR" "$OUTPUT"

echo "Paquete Linux generado: $OUTPUT"
