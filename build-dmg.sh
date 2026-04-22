#!/usr/bin/env bash
# Builds a distributable .dmg installer for Skill Reader.
# Usage: bash build-dmg.sh
# Output: dist/Skill Reader.dmg
set -euo pipefail

BINARY_NAME="SkillReaderMac"
APP_NAME="Skill Reader"
DIST="dist"
STAGING="$DIST/staging"
APP_BUNDLE="$STAGING/$APP_NAME.app"
DMG_RW="$DIST/rw.$APP_NAME.dmg"
DMG_OUT="$DIST/$APP_NAME.dmg"
VOL_NAME="$APP_NAME"

rm -rf "$STAGING"
bash assemble-app.sh "$STAGING"

# ── Build DMG (no Finder/AppleScript dependency) ──────────────────────────
echo "-> Building DMG..."
rm -f "$DMG_OUT" "$DMG_RW"

# Create a temporary read-write DMG
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$DMG_RW" > /dev/null

# Mount it and capture the mount point (last column of last line)
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW")
MOUNT_DIR=$(echo "$ATTACH_OUT" | grep "/Volumes/" | awk -F'\t' '{print $NF}' | tail -1)
DEV_NODE=$(echo "$ATTACH_OUT" | grep "/Volumes/" | awk '{print $1}' | tail -1)

# Add symlink to /Applications inside the DMG
ln -sf /Applications "$MOUNT_DIR/Applications"

# Unmount
hdiutil detach "$DEV_NODE" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" > /dev/null
rm -f "$DMG_RW"

SIZE=$(du -sh "$DMG_OUT" | cut -f1)
echo ""
echo "Done: $DMG_OUT ($SIZE)"
echo ""
echo "Distribute this file. Users open it and drag Skill Reader -> Applications."
