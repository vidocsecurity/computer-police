#!/usr/bin/env bash
set -euo pipefail

echo "Resetting npm registry to the public registry to simulate drift..."
if command -v npm >/dev/null 2>&1; then
  npm config set registry https://registry.npmjs.org/
else
  echo "npm not found; skipping npm registry drift."
fi

if command -v bun >/dev/null 2>&1; then
  bunfig="$HOME/.bunfig.toml"
  if [[ -f "$bunfig" ]]; then
    cp "$bunfig" "$bunfig.package-police-drift-backup"
  fi
  {
    echo "[install]"
    echo 'registry = "https://registry.npmjs.org"'
  } > "$bunfig"
else
  echo "bun not found; skipping bun registry drift."
fi

echo "Registry drift simulated. Computer Police should turn yellow and offer Repair."
