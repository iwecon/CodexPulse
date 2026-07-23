#!/bin/bash

set -euo pipefail

ARCH=""
VERSION=""
OUTPUT_DIR="dist"

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

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ABSOLUTE_OUTPUT_DIR="$(cd "$REPOSITORY_ROOT" && mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-pulse-package.XXXXXX")"
APP_DIR="$WORK_DIR/Codex Pulse.app"
CONTENTS_DIR="$APP_DIR/Contents"
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

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources" "$DMG_ROOT"
ditto "$EXECUTABLE" "$CONTENTS_DIR/MacOS/Codex Pulse"

PLIST="$CONTENTS_DIR/Info.plist"
plutil -create xml1 "$PLIST"
plutil -insert CFBundleDevelopmentRegion -string "zh_CN" "$PLIST"
plutil -insert CFBundleExecutable -string "Codex Pulse" "$PLIST"
plutil -insert CFBundleIdentifier -string "com.iwecon.CodexPulse" "$PLIST"
plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$PLIST"
plutil -insert CFBundleName -string "Codex Pulse" "$PLIST"
plutil -insert CFBundleDisplayName -string "Codex Pulse" "$PLIST"
plutil -insert CFBundlePackageType -string "APPL" "$PLIST"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -insert CFBundleVersion -string "$VERSION" "$PLIST"
plutil -insert LSMinimumSystemVersion -string "26.0" "$PLIST"
plutil -insert LSUIElement -bool true "$PLIST"
plutil -insert NSHighResolutionCapable -bool true "$PLIST"
plutil -insert NSPrincipalClass -string "NSApplication" "$PLIST"

codesign --force --deep --options runtime --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

ditto "$APP_DIR" "$DMG_ROOT/Codex Pulse.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Codex Pulse" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

echo "Created $DMG_PATH"
