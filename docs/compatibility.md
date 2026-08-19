# Compatibility notes

This is a current-state inventory, not a promise for every firmware or future
software version.

## Works without repository workarounds

- Both OLED panels, including 2880×1800 at 120 Hz
- Intel Arc integrated graphics, Wayland and Hyprland
- Wi-Fi and Bluetooth
- Speakers, microphone and webcam
- Touch and stylus input on both panels
- Two real, independently controllable backlights
- LUKS, Btrfs, UEFI/Limine and Windows 11 dual boot
- Bluetooth keyboard pairing and normal keyboard/touchpad input

These are treated as upstream-working. Do not add a patch unless a concrete
regression is reproduced and documented with affected versions.

## Requires a local workaround

1. Hyprland's automatic arrangement placed the internal panels side by side.
   [Explicit vertical layout](dual-screen-layout.md) fixes their geometry.
2. Omarchy selected the first likely internal backlight even when its UI passed
   the focused monitor. The [brightness wrapper](independent-brightness.md)
   provides a per-monitor candidate directory.
3. The detachable keyboard's Fn Lock and backlight use vendor HID reports that
   are not exposed as standard Linux controls. The [Fn-mode](function-keys.md)
   and [keyboard-backlight](keyboard-backlight.md) helper handles both USB and
   Bluetooth without a global key remapper.

## Requires an event-driven workaround

- Covering `eDP-2` with the detachable keyboard does not trigger display policy
  upstream. The [keyboard dock workaround](keyboard-dock.md) uses the observed
  pogo-pin USB transition without polling or privileged services.

## Open validation

- Confirm touch/stylus coordinate mapping after dynamically disabling and
  restoring the lower display.

## Regression checklist

After a major update, capture versions, remove or bypass one workaround at a
time, and test the original failure. Prefer deleting a workaround over adapting
it when upstream now handles the case. Pay particular attention to changes in:

- Linux DRM/backlight and ASUS WMI drivers
- Hyprland monitor configuration and input mapping
- Omarchy's display/backlight resolver
- BlueZ keyboard connection behavior
- ASUS firmware
