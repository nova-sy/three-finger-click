#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ThreeFingerClick"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
APP_ARCHS="${APP_ARCHS:-arm64 x86_64}"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
UNIVERSAL_BINARY_PATH="$ROOT_DIR/dist/$APP_NAME-universal"

cd "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

binary_paths=()
for arch in $APP_ARCHS; do
    swift build -c release --product "$APP_NAME" --arch "$arch"
    binary_paths+=("$ROOT_DIR/.build/$arch-apple-macosx/release/$APP_NAME")
done

if [[ "${#binary_paths[@]}" -eq 1 ]]; then
    cp "${binary_paths[0]}" "$MACOS_DIR/$APP_NAME"
else
    lipo -create "${binary_paths[@]}" -output "$UNIVERSAL_BINARY_PATH"
    cp "$UNIVERSAL_BINARY_PATH" "$MACOS_DIR/$APP_NAME"
    rm -f "$UNIVERSAL_BINARY_PATH"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ThreeFingerClick</string>
    <key>CFBundleIdentifier</key>
    <string>local.threefingerclick.app</string>
    <key>CFBundleName</key>
    <string>ThreeFingerClick</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built $APP_DIR ($APP_VERSION build $APP_BUILD, archs: $APP_ARCHS)"
