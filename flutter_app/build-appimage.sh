#!/bin/bash
#
# build-appimage.sh - Build AppImage for Sciometa OSD
#
# Usage:
#   ./build-appimage.sh          # Build AppImage (uses existing release build if available)
#   ./build-appimage.sh --clean  # Clean rebuild from scratch
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="order-status-display"
APP_ID="com.sciometa.osd"
BINARY_NAME="osd_app"
ARCH="x86_64"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="build/AppDir"
APPIMAGE_DIR="appimage"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Check appimagetool
APPIMAGETOOL="$(command -v appimagetool 2>/dev/null || echo "$HOME/.local/bin/appimagetool")"
if [ ! -x "$APPIMAGETOOL" ]; then
    error "appimagetool not found. Install it with:
    wget -O ~/.local/bin/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x ~/.local/bin/appimagetool"
fi

# Step 1: Flutter release build
if [ "${1:-}" = "--clean" ] || [ ! -f "$BUILD_DIR/$BINARY_NAME" ]; then
    if [ "${1:-}" = "--clean" ]; then
        info "Cleaning previous build..."
        flutter clean
        flutter pub get
    fi
    info "Building Flutter Linux release..."
    flutter build linux --release
else
    info "Using existing release build. Use --clean to rebuild."
fi

[ -f "$BUILD_DIR/$BINARY_NAME" ] || error "Release build not found at $BUILD_DIR/$BINARY_NAME"

# Step 2: Create AppDir structure
info "Creating AppDir structure..."
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/metainfo"

# Step 3: Copy Flutter bundle (keep original structure: binary + lib/ + data/ together)
info "Copying Flutter bundle..."
cp -a "$BUILD_DIR/"* "$APPDIR/usr/"

# Step 4: Copy .env if it exists (next to binary)
if [ -f ".env" ]; then
    info "Copying .env configuration..."
    cp ".env" "$APPDIR/usr/"
fi

# Step 5: Desktop file and icon
info "Setting up desktop integration..."
ICON_SOURCE="assets/icons/app_icon.png"
if [ -f "linux/runner/app_icon.png" ]; then
    ICON_SOURCE="linux/runner/app_icon.png"
fi
cp "$APPIMAGE_DIR/$APP_ID.desktop" "$APPDIR/"
cp "$APPIMAGE_DIR/$APP_ID.desktop" "$APPDIR/usr/share/applications/"
cp "$ICON_SOURCE" "$APPDIR/$APP_ID.png"
cp "$ICON_SOURCE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
cp "$ICON_SOURCE" "$APPDIR/.DirIcon"

# Step 6: AppRun
cp "$APPIMAGE_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# Step 7: Bundle system libraries that may not be available on target
info "Bundling required system libraries..."
bundle_lib() {
    local lib_path
    lib_path=$(ldd "$BUILD_DIR/$BINARY_NAME" 2>/dev/null | grep "$1" || true)
    lib_path=$(echo "$lib_path" | awk '{print $3}')
    if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
        cp -L "$lib_path" "$APPDIR/usr/lib/" 2>/dev/null || true
        info "  Bundled: $1"
    fi
}

bundle_lib "libsecret-1.so"
bundle_lib "libjsoncpp.so"

# Step 8: AppStream metainfo
cat > "$APPDIR/usr/share/metainfo/$APP_ID.appdata.xml" << 'METAEOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>com.sciometa.osd</id>
  <metadata_license>MIT</metadata_license>
  <project_license>Proprietary</project_license>
  <name>Sciometa OSD</name>
  <summary>Order Status Display for restaurants</summary>
  <description>
    <p>Sciometa OSD is an order status display application for restaurants, showing real-time order progress to customers.</p>
  </description>
  <launchable type="desktop-id">com.sciometa.osd.desktop</launchable>
  <url type="homepage">https://sciometa.com</url>
  <provides>
    <binary>osd_app</binary>
  </provides>
</component>
METAEOF

# Step 9: Build AppImage
info "Building AppImage..."
VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
export VERSION

OUTPUT_NAME="${APP_NAME}-${VERSION}-${ARCH}.AppImage"
ARCH="$ARCH" "$APPIMAGETOOL" --no-appstream "$APPDIR" "build/$OUTPUT_NAME"

if [ -f "build/$OUTPUT_NAME" ]; then
    SIZE=$(du -h "build/$OUTPUT_NAME" | cut -f1)
    info "========================================="
    info "AppImage created successfully!"
    info "  File: build/$OUTPUT_NAME"
    info "  Size: $SIZE"
    info "========================================="
    info ""
    info "Distribute this single file. Desktop shortcut is created automatically on first launch."
    info "To run:  chmod +x build/$OUTPUT_NAME && ./build/$OUTPUT_NAME"
else
    error "Failed to create AppImage"
fi
