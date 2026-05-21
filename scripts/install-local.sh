#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${PACKAGE_POLICE_INSTALL_DIR:-${GOBIN:-$HOME/.local/bin}}"
binary_name="${PACKAGE_POLICE_BINARY_NAME:-package-police}"
target="$install_dir/$binary_name"

mkdir -p "$install_dir"

echo "Building Computer Police..."
(cd "$repo_root" && go build -o "$target" ./cmd/package-police)
chmod 0755 "$target"

echo "Installed $binary_name to $target"

case ":$PATH:" in
  *":$install_dir:"*)
    ;;
  *)
    echo
    echo "Note: $install_dir is not on your PATH."
    echo "Add this to your shell profile if you want to run $binary_name from anywhere:"
    echo "  export PATH=\"$install_dir:\$PATH\""
    ;;
esac

echo
"$target" --version
