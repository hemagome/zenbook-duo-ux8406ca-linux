# Keyboard-over-lower-display detection

## Workaround record

```text
Tested on: ASUS Zenbook Duo UX8406CA
Kernel: 7.1.8-arch1-3
Omarchy: 4.0.0-1
Hyprland: 0.56.2
Applicability: Hyprland policy; USB dock detection is Linux universal.

Problem: eDP-2 remains enabled and lit when the keyboard covers it.
Cause: The kernel exposes the dock transition but does not apply display policy.
Workaround: Follow the pogo-pin USB device and update the Hyprland monitor rule.
How to revert: Run ./uninstall.sh --keyboard-dock.
Upstream status: Secondary-display policy remains unresolved upstream as tested.
```

## Observed dock signal

The keyboard changes transport depending on its physical position:

| State | Bus | USB vendor:product |
|---|---|---|
| Detached | Bluetooth HID | `0b05:1bf3` |
| Docked over `eDP-2` | Pogo-pin USB HID | `0b05:1bf2` |

The transition was captured directly with `udevadm monitor`. Removing the
keyboard removes the USB device and reconnects its Bluetooth HID interfaces;
docking it removes the Bluetooth interfaces and adds the USB device.

With the workaround applied and the keyboard docked, the tested kernel reports
the DRM connector as `enabled=disabled`, DPMS as `Off`, and the lower-panel
`actual_brightness` as `0`. The panel is genuinely off, not merely hidden from
the logical layout.

The product ID matters: the older UX8406MA commonly uses `0b05:1b2c`, while
the tested UX8406CA uses `0b05:1bf2`. Do not copy the older value blindly.

## Design

[`ux8406ca-keyboard-dock`](../scripts/ux8406ca-keyboard-dock) performs an
initial sysfs check, then sleeps inside `udevadm monitor` until a physical USB
device is added or removed. It does not poll.

After a 400 ms enumeration debounce it rescans the USB devices and applies one
of these dynamic Hyprland rules:

```text
docked   -> eDP-2,disable
detached -> eDP-2,2880x1800@120,0x900,2
```

The script keeps an internal state to ignore duplicate events and uses a
runtime lock to prevent multiple instances. Omarchy starts it as part of the
Hyprland session, so it inherits the compositor environment and exits with the
session. It requires no root privileges, udev rules or system service.

## Install and inspect

```bash
./install.sh --keyboard-dock
~/.local/bin/ux8406ca-keyboard-dock --status
```

The autostart applies on the next Hyprland session start. To test immediately:

```bash
uwsm-app -- ~/.local/bin/ux8406ca-keyboard-dock
```

Check runtime messages in the user journal and confirm the resulting state:

```bash
journalctl --user -b | grep ux8406ca-keyboard-dock
hyprctl monitors all
```

If the display configuration is reloaded manually while the keyboard remains
docked, restart the monitor or run it once to reassert physical state:

```bash
~/.local/bin/ux8406ca-keyboard-dock --once
```

## Internet implementations reviewed

The event strategy matches existing Zenbook Duo tools, but this implementation
is deliberately limited to the observed UX8406CA/Hyprland problem:

- `laithm/zenbook-duo-hyprland` uses the same USB-event approach for Hyprland,
  but defaults to the UX8406MA product ID `1b2c`.
- `PegasisForever/zenbook-duo-daemon` recognizes `1bf2` for UX8406CA, but also
  manages HID keys, keyboard LEDs and brightness and uses a privileged system
  daemon with periodic checks.
- Broader GNOME/KDE daemons install system services, dependencies and policies
  that are unnecessary for Omarchy's already-working features.

Prefer this small workaround only while upstream does not implement the panel
policy. Re-test it after kernel, ASUS WMI, Hyprland or Omarchy updates.
