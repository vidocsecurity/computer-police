#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Computer Police"
CLI_NAME="computer-police"
REPO="${COMPUTER_POLICE_REPO:-vidocsecurity/computer-police}"
RELEASE_BASE_URL="${COMPUTER_POLICE_RELEASE_BASE_URL:-https://github.com/$REPO/releases/download}"
GITHUB_API_URL="${COMPUTER_POLICE_GITHUB_API_URL:-https://api.github.com/repos/$REPO/releases/latest}"
INSTALL_DIR="${COMPUTER_POLICE_INSTALL_DIR:-$HOME/.computer-police/bin}"
APP_DIR="${COMPUTER_POLICE_APP_DIR:-/Applications}"
NO_MODIFY_PATH=false
NO_LAUNCH=false
REQUESTED_VERSION="${VERSION:-}"
UNINSTALL=false

red=''
dim=''
reset=''
if [ -t 2 ]; then
  red="$(printf '\033[0;31m')"
  dim="$(printf '\033[0;2m')"
  reset="$(printf '\033[0m')"
fi

usage() {
  cat <<EOF
Computer Police Installer

Usage: install.sh [options]

Options:
  -h, --help                Display this help message
  -v, --version <version>   Install a specific version, for example v0.1.0
      --install-dir <path>  Install CLI into this directory
      --app-dir <path>      Install the macOS app into this directory
      --no-modify-path      Do not modify shell profile files
      --no-launch           Do not launch the macOS app after installation
      --uninstall           Remove the public install

Examples:
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/scripts/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/scripts/install.sh | bash -s -- --version v0.1.0
  ./scripts/install.sh --uninstall
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      if [ -z "${2:-}" ]; then
        echo "${red}Error: --version requires a value${reset}" >&2
        exit 1
      fi
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    --install-dir)
      if [ -z "${2:-}" ]; then
        echo "${red}Error: --install-dir requires a value${reset}" >&2
        exit 1
      fi
      INSTALL_DIR="$2"
      shift 2
      ;;
    --app-dir)
      if [ -z "${2:-}" ]; then
        echo "${red}Error: --app-dir requires a value${reset}" >&2
        exit 1
      fi
      APP_DIR="$2"
      shift 2
      ;;
    --no-modify-path)
      NO_MODIFY_PATH=true
      shift
      ;;
    --no-launch)
      NO_LAUNCH=true
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    *)
      echo "${red}Error: unknown option $1${reset}" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "${red}Error: '$1' is required but was not found.${reset}" >&2
    exit 1
  fi
}

detect_platform() {
  raw_os="$(uname -s)"
  raw_arch="$(uname -m)"

  case "$raw_os" in
    Darwin*) os="macos" ;;
    Linux*) os="linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *)
      echo "${red}Unsupported OS: $raw_os${reset}" >&2
      exit 1
      ;;
  esac

  case "$raw_arch" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
      echo "${red}Unsupported CPU architecture: $raw_arch${reset}" >&2
      exit 1
      ;;
  esac

  if [ "$os" = "macos" ] && [ "$arch" = "x86_64" ]; then
    rosetta="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
    if [ "$rosetta" = "1" ]; then
      arch="arm64"
    fi
  fi
}

resolve_version() {
  if [ -n "$REQUESTED_VERSION" ]; then
    case "$REQUESTED_VERSION" in
      v*) version="$REQUESTED_VERSION" ;;
      *) version="v$REQUESTED_VERSION" ;;
    esac
    return
  fi

  need_cmd curl
  version="$(curl -fsSL "$GITHUB_API_URL" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
  if [ -z "$version" ]; then
    echo "${red}Error: could not resolve the latest release version.${reset}" >&2
    exit 1
  fi
}

artifact_for_platform() {
  if [ "$os" = "macos" ]; then
    artifact="ComputerPolice-$version-macos-universal.zip"
    checksum_artifact="$artifact.sha256"
    archive_type="zip"
    return
  fi

  label="$os-$arch"
  case "$label" in
    linux-x86_64|linux-arm64)
      artifact="ComputerPoliceCLI-$version-$label.tar.gz"
      archive_type="tar.gz"
      ;;
    windows-x86_64|windows-arm64)
      artifact="ComputerPoliceCLI-$version-$label.zip"
      archive_type="zip"
      ;;
    *)
      echo "${red}Unsupported OS/Arch: $os/$arch${reset}" >&2
      exit 1
      ;;
  esac
  checksum_artifact="ComputerPoliceCLI-$version-checksums.txt"
}

download() {
  url="$1"
  output="$2"
  need_cmd curl
  curl -fL --retry 3 --retry-delay 1 -o "$output" "$url"
}

sha256_file() {
  file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$file" | awk '{print $1}'
  else
    echo "${red}Error: sha256sum, shasum, or openssl is required for checksum verification.${reset}" >&2
    exit 1
  fi
}

verify_checksum() {
  archive_path="$1"
  checksum_path="$2"

  expected="$(awk -v target="$artifact" '$0 ~ target {print $1; exit}' "$checksum_path")"
  if [ -z "$expected" ]; then
    expected="$(awk 'NF {print $1; exit}' "$checksum_path")"
  fi
  actual="$(sha256_file "$archive_path")"

  if [ "$actual" != "$expected" ]; then
    echo "${red}Error: checksum mismatch for $artifact${reset}" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

shell_config_files() {
  xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  current_shell="$(basename "${SHELL:-sh}")"
  case "$current_shell" in
    fish) echo "$HOME/.config/fish/config.fish" ;;
    zsh) echo "${ZDOTDIR:-$HOME}/.zshrc ${ZDOTDIR:-$HOME}/.zshenv $xdg_config_home/zsh/.zshrc $xdg_config_home/zsh/.zshenv" ;;
    bash) echo "$HOME/.bashrc $HOME/.bash_profile $HOME/.profile $xdg_config_home/bash/.bashrc $xdg_config_home/bash/.bash_profile" ;;
    *) echo "$HOME/.bashrc $HOME/.bash_profile $HOME/.profile" ;;
  esac
}

path_command_for_shell() {
  current_shell="$(basename "${SHELL:-sh}")"
  case "$current_shell" in
    fish) echo "fish_add_path $INSTALL_DIR" ;;
    *) echo "export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
  esac
}

add_to_path() {
  if [ "$NO_MODIFY_PATH" = true ]; then
    return
  fi
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return ;;
  esac

  command_line="$(path_command_for_shell)"
  config_file=""
  for candidate in $(shell_config_files); do
    if [ -f "$candidate" ]; then
      config_file="$candidate"
      break
    fi
  done

  if [ -z "$config_file" ]; then
    echo "Add Computer Police to your PATH:"
    echo "  $command_line"
    return
  fi
  if grep -Fxq "$command_line" "$config_file"; then
    return
  fi
  if [ ! -w "$config_file" ]; then
    echo "Add Computer Police to your PATH:"
    echo "  $command_line"
    return
  fi

  {
    echo ""
    echo "# Computer Police"
    echo "$command_line"
  } >> "$config_file"
  echo "Added $INSTALL_DIR to PATH in $config_file"
}

remove_from_path() {
  command_line="$(path_command_for_shell)"
  for candidate in $(shell_config_files); do
    if [ -f "$candidate" ] && [ -w "$candidate" ]; then
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
      ' "$candidate" > "$tmp_file"
      cat "$tmp_file" > "$candidate"
      rm -f "$tmp_file"
    fi
  done
}

install_cli_from_dir() {
  source_dir="$1"
  ext=""
  if [ "$os" = "windows" ]; then
    ext=".exe"
  fi
  source_bin="$source_dir/$CLI_NAME$ext"
  if [ ! -f "$source_bin" ]; then
    echo "${red}Error: archive did not contain $CLI_NAME$ext${reset}" >&2
    exit 1
  fi
  mkdir -p "$INSTALL_DIR"
  target_bin="$INSTALL_DIR/$CLI_NAME$ext"
  tmp_bin="$target_bin.tmp.$$"
  cp "$source_bin" "$tmp_bin"
  chmod 0755 "$tmp_bin"
  mv -f "$tmp_bin" "$target_bin"
}

install_macos_app() {
  extract_dir="$1"
  app_source="$extract_dir/$APP_NAME.app"
  if [ ! -d "$app_source" ]; then
    echo "${red}Error: archive did not contain $APP_NAME.app${reset}" >&2
    exit 1
  fi

  target_app_dir="$APP_DIR"
  if ! mkdir -p "$target_app_dir" 2>/dev/null || [ ! -w "$target_app_dir" ]; then
    target_app_dir="$HOME/Applications"
    mkdir -p "$target_app_dir"
    echo "Installing the app to $target_app_dir because $APP_DIR is not writable."
  fi

  rm -rf "$target_app_dir/$APP_NAME.app"
  cp -R "$app_source" "$target_app_dir/$APP_NAME.app"
  install_cli_from_dir "$target_app_dir/$APP_NAME.app/Contents/Resources/bin"
  echo "Installed $APP_NAME.app to $target_app_dir"
  installed_app_path="$target_app_dir/$APP_NAME.app"
}

launch_macos_app() {
  if [ "$NO_LAUNCH" = true ]; then
    return
  fi
  if [ -z "${installed_app_path:-}" ] || [ ! -d "$installed_app_path" ]; then
    return
  fi
  if ! command -v open >/dev/null 2>&1; then
    echo "Open $installed_app_path to start Computer Police."
    return
  fi
  if open "$installed_app_path"; then
    echo "Started $APP_NAME. Look for the shield in the macOS menu bar."
  else
    echo "Installed $APP_NAME, but macOS did not launch it automatically."
    echo "Open $installed_app_path to start protection."
  fi
}

install_release() {
  detect_platform
  resolve_version
  artifact_for_platform

  if [ "$archive_type" = "tar.gz" ]; then
    need_cmd tar
  else
    need_cmd unzip
  fi

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/computer-police-install.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  archive_path="$tmp_dir/$artifact"
  checksum_path="$tmp_dir/$checksum_artifact"
  artifact_url="$RELEASE_BASE_URL/$version/$artifact"
  checksum_url="$RELEASE_BASE_URL/$version/$checksum_artifact"

  echo "Installing $APP_NAME $version for $os/$arch..."
  download "$artifact_url" "$archive_path"
  download "$checksum_url" "$checksum_path"
  verify_checksum "$archive_path" "$checksum_path"

  extract_dir="$tmp_dir/extract"
  mkdir -p "$extract_dir"
  if [ "$archive_type" = "tar.gz" ]; then
    tar -xzf "$archive_path" -C "$extract_dir"
  else
    unzip -q "$archive_path" -d "$extract_dir"
  fi

  if [ "$os" = "macos" ]; then
    install_macos_app "$extract_dir"
    launch_macos_app
  else
    install_cli_from_dir "$extract_dir"
  fi

  add_to_path

  echo ""
  echo "Computer Police installed."
  echo "Run: $CLI_NAME doctor"
}

uninstall_release() {
  detect_platform
  ext=""
  if [ "$os" = "windows" ]; then
    ext=".exe"
  fi
  target="$INSTALL_DIR/$CLI_NAME$ext"

  if [ -x "$target" ]; then
    "$target" proxy disable >/dev/null 2>&1 || true
    "$target" proxy stop >/dev/null 2>&1 || true
  fi

  rm -f "$target"
  rmdir "$INSTALL_DIR" 2>/dev/null || true

  if [ "$os" = "macos" ]; then
    rm -rf "$APP_DIR/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"
  fi

  if [ "$NO_MODIFY_PATH" != true ]; then
    remove_from_path
  fi

  echo "Computer Police has been uninstalled."
  echo "Local ledger and configuration data in ~/.computer-police were left in place."
}

if [ "$UNINSTALL" = true ]; then
  uninstall_release
else
  install_release
fi
