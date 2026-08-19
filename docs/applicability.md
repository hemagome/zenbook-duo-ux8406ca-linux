# Workaround applicability

This page identifies the software layer required by each implementation in
this repository. The underlying UX8406CA hardware behavior may exist on every
distribution even when the supplied integration targets Hyprland or Omarchy.

| Workaround | Supplied implementation | Portable part | What changes elsewhere |
|---|---|---|---|
| Vertical dual-screen layout | **Hyprland**; the packaged file also follows Omarchy's Lua config structure | The 2880×1800 modes, scale-2 geometry and vertical relationship apply generally | GNOME/KDE must express the same layout through their own display configuration; plain Hyprland can translate the rules to its native syntax |
| Independent panel brightness | **Omarchy + Hyprland** for focused-monitor selection and OSD | The two kernel backlight devices and `brightnessctl -d …` commands are **Linux universal** for this hardware | Another desktop needs its own UI/key binding to select the appropriate sysfs backlight |
| Keyboard-over-display detection | **Hyprland**; Omarchy only supplies session autostart in the installed configuration | USB `0b05:1bf2` add/remove detection through udev is **Linux universal** | GNOME/KDE need a backend that disables/restores the display through their compositor/display API |
| Fn mode and Fn Lock | **Linux universal userspace mechanism** for this keyboard; packaging assumes systemd, udev and hidraw | USB/Bluetooth HID discovery, native mode reports and `Fn+Esc` listener are independent of Arch, Hyprland and Omarchy | Non-systemd distributions need different service startup and permissions; the core HID logic remains usable |
| Keyboard backlight / F4 | **Linux universal control**, with **Omarchy-only OSD feedback** | HID reports, four levels and saved state do not depend on the desktop | Replace or omit the OSD helper outside Omarchy |
| Display brightness / F5–F6 | **Omarchy + Hyprland** backend | Detecting the keyboard's `0x10`/`0x20` HID reports is **Linux universal** | Replace `omarchy-brightness-display` and focused Hyprland monitor lookup with the target desktop's brightness policy |
| Microphone mute / F9 | **Omarchy** action on top of **PipeWire** | Detecting `0x7c`, querying PipeWire and controlling the keyboard LED are desktop-independent | Replace the Omarchy mute/OSD helper; distributions without PipeWire also need another audio backend |
| Emoji picker / F11 | **Omarchy** | Detecting the `0x7e` HID report is **Linux universal** | Replace the `omarchy.emojis` action with the desired GNOME, KDE or other launcher |
| Bluetooth pairing | **Linux/BlueZ universal**; no repository workaround | Standard BlueZ pairing and trust | Only the distribution's Bluetooth UI/service management may differ |

## Layer labels

- **Linux universal**: no Arch-specific package behavior or desktop compositor
  is required, although this repository currently installs user services with
  systemd and permissions with udev.
- **Arch Linux**: no current workaround contains Arch-only functional logic.
  Arch affects package names and installation conventions, not the device
  protocol.
- **Hyprland**: the implementation calls Hyprland or uses its monitor/workspace
  model. It is usable outside Omarchy with configuration-format adjustments.
- **Omarchy**: the implementation calls an Omarchy helper, OSD or shell action.
  That integration must be replaced on plain Hyprland, GNOME or KDE.

Treat these labels as an implementation inventory, not a compatibility claim.
Re-test the original defect before installing a workaround on another system.
