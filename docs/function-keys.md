# Function row and Fn mode

Tested on:

```text
Kernel: 7.1.8-arch1-3
Omarchy: 4.0.0-1
Hyprland: 0.56.2
Keyboard USB ID: 0b05:1bf2
```

Problem: When docked over `eDP-2`, both `F1` and `Fn+F1` generate `KEY_F1`.
Through Bluetooth, `F1` generates `KEY_MUTE` and `Fn+F1` generates `KEY_F1`.
Before initialization, `Fn+Esc` did not toggle Fn Lock on either transport.

Cause: The docked keyboard exposes a vendor-control HID interface but the
current kernel does not initialize its Fn mode. When docked, `Fn+Esc` produces
the proprietary input report `5a 4e 00 00 00 00` on interface 4; userspace
must configure the keyboard in response. This remains open upstream.

Workaround: `ux8406ca-fn-mode` applies one of the keyboard's two native modes:

| Mode | Top row | With Fn held |
|---|---|---|
| `media` (default) | Media actions | F1-F12 |
| `function` | F1-F12 | Media actions |

```bash
ux8406ca-fn-mode media
ux8406ca-fn-mode function
ux8406ca-fn-mode toggle
ux8406ca-fn-mode status
```

The native helper matches only USB vendor/product `0b05:1bf2` and interface 4.
The udev rule grants the active desktop session access only to that interface;
the monitor and helper run unprivileged. A different USB or Bluetooth keyboard
cannot match this workaround.

The selected mode is reapplied after the pogo-pin USB device is attached.
While docked, the helper listens for the native `Fn+Esc` report and toggles the
saved mode. The Bluetooth transport already provides a working momentary Fn
layer, but native Fn Lock over Bluetooth remains under investigation.

How to revert:

```bash
./uninstall.sh --fn-mode
```

Upstream status: Not fixed. Track
[`asusctl` issue 25](https://github.com/OpenGamingCollective/asusctl/issues/25).
The feature reports were independently documented by
[`zenbook-duo-daemon`](https://github.com/PegasisForever/zenbook-duo-daemon),
which also recognizes the UX8406CA product ID. This repository uses only the
minimal Fn initialization, not that project's full privileged daemon.

## Fn+Esc validation

The report was confirmed directly on the vendor HID interface. To diagnose it
again, identify the `if04-hidraw` symlink and read that device while pressing
`Fn+Esc`. It should produce alternating `5a 4e ...` press and `5a 00 ...`
release reports.

```bash
udevadm info /dev/input/by-id/usb-Primax_Electronics_Ltd._ASUS_Zenbook_Duo_Keyboard-if04-hidraw
```

This event does not appear on `Asus WMI hotkeys` or as a normal evdev key.
Do not add a global keyboard remap: old `KEYBOARD_KEY_7003*` hwdb rules can
destroy the native distinction between the top row and the held-Fn layer.
