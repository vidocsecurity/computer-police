#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${VERSION:-v9.9.9}"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/package-police-installer-e2e.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

release_root="$workdir/releases"
release_dir="$release_root/$version"
home_dir="$workdir/home"
install_dir="$workdir/install/bin"
mkdir -p "$release_dir" "$home_dir"
touch "$home_dir/.bashrc"

echo "Building release-shaped CLI artifacts..."
DIST_DIR="$release_dir" VERSION="$version" "$repo_root/scripts/release/build_cli_artifacts.sh"

echo "Installing from local release artifacts..."
HOME="$home_dir" \
SHELL=/bin/bash \
PACKAGE_POLICE_RELEASE_BASE_URL="file://$release_root" \
"$repo_root/scripts/install.sh" \
  --version "$version" \
  --install-dir "$install_dir" \
  --no-modify-path

installed_version="$("$install_dir/package-police" --version)"
if [ "$installed_version" != "$version" ]; then
  echo "installed version = $installed_version, want $version" >&2
  exit 1
fi

echo "Updating through package-police self update..."
HOME="$home_dir" \
SHELL=/bin/bash \
PACKAGE_POLICE_INSTALL_SCRIPT="$repo_root/scripts/install.sh" \
PACKAGE_POLICE_RELEASE_BASE_URL="file://$release_root" \
"$install_dir/package-police" self update \
  --version "$version" \
  --install-dir "$install_dir" \
  --no-modify-path

echo "Checking checksum failure path..."
corrupt_root="$workdir/corrupt-releases"
corrupt_dir="$corrupt_root/$version"
mkdir -p "$corrupt_dir"
cp "$release_dir"/* "$corrupt_dir/"
printf 'not a valid archive\n' > "$corrupt_dir/ComputerPoliceCLI-$version-linux-x86_64.tar.gz"
if HOME="$home_dir" \
  SHELL=/bin/bash \
  PACKAGE_POLICE_RELEASE_BASE_URL="file://$corrupt_root" \
  "$repo_root/scripts/install.sh" \
    --version "$version" \
    --install-dir "$workdir/bad-install/bin" \
    --no-modify-path >/tmp/package-police-corrupt-install.log 2>&1; then
  echo "corrupt archive install unexpectedly succeeded" >&2
  exit 1
fi
if ! rg -q "checksum mismatch" /tmp/package-police-corrupt-install.log; then
  echo "corrupt archive did not report checksum mismatch" >&2
  exit 1
fi

echo "Uninstalling through package-police self uninstall..."
HOME="$home_dir" \
SHELL=/bin/bash \
PACKAGE_POLICE_INSTALL_SCRIPT="$repo_root/scripts/install.sh" \
"$install_dir/package-police" self uninstall \
  --install-dir "$install_dir" \
  --no-modify-path

if [ -e "$install_dir/package-police" ]; then
  echo "package-police still exists after uninstall" >&2
  exit 1
fi

echo "Public installer e2e passed."
