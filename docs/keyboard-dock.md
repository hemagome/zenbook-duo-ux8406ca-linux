# Keyboard-over-lower-display detection

Status: **open; no workaround is installed**.

## Reproduced behavior

With the keyboard physically covering the lower panel, Hyprland still reports
`eDP-2` as enabled with DPMS on, and the lower-panel
`actual_brightness` remains unchanged. Hyprland continues rendering underneath
the keyboard.

Desired state transition:

```text
keyboard placed   -> disable eDP-2 -> eDP-1 only
keyboard removed  -> enable eDP-2  -> 2880x1800@120, scale 2, position 0x900
```

## What static inspection found

- The keyboard is a Bluetooth HID device and exposes keyboard, mouse and
  touchpad interfaces.
- Hyprland exposes a normal lid switch.
- No explicit dock or tablet-mode switch was visible during the static
  inspection.
- There was no existing UX8406CA udev rule or user service handling this state.

This does **not** prove that no event exists. A vendor HID report, ACPI/WMI
event, input switch or device property may change only while placing/removing
the keyboard.

## Next diagnostic task

Capture a short, sanitized event window while physically placing and removing
the keyboard. Candidate sources, checked in this order:

1. `libinput debug-events` for an input switch (if already available).
2. `udevadm monitor --kernel --udev --property` for device/property changes.
3. `journalctl -f` filtered to Bluetooth, HID, ASUS WMI and ACPI messages.
4. Raw input/HID inspection only if the higher-level sources show nothing.

Do not commit raw captures: Bluetooth addresses and unique device paths must be
redacted. Installing `evtest`, `usbutils` or another diagnostic package requires
explicit approval.

## Intended architecture, if a stable event is found

A small event-driven `systemd --user` service should translate only the proven
signal into Hyprland monitor commands. It should debounce duplicate events,
restore the exact tested layout, log concise state transitions, and provide a
complete uninstall path. It must not poll aggressively, require a custom
kernel, or modify `/usr/share/omarchy`.

No service template is included yet because choosing a trigger before observing
one would encode an unsupported assumption.
