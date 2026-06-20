#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacFan"
VERSION="${1:-${MACFAN_VERSION:-0.2.0}}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARTIFACT_DIR="$ROOT_DIR/artifacts"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$ARTIFACT_DIR/$APP_NAME-$VERSION-macos.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

export MACFAN_VERSION="$VERSION"

"$ROOT_DIR/script/build_and_run.sh" --build-only

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

mkdir -p "$ARTIFACT_DIR"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"

(
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

/usr/bin/shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Created $ZIP_PATH"
echo "Created $CHECKSUM_PATH"
