# Hardware, firmware, storage, and boot findings

Review date: 2026-08-08

This document records the attached unit rather than treating a generic RK3066
board as equivalent. The observations below came from the live ADB connection
for serial HNPKB1AIA4. No flash, reboot, partition write, module replacement,
or other device mutation was performed during this review.

## Confirmed live baseline

| Area | Observation | Consequence |
|---|---|---|
| USB/ADB | Rockchip vendor 0x2207, product 0x0010; normal ADB mode; uid 0 | Recovery work is possible, but the unit is not currently in maskrom |
| Board identity | rk30mtk, RK30board, Android 4.2.2, kernel 3.0.36+ | Generic MK808/MK802 instructions are references only |
| CPU | Dual ARMv7 Cortex-A9, VFPv3 and NEON | ARMv7 hard-float Debian/Ubuntu/Alpine userlands are architecturally plausible |
| Memory | 877,540 kB reported by /proc/meminfo | Modern full Ubuntu Server is a poor fit; small rootfs/chroot is reasonable |
| GPU | Mali-400; Android mali and ump modules are loaded | The Android GPU path is active at kernel-module level; this is not a 3D benchmark |
| Wireless | MT5931 on SDIO 037a:5931; MT6622 companion; wlan0 and p2p0 | The exact stock driver is already present; native Linux needs the old vendor stack or a replacement adapter |
| Storage | /data is an approximately 1 GB ext4 partition; /mnt/sdcard is an approximately 5.7 GB vfat partition | A rootfs should live on ext4, an ext4 image, or an external card; do not unpack a Unix rootfs directly onto vfat |

The live kernel log identifies the SDIO card as MT5931 and reports the
Rockchip MT5931 driver version 3.08. The current Android driver exposes
Wireless Extensions v22. The interface was present but not associated during
the audit.

## Firmware and kernel module chain

The stock system contains the following separate pieces:

| Artifact | Role | What it means for a port |
|---|---|---|
| /system/lib/modules/mt5931.ko | Real MT5931 Wi-Fi driver; internally named wlan; version 3.08 | Built for 3.0.36+, with the stock vendor ABI; not a drop-in module for mainline |
| /system/lib/modules/wlan.ko | Small Rockchip launcher shim | Loading the shim alone does not replace the real driver |
| /system/lib/modules/rkwifi.ko | Board-specific Wi-Fi power/platform control | GPIO and regulator details are part of the exact PCB port |
| /etc/firmware/WIFI_RAM_CODE | MT5931 firmware, 139,776 bytes | The Linux3188 source tree carries a same-named firmware artifact |
| /etc/firmware/MTK_MT6622_E2_Patch.nb0 | MT6622 Bluetooth/coexistence patch, 7,976 bytes | Used by the stock Android image; a matching native-Linux loader was not established |
| /system/lib/modules/mali.ko and ump.ko | Legacy Android Mali-400 and UMP interfaces | A native legacy kernel needs matching kernel and user-space graphics interfaces |

The stock module has vermagic 3.0.36+ and no __versions section. That is useful
for identifying the build family, but it does not make the binary safe to load
into another kernel. Preserve the device copies before experimenting and treat
both firmware blobs as a redistribution/licensing question. Bluetooth has an
additional uncertainty: the public Linux trees reviewed here do not establish
a complete MT6622 patch/initialization path for this exact board.

## Exact NAND map from the attached unit

The live /proc/cmdline reports this layout:

    mtdparts=rk29xxnand:0x00002000@0x00002000(misc),0x00008000@0x00004000(kernel),0x00008000@0x0000c000(boot),0x00010000@0x00014000(recovery),0x00020000@0x00024000(backup),0x00040000@0x00044000(cache),0x00200000@0x00084000(userdata),0x00002000@0x00284000(kpanic),0x00100000@0x00286000(system),-@0x00386000(user)

The corresponding live /proc/mtd entries are:

| MTD | Name | Size | Offset from cmdline |
|---|---|---:|---:|
| mtd0 | misc | 4 MiB | 0x00002000 |
| mtd1 | kernel | 16 MiB | 0x00004000 |
| mtd2 | boot | 16 MiB | 0x0000c000 |
| mtd3 | recovery | 32 MiB | 0x00014000 |
| mtd4 | backup | 64 MiB | 0x00024000 |
| mtd5 | cache | 128 MiB | 0x00044000 |
| mtd6 | userdata | 1 GiB | 0x00084000 |
| mtd7 | kpanic | 4 MiB | 0x00284000 |
| mtd8 | system | 512 MiB | 0x00286000 |
| mtd9 | user | approximately 5.7 GiB | 0x00386000 |

This differs from the example values in the existing Path A notes. In
particular, the attached unit's recovery starts at 0x14000 and is 0x10000
sectors in the command-line map; its kernel starts at 0x4000 and is 0x8000
sectors. The example offsets must not be copied to this unit.

The Linuxium NAND example also creates a new partition map and then calls the
new first Linux partition mtdblock0. On this untouched unit mtdblock0 is the
4 MiB misc partition. Formatting or mounting it as a Linux rootfs without a
deliberate, fully backed-up repartition is unsafe.

## Boot and recovery implications

The unit is currently in normal ADB mode, not maskrom. A native-kernel
experiment therefore needs a controlled bootloader/recovery procedure and
known-good backups of at least misc, kernel, boot, recovery, parameter/cmdline
information, system, userdata, and user data. The exact command syntax and
sector units must be checked against the selected flashing tool.

The observed USB product 0x0010 is the Android/ADB state. The Rockchip
Rockusb tools expect the RK30 download interface at 0x2207:0x300a. Do not
assume that adb reboot bootloader produces that interface; observe the USB
identity after any explicitly approved mode change. A 0x300a device is
necessary evidence of a usable Rockusb path, not proof that the available
loader matches this TCL board.

The [U-Boot RK3066 documentation](https://docs.u-boot.org/en/v2023.10/board/rockchip/rockchip.html)
records that the RK3066 BootROM has no direct SDMMC boot support. An SD card
therefore cannot be the sole rescue mechanism: a compatible loader must
already initialize the chip or be supplied through USB OTG.

The relevant primary tooling references are:

- [Galland/rkflashtool_rk3066](https://github.com/Galland/rkflashtool_rk3066), including its README backup/flash syntax
- [linuxerwang/rkflashkit](https://github.com/linuxerwang/rkflashkit), an alternative Rockchip flashing toolkit
- [rockchip-linux/rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool), the Rockchip USB download/write tool
- [Galland/rk30_linux_initramfs](https://github.com/Galland/rk30_linux_initramfs), historical RK30/RK31 initramfs files
- [linuxium/3066-NAND](https://github.com/linuxium/3066-NAND), a historical NAND-only layout and boot flow

These repositories document hardware families and procedures, not a verified
recovery image for rk30mtk. The safest first native step is read-only backup
and image inspection; it is not flashing.

## Board-specific gaps still open

No public exact rk30mtk board DTS, schematic, or serial-specific kernel source
was found in this review. The generic Rockchip source gives plausible
registers and board families, but the following must still be derived from the
stock image or PCB before a native boot:

1. Wi-Fi power, reset, interrupt, and SDIO bus wiring.
2. MT6622 Bluetooth power and UART/SDIO wiring.
3. Mali clocks, power domain, interrupt routing, and reserved memory.
4. Display/VOP/HDMI wiring and the actual connector path.
5. DRAM timing, bootloader handoff, kernel load address, and exact partition
   parameters.

This is why the exact board remains the main native-Linux risk even though the
SoC-level GPU and Wi-Fi source components are available.
