#!/bin/bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ux8406ca-linux"
backup_dir="$state_dir/backups"
manifest_dir="$state_dir/manifest"
layout=0
brightness=0

usage() {
  printf 'Usage: ./uninstall.sh [--layout] [--brightness] [--all]\n'
}

while (( $# > 0 )); do
  case "$1" in
    --layout) layout=1 ;;
    --brightness) brightness=1 ;;
    --all) layout=1; brightness=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if (( ! layout && ! brightness )); then usage; exit 2; fi

restore_managed_file() {
  local destination="$1" key="$2"
  local backup="$backup_dir/$key" checksum="$manifest_dir/$key.sha256"

  [[ -f "$checksum" ]] || { printf 'Not installed: %s\n' "$destination"; return; }
  if [[ -f "$destination" ]]; then
    local expected current
    expected="$(<"$checksum")"
    current="$(sha256sum "$destination" | awk '{print $1}')"
    if [[ "$current" != "$expected" ]]; then
      printf 'Refusing to replace a user-modified file: %s\n' "$destination" >&2
      exit 1
    fi
  fi

  if [[ -e "$backup" ]]; then
    printf 'Restore: %s\n' "$destination"
    cp -a -- "$backup" "$destination"
  else
    printf 'Remove: %s\n' "$destination"
    rm -f -- "$destination"
  fi
  rm -f -- "$checksum"
}

remove_path_block() {
  local destination="$HOME/.config/hypr/hyprland.lua"
  local temp block expected
  [[ -f "$destination" ]] || return
  if ! rg -q '^-- BEGIN ux8406ca-linux PATH override$' "$destination"; then return; fi
  temp="$(mktemp "${TMPDIR:-/tmp}/ux8406ca-hyprland.XXXXXX")"
  block="$(mktemp "${TMPDIR:-/tmp}/ux8406ca-block.XXXXXX")"
  expected="$(mktemp "${TMPDIR:-/tmp}/ux8406ca-expected.XXXXXX")"
  sed -n '/^-- BEGIN ux8406ca-linux PATH override$/,/^-- END ux8406ca-linux PATH override$/p' \
    "$destination" >"$block"
  sed -n '/^-- BEGIN ux8406ca-linux PATH override$/,/^-- END ux8406ca-linux PATH override$/p' \
    "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/configs/omarchy/path-precedence.lua" >"$expected"
  if ! cmp -s "$block" "$expected"; then
    printf 'Refusing to remove a modified managed PATH block: %s\n' "$destination" >&2
    exit 1
  fi
  awk '
    /^-- BEGIN ux8406ca-linux PATH override$/ { skip=1; next }
    /^-- END ux8406ca-linux PATH override$/ { skip=0; next }
    !skip { print }
  ' "$destination" >"$temp"
  printf 'Remove managed PATH block: %s\n' "$destination"
  cp -- "$temp" "$destination"
  rm -f -- "$temp" "$block" "$expected"
}

if (( brightness )); then
  restore_managed_file "$HOME/.local/bin/omarchy-brightness-display" omarchy-brightness-display
  remove_path_block
  printf 'Remove per-monitor backlight mappings\n'
  rm -f -- "$HOME/.local/share/omarchy-backlights/eDP-1/intel_backlight"
  rm -f -- "$HOME/.local/share/omarchy-backlights/eDP-2/card1-eDP-2-backlight"
  rmdir --ignore-fail-on-non-empty "$HOME/.local/share/omarchy-backlights/eDP-1" \
    "$HOME/.local/share/omarchy-backlights/eDP-2" \
    "$HOME/.local/share/omarchy-backlights" 2>/dev/null || true
fi

if (( layout )); then
  restore_managed_file "$HOME/.config/hypr/monitors.lua" monitors.lua
fi

printf 'Done. Apply and validate with: hyprctl reload && hyprctl configerrors\n'
