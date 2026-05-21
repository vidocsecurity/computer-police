#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="${PACKAGE_POLICE_APP_DIR:-/Applications}"
app_path="$app_dir/Computer Police.app"
legacy_app_path="$app_dir/PackagePolice.app"
dev_advisory_dir="${PACKAGE_POLICE_DEV_ADVISORY_DIR:-$repo_root/internal/proxy/testdata/osv}"
dev_app_log="${PACKAGE_POLICE_DEV_APP_LOG:-/tmp/package-police-dev-app.log}"
diagnostic_dir="$HOME/Library/Logs/DiagnosticReports"
force_launch_exit="${PACKAGE_POLICE_DEV_FORCE_LAUNCH_EXIT:-}"

print_launch_diagnostics() {
  local app_pid="$1"
  local latest_report=""
  local candidate=""
  local candidate_mtime=""

  echo
  echo "Computer Police did not stay running after launch."
  echo
  echo "--- process check ---"
  if [[ -n "$app_pid" ]] && kill -0 "$app_pid" >/dev/null 2>&1; then
    echo "PackagePolice process is still alive: $app_pid"
  else
    echo "PackagePolice process is not running."
  fi

  echo
  echo "--- app log: $dev_app_log ---"
  if [[ -s "$dev_app_log" ]]; then
    sed -n '1,220p' "$dev_app_log"
  else
    echo "(empty)"
  fi

  echo
  echo "--- recent system log entries ---"
  log show \
    --last 2m \
    --style compact \
    --predicate 'subsystem == "dev.computerpolice.app" OR process == "PackagePolice"' \
    2>/dev/null | sed -n '1,160p' || true

  echo
  echo "--- newest crash report ---"
  if [[ -d "$diagnostic_dir" ]]; then
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      candidate_mtime="$(stat -f '%m' "$candidate" 2>/dev/null || echo 0)"
      if (( candidate_mtime >= launch_started_at )); then
        latest_report="$candidate"
        break
      fi
    done < <(/bin/ls -t "$diagnostic_dir"/PackagePolice-*.ips 2>/dev/null || true)
  fi
  if [[ -n "$latest_report" ]]; then
    echo "$latest_report"
    sed -n '1,220p' "$latest_report"
  else
    echo "(no PackagePolice crash report found)"
  fi
}

echo "Quitting any running Computer Police.app..."
osascript -e 'quit app "Computer Police"' >/dev/null 2>&1 || true
osascript -e 'quit app "PackagePolice"' >/dev/null 2>&1 || true

if command -v computer-police >/dev/null 2>&1; then
  echo "Stopping any prior PATH-installed proxy..."
  computer-police proxy stop >/dev/null 2>&1 || true
elif command -v package-police >/dev/null 2>&1; then
  echo "Stopping any prior PATH-installed proxy..."
  package-police proxy stop >/dev/null 2>&1 || true
fi
if [[ -x "$app_path/Contents/Resources/bin/computer-police" ]]; then
  echo "Stopping any prior app-embedded proxy..."
  "$app_path/Contents/Resources/bin/computer-police" proxy stop >/dev/null 2>&1 || true
elif [[ -x "$app_path/Contents/Resources/bin/package-police" ]]; then
  echo "Stopping any prior app-embedded proxy..."
  "$app_path/Contents/Resources/bin/package-police" proxy stop >/dev/null 2>&1 || true
fi

echo "Building dev app bundle..."
"$repo_root/desktop/PackagePolice/Scripts/package_app.sh"

echo "Installing app to $app_path..."
mkdir -p "$app_dir"
rm -rf "$app_path"
rm -rf "$legacy_app_path"
cp -R "$repo_root/desktop/PackagePolice/Computer Police.app" "$app_path"

echo "Ensuring no stale proxy is still bound..."
"$app_path/Contents/Resources/bin/computer-police" proxy stop >/dev/null 2>&1 || true

if [[ -n "$force_launch_exit" ]]; then
  echo "Forcing launch failure for diagnostics test..."
  mv "$app_path/Contents/MacOS/PackagePolice" "$app_path/Contents/MacOS/PackagePolice.real"
  cat >"$app_path/Contents/MacOS/PackagePolice" <<'FORCED_EXIT'
#!/usr/bin/env bash
echo "PACKAGE_POLICE_DEV_FORCE_LAUNCH_EXIT requested; exiting immediately." >&2
exit 42
FORCED_EXIT
  chmod +x "$app_path/Contents/MacOS/PackagePolice"
fi

echo "Launching Computer Police.app..."
echo "Using dev malware advisories from $dev_advisory_dir"
launch_started_at="$(date +%s)"
nohup env PACKAGE_POLICE_OSV_ADVISORY_DIR="$dev_advisory_dir" \
  "$app_path/Contents/MacOS/PackagePolice" >"$dev_app_log" 2>&1 &
app_pid="$!"
echo "App log: $dev_app_log"

sleep 2
if ! kill -0 "$app_pid" >/dev/null 2>&1; then
  print_launch_diagnostics "$app_pid"
  exit 1
fi
echo "Computer Police.app is running (pid $app_pid)."

cat <<'CHECKLIST'

Manual test checklist:
  1. Look for the shield icon in the macOS menu bar.
  2. Click it. It should show Protection: On with Binary/Proxy/Registry green.
  3. Run ./scripts/seed-events.sh to generate install traffic.
  4. Run ./scripts/kill-proxy.sh to verify watchdog restart.
  5. Run ./scripts/break-registry.sh to verify yellow degraded state and Repair.
  6. Run bun add left-pad to verify the dev-only fake MAL advisory blocks left-pad@1.3.0.
  7. Run ./scripts/uninstall-dev.sh when done.

CHECKLIST
