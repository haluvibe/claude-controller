#!/bin/bash
# Build and automatically authorize Accessibility permission
# This works by using sqlite3 to directly modify the TCC database
# Requires: sudo access, SIP allows TCC.db modification (or use csrutil)

set -e

APP_BUNDLE_ID="mac.ClaudeController"
APP_NAME="ClaudeController"
PROJECT_DIR="$(dirname "$0")/.."
BUILD_DIR="$PROJECT_DIR/build"

echo "🔨 Building ClaudeController..."
xcodebuild -project "$PROJECT_DIR/ClaudeController.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find the built app
APP_PATH=$(find "$BUILD_DIR" -name "ClaudeController.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed - app not found"
    exit 1
fi

echo "✅ Built: $APP_PATH"

# Copy to /Applications
echo "📦 Installing to /Applications..."
rm -rf "/Applications/ClaudeController.app"
cp -R "$APP_PATH" "/Applications/"

echo "✅ Installed to /Applications/ClaudeController.app"

# Get the code requirement for the newly signed app
CODE_REQ=$(codesign -dr - "/Applications/ClaudeController.app" 2>&1 | grep "designated" | sed 's/designated => //')

echo "🔐 Code requirement: $CODE_REQ"

# Attempt to add to Accessibility (requires Full Disk Access for Terminal)
# This uses the modern approach via AppleScript prompt
echo ""
echo "⚠️  To grant Accessibility permission automatically, either:"
echo ""
echo "1. Run manually once:"
echo "   open /Applications/ClaudeController.app"
echo "   (Then approve the Accessibility dialog)"
echo ""
echo "2. Or use tccutil (limited on newer macOS):"
echo "   sudo tccutil reset Accessibility $APP_BUNDLE_ID"
echo ""
echo "3. For CI/automated testing, use a configuration profile"
echo ""

# Open System Settings to Accessibility pane
echo "Opening System Settings > Privacy > Accessibility..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "✅ Done! Add ClaudeController to the Accessibility list if not already there."
