# Intel VMD NVMe boot stalls

## Status

Mitigated on the tested ASUS Zenbook Duo UX8406CA by disabling Intel VMD in
UEFI. Three consecutive VMD-off Omarchy boots completed without an NVMe
timeout. Last validated: 2026-08-21.

Tested configuration:

| Component | Value |
|---|---|
| Laptop | ASUS Zenbook Duo UX8406CA, BIOS 313 |
| VMD controller | Intel `8086:7d0b` |
| SSD | WD PC SN5000S 1 TB, firmware `34230100` |
| Linux | `7.1.8-arch1-3` |
| Omarchy | `4.0.0-1` |

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
No revised patch or merged fix was found as of 2026-08-21, and current upstream
`vmd.c` does not contain the proposed MTL016 quirk.

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
