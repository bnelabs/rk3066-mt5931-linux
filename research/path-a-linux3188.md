# Path A — Use Galland/Linux3188 kernel as a legacy source base (Picuntu path)

Important: this is a historical source path, not a ready-to-flash image for
rk30mtk. The attached unit's exact NAND map, board GPIOs, loader, DRAM
settings, and display wiring differ from the generic examples below. See
the hardware-firmware-boot document before any native experiment.

**Goal:** boot a full (non-Android) Linux on the RK3066 stick with working MT5931 WiFi, MT6622 BT, Mali GPU, and NAND support.

**Verdict: the closest all-hardware source path, but not plug-and-play.** This
is how some RK3066 boxes ran Linux (Picuntu), but the shipped `.config`
targets RK3188 and the pieces still need exact-board integration.

## What Linux3188 is

The checked-in Linux3188 default configuration disables the MT5931/MT6622
combo and the Mali/UMP stack. The source paths exist, but this repository is
not a ready configuration or image for this device.

- Kernel **3.0.36** (matches the device's `3.0.36+`), a fork of `aloksinha2001/Linux3188`, the **Picuntu kernel** (RK3188 tree modified by Galland to also boot RK3066).
- Contains all the components this device needs:
  - `drivers/net/wireless/mt5931/` — MT5931 WiFi + MT6622 BT combo driver + `firmware_5931/WIFI_RAM_CODE`
  - `drivers/gpu/mali/` — Mali-400 r3p2 (`TARGET_PLATFORM=mali400-pmu`, port `arch-pb-rk30-m400-4`)
  - `drivers/mtd/rknand/rknand_base_ko.c` — `CONFIG_MTD_NAND_RK29XX` FTL NAND driver (produces the device's `/dev/mtdblock0..9`)
  - `arch/arm/mach-rk30/` — `SOC_RK3066`, boards incl. `MACH_RK30_BOX_HOTDOG/PIZZA/HAMBURGER` (`RK30board`)
  - Picuntu boot cmdline: `root=LABEL=linuxroot init=/sbin/init ... rootfstype=ext4 rootwait mtdparts=rk29xxnand:...` (`CONFIG_CMDLINE_FORCE=y`)

## The boot reality (RK3066 has no U-Boot SDMMC)

RK3066's BootROM has **no SDMMC support** (per U-Boot docs), so boot is: NAND → RK loader (`RK30xxLoader`/maskrom) → kernel partition / `recovery.img` → Linux on SD or NAND.

- Kernel image: `make kernel.img` → `./mkkrnlimg arch/arm/boot/Image kernel.img`
- Linux-over-recovery (dual-boot): wrap the kernel with a **fake ramdisk** and flash as `recovery.img`:
  ```
  tools/mkbootimg --kernel arch/arm/boot/Image \
    --ramdisk initramfs/fakeramdisk.gz --base 60400000 \
    --pagesize 16384 --ramdiskaddr 62000000 -o recovery.img
  ```
  (`fakeramdisk.gz` = 1 MB of zeros, from `Galland/rk30_linux_initramfs` — satisfies the bootloader's `initrd=0x62000000,...` ATAG while the real root comes from the cmdline.)

## Three-step recipe (proven on MK802IIIS / UG802 / MK808 / iMito)

The historical procedure below is not proven on rk30mtk. In particular, do not
assume adb reboot bootloader produces Rockusb/maskrom; the attached unit is
currently USB 2207:0010, while the Rockchip tooling expects USB 2207:300a.
Observe the USB state and preserve a complete backup before any write.

1. **Prepare a reversible boot test** (Windows: RKAndroidTool; Linux:
   rkflashtool_rk3066). Do not copy the historical offsets in this note.
   Read and archive this unit's parameter/partition data first, then use only
   the exact values confirmed for this unit. The attached map reports kernel
   at offset `0x4000`, size `0x8000` sectors, and recovery at offset
   `0x14000`, size `0x10000` sectors; these are evidence, not a write
   command.
   - Do not use the historical reboot/flash commands until the loader,
     parameter backup, and recovery path are verified on this unit.
2. **Rootfs on microSD**: format ext4, **label `linuxroot`**, extract an armhf rootfs.
3. **Boot**: only after a device-specific image is validated, test a removable
   rootfs. Historical login credentials in old Picuntu notes are not a safe
   default.

## NAND-only (SD-free) boot — directly relevant (5.7 GB NAND)

The Linuxium sequence below is historical and repartitions NAND. On the
untouched attached unit, mtdblock0 is the 4 MiB misc partition, not a Linux
rootfs. Do not run the repartition or erase sequence until a complete,
device-specific backup and recovery path has been independently validated.

`linuxium/3066-NAND` flow:
- Repartition NAND: `mtdparts=rk29xxnand:0x00008000@0x00002000(boot),0x00008000@0x0000A000(kernel),-@0x00012000(linux)` → rootfs on `/dev/mtdblock0` (~3.5 GB)
- Flash SD-boot kernel + parameter + loader via RKAndroidTool, boot from SD, `mkfs.ext4 /dev/mtdblock0`, extract rootfs, then flash a NAND-boot kernel built with `root=/dev/mtdblock0`
- NAND FTL module available as `rk30xxnand_ko.ko.3.0.36+`

## What must change for THIS stick (not "as-is")

| Item | Change |
|---|---|
| Machine | `CONFIG_ARCH_RK30=y` with an RK3066 board definition; a BOX board is only a candidate reference, not a proven match for rk30mtk |
| WiFi | `CONFIG_MT5931_MT6622=y` (this device = MT5931 + MT6622 combo), plus `CONFIG_WIFI_CONTROL_FUNC=y` |
| Mali | `CONFIG_MALI=m` (+`CONFIG_UMP`) — not enabled in any shipped config |
| GPIOs | WiFi power/reset pins per-PCB. MK802IIIS needed `RK30SDK_WIFI_GPIO_POWER_N=RK30_PIN3_PC7`, `RESET=RK30_PIN3_PD1` (stock = PD0/PA7). A wrong GPIO → `mt6622 reset_gpio is busy!` |
| Cmdline | Picuntu: `root=LABEL=linuxroot` (SD) or `root=/dev/mtdblock0` (NAND) + mtdparts |
| Defconfigs | `rk3066b_sdk` / `rk3066b_m701` are historical candidates and need source/build verification; do not select a BOX machine solely from another product |

## Rootfs options

- Picuntu `picuntu-linuxroot-0.9-RC3.tgz`; earlier `picuntu-linuxroot-0.9b.tgz`
- Picuntu 4.4/4.5 (`picuntu-4-4.tgz`, `picuntu-4-5.tgz`) + prebuilt `picuntu-kernel-4.4/4.5.img`
- Ubuntu 12.04 sample rootfs (`ubuntu1204-rfs.gz`, cpio)
- Debian Wheezy: `qemu-debootstrap --variant=minbase --arch=armhf wheezy ...`
- `home://io` edition — full 4 GB SD image, Mali HW accel, RK3066 (MK808)
- MarsBoard RK3066: `MarsBoard_RK3066_PX2_Ubuntu_Trusty_14.04_LTS..._Nand_V3.0.img.7z`

## Firmware requirement

Driver loads `/etc/firmware/WIFI_RAM_CODE` (139,776 B) via `filp_open` (no hotplug/udev needed). Copy from the tree (`drivers/net/wireless/mt5931/firmware_5931/`) or pull from the device. Also place `MTK_MT6622_E2_Patch.nb0` (7,976 B) for BT coexistence.

## References

- `github.com/Galland/Linux3188` (this kernel), `github.com/aloksinha2001/Linux3188` (upstream, extra `picuntu-kernel-*.img`)
- `github.com/aloksinha2001/picuntu-3.0.8-alok` Issue #2 — the MT5931 bring-up thread (Galland, usumfabricae's verified MK802IIIS procedure, RubCaj's GPIO gist `RubCaj/5841962`)
- `github.com/Galland/rk3x_kernel_3.0.36` (older recommended RK3066 kernel, `config.galland`)
- `github.com/Galland/rk30_linux_initramfs`, `github.com/Galland/rkflashtool_rk3066`
- `github.com/linuxium/3066-NAND`, `github.com/linuxerwang/rkflashkit`
- hwswbits.blogspot.com ("Compiling Picuntu kernel for RK3066"), autostatic.com ("Installing Linux on a RK3066 based device")
