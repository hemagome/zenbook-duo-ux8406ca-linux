# Troubleshooting

## Hyprland reports configuration errors

```bash
hyprctl reload
hyprctl configerrors
```

If errors began after installation, uninstall the relevant component. The
first pre-install version of a replaced file is kept under
`${XDG_STATE_HOME:-~/.local/state}/ux8406ca-linux/backups/`.

## Displays are side by side

Confirm that `~/.config/hypr/monitors.lua` contains the two explicit rules and
that `hyprctl monitors` reports `eDP-1` at `0x0`, `eDP-2` at `0x900`, scale 2.
Check that another later-loaded monitor rule does not override them.

## Wrong panel changes brightness

Check command resolution and the candidate links:

```bash
type -a omarchy-brightness-display
find ~/.local/share/omarchy-backlights -maxdepth 2 -type l -ls
```

`~/.local/bin/omarchy-brightness-display` must resolve before the packaged
command. Also verify that both real devices still exist under
`/sys/class/backlight`; kernel naming can change.

Do not use `asus_screenpad` merely because it exists. Validate values and
physical effect before mapping any backlight.

## Roll back

```bash
./uninstall.sh --all
hyprctl reload
hyprctl configerrors
```

Uninstall removes the managed PATH block and local symlink directories. For
files the installer replaced, it restores the first-install backup. It refuses
to overwrite a subsequently modified destination; resolve that conflict
manually so newer user work is not lost.
