# Stock boot, kernel, and firmware forensics

Capture date: 2026-08-08
Device: rk30mtk, serial HNPKB1AIA4
Method: read-only ADB/root capture; no partition, bootloader, module, or
firmware write was attempted.

This is the strongest device-specific result in the current investigation. It
does not prove that a newly built kernel is safe to boot, but it identifies the
stock image contract and narrows the source search to the correct RK30 board
family.

## Captured partition contract

The live command line reports the following MTD map:

    mtdparts=rk29xxnand:0x00002000@0x00002000(misc),0x00008000@0x00004000(kernel),0x00008000@0x0000c000(boot),0x00010000@0x00014000(recovery),0x00020000@0x00024000(backup),0x00040000@0x00044000(cache),0x00200000@0x00084000(userdata),0x00002000@0x00284000(kpanic),0x00100000@0x00286000(system),-@0x00386000(user)

The read-only character devices /dev/mtd/mtd1ro, /dev/mtd/mtd2ro, and
/dev/mtd/mtd3ro were pulled with ADB. The captured raw sizes are 16 MiB,
16 MiB, and 32 MiB respectively. The raw SHA-256 values are in
[stock-capture-sha256.txt](stock-capture-sha256.txt); the binary captures
are intentionally not committed.

## Rockchip KRNL images

Both the stock kernel and boot partitions use the standard Rockchip KRNL
wrapper used by mkkrnlimg:

    offset 0x00: 4-byte ASCII magic KRNL
    offset 0x04: little-endian payload length
    offset 0x08: payload
    after payload: 4-byte Rockchip CRC
    remaining partition bytes: padding

The exact observations are:

| Partition | Header payload length | Payload | Verification |
|---|---:|---|---|
| mtd1 / kernel | 0x00884024 = 8,929,316 bytes | raw Linux kernel payload | mkkrnlimg -r unpacked it; payload hash begins 6ccff2f |
| mtd2 / boot | 0x0021797e = 2,193,790 bytes | gzip-compressed cpio ramdisk | mkkrnlimg -r unpacked it; gzip decompression succeeds |

The mtd1 payload has a 4-byte CRC immediately after the payload at offset
0x88402c. The mtd2 payload has the same structure. The bytes after the
four-byte magic happen to make the stock hexdump look like KRNL$@... and
KRNL~y!...; the authoritative fields are the magic and little-endian length
above.

The format was independently checked with the mkkrnlimg.c implementation from
[dayongxie/rk2918_tools](https://github.com/dayongxie/rk2918_tools/tree/761b9f67df1c43abb46198671658d86a9c421282).
This confirms an image-packaging route for future offline work; it is not a
license to write a newly built image to NAND.

## Recovery image and kernel identity

mtd3 is an Android boot image with:

    magic          ANDROID!
    page size      16384 (0x4000)
    kernel size    0x00884024 = 8,929,316
    kernel address 0x60408000
    ramdisk size   0x003e9551 = 4,101,457
    ramdisk addr   0x62000000
    second size    0
    second address 0x60f00000
    tags address   0x60088000

The kernel starts at page 1 (0x4000) and the ramdisk starts at 0x88c000.
Most importantly:

    SHA-256(mtd1 KRNL payload)       = 6ccff2f036b4b9a6c8007e2dce9cf5850d03305c0ee0df450c18bca166954679
    SHA-256(recovery kernel payload) = 6ccff2f036b4b9a6c8007e2dce9cf5850d03305c0ee0df450c18bca166954679

The extracted kernel payloads compare byte-for-byte. The stock recovery is
therefore a second, inspectable copy of the exact running kernel, not an
independent kernel candidate.

## Ramdisk and board clues

The stock boot ramdisk contains the expected RK30 Android init files:

- init.rk30board.rc, init.rk30board.usb.rc, and ueventd.rk30board.rc;
- MT5931-specific services mtk_psupplicant, mtk_wsupplicant, and
  mtk_ap_daemon;
- Wi-Fi state directories and the stock wpa_supplicant path;
- Rockchip NAND helper modules for the 3.0.36 ABI.

The uevent rules explicitly grant access to the graphics and media devices:

    /dev/mali  0666
    /dev/ump   0666
    /dev/rga   0666
    /dev/vpu   0666
    /dev/vpu_service 0666
    /dev/ion   0666

That matches the live Android observation that Mali-400 acceleration is
available through the legacy /dev/mali and /dev/ump interfaces, while no DRM
/dev/dri device is present. The ramdisk also confirms the historical
Android-side MT5931 service chain, but it does not expose the original board
Kconfig or a device tree.

## Stock module and firmware inventory

The following stock files were hashed in /system and /system/etc/firmware:

| File | Size | SHA-256 |
|---|---:|---|
| mali.ko.3.0.36+ | 163,783 | 4fc7ab1fa1e894595926aa86c1818cb312e682cc9665eb7a3b55cc35ae7e4346 |
| ump.ko.3.0.36+ | 44,593 | c5d8b41ae33a561e49f4f248ba679e647960c87e71515181015a230bf86cfe17 |
| mt5931.ko | 402,614 | 46d0b9967017e5341bc974fb0beac0e447a33c02f8720b3cbf5b15c8b8536b1b |
| rkwifi.ko | 577,318 | 45fce53d0c80ea916ff5638426022d51f4a029495466a0988bbda8a59efcc016 |
| wlan.ko | 2,778 | 633d0939ee3d2a3cab0f6e0d93b72d1351079860fe1148ac273412ff3f8cd4b5 |
| vpu_service.ko.3.0.36+ | 20,743 | 2c8a408de35a1ca201b413fb4ddd36a15bd960d73d6d9f0ed974234fbb950dc7 |
| rk30_mirroring.ko.3.0.36+ | 18,783 | bc12f91514331f5414ad5fc3216bd58b612c84d1f053aa97344ff0146c327e6d |
| WIFI_RAM_CODE | 139,776 | af345785369ee0a53efd85654810ba47463833186201fb3d3e9f9ac8195ca53c |
| MTK_MT6622_E2_Patch.nb0 | 7,976 | b797be5b03eddfc17f422fed556e8a757a9fc9c6a473bcbc298501c294f8c5a3 |
| bdata.SD31.bin | 1,024 | 235486b00176902063842c9f124024d8db2681c691db6cf2b205f7e85b83780c |

The device WIFI_RAM_CODE is byte-identical to the same-named file in the
tested [Galland/Linux3188](https://github.com/Galland/Linux3188/tree/3935f967e677948aee878a0ee29c4681b8fbe623)
source snapshot. This is a strong exact-firmware match. The module itself
reports alias=sdio:c*v037Ad5931* and vermagic=3.0.36+ SMP preempt mod_unload
ARMv7, which is why the blob match does not make the Android module usable in
a modern kernel.

## Board-family match and build consequence

The running kernel identifies itself as:

    Linux version 3.0.36+ (arron@cyxtech-server) (gcc version 4.6.x-google...) #67 SMP PREEMPT Wed Jun 26 19:00:44 CST 2013
    Machine: RK30board

Its logs report tps65910_i2c_probe, Mali400 inside of rk3066, MT5931 SDIO
WiFi driver (Powered by Rockchip,Ver 3.08), and the Rockchip Wi-Fi
GPIO/card-detect sequence. The public board-rk30-box.c plus
board-rk30-sdk-sdmmc.c source has the matching RK30/RBox path and, for the
non-RK3066B branch, the same default MT5931 power/reset GPIOs, PC6 and PD1.

A disposable Docker build configured as SOC_RK3066=y and
MACH_RK30_BOX_PIZZA=y compiled these source components together:

    arch/arm/mach-rk30/board-rk30-box.o
    arch/arm/mach-rk30/board-rk30-sdk-rfkill.o
    drivers/net/wireless/mt5931/built-in.o
    drivers/gpu/mali/mali/mali.o
    drivers/gpu/mali/ump/ump.o
    drivers/video/rockchip/lcdc/rk30_lcdc.o
    drivers/video/rockchip/hdmi/rk30/rk30_hdmi.o
    drivers/video/rockchip/hdmi/rk30/rk30_hdmi_hw.o

The component result is a material improvement over the previous missing
board source assessment: the generic RK30-box candidate is now compile-
confirmed for RK3066 + MT5931/MT6622 + legacy Mali/UMP + display/HDMI. It is
still not proof that the TCL PCB is the Pizza variant. The exact GPIO,
regulator, DRAM, NAND, display, and bootloader values must be confirmed before
booting it.

When HDMI is enabled, the builder injects a declaration-only compatibility
header because the public board file references hdmi_init_lcdc without a
prototype. The header changes no ABI or driver behavior; it makes the
historical GCC 4.6 source compile under GCC 12.

The full Linux 3.0.36 zImage attempt stopped in generic fs/fat/dir.c at old
ARM put_user inline-assembly register assertions under GCC 12. That is a
toolchain compatibility blocker outside the board, Wi-Fi, GPU, or display
objects; it is recorded rather than hidden behind an unreviewed kernel patch.

## Deployment decision

The safe next step is offline source and image work: recover the exact board
configuration, preserve the stock image contract, and package only after the
kernel links with a compatible compiler or an explicitly reviewed compatibility
patch. Without removable storage or a verified recovery loader, flashing a
newly built image is not reasonable. The stock Android system remains the best
working deployment for Wi-Fi and GPU, and a chroot can add user-space tools but
cannot add a kernel driver or a DRM device.
