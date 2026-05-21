#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dist_dir="${DIST_DIR:-$repo_root/dist}"
version="${VERSION:-dev}"
app_path="$repo_root/desktop/PackagePolice/Computer Police.app"
zip_path="$dist_dir/ComputerPolice-$version-macos-universal.zip"

mkdir -p "$dist_dir"

"$repo_root/desktop/PackagePolice/Scripts/package_app.sh"

if [[ ! -d "$app_path" ]]; then
  echo "Missing built app bundle: $app_path" >&2
  exit 1
fi

rm -f "$zip_path"
ditto -c -k --keepParent "$app_path" "$zip_path"
shasum -a 256 "$zip_path" > "$zip_path.sha256"

echo "macOS app artifact written to $zip_path"
