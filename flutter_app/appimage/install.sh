#!/bin/bash
#
# install.sh - Install Sciometa OSD AppImage
#
# Installs the AppImage to /opt/sciometa/ and creates a desktop shortcut.
# Run with: sudo ./install.sh
#
set -euo pipefail

APP_NAME="Sciometa OSD"
APP_ID="com.sciometa.osd"
INSTALL_DIR="/opt/sciometa"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Find AppImage in same directory as this script
APPIMAGE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "order-status-display-*.AppImage" | head -1)
[ -n "$APPIMAGE" ] || error "order-status-display-*.AppImage not found in $SCRIPT_DIR"

APPIMAGE_NAME=$(basename "$APPIMAGE")
ICON_FILE="$SCRIPT_DIR/app_icon.png"

# Need root for /opt install
if [ "$(id -u)" -ne 0 ]; then
    error "Please run with sudo: sudo ./install.sh"
fi

# Get the actual user (not root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

info "Installing $APP_NAME..."

# Step 1: Copy AppImage to /opt/sciometa/
mkdir -p "$INSTALL_DIR"
cp "$APPIMAGE" "$INSTALL_DIR/$APPIMAGE_NAME"
chmod +x "$INSTALL_DIR/$APPIMAGE_NAME"
info "AppImage installed to $INSTALL_DIR/$APPIMAGE_NAME"

# Step 2: Install icon
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$ICON_DIR/$APP_ID.png"
    info "Icon installed"
fi

# Step 3: Create system .desktop file
DESKTOP_FILE="/usr/share/applications/$APP_ID.desktop"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Order Status Display for restaurants
Exec=$INSTALL_DIR/$APPIMAGE_NAME
Icon=$APP_ID
Categories=Office;Finance;
Terminal=false
StartupNotify=true
EOF
info "Desktop entry created at $DESKTOP_FILE"

# Step 4: Create desktop shortcut for user
DESKTOP_DIR="$REAL_HOME/Desktop"
if [ -d "$DESKTOP_DIR" ]; then
    SHORTCUT="$DESKTOP_DIR/$APP_NAME.desktop"
    cp "$DESKTOP_FILE" "$SHORTCUT"
    chown "$REAL_USER:$REAL_USER" "$SHORTCUT"
    chmod +x "$SHORTCUT"
    # Trust the desktop file (GNOME)
    if command -v gio &>/dev/null; then
        su "$REAL_USER" -c "gio set '$SHORTCUT' metadata::trusted true" 2>/dev/null || true
    fi
    info "Desktop shortcut created"
fi

info "========================================="
info "$APP_NAME installed successfully!"
info "========================================="
info ""
info "You can launch it from:"
info "  - Desktop shortcut"
info "  - Application menu"
info "  - Terminal: $INSTALL_DIR/$APPIMAGE_NAME"
