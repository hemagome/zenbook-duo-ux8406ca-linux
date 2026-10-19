# Intermittent loss of internal speaker audio

## Status

Reported on 2026-09-01 and reproduced during a live diagnostic session on
2026-09-02. The failure is intermittent: the laptop can boot and play audio
normally, but on some occasions the internal speakers become silent while the
audio stack continues to present a valid output device and an active stream.

The reproduction confirms a low-level speaker-amplifier failure, but not yet
the event that triggers it or a permanent fix. This is not a claim that the
speakers fail on every boot.

The failure was **not fixed by the September Omarchy update**. Validation on
2026-09-22 reproduced the same CS35L41 amplifier timeout while running Omarchy
`4.0.4-1` and kernel `7.2.5-3-omarchy`. Earlier October tests passed, but
**the same failure recurred on `7.2.8-9-omarchy` on 2026-10-19 at 15:10**,
after several successful reboots. The updated kernel/firmware combination
therefore does not prevent the intermittent failure on this machine.

Headphone, Bluetooth-audio and microphone behavior during the reproduced
failure has not yet been recorded.

## Tested system

```text
Model: ASUS Zenbook Duo UX8406CA_UX8406CA
Kernel: 7.2.3-arch1-3
Omarchy: 4.0.3-1
Hyprland: 0.56.2-2
PipeWire: 1:1.6.8-1
WirePlumber: 0.5.17-1
sof-firmware: 2025.12.2-1
alsa-ucm-conf: 1.2.16.1-1
Audio controller: Intel 00:1f.3, PCI ID 8086:7728
Audio driver: sof-audio-pci-intel-mtl
Codec: Realtek ALC294, subsystem 1043:1c43
Speaker amplifiers: Cirrus Logic CS35L41 ×2
```

## Current evidence

### Reproduced failure — 2026-09-02

The following capture was taken while the speakers were silent, at
`2026-09-02T15:20:04-06:00`, on the system described above. PipeWire and ALSA
were still functioning at the logical-device level:

- The default sink was the internal **Speaker** sink at 35% volume, not a
  `Dummy Output` or `auto_null` sink.
- PipeWire showed an active output stream connected to the Speaker sink.
- The speaker sink was `RUNNING`; the HDMI sinks were `SUSPENDED`.
- ALSA exposed the expected `sof-hda-dsp` card and HDA Analog playback device.
- The ALSA PCM status was `RUNNING` with a 48 kHz, two-channel stream.
- The hardware mixer reported `Speaker [on]`, with no master mute and
  `Auto-Mute Mode Disabled`.

The kernel log contained the following error for **both** Cirrus CS35L41
amplifiers:

```text
Failed waiting for CS35L41_PUP_DONE_MASK: -110
```

It appeared during the boot and repeated while the failure was active, at
approximately 15:08, 15:18:38, 15:19:32 and 15:19:46. `-110` is a timeout:
the kernel driver waits for each amplifier to report that its power-up
sequence has completed, but the `PUP_DONE` condition is not observed.

The same boot also shows the expected initialization before the failure:
SOF firmware 2.14.1.1 booted, both CS35L41 devices loaded their Cirrus
firmware and calibration, and both amplifiers bound to the Realtek codec.
There was no evidence of missing `sof-firmware`, a missing ALSA card,
`sof_probe_work failed`, or an amplifier short-circuit error.

### Interpretation

The reproduced failure is below PipeWire's routing and volume controls. Audio
data reaches the codec/PCM path, but both physical speaker amplifiers fail to
complete their power-up handshake. This explains why the system can show an
active stream and a healthy speaker sink while the laptop remains silent.

The leading hypothesis is an intermittent power-state, ACPI/EC, firmware or
kernel-driver interaction affecting the CS35L41 amplifier startup sequence.
The exact trigger is still unknown; suspend/resume, a prior Windows restart,
display changes, docking, headphone events and other power transitions remain
to be correlated with future captures. The evidence does not currently point
to a PipeWire profile-selection problem or to absent SOF firmware.

When the failure was not active, the same machine reported the same valid
`sof-hda-dsp` card and both amplifiers binding successfully. The earlier
warning below remains relevant but is not, by itself, proof of the cause:

```text
cs35l41-hda ...: Reset line busy, assuming shared reset
```

The observed `speaker_outs=0` together with one `line_out` classified as
`speaker` is recorded for comparison, but is not yet established as the cause:
the current session's speakers were reported to be working.

### Workaround test: `firmware_autostart=0` — 2026-09-02

The workaround documented for the ASUS Zenbook UX3405MA was tested on this
UX8406CA by installing:

```text
options snd_hda_scodec_cs35l41 firmware_autostart=0
```

After reboot, the module parameter was active (`N`, the sysfs representation
of `0`) and both amplifiers bound with `FW EN: 0`. The kernel nevertheless
continued to report `PUP_DONE_MASK: -110` for both amplifiers at approximately
15:36:59, 15:37:00 and 15:37:20. The workaround therefore did not prevent the
failure on this model.

The temporary configuration was disabled and the system was rebooted again.
The parameter is now back at `Y` (`1`), both amplifiers load the speaker
protection firmware with `FW EN: 1`, and the timeout still appears at
approximately 15:39:50. No speaker-protection override remains active.

The same boot records an additional clue for this machine:

```text
CS35L41 Bound - SSID: 10431C43, BST: 1, VSPK: 1, CH: L, FW EN: 1, SPKID: 0
CS35L41 Bound - SSID: 10431C43, BST: 1, VSPK: 0, CH: R, FW EN: 1, SPKID: 0
```

The right amplifier has `VSPK: 0` while the left has `VSPK: 1`. This is a
useful ACPI/GPIO lead, not a confirmed root cause; the UX8406CA's `10431C43`
configuration is different from the `10431A63` configuration in the
documented UX3405MA workaround.

### Post-update validation — 2026-09-08

The first boot after updating to Linux `7.2.3-arch1-3` and Omarchy `4.0.3-1`
completed with both CS35L41 amplifiers loading their `10431C43` firmware and
binding with `FW EN: 1`. No `PUP_DONE_MASK: -110` or `PDN_DONE_MASK` timeout
appeared in the boot journal. The right amplifier still reported `VSPK: 0`,
so this is a clean-boot observation rather than confirmation that the
intermittent failure is fixed. Suspend/resume and other power transitions
still need to be tested before changing the investigation status.

### Reproduced after update — 2026-09-22

The failure recurred on the newer Omarchy/kernel environment:

```text
Kernel running: 7.2.5-3-omarchy
Omarchy: 4.0.4-1
Boot: 2026-09-21T09:54:03-06:00
```

The first timeout in this boot appeared at `09:54:08`, during the initial
graphical session startup, for both amplifiers:

```text
Failed waiting for CS35L41_PUP_DONE_MASK: -110
```

The same error recurred on 2026-09-22 at 09:45:07, 09:56:51, 10:16:32,
10:17:28, 10:24:51, 10:26:20, 10:27:21, 10:32:52, 11:37:46, 11:38:49
and 11:40:48. The current boot has no recorded suspend/resume transition, so
this capture shows that the failure was already present from system startup,
not first introduced by a later resume from suspension.

The audio device remained logically available: SOF firmware 2.14.1.1 and both
CS35L41 firmware images loaded, `/proc/asound/cards` exposed `sof-hda-dsp`, and
the analog playback PCM remained `RUNNING`. This matches the earlier failure
signature: the audio path is active at the software level while both physical
speaker amplifiers fail their power-up handshake.

The installed `linux` package was reported as `7.2.3.arch1-3`, while the
running kernel identified itself as `7.2.5-3-omarchy`; both values are recorded
to make the validation reproducible.

### Latest inspection — 2026-10-19

Running kernel `7.2.8-9-omarchy`, Omarchy `4.0.5-1`, PipeWire `1:1.6.9-1`,
WirePlumber `0.5.18-1`, and `sof-firmware 2026.09.2-1` were inspected after
booting at 13:09:48 (America/Mexico_City).

- SOF now reports firmware **2.15.0.1**, compared with 2.14.1.1 in September.
- Both CS35L41 amplifiers load their `10431C43` firmware and calibration with
  `FW EN: 1`; `firmware_autostart` remains `Y`.
- The left/right values remain `VSPK: 1` / `VSPK: 0`, and the shared-reset
  warning remains. Neither observation alone proves a failure.
- No `PUP_DONE` or `PDN_DONE` timeout occurred in the journal inspected around
  13:20. The internal Speaker sink exists, is unmuted, and was `SUSPENDED`
  when queried; no audible playback test was performed.
- No suspend/resume transition was recorded in the inspected boot.

The reviewed Omarchy audio patches contain CS35L41 firmware resource/error
handling cleanup, but no identified fix for this machine's intermittent
power-up timeout. A related October report for UX3405MA/SSID `10431A63`
correlates the same symptom with a preceding Windows session. That is a useful
future test condition, not a diagnosis or a patch for UX8406CA/`10431C43`.

### User-assisted playback and suspend validation — 2026-10-19

After the initial inspection, the user confirmed audible internal-speaker
playback, then confirmed that audio remained functional after both the idle
playback test and a suspend/resume test. The journal records `s2idle` entry
at **13:36:39** and exit at **13:40:12** (America/Mexico_City), on the same
`7.2.8-9-omarchy` boot. A follow-up kernel-log inspection at **13:45** found
no `PUP_DONE` or `PDN_DONE` timeout and no matching CS35L41 failure/error.
The earlier statements about untested playback and suspension describe the
initial inspection only and are superseded by this follow-up.

**Result: playback, idle recovery and one suspend/resume cycle passed.**
Several subsequent reboots also passed, as recorded below. Separate left/right
channel verification, repeated cycles, additional boots and Windows-to-Linux
transitions have not been validated here. This provides
a successful functional baseline for the updated kernel/firmware combination,
but does not isolate a particular fix or establish that the intermittent
failure is permanently resolved. Keep the issue open for longer-term validation.
See the [update audit](revalidation-2026-10-19.md) for exact patch references
and remaining physical tests.

### User-reported reboot validation — 2026-10-19

After the playback, idle and suspend/resume tests above, the user restarted
the laptop and confirmed that the internal-speaker audio continued to work.
The user later confirmed that audio continued to work after **several
reboots**; the exact count was not supplied. This extends the initial
one-reboot report. The exact
reboot time, post-reboot kernel version and amplifier journal were not
independently captured for this follow-up; the clean logs through 13:45
belong to the earlier boot.

The issue remains open because the failure is intermittent. This result does
not establish a permanent fix or identify which update changed the behavior.

### Confirmed recurrence after reboot — 2026-10-19, 15:11

The user reported speaker silence after another reboot. Read-only validation
at **15:11:29–15:11:36 America/Mexico_City** confirmed the same amplifier
failure signature on running kernel **`7.2.8-9-omarchy`**. The boot began at
**15:09:32**. Both CS35L41 amplifiers logged the following at **15:10:12**
and again at **15:10:39**:

```text
Failed waiting for CS35L41_PUP_DONE_MASK: -110
```

SOF firmware **2.15.0.1** booted, both amplifiers loaded their `10431C43`
speaker-protection firmware and calibration, and both bound with `FW EN: 1`.
The left/right `VSPK: 1/0` values remain unchanged. ALSA still exposes
`sof-hda-dsp`. PipeWire selects the internal Speaker sink as default, unmuted
at 100%; the ALSA Speaker controls are also on at 100% for both channels.
At capture time there were no active playback streams, the sink was
`SUSPENDED` and the playback PCM was `closed`; no new playback test was
started during this validation.

**Conclusion: the same low-level amplifier fault has recurred on the updated
kernel**, consistent with the user's silence report. Earlier successful
playback and reboots remain valid observations, but do not demonstrate a fix.
No audio service was restarted and no mixer or system setting was changed.
This capture does not establish a causal link to the earlier VMD BIOS test.

## Reproduction data to capture

When the speakers are silent, record whether the failure followed any of these
events: suspend/resume, display or HDMI connection, keyboard docking or
undocking, headphone insertion, Bluetooth connection, volume/mute changes,
or a system update. Also record whether headphones, Bluetooth audio and the
microphone still work.

Run the following before restarting audio or rebooting, then review the output
for machine-specific identifiers before sharing it:

```bash
date --iso-8601=seconds
uname -r
omarchy version
pacman -Q omarchy linux hyprland bluez pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber sof-firmware alsa-ucm-conf
wpctl status
wpctl get-volume @DEFAULT_AUDIO_SINK@
pactl list sinks short
aplay -l
cat /proc/asound/cards
journalctl -k -b --no-pager | rg -i 'sof|hda|snd|cs35l|speaker|audio'
journalctl --user -b --no-pager -u pipewire -u pipewire-pulse -u wireplumber
```

For this particular failure, also capture the low-level runtime state before
restarting audio or rebooting:

```bash
wpctl inspect @DEFAULT_AUDIO_SINK@
pactl list short sinks
pactl list sink-inputs
cat /proc/asound/card0/pcm0p/sub0/status
amixer -c 0 scontents
```

If the audio menu is available, Omarchy's documented **Update > Hardware >
Audio** reload is a useful diagnostic. Record whether it restores the speakers;
do not treat a successful reload as a confirmed fix until the failure and the
recovery are repeated.

## Related documentation

- [Omarchy troubleshooting manual](https://omarchy.org/manual/troubleshooting/): documents reloading the Audio subsystem and checking Omarchy speaker tuning.
- [Omarchy issue #6110](https://github.com/basecamp/omarchy/issues/6110): documents total Arrow Lake audio loss caused by missing `sof-firmware`; the current UX8406CA does not match that failure because its firmware and ALSA card are present.
- [Linux CS35L41 driver source](https://codebrowser.dev/linux/linux/sound/soc/codecs/cs35l41-lib.c.html): shows the `PUP_DONE` polling performed during amplifier power-up and the timeout path that emits this error.
- [Related ASUS Zenbook UX3405MA report](https://www.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6280840.html): reports the same `PUP_DONE_MASK -110` symptom in a different Zenbook model, associated with amplifier power/ACPI initialization. It is related evidence, not a confirmed diagnosis for the UX8406CA.
- [Related post-hibernation CS35L41 report](https://discuss.kde.org/t/after-hibernation-only-left-channel-have-sound/37622): documents a similar amplifier timeout after a power-state transition on other hardware.
- [Linux for ROG Cirrus amplifier guide](https://asus-linux.org/guides/cirrus-amps/): documents general CS35L41 initialization and ACPI issues on related ASUS hardware, but does not document this UX8406CA intermittent failure.

No confirmed model-specific fix was identified in the 2026-10-19 review.
The September reproductions remain valid evidence; the clean September and
October boots do not supersede them. Repeat playback and power-transition
tests before closing this intermittent issue.
