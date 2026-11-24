#!/bin/sh
#
# Builds one of the apps for the iOS Simulator, on Apple's SwiftUI, and
# wraps it as an app bundle the simulator can install.
#
#   Scripts/ios-simulator-app.sh <product> [<display name>]
#
# For example: Scripts/ios-simulator-app.sh calculator Calculator
# The bundle is written to .build/ios-simulator/<display name>.app. Install
# and open it with:
#
#   xcrun simctl install booted .build/ios-simulator/Calculator.app
#   xcrun simctl launch booted org.pureswift.calculator

set -eu

product=$1
name=${2:-$product}
cd "$(dirname "$0")/.."

arch=$(uname -m)
triple="$arch-apple-ios17.0-simulator"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)

swift build --traits Apple --triple "$triple" --sdk "$sdk" --product "$product"
binary=$(swift build --traits Apple --triple "$triple" --sdk "$sdk" --show-bin-path)/$product

app=.build/ios-simulator/$name.app
rm -rf "$app"
mkdir -p "$app"
cp "$binary" "$app/$name"
identifier=org.pureswift.$(printf '%s' "$product" | tr '[:upper:]' '[:lower:]')
# Keys of the app's own, such as the camera's usage strings, from
# Scripts/ios-info/<product>.plist: <key>s and their values, no <dict>.
extra=$(cat "Scripts/ios-info/$product.plist" 2>/dev/null || true)

cat > "$app/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$identifier</string>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundleDisplayName</key><string>$name</string>
    <key>CFBundleExecutable</key><string>$name</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>MinimumOSVersion</key><string>17.0</string>
    <key>UILaunchScreen</key><dict/>
    <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
$extra
</dict>
</plist>
PLIST

echo "$app ($identifier)"
