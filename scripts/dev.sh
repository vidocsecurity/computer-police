#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${PACKAGE_POLICE_APP_DIR:-/Applications}"
app_path="$app_dir/PackagePolice.app"

echo "Quitting any running PackagePolice.app..."
osascript -e 'quit app "PackagePolice"' >/dev/null 2>&1 || true

if command -v package-police >/dev/null 2>&1; then
  echo "Stopping any prior PATH-installed proxy..."
  package-police proxy stop >/dev/null 2>&1 || true
fi

echo "Building dev app bundle..."
"$repo_root/desktop/PackagePolice/Scripts/package_app.sh"

echo "Installing app to $app_path..."
mkdir -p "$app_dir"
rm -rf "$app_path"
cp -R "$repo_root/desktop/PackagePolice/PackagePolice.app" "$app_path"

echo "Launching PackagePolice.app..."
open "$app_path"

cat <<'CHECKLIST'

Manual test checklist:
  1. Look for the shield icon in the macOS menu bar.
  2. Click it. It should show Protection: On with Binary/Proxy/Registry green.
  3. Run ./scripts/seed-events.sh to generate install traffic.
  4. Run ./scripts/kill-proxy.sh to verify watchdog restart.
  5. Run ./scripts/break-registry.sh to verify yellow degraded state and Repair.
  6. Run ./scripts/uninstall-dev.sh when done.

CHECKLIST
