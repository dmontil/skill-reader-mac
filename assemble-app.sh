#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="SkillReaderMac"
APP_NAME="Skill Reader"
BUNDLE_ID="com.dmontil.skill-reader-mac"
VERSION="${VERSION:-1.0}"
DEST_ROOT="${1:-dist}"
APP_BUNDLE="$DEST_ROOT/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
PLIST="$APP_BUNDLE/Contents/Info.plist"

echo "-> Building Skill Reader (release)..."
swift build -c release --quiet

BINARY=".build/release/$BINARY_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found." >&2
    exit 1
fi

echo "-> Assembling $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/$BINARY_NAME"

ICON_SOURCE=""
if [ -f "Assets/AppIcon.icns" ]; then
    ICON_SOURCE="Assets/AppIcon.icns"
elif [ -f "Sources/SkillReaderMac/Resources/AppIcon.icns" ]; then
    ICON_SOURCE="Sources/SkillReaderMac/Resources/AppIcon.icns"
fi

if [ -n "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>           <string>$BINARY_NAME</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleVersion</key>              <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSPrincipalClass</key>             <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key><true/>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
</dict>
</plist>
EOF

echo "-> Signing (ad-hoc)..."
codesign --force --deep -s - "$APP_BUNDLE"

echo ""
echo "App bundle ready: $APP_BUNDLE"
