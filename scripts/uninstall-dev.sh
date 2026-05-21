#!/usr/bin/env bash
set -euo pipefail

purge=false
if [[ "${1:-}" == "--purge" ]]; then
  purge=true
fi

app_dir="${PACKAGE_POLICE_APP_DIR:-/Applications}"
app_path="$app_dir/Computer Police.app"
legacy_app_path="$app_dir/PackagePolice.app"
binary="$app_path/Contents/Resources/bin/package-police"

echo "Quitting Computer Police.app..."
osascript -e 'quit app "Computer Police"' >/dev/null 2>&1 || true
osascript -e 'quit app "PackagePolice"' >/dev/null 2>&1 || true

if [[ -x "$binary" ]]; then
  echo "Restoring registry settings and stopping proxy..."
  "$binary" proxy disable >/dev/null 2>&1 || true
  "$binary" proxy stop >/dev/null 2>&1 || true
elif command -v package-police >/dev/null 2>&1; then
  package-police proxy disable >/dev/null 2>&1 || true
  package-police proxy stop >/dev/null 2>&1 || true
fi

echo "Removing $app_path..."
rm -rf "$app_path"
rm -rf "$legacy_app_path"

if [[ "$purge" == true ]]; then
  echo "Removing ~/.package-police..."
  rm -rf "$HOME/.package-police"
fi

echo "Uninstall complete."
