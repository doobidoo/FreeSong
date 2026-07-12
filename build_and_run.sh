#!/bin/bash
set -e

SCHEME="FreeSong"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max"
DERIVED_DATA="/Users/hkr/GitHub/FreeSong/.build"

echo "🔨 Building $SCHEME for iOS Simulator..."
xcodebuild -scheme "$SCHEME" \
  -workspace /Users/hkr/GitHub/FreeSong/.swiftpm/xcode/package.xcworkspace \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILD_DIR="$DERIVED_DATA/Build/Products/Debug-iphonesimulator"
BINARY="$BUILD_DIR/FreeSong"
APP_BUNDLE="$BUILD_DIR/FreeSong.app"

echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/FreeSong"

# Create minimal Info.plist
cat > "$APP_BUNDLE/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleDisplayName</key><string>FreeSong</string>
<key>CFBundleExecutable</key><string>FreeSong</string>
<key>CFBundleIdentifier</key><string>com.freesong.app</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>FreeSong</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UILaunchScreen</key><dict/>
<key>UISupportedInterfaceOrientations~iphone</key>
<array>
<string>UIInterfaceOrientationPortrait</string>
<string>UIInterfaceOrientationLandscapeLeft</string>
<string>UIInterfaceOrientationLandscapeRight</string>
</array>
</dict>
</plist>
PLIST

# Copy all SPM resource bundles into .app (required for CoreData models, privacy manifests, etc.)
for bundle in "$BUILD_DIR"/*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP_BUNDLE/"
done

# Ad-hoc sign for simulator (required for iOS 17+)
codesign --force --sign - --timestamp=none "$APP_BUNDLE" 2>/dev/null || true

echo "📱 Installing to Simulator..."
# Boot simulator if not running
xcrun simctl boot "$(xcrun simctl list devices | grep -v unavailable | grep -i 'iphone 17' | head -1 | grep -o '[A-F0-9-]\{36\}')" 2>/dev/null || true

# Install and launch
xcrun simctl install booted "$APP_BUNDLE"
xcrun simctl launch booted com.freesong.app

echo "✅ Done"
