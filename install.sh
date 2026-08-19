#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ux8406ca-linux"
backup_dir="$state_dir/backups"
manifest_dir="$state_dir/manifest"
layout=0
brightness=0
keyboard_dock=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--layout] [--brightness] [--keyboard-dock] [--all] [--list]

  --layout      Install the tested vertical monitor layout
  --brightness  Install independent Omarchy brightness selection
  --keyboard-dock
                Toggle eDP-2 when the pogo-pin keyboard is docked or removed
  --all         Install all workarounds
  --list        Show available workarounds
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --layout) layout=1 ;;
    --brightness) brightness=1 ;;
    --keyboard-dock) keyboard_dock=1 ;;
    --all) layout=1; brightness=1; keyboard_dock=1 ;;
    --list) usage; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if (( ! layout && ! brightness && ! keyboard_dock )); then
  usage
  exit 2
fi

mkdir -p "$backup_dir" "$manifest_dir"

install_managed_file() {
  local component="$1" source="$2" destination="$3" key="$4"
  local backup="$backup_dir/$key" absent="$backup_dir/$key.absent"
  local checksum="$manifest_dir/$key.sha256"

  mkdir -p "$(dirname "$destination")" "$(dirname "$backup")" "$(dirname "$checksum")"

  if [[ ! -e "$checksum" && ! -e "$backup" && ! -e "$absent" ]]; then
    if [[ -e "$destination" ]]; then
      printf 'Backup: %s -> %s\n' "$destination" "$backup"
      cp -a -- "$destination" "$backup"
    else
      printf 'Record originally absent: %s\n' "$destination"
      : >"$absent"
    fi
  fi

  if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
    printf 'Unchanged: %s\n' "$destination"
  else
    if [[ -f "$checksum" && -f "$destination" ]]; then
      local expected current
      expected="$(<"$checksum")"
      current="$(sha256sum "$destination" | awk '{print $1}')"
      if [[ "$current" != "$expected" ]]; then
        printf 'Refusing to overwrite a user-modified file: %s\n' "$destination" >&2
        exit 1
      fi
    fi
    printf 'Install %s: %s\n' "$component" "$destination"
    cp -- "$source" "$destination"
  fi

  sha256sum "$destination" | awk '{print $1}' >"$checksum"
}

ensure_path_block() {
  local destination="$HOME/.config/hypr/hyprland.lua"
  local snippet="$repo_dir/configs/omarchy/path-precedence.lua"
  local backup="$backup_dir/hyprland.lua"

  [[ -f "$destination" ]] || { printf 'Missing Hyprland config: %s\n' "$destination" >&2; exit 1; }
  if rg -q '^-- BEGIN ux8406ca-linux PATH override$' "$destination"; then
    printf 'Unchanged: managed PATH block already exists in %s\n' "$destination"
    return
  fi
  if rg -q '^local user_bin = os.getenv\("HOME"\) \.\. "/\.local/bin"$' "$destination" &&
     rg -q '^local omarchy_bin = "/usr/share/omarchy/bin"$' "$destination"; then
    printf 'Unchanged: equivalent PATH override already exists in %s\n' "$destination"
    return
  fi
  if [[ ! -e "$backup" ]]; then
    printf 'Backup: %s -> %s\n' "$destination" "$backup"
    cp -a -- "$destination" "$backup"
  fi
  printf 'Append brightness PATH block: %s\n' "$destination"
  printf '\n' >>"$destination"
  sed -n '/^-- BEGIN ux8406ca-linux PATH override$/,/^-- END ux8406ca-linux PATH override$/p' "$snippet" >>"$destination"
}

ensure_keyboard_dock_autostart() {
  local destination="$HOME/.config/hypr/autostart.lua"
  local snippet="$repo_dir/configs/omarchy/keyboard-dock-autostart.lua"
  local backup="$backup_dir/autostart.lua"

  [[ -f "$destination" ]] || { printf 'Missing Hyprland autostart config: %s\n' "$destination" >&2; exit 1; }
  if rg -q '^-- BEGIN ux8406ca-linux keyboard-dock$' "$destination"; then
    printf 'Unchanged: keyboard-dock autostart already exists in %s\n' "$destination"
    return
  fi
  if [[ ! -e "$backup" ]]; then
    printf 'Backup: %s -> %s\n' "$destination" "$backup"
    cp -a -- "$destination" "$backup"
  fi
  printf 'Append keyboard-dock autostart: %s\n' "$destination"
  printf '\n' >>"$destination"
  sed -n '/^-- BEGIN ux8406ca-linux keyboard-dock$/,/^-- END ux8406ca-linux keyboard-dock$/p' \
    "$snippet" >>"$destination"
}

if (( layout )); then
  install_managed_file layout "$repo_dir/configs/omarchy/monitors.lua" \
    "$HOME/.config/hypr/monitors.lua" monitors.lua
fi

if (( brightness )); then
  install_managed_file brightness "$repo_dir/scripts/omarchy-brightness-display" \
    "$HOME/.local/bin/omarchy-brightness-display" omarchy-brightness-display
  chmod 0755 "$HOME/.local/bin/omarchy-brightness-display"

  printf 'Create per-monitor backlight mappings\n'
  mkdir -p "$HOME/.local/share/omarchy-backlights/eDP-1" \
    "$HOME/.local/share/omarchy-backlights/eDP-2"
  ln -sfn /sys/class/backlight/intel_backlight \
    "$HOME/.local/share/omarchy-backlights/eDP-1/intel_backlight"
  ln -sfn /sys/class/backlight/card1-eDP-2-backlight \
    "$HOME/.local/share/omarchy-backlights/eDP-2/card1-eDP-2-backlight"
  ensure_path_block
fi

if (( keyboard_dock )); then
  install_managed_file keyboard-dock "$repo_dir/scripts/ux8406ca-keyboard-dock" \
    "$HOME/.local/bin/ux8406ca-keyboard-dock" ux8406ca-keyboard-dock
  chmod 0755 "$HOME/.local/bin/ux8406ca-keyboard-dock"
  ensure_keyboard_dock_autostart
fi

printf 'Done. Apply and validate with: hyprctl reload && hyprctl configerrors\n'
