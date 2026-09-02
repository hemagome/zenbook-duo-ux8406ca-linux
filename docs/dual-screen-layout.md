# Vertical dual-screen layout

## Workaround record

```text
Tested on: ASUS Zenbook Duo UX8406CA
Kernel: 7.1.9-arch1-2
Omarchy: 4.0.2-1
Hyprland: 0.56.2
Applicability: Hyprland; the reusable Lua file follows Omarchy's config structure.

Problem: Automatic placement arranged the internal panels horizontally.
Cause: Generic automatic monitor placement does not know the physical chassis layout.
Workaround: Set both panel modes, scale and logical positions explicitly.
How to revert: Run ./uninstall.sh --layout or restore ~/.config/hypr/monitors.lua.
Upstream status: Hardware support works; physical arrangement still needs local policy.
```

The incorrect automatic result was logically `eDP-1` at `0x0` and `eDP-2` at
`1440x0`. The lower panel is physically below the upper panel.

At scale 2, each 2880×1800 panel occupies 1440×900 logical pixels. Therefore
the correct lower-panel origin is Y=900:

```lua
hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@120",
    position = "0x0",
    scale = 2
})

hl.monitor({
    output = "eDP-2",
    mode = "2880x1800@120",
    position = "0x900",
    scale = 2
})
```

The global values must not force scale 3. The tested configuration uses
`GDK_SCALE=2`, a generic monitor fallback with scale `"auto"`, and the two
specific scale-2 rules. See [the reusable config](../configs/omarchy/monitors.lua).

Install it with `./install.sh --layout`, then check:

```bash
hyprctl reload
hyprctl configerrors
hyprctl monitors
```

Expected logical origins are `0x0` and `0x900`. Hyprland reports dimensions and
positions in logical pixels when scaling is active.
