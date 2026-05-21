#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry="${COMPUTER_POLICE_TEST_REGISTRY:-http://127.0.0.1:4873}"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/computer-police-left-pad.XXXXXX")"
cache_dir="$workdir/bun-cache"

echo "Testing left-pad block through $registry"
echo "Working directory: $workdir"

if ! curl --noproxy '*' -fsS "$registry/api/advisories" >/dev/null; then
  echo "Proxy is not reachable at $registry." >&2
  echo "Run ./scripts/dev.sh first, or set COMPUTER_POLICE_TEST_REGISTRY to a running proxy." >&2
  exit 2
fi

cd "$workdir"
set +e
output="$(
  HOME="$workdir/home" \
  BUN_INSTALL_CACHE_DIR="$cache_dir" \
  bun add left-pad \
    --registry "$registry" \
    --force \
    --no-cache \
    --cache-dir "$cache_dir" \
    2>&1
)"
status=$?
set -e

printf '%s\n' "$output"

if [[ $status -eq 0 ]]; then
  echo "Expected left-pad to be blocked, but Bun installed it." >&2
  exit 1
fi

if [[ "$output" != *"403"* ]]; then
  echo "Bun failed, but not with the expected 403 registry block." >&2
  exit 1
fi

echo "left-pad was blocked as expected."
