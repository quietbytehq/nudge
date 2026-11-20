#!/bin/sh
# Packages the exported Linux build (build/linux/nudge.x86_64) as
# tar.gz, .deb and, when appimagetool is available, an AppImage.
# Usage: packaging/build_linux.sh <version>
set -e
VERSION="${1:?version required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/linux/nudge.x86_64"
DIST="$ROOT/dist"
[ -f "$BIN" ] || { echo "missing $BIN - export the Linux preset first"; exit 1; }
mkdir -p "$DIST"

# tar.gz for any distribution
TMP="$(mktemp -d)"
mkdir -p "$TMP/nudge-$VERSION"
cp "$BIN" "$TMP/nudge-$VERSION/nudge"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$TMP/nudge-$VERSION/"
tar -C "$TMP" -czf "$DIST/nudge-$VERSION-linux-x86_64.tar.gz" "nudge-$VERSION"

# .deb
DEB="$TMP/deb"
mkdir -p "$DEB/DEBIAN" "$DEB/usr/lib/nudge" "$DEB/usr/bin" "$DEB/usr/share/applications" \
  "$DEB/usr/share/icons/hicolor/512x512/apps" "$DEB/usr/share/doc/nudge"
cp "$BIN" "$DEB/usr/lib/nudge/nudge.x86_64"
chmod 755 "$DEB/usr/lib/nudge/nudge.x86_64"
cat > "$DEB/usr/bin/nudge" <<'WRAP'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/../lib/nudge/nudge.x86_64" "$@"
WRAP
chmod 755 "$DEB/usr/bin/nudge"
cp "$ROOT/packaging/nudge.desktop" "$DEB/usr/share/applications/nudge.desktop"
cp "$ROOT/assets/logo/nudge-512.png" "$DEB/usr/share/icons/hicolor/512x512/apps/nudge.png"
cp "$ROOT/LICENSE" "$ROOT/NOTICE" "$DEB/usr/share/doc/nudge/"
cat > "$DEB/DEBIAN/control" <<CTRL
Package: nudge
Version: $VERSION
Section: games
Priority: optional
Architecture: amd64
Maintainer: QuietByte <quietbyte.2026@gmail.com>
Description: Nudge - arcade pinball
 A 3D arcade pinball game by QuietByte with three tables, Cosmic Drift,
 Paradise Bay and Alpenglow, and a global top 100.
CTRL
dpkg-deb --build --root-owner-group "$DEB" "$DIST/nudge_${VERSION}_amd64.deb" >/dev/null

# AppImage
TOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
if [ -n "$TOOL" ]; then
  APP="$TMP/Nudge.AppDir"
  mkdir -p "$APP/usr/bin"
  cp "$BIN" "$APP/usr/bin/nudge"
  cp "$ROOT/packaging/nudge.desktop" "$APP/nudge.desktop"
  cp "$ROOT/assets/logo/nudge-512.png" "$APP/nudge.png"
  printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")/usr/bin/nudge" "$@"\n' > "$APP/AppRun"
  chmod 755 "$APP/AppRun" "$APP/usr/bin/nudge"
  ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APP" "$DIST/Nudge-$VERSION-x86_64.AppImage" >/dev/null
else
  echo "appimagetool not found - skipping the AppImage"
fi
rm -rf "$TMP"
ls -la "$DIST"
