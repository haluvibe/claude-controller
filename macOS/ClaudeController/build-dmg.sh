#!/bin/bash
# Build script for ClaudeController - creates a signed DMG

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="ClaudeController"
BUILD_DIR="$SCRIPT_DIR/.build/release"
DMG_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$DMG_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Build release version
swift build -c release

# Create dist directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeController</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.personal.ClaudeController</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ClaudeController</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Sign the app (ad-hoc for local use)
echo "🔏 Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Add Applications symlink for drag-to-install
ln -sf /Applications "$DMG_DIR/Applications"

# Create DMG
echo "📦 Creating DMG..."
DMG_PATH="$SCRIPT_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

echo ""
echo "✅ Build complete!"
echo "📍 DMG: $DMG_PATH"
echo ""
echo "To install:"
echo "1. Open the DMG"
echo "2. Drag ClaudeController to /Applications"
echo "3. Open from /Applications"
echo "4. Grant Accessibility permissions when prompted"
echo ""
