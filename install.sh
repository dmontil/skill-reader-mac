#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="SkillReaderMac"
BUNDLE_ID="com.dmontil.skill-reader-mac"
DEST="${1:-$HOME/Applications}"
APP_BUNDLE="$DEST/Skill Reader.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
PLIST="$APP_BUNDLE/Contents/Info.plist"

# ── Build ──────────────────────────────────────────────────────────────────
echo "-> Building Skill Reader (release)..."
swift build -c release --quiet

BINARY=".build/release/$BINARY_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found." && exit 1
fi

# ── Bundle ─────────────────────────────────────────────────────────────────
echo "-> Creating app bundle at $APP_BUNDLE..."
mkdir -p "$MACOS_DIR"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$MACOS_DIR/$BINARY_NAME"
[ -f "Assets/AppIcon.icns" ] && cp "Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$PLIST" << 'EOF'
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

# ── Sign ───────────────────────────────────────────────────────────────────
echo "-> Signing (ad-hoc)..."
codesign --force --deep -s - "$APP_BUNDLE"

echo ""
echo "Installed: $APP_BUNDLE"
echo ""
echo "  Launch:  open \"$APP_BUNDLE\""
echo "  Remove:  rm -rf \"$APP_BUNDLE\""
