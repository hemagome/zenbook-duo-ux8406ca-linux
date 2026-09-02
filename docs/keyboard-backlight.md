# Detachable-keyboard backlight

Tested on:

```text
Kernel: 7.1.9-arch1-2
Omarchy: 4.0.2-1
Hyprland: 0.56.2
USB HID: 0b05:1bf2, interface 4
Bluetooth HID: 0b05:1bf3, vendor collection FF31:0076
Applicability: Linux universal HID control; Omarchy only provides the current OSD.
```

Problem: The keyboard has four backlight levels, but it does not expose a
`*kbd_backlight*` LED under `/sys/class/leds`. Omarchy's stock
`omarchy-brightness-keyboard` therefore exits with `No keyboard backlight
device found`.

The physical shortcut depends on the selected Fn mode:

| Fn mode | Normal F4 | Backlight shortcut |
|---|---|---|
| `media` | Backlight cycle | `F4` |
| `function` | `KEY_F4` | `Fn+F4` |

Cause: The shortcut arrives outside normal evdev input as vendor report
`5a c7 ...`. Brightness is also configured through a vendor report rather
than the Linux LED class.

Workaround: The existing UX8406CA HID listener detects the F4 report, cycles
levels `0 → 1 → 2 → 3 → 0`, saves the result, shows Omarchy OSD feedback and
restores the level after USB or Bluetooth reconnection.

Manual control is available without remapping other keyboards:

```bash
ux8406ca-keyboard-backlight cycle
ux8406ca-keyboard-backlight 0
ux8406ca-keyboard-backlight 1
ux8406ca-keyboard-backlight 2
ux8406ca-keyboard-backlight 3
ux8406ca-keyboard-backlight status
```

The saved level lives at
`${XDG_CONFIG_HOME:-$HOME/.config}/ux8406ca-linux/keyboard-backlight`. The
device command is USB report `5a ba c5 c4 <level> ...`; over Bluetooth, hidapi
translates the same HID report to the GATT payload `ba c5 c4 <level>`.

How to revert:

```bash
./uninstall.sh --fn-mode
```

Upstream status: No LED-class interface exists on the tested kernel. The
Bluetooth payload was independently documented by
[`mytikfy/asus-zenbookduo`](https://github.com/mytikfy/asus-zenbookduo), and
[`zenbook-duo-daemon`](https://github.com/PegasisForever/zenbook-duo-daemon)
documents the USB reports and physical F4 event. This repository dynamically
selects the keyboard HID collection and does not hardcode Bluetooth addresses
or GATT object paths.
