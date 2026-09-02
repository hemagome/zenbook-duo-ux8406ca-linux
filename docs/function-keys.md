# Function row and Fn mode

Tested on:

```text
Kernel: 7.1.9-arch1-2
Omarchy: 4.0.2-1
Hyprland: 0.56.2
Keyboard USB ID: 0b05:1bf2
Keyboard Bluetooth HID ID: 0b05:1bf3
Applicability: Linux universal HID core; individual desktop actions vary below.
```

Problem: When docked over `eDP-2`, both `F1` and `Fn+F1` generate `KEY_F1`.
Through Bluetooth, `F1` generates `KEY_MUTE` and `Fn+F1` generates `KEY_F1`.
Before initialization, `Fn+Esc` did not toggle Fn Lock on either transport.

Cause: The keyboard exposes transport-specific vendor-control HID collections,
but the current kernel does not initialize its Fn mode. On USB and Bluetooth,
`Fn+Esc` produces the proprietary input report `5a 4e 00 00 00 00`; userspace
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

The native helper matches only USB `0b05:1bf2` interface 4 or Bluetooth
`0b05:1bf3` vendor collection `FF31:0076`. The udev rule grants the active
desktop session access only to those control collections and gives them the
`input` group with mode `0660`, so startup also works when the keyboard is
enumerated before the graphical session. The monitor and helper run
unprivileged. A different USB or Bluetooth keyboard cannot match this
workaround.

The selected mode is reapplied after either transport connects. The helper
listens for the native `Fn+Esc` report and toggles the saved mode on USB or
Bluetooth. The same listener handles the proprietary F4 backlight event; see
[Detachable-keyboard backlight](keyboard-backlight.md). It also delegates the
proprietary F5/F6 events to the tested
[independent-display brightness](independent-brightness.md) workaround.

## Omarchy actions: F9 and F11

Applicability: F9 uses Omarchy's PipeWire mute/OSD helper and F11 uses the
Omarchy shell. Only detection of their HID reports and F9 LED synchronization
are desktop-independent.

The remaining useful vendor reports are handled by the Omarchy backend:

| Report | Special key | Action |
|---|---|---|
| `0x7c` | F9 | Run `omarchy-audio-input-mute`, then synchronize the keyboard mic-mute LED |
| `0x7e` | F11 | Toggle the native `omarchy.emojis` overlay |

The physical key depends on Fn mode: use F9/F11 directly in `media`, or
Fn+F9/Fn+F11 in `function`. Standard F9/F11 remain available in the opposite
layer. The microphone action controls PipeWire's default input and shows
Omarchy OSD. Its LED state is restored after USB or Bluetooth reconnection.
Toggle-style reports use a 2 second debounce window because the keyboard can
emit multiple complete press/release cycles while a key is held. Display
brightness retains normal hardware repetition.

These two actions are desktop integrations, unlike the portable HID protocol.
A GNOME, KDE or generic Hyprland installation should replace the invoked
helpers rather than changing the device reports.

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

The report was confirmed directly on both vendor HID transports. To diagnose
USB again, identify the `if04-hidraw` symlink and read that device while
pressing `Fn+Esc`. Bluetooth uses a BlueZ UHID device instead of that symlink.
Both produce alternating `5a 4e ...` press and `5a 00 ...` release reports.

```bash
udevadm info /dev/input/by-id/usb-Primax_Electronics_Ltd._ASUS_Zenbook_Duo_Keyboard-if04-hidraw
```

This event does not appear on `Asus WMI hotkeys` or as a normal evdev key.
Do not add a global keyboard remap: old `KEYBOARD_KEY_7003*` hwdb rules can
destroy the native distinction between the top row and the held-Fn layer.
