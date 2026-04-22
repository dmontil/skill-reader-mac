#!/usr/bin/env bash
set -euo pipefail

DEST="${1:-$HOME/Applications}"
APP_BUNDLE="$DEST/Skill Reader.app"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$DEST"
bash assemble-app.sh "$TMP_ROOT"
rm -rf "$APP_BUNDLE"
mv "$TMP_ROOT/Skill Reader.app" "$APP_BUNDLE"

echo ""
echo "Installed: $APP_BUNDLE"
echo ""
echo "  Launch:  open \"$APP_BUNDLE\""
echo "  Remove:  rm -rf \"$APP_BUNDLE\""
