#!/bin/bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ux8406ca-linux"
backup_dir="$state_dir/backups"
manifest_dir="$state_dir/manifest"
layout=0
brightness=0
keyboard_dock=0
fn_mode=0
privilege_helper="${UX8406CA_PRIVILEGE_HELPER:-sudo}"

as_root() {
  "$privilege_helper" "$@"
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [--layout] [--brightness] [--keyboard-dock] [--fn-mode] [--all] [--list]

  --layout      Install the tested vertical monitor layout
  --brightness  Install independent Omarchy brightness selection
  --keyboard-dock
                Toggle eDP-2 when the pogo-pin keyboard is docked or removed
  --fn-mode     Install native Fn Lock and keyboard-backlight controls
  --all         Install all workarounds
  --list        Show available workarounds
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --layout) layout=1 ;;
    --brightness) brightness=1 ;;
    --keyboard-dock) keyboard_dock=1 ;;
    --fn-mode) fn_mode=1 ;;
    --all) layout=1; brightness=1; keyboard_dock=1; fn_mode=1 ;;
    --list) usage; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if (( ! layout && ! brightness && ! keyboard_dock && ! fn_mode )); then
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

ensure_marked_autostart() {
  local component="$1" marker="$2" snippet="$3"
  local destination="$HOME/.config/hypr/autostart.lua"
  local backup="$backup_dir/autostart.lua"

  [[ -f "$destination" ]] || { printf 'Missing Hyprland autostart config: %s\n' "$destination" >&2; exit 1; }
  if rg -q "^-- BEGIN ux8406ca-linux ${marker}$" "$destination"; then
    printf 'Unchanged: %s autostart already exists in %s\n' "$component" "$destination"
    return
  fi
  if [[ ! -e "$backup" ]]; then
    printf 'Backup: %s -> %s\n' "$destination" "$backup"
    cp -a -- "$destination" "$backup"
  fi
  printf 'Append %s autostart: %s\n' "$component" "$destination"
  printf '\n' >>"$destination"
  sed -n "/^-- BEGIN ux8406ca-linux ${marker}$/,/^-- END ux8406ca-linux ${marker}$/p" \
    "$snippet" >>"$destination"
}

install_fn_udev_rule() {
  local source="$repo_dir/configs/udev/70-ux8406ca-fn-mode.rules"
  local destination="/etc/udev/rules.d/70-ux8406ca-fn-mode.rules"
  local backup="$backup_dir/70-ux8406ca-fn-mode.rules"
  local absent="$backup_dir/70-ux8406ca-fn-mode.rules.absent"
  local checksum="$manifest_dir/70-ux8406ca-fn-mode.rules.sha256"
  local changed=0

  if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
    printf 'Unchanged: %s\n' "$destination"
  else
    if [[ -e "$destination" && ! -e "$backup" && ! -e "$absent" && ! -e "$checksum" ]]; then
      printf 'Backup: %s -> %s\n' "$destination" "$backup"
      cat "$destination" >"$backup"
    elif [[ ! -e "$destination" ]]; then
      : >"$absent"
    fi
    printf 'Install fn-mode device permission rule: %s\n' "$destination"
    as_root install -Dm0644 "$source" "$destination"
    changed=1
  fi
  sha256sum "$source" | awk '{print $1}' >"$checksum"
  if (( changed )); then
    as_root udevadm control --reload
    as_root udevadm trigger --subsystem-match=hidraw --action=add
  fi
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

if (( fn_mode )); then
  command -v gcc >/dev/null || { printf 'Missing build dependency: gcc\n' >&2; exit 1; }
  pkg-config --exists hidapi-hidraw || { printf 'Missing build dependency: hidapi\n' >&2; exit 1; }
  mkdir -p "$state_dir/build"
  printf 'Build fn-mode HID helper\n'
  # shellcheck disable=SC2046
  gcc -std=c11 -O2 -Wall -Wextra -Werror $(pkg-config --cflags hidapi-hidraw) \
    "$repo_dir/src/ux8406ca-fn-send.c" $(pkg-config --libs hidapi-hidraw) \
    -o "$state_dir/build/ux8406ca-fn-send"
  install_managed_file fn-mode "$state_dir/build/ux8406ca-fn-send" \
    "$HOME/.local/libexec/ux8406ca-fn-send" ux8406ca-fn-send
  install_managed_file fn-mode "$repo_dir/scripts/ux8406ca-fn-mode" \
    "$HOME/.local/bin/ux8406ca-fn-mode" ux8406ca-fn-mode
  install_managed_file fn-mode "$repo_dir/scripts/ux8406ca-keyboard-backlight" \
    "$HOME/.local/bin/ux8406ca-keyboard-backlight" ux8406ca-keyboard-backlight
  chmod 0755 "$HOME/.local/libexec/ux8406ca-fn-send" \
    "$HOME/.local/bin/ux8406ca-fn-mode" "$HOME/.local/bin/ux8406ca-keyboard-backlight"
  install_fn_udev_rule
  ensure_marked_autostart fn-mode fn-mode "$repo_dir/configs/omarchy/fn-mode-autostart.lua"
  "$HOME/.local/bin/ux8406ca-fn-mode" apply
  "$HOME/.local/bin/ux8406ca-keyboard-backlight" apply
fi

printf 'Done. Apply and validate with: hyprctl reload && hyprctl configerrors\n'
