# Update revalidation — 2026-10-19

Read-only system inspection on ASUS Zenbook Duo UX8406CA, around
13:09–13:20 America/Mexico_City, with a user-assisted audio follow-up through
13:45, subsequent user-reported successful audio reboots, a failed
VMD-on boot attempt, and a confirmed audio recurrence at 15:11. This review updates the repository's known
bugs and workaround inventory without installing, removing or disabling any
workaround, changing UEFI, or rebooting. The user subsequently performed the
audio, suspension, reboot and BIOS VMD tests recorded below.

## Inspected environment

| Component | Value |
|---|---|
| Running kernel | `7.2.8-9-omarchy` |
| Running kernel package | `linux-omarchy 7.2.8-9`, built 2026-10-17 |
| Alternate installed kernel | `linux 7.2.11.arch1-1`; not boot-tested here |
| Omarchy | `4.0.5-1` |
| Hyprland | `0.56.2-4` |
| BlueZ | `5.87-2` |
| PipeWire / WirePlumber | `1:1.6.9-1` / `0.5.18-1` |
| SOF package / loaded firmware | `2026.09.2-1` / `2.15.0.1` |
| ALSA UCM | `1.2.16.1-1` |
| BIOS | `UX8406CA.313` |

The kernel package describes BORE CPU and ADIOS I/O schedulers. Its public
recipe at commit `cc664d884b8400accad0e02347c39d6b2cd6b688` matches the
installed version, `7.2.8-9`. Version numbers alone do not establish that a
particular hardware fix is present.

## Decisions

| Known issue / component | Evidence after update | Decision |
|---|---|---|
| VMD NVMe stalls, MTL016 | Omarchy patch `0704` targets `8086:7d0b`; installed module contains its interrupt flush and device quirk | **Native packaged fix present; VMD-on boot failed at root mount; successful validation blocked** |
| Intermittent speaker silence | User confirmed playback after idle, one s2idle cycle and several subsequent reboots; no amplifier timeout in the earlier boot through 13:45 | **Later recurrence confirmed on current kernel at 15:10; issue remains reproduced** |
| UX8406CA ASUS WMI identification | Boot explicitly identifies this model | **Already upstream; no extra DMI patch needed** |
| Vertical panel arrangement | Explicit positions remain `0x0` / `0x900`, scale 2, 2880×1800 at 120 Hz | **Retain configuration**; automatic placement was not retested |
| Per-panel Omarchy brightness | Packaged helper still resolves both internal panels through `omarchy-hw-display`; default resolver selects `intel_backlight` | **Retain wrapper** |
| Keyboard covers lower panel | Dock listener running and reports `docked`; DRM says lower panel disabled, DPMS Off, actual brightness 0 | **Retain dock policy**; undock/redock not repeated |
| Fn initialization / Fn Lock | USB collections bind to `hid-generic` / `hid-multitouch`, not an ASUS keyboard control driver; user listener running, saved mode `function` | **Retain HID helper**; physical key and Bluetooth tests pending |
| Keyboard backlight / F4 | No `*kbd_backlight*` LED device exists; stock Omarchy still requires one | **Retain vendor HID control** |
| F5/F6, F9, F11 | No identified device support replacing vendor-report listener or desktop actions | **Retain integrations**; key actions not physically retested |
| Touch/stylus mapping | Both ELAN touch and stylus pairs enumerate in Hyprland | **Still needs physical coordinate tests** during layout changes |

## Kernel patch findings

### VMD: meaningful change from the September review

The recipe includes:

- `0704-pci-vmd-meteor-lake-mtl016-flush.patch`: flush the child device's
  posted writes before handling its MSI, and enable the quirk for `7d0b`.
- `0706-pci-vmd-arrow-lake-arl004-flush.patch`: extend that quirk to `ad0b`.
- `0703-pci-vmd-scan-bios-enumerated-devices.patch`: a separate enumeration
  change; it is not the MTL016 fix.

The installed `/usr/lib/modules/7.2.8-9-omarchy/kernel/drivers/pci/controller/vmd.ko.zst`
was decompressed to a temporary file for inspection. Disassembly of `vmd_irq`
shows a conditional 16-bit MMIO read under the configuration lock before
`generic_handle_irq`. The PCI table contains `driver_data=0xae` for both
`8086:7d0b` and `8086:ad0b`, including interrupt-quirk bit 7. This confirms
that the actual installed module includes the mechanism and affected IDs.

At the initial inspection, VMD was disabled: the SSD was directly at `0000:01:00.0`, no VMD PCI
controller is exposed, and there are no NVMe timeouts in this boot. The fix
had **not yet been exercised on this laptop**; see the later failed boot attempt below. Keep the working UEFI setting
until controlled testing is practical; see [storage notes](login-startup-timing.md).
The inspected Torvalds `master` driver did not yet contain this interrupt
quirk; an Omarchy backport and a fix discussed in the PCI tree do not establish
availability in every mainline or stable kernel.

### ASUS HID: the new patch is not Duo keyboard support

`0566-hid-asus-no-keyboard-init-reports-to-touchpads.patch` prevents ASUS
keyboard initialization reports from being sent to touchpads. It does not add
USB `0b05:1bf2` / Bluetooth `0b05:1bf3` support. The inspected upstream
`hid-asus.c` and `hid-ids.h` do not identify these Duo devices. Although that
driver has Fn Lock support for other ASUS keyboards, that does not make it
active for this keyboard. Current USB bindings and the absent backlight LED
interface support retaining this repository's narrowly scoped helper.

### Audio: newer firmware, no confirmed power-up fix

All `0510`–`0532` audio patch files listed in the recipe were reviewed for
CS35L41 changes. `0510-sound-updates.patch` changes CS35L41 firmware resource
cleanup, error handling and ACPI reference lifetime. No identified change
fixes this model's `PUP_DONE_MASK -110` startup handshake or adds an
`10431C43`-specific workaround. This is a scoped source review, not proof that
no generic kernel change could affect the symptom.

The SOF firmware has advanced from the previously logged 2.14.1.1 to 2.15.0.1.
Both speaker amplifiers still load the same `10431C43` speaker-protection
firmware, with `firmware_autostart=Y`, `FW EN: 1`, and left/right `VSPK: 1/0`.
No `PUP_DONE` / `PDN_DONE` timeout was logged in the inspected boot. The
Speaker sink was present, unmuted, and idle (`SUSPENDED`), so this does not
establish audible output or freedom from the intermittent failure.

A new related UX3405MA/`10431A63` report correlates failures with a preceding
Windows session. Use that as a future comparison condition; do not transfer
its GPIO or firmware overrides to this different SSID. See the
[audio investigation](intermittent-speaker-audio.md).

## Installed workaround checks

Hyprland reports no configuration errors. Both panel modes remain exposed.
The lower display is physically off while the keyboard is docked, as confirmed
by DRM and backlight sysfs; Hyprland's cached `dpmsStatus` field alone was not
used to determine that state.

The installed Fn-mode, keyboard-backlight and dock scripts match the repository
copies. The installed brightness wrapper is an older equivalent: its monitor
mapping and delegation match, but it lacks the repository's `set -u` and
missing-helper guard. It was left untouched. Both per-monitor symlinks point
to the expected separate backlights. Read-only brightness queries return 10%
on each panel, with and without the wrapper; equal values alone cannot prove
independent adjustment. The retained-wrapper decision comes from the actual
resolver code and sysfs mapping, not that numerical coincidence.

## Earlier audio follow-up — passed on 2026-10-19

The user confirmed audible playback, then successful playback after the idle
test and after suspension. The same boot records `s2idle` entry at 13:36:39
and exit at 13:40:12, America/Mexico_City. The follow-up kernel journal at
13:45 contains no `PUP_DONE` / `PDN_DONE` timeout or matching CS35L41
failure/error. This supersedes the initial inspection's playback limitation.
It validates this session and one resume cycle, without proving a permanent
fix for the intermittent defect or independently confirming each channel.

The user subsequently restarted the laptop and confirmed that internal-speaker
audio continued to work. The user later confirmed that audio continued to work after several
reboots on 2026-10-19; the exact count was not supplied. No exact restart time, post-reboot kernel version or
post-reboot amplifier-log inspection was captured in this follow-up; the
clean journal through 13:45 applies only to the preceding boot. The
intermittent audio issue remains open.

## Later audio follow-up — recurrence confirmed on 2026-10-19

After the earlier successful tests and several reboots, the user reported
speaker silence after another reboot. Read-only inspection at 15:11 confirmed
`CS35L41_PUP_DONE_MASK: -110` in both amplifiers at 15:10:12 and 15:10:39,
in the boot begun at 15:09:32 on `7.2.8-9-omarchy` (America/Mexico_City).
SOF 2.15.0.1 and both amplifier firmware images loaded; ALSA exposed the card.
The default Speaker sink and both hardware Speaker controls were unmuted at
100%. There was no active playback at capture time, and no new playback test
or recovery action was performed. See the [audio evidence](intermittent-speaker-audio.md).

**The intermittent amplifier failure is reproduced on the updated kernel.**
Earlier successful boots do not establish a permanent fix. A causal link to
the VMD test has not been established.

## VMD-on follow-up — boot failed on 2026-10-19

The user enabled VMD in BIOS and reported that Omarchy could no longer boot:

```text
ERROR: Failed to mount '/dev/mapper/omarchy_root' on real root...
```

This changes the status from untested to **attempted, failed at root mount**.
The packaged MTL016 fix remains confirmed by module inspection, but its
runtime effectiveness is unresolved. The error alone does not establish
whether VMD/NVMe discovery, encrypted-root activation, storage I/O or the
filesystem mount failed. No complete failed-boot log or kernel version was
captured. A subsequent read-only check shows the working direct-NVMe path
again on `7.2.8-9-omarchy`.

Initramfs inclusion/loading of `vmd` is a hypothesis to check, not a confirmed
cause. See the [storage follow-up](login-startup-timing.md) for the available
configuration evidence and diagnostic limits.

## Remaining acceptance tests

1. Repeat audio playback and power-transition tests across more suspend/resume cycles and
   additional boots; verify each speaker channel separately. Compare cold boot
   with a boot following Windows, and inspect amplifier
   errors before any recovery action.
2. Undock/redock, verify panel enable/disable, and check touch/stylus coordinates
   on both panels after the layout changes.
3. Test Fn+Esc, F4, F5/F6, F9 and F11 in both Fn modes over USB and Bluetooth,
   including reconnect and LED state restoration.
4. Before retrying VMD, inspect the actual initramfs and boot entry for VMD,
   NVMe and encrypted-root support, and plan reversible UEFI/Windows preparation.
   Then test several VMD-on boots and sustained storage I/O with zero completion-polled timeouts.

Apart from the recorded audio tests and failed VMD-on boot attempt, these remaining physical
tests have not been performed. No workaround
is classified as obsolete solely because it was active and working.

## Sources

- [Exact Omarchy kernel recipe](https://github.com/omacom/omarchy-pkgs/blob/cc664d884b8400accad0e02347c39d6b2cd6b688/pkgbuilds/linux-omarchy/PKGBUILD).
- [MTL016 packaged patch](https://github.com/omacom/omarchy-pkgs/blob/cc664d884b8400accad0e02347c39d6b2cd6b688/pkgbuilds/linux-omarchy/0704-pci-vmd-meteor-lake-mtl016-flush.patch), [ARL004 extension](https://github.com/omacom/omarchy-pkgs/blob/cc664d884b8400accad0e02347c39d6b2cd6b688/pkgbuilds/linux-omarchy/0706-pci-vmd-arrow-lake-arl004-flush.patch).
- [ASUS touchpad initialization patch](https://github.com/omacom/omarchy-pkgs/blob/cc664d884b8400accad0e02347c39d6b2cd6b688/pkgbuilds/linux-omarchy/0566-hid-asus-no-keyboard-init-reports-to-touchpads.patch).
- [Audio update patch](https://github.com/omacom/omarchy-pkgs/blob/cc664d884b8400accad0e02347c39d6b2cd6b688/pkgbuilds/linux-omarchy/0510-sound-updates.patch).
- [Upstream HID ASUS driver](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-asus.c), [device IDs](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-ids.h), [VMD driver](https://github.com/torvalds/linux/blob/master/drivers/pci/controller/vmd.c), inspected 2026-10-19.
- [VMD developer/tester discussion and PCI-tree commit references](https://github.com/CachyOS/linux-cachyos/issues/1076).
- [ASUS Duo support tracking](https://github.com/OpenGamingCollective/asusctl/issues/25).
- [Related UX3405MA report, 2026-10-01](https://go.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6317351.html).
