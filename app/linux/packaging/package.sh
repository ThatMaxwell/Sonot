#!/usr/bin/env bash
# Packs the Flutter Linux bundle into Sonot-linux-x64.tar.gz,
# Sonot-x86_64.AppImage and sonot_<version>_amd64.deb.
# Run from app/ after `flutter build linux --release`.
set -euo pipefail

BUNDLE=build/linux/x64/release/bundle
ICON=../assets/brand/sonot-icon-512.png
VERSION=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
OUT=${OUT:-.}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

desktop() { # $1 = Exec line
  cat <<DESK
[Desktop Entry]
Type=Application
Name=Sonot
Comment=Chat, code and Buds
Exec=$1
Icon=sonot
Terminal=false
Categories=Utility;Development;Chat;
StartupWMClass=com.thatmaxwell.sonot
DESK
}

# tar.gz: the bundle as is.
tar -czf "$OUT/Sonot-linux-x64.tar.gz" -C "$BUNDLE" .

# .deb: bundle in /opt/sonot, launcher in /usr/bin, menu entry and icon.
DEB=$WORK/deb
mkdir -p "$DEB/DEBIAN" "$DEB/opt/sonot" "$DEB/usr/bin" "$DEB/usr/share/applications" "$DEB/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE"/. "$DEB/opt/sonot/"
ln -s /opt/sonot/sonot "$DEB/usr/bin/sonot"
desktop sonot > "$DEB/usr/share/applications/sonot.desktop"
cp "$ICON" "$DEB/usr/share/icons/hicolor/512x512/apps/sonot.png"
cat > "$DEB/DEBIAN/control" <<CTRL
Package: sonot
Version: $VERSION
Architecture: amd64
Maintainer: ThatMaxwell <noreply@github.com>
Depends: libgtk-3-0
Section: utils
Priority: optional
Homepage: https://github.com/ThatMaxwell/Sonot
Description: Sonot: chat, code and Buds
 The Sonot app for Linux.
CTRL
dpkg-deb --root-owner-group --build "$DEB" "$OUT/sonot_${VERSION}_amd64.deb"

# AppImage: the bundle plus AppRun, desktop entry and icon.
APP=$WORK/Sonot.AppDir
mkdir -p "$APP/usr/bin"
cp -r "$BUNDLE"/. "$APP/usr/bin/"
cat > "$APP/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/sonot" "$@"
RUN
chmod +x "$APP/AppRun"
desktop sonot > "$APP/sonot.desktop"
cp "$ICON" "$APP/sonot.png"
TOOL=${APPIMAGETOOL:-$WORK/appimagetool}
if [ ! -x "$TOOL" ]; then
  curl -fsSL -o "$TOOL" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$TOOL"
fi
ARCH=x86_64 "$TOOL" --appimage-extract-and-run --no-appstream "$APP" "$OUT/Sonot-x86_64.AppImage"
