#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${COMPUTER_POLICE_INSTALL_DIR:-${GOBIN:-$HOME/.local/bin}}"
binary_name="${COMPUTER_POLICE_BINARY_NAME:-computer-police}"
target="$install_dir/$binary_name"
legacy_binary_name="${binary_name/computer/package}"
legacy_target="$install_dir/$legacy_binary_name"

mkdir -p "$install_dir"

echo "Building Computer Police..."
(cd "$repo_root" && go build -o "$target" ./cmd/computer-police)
chmod 0755 "$target"

echo "Installed $binary_name to $target"

if [[ "$legacy_binary_name" != "$binary_name" && -e "$legacy_target" ]]; then
  retired_target="$legacy_target.old"
  if [[ -e "$retired_target" ]]; then
    retired_target="$legacy_target.old.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$legacy_target" "$retired_target"
  echo "Retired old CLI at $legacy_target -> $retired_target"
fi

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
