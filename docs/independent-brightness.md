# Independent display brightness

## Workaround record

```text
Tested on: ASUS Zenbook Duo UX8406CA
Kernel: 7.1.8-arch1-3
Omarchy: 4.0.0-1
Hyprland: 0.56.2

Problem: Omarchy's slider adjusted intel_backlight for either focused monitor.
Cause: The generic resolver sees several backlights but has no panel mapping.
Workaround: A local wrapper supplies a one-device candidate directory per monitor.
How to revert: Run ./uninstall.sh --brightness.
Upstream status: Kernel interfaces work; Omarchy has no UX8406CA mapping as tested.
```

The kernel already provides correct independent controls:

```bash
brightnessctl -d intel_backlight set 30%
brightnessctl -d card1-eDP-2-backlight set 30%
```

They control the upper and lower panel respectively. `asus_screenpad` is ignored
because its reported values are inconsistent.

## How the override works

The installer creates these candidate directories:

```text
~/.local/share/omarchy-backlights/eDP-1/intel_backlight
  -> /sys/class/backlight/intel_backlight
~/.local/share/omarchy-backlights/eDP-2/card1-eDP-2-backlight
  -> /sys/class/backlight/card1-eDP-2-backlight
```

The local `omarchy-brightness-display` wrapper maps the passed or focused
monitor to one directory through `OMARCHY_BACKLIGHT_PATH`, then delegates every
original argument to `/usr/share/omarchy/bin/omarchy-brightness-display`.
Omarchy's resolver natively honors that environment variable.

The managed Hyprland block puts `~/.local/bin` before
`/usr/share/omarchy/bin`. No packaged file is modified.

Install and verify:

```bash
./install.sh --brightness
hyprctl reload
hyprctl configerrors
omarchy-brightness-display --monitor eDP-1
omarchy-brightness-display --monitor eDP-2
```

The last two commands only read the current percentages. Adjusting brightness
is an explicit user action.
