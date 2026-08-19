# Linux on the ASUS Zenbook Duo UX8406CA

Focused documentation and reversible workarounds for the **ASUS Zenbook Duo
UX8406CA**, with special attention to **Omarchy Quattro 4.x + Hyprland**.

This repository documents observed behavior on real hardware. It deliberately
does not collect old UX8406/UX8406MA kernel patches unless the same defect is
reproduced on the UX8406CA with a current kernel.

## Tested system

| Component | Tested version / hardware |
|---|---|
| Model | ASUS Zenbook Duo UX8406CA (`UX8406CA_UX8406CA`) |
| Linux | `7.1.8-arch1-3` |
| Omarchy | `4.0.0-1` |
| Hyprland | `0.56.2` |
| BlueZ | `5.87-2` |
| Boot | Limine `12.5.2`, UEFI, Secure Boot off, TPM 2 active |
| Storage | WD PC SN5000S 1 TB; Windows 11 + LUKS/Btrfs dual boot |
| Displays | 2× Samsung 2880×1800 at 120 Hz (`eDP-1`, `eDP-2`) |

Results apply to these versions. Re-test after kernel, Hyprland, Omarchy,
BlueZ or firmware updates.

## Compatibility

| Feature | Status | Notes |
|---|---|---|
| Intel Arc graphics / Wayland | ✅ Works upstream | i915 on the tested kernel |
| Both internal panels at 120 Hz | ✅ Works upstream | Both modes are exposed normally |
| Touch and stylus on both panels | ✅ Works upstream | Two touch and two stylus devices detected |
| Wi-Fi, Bluetooth, audio, microphone, webcam | ✅ Works upstream | No repository workaround required |
| LUKS, Btrfs, Limine, Windows dual boot | ✅ Works upstream | Installation-specific; keep backups |
| Vertical dual-screen layout | 🛠 Workaround required | Explicit Hyprland positions and scale |
| Independent brightness in Omarchy UI | 🛠 Workaround required | Per-monitor backlight wrapper |
| Detachable Bluetooth keyboard | ✅ Works upstream | Pair and trust with BlueZ |
| Disable lower panel when keyboard covers it | ❌ Not working | Detection mechanism still under investigation |
| Automatic touch mapping validation | ⚠️ Partial / needs validation | Input exists; mapping across layout changes needs testing |

Status legend: ✅ Works upstream · 🛠 Workaround required · ⚠️ Partial / needs
validation · ❌ Not working.

## Quick start

Inspect the scripts before running them. Installation does not require root and
never changes `/usr/share/omarchy`.

```bash
./install.sh --list
./install.sh --layout
./install.sh --brightness
# or both
./install.sh --all
```

The installer shows its operations, creates first-install backups under
`${XDG_STATE_HOME:-~/.local/state}/ux8406ca-linux/`, and refuses unexpected
conflicts. Remove selected changes with:

```bash
./uninstall.sh --brightness
./uninstall.sh --layout
```

Reload and validate Hyprland after installation:

```bash
hyprctl reload
hyprctl configerrors
```

## Documentation

- [Hardware and inspected system](docs/hardware.md)
- [Detailed compatibility](docs/compatibility.md)
- [Vertical dual-screen layout](docs/dual-screen-layout.md)
- [Independent brightness](docs/independent-brightness.md)
- [Bluetooth keyboard pairing](docs/bluetooth-keyboard.md)
- [Keyboard dock investigation](docs/keyboard-dock.md)
- [Troubleshooting and rollback](docs/troubleshooting.md)
- [Installer design](install/README.md)

## Project philosophy

> Prefer upstream fixes over workarounds.

Before retaining a workaround, reproduce the issue after updating the Linux
kernel, Hyprland, Omarchy, `asusctl` (if used) and BlueZ. Remove local code when
upstream behavior is correct. Every workaround must record:

```text
Tested on:
Kernel:
Omarchy:
Hyprland:

Problem:
Cause:
Workaround:
How to revert:
Upstream status:
```

Do not install historic model-specific repositories wholesale. A workaround
for an older UX8406 variant or Linux 6.x is evidence to investigate, not proof
that a current UX8406CA needs it.

## Safety

Review paths and backups before applying changes. No serial numbers, Bluetooth
addresses, credentials or personal configuration belong in issues or commits.
Use placeholders such as `XX:XX:XX:XX:XX:XX` and sanitize diagnostic output.
