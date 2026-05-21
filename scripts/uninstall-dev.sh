#!/usr/bin/env bash
set -euo pipefail

purge=false
if [[ "${1:-}" == "--purge" ]]; then
  purge=true
fi

app_dir="${COMPUTER_POLICE_APP_DIR:-/Applications}"
app_path="$app_dir/Computer Police.app"
binary="$app_path/Contents/Resources/bin/computer-police"

echo "Quitting Computer Police.app..."
osascript -e 'quit app "Computer Police"' >/dev/null 2>&1 || true

if [[ -x "$binary" ]]; then
  echo "Restoring registry settings and stopping proxy..."
  "$binary" proxy disable >/dev/null 2>&1 || true
  "$binary" proxy stop >/dev/null 2>&1 || true
elif command -v computer-police >/dev/null 2>&1; then
  computer-police proxy disable >/dev/null 2>&1 || true
  computer-police proxy stop >/dev/null 2>&1 || true
fi

echo "Removing $app_path..."
rm -rf "$app_path"

if [[ "$purge" == true ]]; then
  echo "Removing ~/.computer-police..."
  rm -rf "$HOME/.computer-police"
fi

echo "Uninstall complete."
