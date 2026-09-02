# Intermittent loss of internal speaker audio

## Status

Reported on 2026-09-01; not reproduced in the current session. The failure is
described as random loss of sound from the laptop's internal speakers. The
trigger is unknown, and no workaround or root cause is confirmed.

This is a user-reported regression against an otherwise working audio stack,
not a claim that the speakers fail on every boot. Headphone, Bluetooth-audio
and microphone behavior during a failure has not yet been recorded.

## Tested system

```text
Model: ASUS Zenbook Duo UX8406CA_UX8406CA
Kernel: 7.1.9-arch1-2
Omarchy: 4.0.2-1
Hyprland: 0.56.2
PipeWire: 1.6.8-1
WirePlumber: 0.5.15-1
sof-firmware: 2025.12.2-1
alsa-ucm-conf: 1.2.16.1-1
Audio controller: Intel 00:1f.3, PCI ID 8086:7728
Audio driver: sof-audio-pci-intel-mtl
Codec: Realtek ALC294, subsystem 1043:1c43
Speaker amplifiers: Cirrus Logic CS35L41 ×2
```

## Current evidence

The failure was not active during inspection. The current boot has a
`sof-hda-dsp` ALSA card, `sof-firmware` is installed, and the kernel log shows
SOF firmware 2.14.1.1 booting and both CS35L41 amplifiers binding to the
Realtek codec. The only matching amplifier warning in the current boot is:

```text
cs35l41-hda ...: Reset line busy, assuming shared reset
```

The current boot did not show `sof_probe_work failed`, missing SOF firmware,
or an amplifier short error. PipeWire's live sink list could not be queried
from the inspection environment because its user session bus is isolated.

The observed `speaker_outs=0` together with one `line_out` classified as
`speaker` is recorded for comparison, but is not yet established as the cause:
the current session's speakers were reported to be working.

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

If the audio menu is available, Omarchy's documented **Update > Hardware >
Audio** reload is a useful diagnostic. Record whether it restores the speakers;
do not treat a successful reload as a confirmed fix until the failure and the
recovery are repeated.

## Related documentation

- [Omarchy troubleshooting manual](https://omarchy.org/manual/troubleshooting/): documents reloading the Audio subsystem and checking Omarchy speaker tuning.
- [Omarchy issue #6110](https://github.com/basecamp/omarchy/issues/6110): documents total Arrow Lake audio loss caused by missing `sof-firmware`; the current UX8406CA does not match that failure because its firmware and ALSA card are present.
- [Linux for ROG Cirrus amplifier guide](https://asus-linux.org/guides/cirrus-amps/): documents general CS35L41 initialization and ACPI issues on related ASUS hardware, but does not document this UX8406CA intermittent failure.

No model-specific public documentation or confirmed fix for this intermittent
UX8406CA speaker failure was found during the 2026-09-01 review.
