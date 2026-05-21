#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Computer Police"
APP_BUNDLE_NAME="$APP_NAME.app"
CLI_NAME="computer-police"
HOME_DIR="${HOME:?HOME is required}"
STATE_DIR="$HOME_DIR/.computer-police"

app_dirs=(
  "${COMPUTER_POLICE_APP_DIR:-/Applications}"
  "$HOME_DIR/Applications"
)

cli_candidates=(
  "$STATE_DIR/bin/$CLI_NAME"
  "$HOME_DIR/.local/bin/$CLI_NAME"
)

if command -v "$CLI_NAME" >/dev/null 2>&1; then
  cli_path="$(command -v "$CLI_NAME")"
  case "$cli_path" in
    "$STATE_DIR"/bin/*|"$HOME_DIR"/.local/bin/*)
      cli_candidates+=("$cli_path")
      ;;
  esac
fi

for app_dir in "${app_dirs[@]}"; do
  app_path="$app_dir/$APP_BUNDLE_NAME"
  if [[ -x "$app_path/Contents/Resources/bin/$CLI_NAME" ]]; then
    cli_candidates+=("$app_path/Contents/Resources/bin/$CLI_NAME")
  fi
done

unique_existing_cli_candidates() {
  local seen=""
  local candidate
  for candidate in "${cli_candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    case ":$seen:" in
      *":$candidate:"*) continue ;;
    esac
    seen="$seen:$candidate"
    printf '%s\n' "$candidate"
  done
}

run_cli_cleanup() {
  local cli="$1"
  echo "Restoring package-manager config with $cli..."
  "$cli" uninstall --project >/dev/null 2>&1 || true
  "$cli" uninstall >/dev/null 2>&1 || true
  "$cli" proxy stop >/dev/null 2>&1 || true
}

remove_path_entry() {
  local config_file="$1"
  local command_line="$2"
  [[ -f "$config_file" && -w "$config_file" ]] || return 0

  local tmp_file
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/computer-police-path.XXXXXX")"
  awk -v cmd="$command_line" '
    $0 == "# Computer Police" { marker = $0; next }
    $0 == cmd {
      marker = ""
      next
    }
    marker != "" {
      print marker
      marker = ""
    }
    { print }
    END {
      if (marker != "") print marker
    }
  ' "$config_file" > "$tmp_file"
  cat "$tmp_file" > "$config_file"
  rm -f "$tmp_file"
}

remove_shell_path_config() {
  local install_dir="$STATE_DIR/bin"
  local xdg_config_home="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
  local command_line="export PATH=\"$install_dir:\$PATH\""
  local fish_command="fish_add_path $install_dir"
  local candidates=(
    "${ZDOTDIR:-$HOME_DIR}/.zshrc"
    "${ZDOTDIR:-$HOME_DIR}/.zshenv"
    "$HOME_DIR/.bashrc"
    "$HOME_DIR/.bash_profile"
    "$HOME_DIR/.profile"
    "$xdg_config_home/zsh/.zshrc"
    "$xdg_config_home/zsh/.zshenv"
    "$xdg_config_home/bash/.bashrc"
    "$xdg_config_home/bash/.bash_profile"
    "$HOME_DIR/.config/fish/config.fish"
  )

  local file
  for file in "${candidates[@]}"; do
    remove_path_entry "$file" "$command_line"
    remove_path_entry "$file" "$fish_command"
  done
}

echo "Quitting $APP_NAME..."
if command -v osascript >/dev/null 2>&1; then
  osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
fi
pkill -x ComputerPolice >/dev/null 2>&1 || true

while IFS= read -r cli; do
  run_cli_cleanup "$cli"
done < <(unique_existing_cli_candidates)

for app_dir in "${app_dirs[@]}"; do
  app_path="$app_dir/$APP_BUNDLE_NAME"
  if [[ -e "$app_path" ]]; then
    echo "Removing $app_path..."
    rm -rf "$app_path"
  fi
done

for cli in "$STATE_DIR/bin/$CLI_NAME" "$HOME_DIR/.local/bin/$CLI_NAME"; do
  if [[ -e "$cli" ]]; then
    echo "Removing $cli..."
    rm -f "$cli"
  fi
done

echo "Removing shell PATH entries..."
remove_shell_path_config

if command -v defaults >/dev/null 2>&1; then
  echo "Removing macOS app preferences..."
  defaults delete dev.computerpolice.app >/dev/null 2>&1 || true
fi

if [[ -e "$STATE_DIR" ]]; then
  echo "Removing $STATE_DIR..."
  rm -rf "$STATE_DIR"
fi

echo "Computer Police local cleanup complete."
