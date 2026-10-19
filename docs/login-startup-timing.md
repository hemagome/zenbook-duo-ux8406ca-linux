# Intel VMD NVMe boot stalls

## Status

Mitigated on the tested ASUS Zenbook Duo UX8406CA by disabling Intel VMD in
UEFI. Three consecutive VMD-off Omarchy boots completed without an NVMe
timeout. A fresh boot on 2026-09-08 also completed without an NVMe timeout.
The 2026-10-19 update ships the MTL016 driver fix. A subsequent user test
with VMD enabled failed to mount `/dev/mapper/omarchy_root`, so successful
VMD-on operation remains unvalidated. The current session again uses direct
NVMe without an exposed VMD controller; see the follow-up below.

Tested configuration:

| Component | Value |
|---|---|
| Laptop | ASUS Zenbook Duo UX8406CA, BIOS 313 |
| VMD controller | Intel `8086:7d0b` |
| SSD | WD PC SN5000S 1 TB, firmware `34230100` |
| Linux | `7.2.3-arch1-3` |
| Omarchy | `4.0.3-1` |

## Problem

With Intel VMD enabled, the NVMe SSD was placed behind the VMD-managed PCIe
domain. The kernel repeatedly reported:

```text
nvme nvme0: I/O ... timeout, completion polled
```

Each message means that the NVMe completion was present when Linux eventually
polled for it, but its interrupt had not been delivered or processed in time.
The pattern matches Intel erratum **MTL016**, which affects ordering between a
VMD-owned MSI and preceding device writes. The affected VMD device ID is the
same `8086:7d0b` targeted by the proposed Linux workaround.

The SSD itself did not show evidence of media failure: SMART passed, wear was
1%, and the media-error and NVMe error-log counters were zero. Disabling NVMe
APST and disabling PCIe ASPM were tested independently; neither stopped the
timeouts.

## Consequences

Every missed completion added an approximately 30-second stall. Several could
occur in one boot, causing:

- a loading bar lasting roughly one or two minutes;
- a black screen or pointer without wallpaper;
- delayed Hyprland and Omarchy Shell startup;
- UWSM/Hyprland startup timeouts and, in the worst run, a second login prompt.

These desktop failures were downstream effects of storage stalls, not separate
Hyprland or Omarchy defects. Before the mitigation, the issue appeared in 15
of 16 inspected boots.

## Solution

Disable **Intel VMD** in UEFI so Linux accesses the NVMe controller through the
normal PCIe/NVMe path. On this machine the SSD then moved from a VMD-managed
domain to direct PCI address `0000:01:00.0`.

Validated result:

| Result | VMD enabled | VMD disabled |
|---|---:|---:|
| NVMe timeouts | Recurrent; often several per boot | 0 in 3 consecutive boots |
| Typical individual stall | 30 seconds | None |
| Authentication to wallpaper | Up to more than 1 minute | About 5 seconds |
| Failed first graphical session | Observed | Not observed |

Keep VMD disabled unless it is required by Windows or another storage setup.
Changing this setting can make an existing Windows installation unbootable if
Windows does not have a suitable direct-NVMe boot driver enabled. If Windows
fails with `INACCESSIBLE_BOOT_DEVICE`, restore VMD immediately instead of
allowing automatic repair to modify the installation.

The unrelated incident where external USB keyboard and mouse stopped working
in UEFI/Limine and Windows was resolved by the official ASUS 40-second EC/RTC
reset. Linux had been reinitializing the xHCI controller successfully. This was
not caused by VMD or dual boot.

## Upstream tracking

Linux kernel development normally uses mailing-list patches rather than GitHub
pull requests for a change like this. A patch titled **“PCI: vmd: Delay
interrupt handling on MTL VMD controller”** was submitted on 2024-09-02 for
the exact `8086:7d0b` controller and MTL016 symptom. Reviewers rejected a fixed
delay as an ordering guarantee and requested a proper register-read solution.
No revised patch or merged fix was found in the 2026-09-08 review. That
conclusion is historical and is superseded by the packaged fix below.

### Update — 2026-10-19: fix included in the running Omarchy kernel

`linux-omarchy 7.2.8-9` includes
`0704-pci-vmd-meteor-lake-mtl016-flush.patch`, which adds a PCI configuration
read of the initiating device before delivering its interrupt. It sets
`VMD_FEAT_INTERRUPT_QUIRK` for **`8086:7d0b`**, the controller previously
observed on this laptop. The accompanying `0706` patch extends the mechanism
to Arrow Lake's `8086:ad0b`.

This was verified beyond the package recipe: the installed `vmd.ko.zst`
contains the guarded 16-bit read before `generic_handle_irq`, and the PCI
entries for `7d0b` and `ad0b` contain driver data `0xae` (including quirk bit 7).
The fix is supplied by Omarchy without a local module override. The upstream
PCI tree also carries the corresponding fix; presence in every vanilla/stable
kernel must be checked separately.

The initial inspection boot used direct NVMe at `0000:01:00.0`, with no VMD controller
exposed and no NVMe timeout. This verifies the existing VMD-off mitigation,
**not** the new fix under VMD. Leave the working UEFI setting unchanged until a
controlled VMD-on test can cover multiple boots and sustained I/O, including
the Windows boot implications above. No BIOS setting was changed during that initial inspection.

### User VMD-on boot attempt — 2026-10-19

The user enabled Intel VMD in BIOS and then could not boot into Omarchy.
The reported message was:

```text
ERROR: Failed to mount '/dev/mapper/omarchy_root' on real root...
```

**Result: VMD-on boot attempted and failed at root mounting.** This supersedes
"not tested" for the boot attempt, but does not establish whether the MTL016
interrupt-ordering fix works. The message alone does not distinguish a missing
root mapping, an inaccessible underlying SSD, a decryption problem, a storage
timeout or a filesystem-mount failure. The failed boot's kernel version,
complete preceding messages and initramfs contents were not captured.

A read-only check after the report shows kernel `7.2.8-9-omarchy` and direct
NVMe at `0000:01:00.0`, with no exposed VMD controller. This is the working
VMD-off configuration again; the exact BIOS recovery steps were not reported.

One hypothesis is that `vmd` was absent from, or not loaded by, the initramfs
used for the failed boot. The current mkinitcpio configuration uses `autodetect`,
`block` and `encrypt`, and does not explicitly add `vmd` to `MODULES`; this
**does not prove the module is missing**, since hooks can include modules.
The actual boot image could not be inspected with current read access to
`/boot`. A missing-module failure has a historical precedent in
[Arch FS#68704](https://bugs.archlinux.org/task/68704), fixed in mkinitcpio 31;
that old report is not evidence of the same bug in this installation.

Retain the working VMD-off setting. Before another VMD-on attempt, inspect
the actual boot entry and its initramfs for `vmd`, NVMe and encrypted-root
support. If the attempt still fails, capture the preceding storage/decryption
messages and device/mapping availability before attributing the mount error
to MTL016. No boot images or system configuration were changed in this follow-up.

See the [full update audit](revalidation-2026-10-19.md) for immutable patch
links and evidence limits.

Tracking links:

- [Original patch and discussion](https://lore.kernel.org/linux-pci/20240903025544.286223-1-kai.heng.feng@canonical.com/)
- [Review discussion requesting a register-read solution (2024-09-13)](https://lkml.iu.edu/hypermail/linux/kernel/2409.1/08547.html)
- [Kernel bug 217871](https://bugzilla.kernel.org/show_bug.cgi?id=217871)
- [Intel erratum MTL016](https://edc.intel.com/content/www/us/en/design/products/platforms/details/meteor-lake-u-p/core-ultra-processor-specification-update/errata-details/#MTL016)
- [Current upstream VMD driver](https://github.com/torvalds/linux/blob/master/drivers/pci/controller/vmd.c)
- [VMD driver commit history and dates](https://github.com/torvalds/linux/commits/master/drivers/pci/controller/vmd.c)

Before re-enabling VMD, verify that a merged upstream commit implements MTL016
or an equivalent fix for `8086:7d0b`, that the commit is present in the locally
installed kernel, and that several controlled VMD-on boots complete with zero
`timeout, completion polled` events.
