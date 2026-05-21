#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dist_dir="${DIST_DIR:-$repo_root/dist}"
version="${VERSION:-dev}"

targets=(
  "darwin/amd64/macos-x86_64"
  "darwin/arm64/macos-arm64"
  "linux/amd64/linux-x86_64"
  "linux/arm64/linux-arm64"
  "windows/amd64/windows-x86_64"
  "windows/arm64/windows-arm64"
)

mkdir -p "$dist_dir"

for target in "${targets[@]}"; do
  IFS="/" read -r goos goarch label <<<"$target"
  name="computer-police"
  ext=""
  archive_ext="tar.gz"
  if [[ "$goos" == "windows" ]]; then
    ext=".exe"
    archive_ext="zip"
  fi

  workdir="$(mktemp -d "${TMPDIR:-/tmp}/computer-police-cli.XXXXXX")"
  trap 'rm -rf "$workdir"' EXIT
  binary="$workdir/$name$ext"

  echo "Building $name $version for $goos/$goarch..."
  (
    cd "$repo_root"
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build \
      -trimpath \
      -ldflags "-s -w -X main.version=$version" \
      -o "$binary" \
      ./cmd/package-police
  )

  archive_base="ComputerPoliceCLI-$version-$label"
  if [[ "$archive_ext" == "zip" ]]; then
    (
      cd "$workdir"
      zip -q "$dist_dir/$archive_base.zip" "$name$ext"
    )
  else
    (
      cd "$workdir"
      tar -czf "$dist_dir/$archive_base.tar.gz" "$name$ext"
    )
  fi
  rm -rf "$workdir"
  trap - EXIT
done

(
  cd "$dist_dir"
  shasum -a 256 ComputerPoliceCLI-"$version"-* > "ComputerPoliceCLI-$version-checksums.txt"
)

echo "CLI artifacts written to $dist_dir"
