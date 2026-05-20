#!/usr/bin/env bash
set -euo pipefail

pid_file="${PACKAGE_POLICE_HOME:-$HOME/.package-police}/registry-proxy/proxy.pid"
if [[ ! -f "$pid_file" ]]; then
  echo "No proxy pid file at $pid_file" >&2
  exit 1
fi

pid="$(sed -n '1p' "$pid_file")"
if [[ -z "$pid" ]]; then
  echo "Proxy pid file is empty: $pid_file" >&2
  exit 1
fi

echo "Killing proxy pid $pid to test watchdog recovery..."
kill "$pid"
