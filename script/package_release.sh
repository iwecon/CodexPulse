#!/bin/bash

set -euo pipefail

ARCH=""
VERSION=""
OUTPUT_DIR="dist"
SIGNING_IDENTITY="-"
SIGNING_KEYCHAIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --signing-identity)
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --signing-keychain)
      SIGNING_KEYCHAIN="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "--arch must be arm64 or x86_64" >&2
  exit 64
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "--version must be a semantic version such as 0.1.0" >&2
  exit 64
fi

if [[ -n "$SIGNING_KEYCHAIN" && "$SIGNING_IDENTITY" == "-" ]]; then
  echo "--signing-keychain requires --signing-identity" >&2
  exit 64
fi

if [[ -n "$SIGNING_KEYCHAIN" && ! -f "$SIGNING_KEYCHAIN" ]]; then
  echo "Signing keychain not found at $SIGNING_KEYCHAIN" >&2
  exit 1
fi

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ABSOLUTE_OUTPUT_DIR="$(cd "$REPOSITORY_ROOT" && mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-pulse-package.XXXXXX")"
APP_DIR="$WORK_DIR/Codex Pulse.app"
CONTENTS_DIR="$APP_DIR/Contents"
ICON_NAME="Codex Pulse Icon"
ICON_SOURCE="$REPOSITORY_ROOT/IconAssets/$ICON_NAME.icon"
ICON_INFO_PLIST="$WORK_DIR/assetcatalog_generated_info.plist"
DMG_ROOT="$WORK_DIR/dmg"
DMG_PATH="$ABSOLUTE_OUTPUT_DIR/Codex-Pulse-$ARCH.dmg"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$REPOSITORY_ROOT"
swift build -c release --product "Codex Pulse" --arch "$ARCH"
BIN_DIR="$(swift build -c release --show-bin-path --arch "$ARCH")"
EXECUTABLE="$BIN_DIR/Codex Pulse"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Release executable not found at $EXECUTABLE" >&2
  exit 1
fi

if ! lipo -archs "$EXECUTABLE" | tr ' ' '\n' | grep -qx "$ARCH"; then
  echo "Built executable does not contain the requested $ARCH architecture" >&2
  exit 1
fi

while IFS= read -r dependency; do
  case "$dependency" in
    /System/Library/*|/usr/lib/*)
      ;;
    *)
      echo "Release executable links a non-system dependency: $dependency" >&2
      exit 1
      ;;
  esac
done < <(otool -L "$EXECUTABLE" | awk 'NR > 1 { print $1 }')

if [[ ! -d "$ICON_SOURCE" ]]; then
  echo "Icon Composer document not found at $ICON_SOURCE" >&2
  exit 1
fi

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources" "$DMG_ROOT"
ditto "$EXECUTABLE" "$CONTENTS_DIR/MacOS/Codex Pulse"
xcrun actool "$ICON_SOURCE" \
  --compile "$CONTENTS_DIR/Resources" \
  --output-format human-readable-text \
  --notices \
  --warnings \
  --errors \
  --output-partial-info-plist "$ICON_INFO_PLIST" \
  --app-icon "$ICON_NAME" \
  --include-all-app-icons \
  --enable-on-demand-resources NO \
  --development-region zh_CN \
  --target-device mac \
  --minimum-deployment-target 26.0 \
  --platform macosx

PLIST="$CONTENTS_DIR/Info.plist"
plutil -create xml1 "$PLIST"
plutil -insert CFBundleDevelopmentRegion -string "zh_CN" "$PLIST"
plutil -insert CFBundleExecutable -string "Codex Pulse" "$PLIST"
plutil -insert CFBundleIdentifier -string "com.iwecon.CodexPulse" "$PLIST"
plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$PLIST"
plutil -insert CFBundleIconFile -string "$(plutil -extract CFBundleIconFile raw "$ICON_INFO_PLIST")" "$PLIST"
plutil -insert CFBundleIconName -string "$(plutil -extract CFBundleIconName raw "$ICON_INFO_PLIST")" "$PLIST"
plutil -insert CFBundleName -string "Codex Pulse" "$PLIST"
plutil -insert CFBundleDisplayName -string "Codex Pulse" "$PLIST"
plutil -insert CFBundlePackageType -string "APPL" "$PLIST"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -insert CFBundleVersion -string "$VERSION" "$PLIST"
plutil -insert LSMinimumSystemVersion -string "26.0" "$PLIST"
plutil -insert LSUIElement -bool true "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
plutil -insert NSPrincipalClass -string "NSApplication" "$PLIST"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "No Developer ID identity supplied; using ad hoc signing"
  codesign --force --deep --options runtime --sign - "$APP_DIR"
else
  echo "Signing app with Developer ID identity $SIGNING_IDENTITY"
  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    codesign --force --deep --options runtime --timestamp \
      --keychain "$SIGNING_KEYCHAIN" \
      --sign "$SIGNING_IDENTITY" \
      "$APP_DIR"
  else
    codesign --force --deep --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$APP_DIR"
  fi
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto "$APP_DIR" "$DMG_ROOT/Codex Pulse.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Codex Pulse" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  echo "Signing disk image with Developer ID identity $SIGNING_IDENTITY"
  if [[ -n "$SIGNING_KEYCHAIN" ]]; then
    codesign --force --timestamp \
      --keychain "$SIGNING_KEYCHAIN" \
      --sign "$SIGNING_IDENTITY" \
      "$DMG_PATH"
  else
    codesign --force --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$DMG_PATH"
  fi
  codesign --verify --strict --verbose=2 "$DMG_PATH"
fi

echo "Created $DMG_PATH"
