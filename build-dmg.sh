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

# ── 1. Build ───────────────────────────────────────────────────────────────
echo "-> Building release binary..."
swift build -c release --quiet
BINARY=".build/release/$BINARY_NAME"
[ -f "$BINARY" ] || { echo "Build failed."; exit 1; }

# ── 2. Create .app bundle ──────────────────────────────────────────────────
echo "-> Assembling $APP_NAME.app..."
rm -rf "$STAGING"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
cp "Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>           <string>com.dmontil.skill-reader-mac</string>
    <key>CFBundleName</key>                 <string>Skill Reader</string>
    <key>CFBundleDisplayName</key>          <string>Skill Reader</string>
    <key>CFBundleExecutable</key>           <string>SkillReaderMac</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleVersion</key>              <string>1.0</string>
    <key>CFBundleShortVersionString</key>   <string>1.0</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSPrincipalClass</key>             <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key><true/>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
</dict>
</plist>
EOF

# ── 3. Ad-hoc sign ─────────────────────────────────────────────────────────
echo "-> Signing (ad-hoc)..."
codesign --force --deep -s - "$APP_BUNDLE"

# ── 4. Build DMG (no Finder/AppleScript dependency) ───────────────────────
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
