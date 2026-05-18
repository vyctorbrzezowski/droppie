#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Droppie"
BUNDLE_ID="com.vyctor.Droppie"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${DROPPIE_VERSION:-0.1.0}"
APP_BUILD="${DROPPIE_BUILD:-1}"
SPARKLE_FEED_URL="${DROPPIE_SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${DROPPIE_SPARKLE_PUBLIC_ED_KEY:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Sources/Droppie/Resources/AppIcon.icns"
INSTALL_DIR="${1:-$HOME/Applications}"

cd "$ROOT_DIR"
swift build -c release --product "$APP_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY" 2>/dev/null || true

copy_sparkle_framework() {
  local framework
  framework="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d -print -quit)"

  if [[ -n "${framework:-}" ]]; then
    mkdir -p "$APP_FRAMEWORKS"
    rm -rf "$APP_FRAMEWORKS/Sparkle.framework"
    ditto "$framework" "$APP_FRAMEWORKS/Sparkle.framework"
  fi
}

copy_sparkle_framework

copy_provider_logos() {
  local source_dir="$ROOT_DIR/Sources/Droppie/Resources/ProviderLogos"

  if [[ -d "$source_dir" ]]; then
    mkdir -p "$APP_RESOURCES"
    rm -rf "$APP_RESOURCES/ProviderLogos"
    ditto "$source_dir" "$APP_RESOURCES/ProviderLogos"
  fi
}

copy_provider_logos

copy_app_icon() {
  if [[ -f "$APP_ICON" ]]; then
    mkdir -p "$APP_RESOURCES"
    cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
  fi
}

copy_app_icon

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>SUAllowsAutomaticUpdates</key>
  <false/>
  <key>SUEnableAutomaticChecks</key>
  <false/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

sign_app() {
  local identity
  identity="$(security find-identity -p codesigning -v 2>/dev/null | awk -F '"' '/Apple Development|Developer ID Application/ { print $2; exit }')"

  if [[ -n "${identity:-}" ]]; then
    codesign --force --deep --options runtime --timestamp=none --sign "$identity" "$APP_BUNDLE"
  else
    codesign --force --deep --sign - "$APP_BUNDLE"
  fi
}

sign_app

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"
echo "$INSTALL_DIR/$APP_NAME.app"
