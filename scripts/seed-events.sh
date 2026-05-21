#!/usr/bin/env bash
set -euo pipefail

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to seed events." >&2
  exit 1
fi

workdir="$(mktemp -d "${TMPDIR:-/tmp}/computer-police-seed.XXXXXX")"
echo "Seeding install events in $workdir"
(
  cd "$workdir"
  npm init -y >/dev/null
  npm install --ignore-scripts left-pad ua-parser-js@0.7.29 lodash
)

echo
echo "Seed complete. The app should update on its next refresh tick."
echo "Keeping $workdir around so you can inspect package-lock.json if useful."
