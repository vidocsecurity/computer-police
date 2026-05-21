#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$package_root/../.." && pwd)"
product_name="ComputerPolice"
app_name="Computer Police"
app_path="$package_root/$app_name.app"
build_dir="$package_root/.build"
embedded_bin_dir="$build_dir/bin"
export GOCACHE="${GOCACHE:-$repo_root/.build/go-cache}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$package_root/.build/clang-module-cache}"

mkdir -p "$CLANG_MODULE_CACHE_PATH"

mkdir -p "$embedded_bin_dir"

echo "Building computer-police CLI..."
(cd "$repo_root" && go build -o "$embedded_bin_dir/computer-police" ./cmd/computer-police)
chmod 0755 "$embedded_bin_dir/computer-police"

echo "Building Computer Police Swift app..."
(cd "$package_root" && swift build -c release --product "$product_name")
swift_bin_dir="$(cd "$package_root" && swift build -c release --show-bin-path)"
swift_exe="$swift_bin_dir/$product_name"

echo "Assembling $app_name.app..."
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/bin"
cp "$script_dir/Info.plist.template" "$app_path/Contents/Info.plist"
cp "$swift_exe" "$app_path/Contents/MacOS/$product_name"
cp "$embedded_bin_dir/computer-police" "$app_path/Contents/Resources/bin/computer-police"
cp -R "$repo_root/internal/proxy/testdata/osv" "$app_path/Contents/Resources/osv-testdata"
chmod 0755 "$app_path/Contents/MacOS/$product_name" "$app_path/Contents/Resources/bin/computer-police"

for bundle in "$swift_bin_dir"/*.bundle; do
  if [[ -d "$bundle" ]]; then
    cp -R "$bundle" "$app_path/Contents/Resources/"
  fi
done

echo "Ad-hoc signing $app_name.app..."
codesign --force --deep --sign - "$app_path" >/dev/null

echo "Built $app_path"
