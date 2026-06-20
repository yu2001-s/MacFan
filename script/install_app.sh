#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacFan"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"

"$ROOT_DIR/script/build_and_run.sh" --build-only

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -w /Applications ]]; then
  rm -rf "$TARGET_APP"
  /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
else
  sudo rm -rf "$TARGET_APP"
  sudo /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
fi

/usr/bin/open "$TARGET_APP"

echo "Installed $TARGET_APP"
