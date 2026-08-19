# Installer design

`install.sh` and `uninstall.sh` are intentionally small Bash programs. They do
not install packages. Only `fn-mode` uses `sudo`, to manage its udev rule.

Available components:

| Component | User files managed |
|---|---|
| `layout` | `~/.config/hypr/monitors.lua` |
| `brightness` | `~/.local/bin/omarchy-brightness-display`, two symlink directories, one marked block in `~/.config/hypr/hyprland.lua` |
| `keyboard-dock` | `~/.local/bin/ux8406ca-keyboard-dock`, one marked block in `~/.config/hypr/autostart.lua` |
| `fn-mode` | User CLI and compiled HID helper, one marked autostart block, and `/etc/udev/rules.d/70-ux8406ca-fn-mode.rules` |

## Guarantees

- The same install can be run repeatedly.
- Planned actions are printed.
- An existing file is saved on the first install.
- A changed destination is never silently replaced or removed.
- Packaged files under `/usr/share/omarchy` are read/delegated to, never edited.
- Components can be installed and removed separately.

State lives in `${XDG_STATE_HOME:-$HOME/.local/state}/ux8406ca-linux`. The
installer records the checksum of its installed copy. Uninstall restores an
original only when the destination still matches that recorded copy; otherwise
it stops and asks for manual conflict resolution.

Read the scripts before use. They affect active user configuration, so this
repository's own validation does not execute installation automatically.
