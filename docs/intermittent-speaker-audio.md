# Intermittent loss of internal speaker audio

## Status

Reported on 2026-09-01 and reproduced during a live diagnostic session on
2026-09-02. The failure is intermittent: the laptop can boot and play audio
normally, but on some occasions the internal speakers become silent while the
audio stack continues to present a valid output device and an active stream.

The reproduction confirms a low-level speaker-amplifier failure, but not yet
the event that triggers it or a permanent fix. This is not a claim that the
speakers fail on every boot.

Headphone, Bluetooth-audio and microphone behavior during the reproduced
failure has not yet been recorded.

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

No model-specific public documentation or confirmed fix for this intermittent
UX8406CA speaker failure was found. The 2026-09-02 capture is the first
confirmed reproduction in this project and should be used as the baseline for
future recovery tests and any upstream report.
