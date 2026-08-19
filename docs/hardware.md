# Hardware and inspected system

The following was observed directly on an ASUS Zenbook Duo UX8406CA on
2026-08-18. Identifiers that are unique to one machine are intentionally
omitted.

| Area | Observed state |
|---|---|
| DMI product | `ASUS Zenbook Duo UX8406CA_UX8406CA` |
| CPU/GPU platform | Intel Arrow Lake-P; integrated Intel Arc, `i915` driver |
| Internal panels | Two Samsung panels, each 2880×1800, 60/120 Hz modes |
| Touch/stylus | ELAN devices for each panel |
| Keyboard | `ASUS Zenbook Duo Keyboard`, Bluetooth HID |
| Wi-Fi | Intel Arrow Lake CNVi, `iwlwifi` |
| Audio | Intel HD Audio speaker and digital microphone through PipeWire |
| Camera | USB2.0 FHD UVC webcam |
| SSD | WD PC SN5000S 1 TB class |
| Linux storage | LUKS container with Btrfs |
| Boot | Limine on UEFI; Windows Boot Manager also present |

## Relevant software

```text
Linux       7.1.8-arch1-3
Omarchy     4.0.0-1
Hyprland    0.56.2
BlueZ       5.87-2
brightnessctl 0.5.1
```

`asusctl` was not installed and is not required by the documented workarounds.

## Backlight interfaces

| Panel | Kernel backlight | Tested range |
|---|---|---|
| `eDP-1` (upper) | `intel_backlight` | 0–400 |
| `eDP-2` (lower) | `card1-eDP-2-backlight` | 0–400 |

The additional `asus_screenpad` interface is not usable on the tested system:
its requested `brightness` was observed above 130,000 while
`max_brightness` was 255. Its presence must not be interpreted as the lower
panel's valid brightness device.

## Safe re-inspection

These commands avoid serial-number fields where practical:

```bash
uname -r
cat /sys/class/dmi/id/product_name
hyprctl version
hyprctl monitors
hyprctl devices
lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS
brightnessctl --list
```

Review output before publishing it. `bootctl status`, Bluetooth tools, PCI/USB
details and input-device metadata may contain machine-specific identifiers.
