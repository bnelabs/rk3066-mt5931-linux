# Kernel, Wi-Fi, and GPU options

Review date: 2026-08-08

This document separates the three driver questions that are easy to conflate:

1. Can the exact MT5931 Wi-Fi chip run outside Android?
2. Can the Mali-400 GPU run with a current Linux graphics stack?
3. Can both be delivered by one kernel on this exact rk30mtk board?

The first answer is yes only through an old vendor kernel today. The second
answer is materially better than the original review suggested. The third
answer is not yet demonstrated because the exact board description is missing.

## Executive conclusion

| Route | MT5931 Wi-Fi | Mali-400 / display | Exact-board work | Overall judgment |
|---|---|---|---|---|
| Stock Android plus chroot | Existing driver works | Existing Android GPU remains available to Android | None | Lowest risk; best first move |
| Legacy Linux3188 / 3.0.36 | Vendor MT5931/MT6622 source exists | Legacy Mali-400 and Rockchip display code exist | High: board config, GPIO, memory, boot | Closest route to all original hardware, but old and fragile |
| Current mainline kernel | No MT5931 driver | RK3066 DT, VOP/HDMI, and Lima Mali-400 support exist | High: exact DTS, boot, Wi-Fi substitute | Best modern GPU route; use USB Wi-Fi or host Wi-Fi |
| Mainline plus a new MT5931 port | Driver source exists only in old vendor trees | Lima route remains available | Very high: driver port plus board bring-up | Engineering project, not a reasonable first experiment |

The important correction is that “mainline has no MT5931” must not be read as
“mainline has no RK3066 GPU support.” Wi-Fi and GPU have different feasibility
profiles.

## 1. Exact stock driver chain

The attached unit confirms:

- SDIO device 037a:5931 and the MT6622 companion.
- mt5931.ko, internally named wlan, with vermagic 3.0.36+.
- rkwifi.ko for board power/platform control.
- WIFI_RAM_CODE and the MT6622 patch in /etc/firmware.
- Android mali.ko and ump.ko loaded in the live kernel.

The source-side equivalents are visible in:

- [Galland/Linux3188 MT5931 Kconfig](https://raw.githubusercontent.com/Galland/Linux3188/master/drivers/net/wireless/mt5931/Kconfig)
- [Galland/Linux3188 MT5931 module build](https://raw.githubusercontent.com/Galland/Linux3188/master/drivers/net/wireless/mt5931/Makefile.module)
- [Galland/Linux3188 MT5931 source tree](https://github.com/Galland/Linux3188/tree/master/drivers/net/wireless/mt5931)
- [Galland/MTK5931](https://github.com/Galland/MTK5931), the related MediaTek WCN source repository

This is a full-MAC vendor design. The firmware owns most MAC management and
the driver exposes a legacy WEXT/cfg80211 integration. A modern kernel port
would need firmware API changes, cfg80211/netdevice API changes, and exact
SDIO power sequencing. Monitor mode and packet injection are not realistic
expectations: the checked vendor glue does not implement a usable monitor
interface or management-frame transmit path.

## 2. Legacy Linux3188: the all-hardware route

[Galland/Linux3188](https://github.com/Galland/Linux3188) is a 3.0.36-era
Rockchip tree with RK30 board code, MT5931/MT6622 source, NAND support,
Rockchip display code, and a legacy Mali tree. It is the most direct source
lineage for this unit, but it is not a ready image.

### Wi-Fi and Bluetooth

The tree contains:

- drivers/net/wireless/mt5931
- firmware_5931/WIFI_RAM_CODE
- drivers/net/wireless/rkwifi
- MT6622 combo support and RK30 board-level Wi-Fi control

The Linux3188 default .config explicitly has MT5931 and MT5931_MT6622
disabled. The checked source therefore proves availability, not a working
configuration for rk30mtk. The board file has multiple candidate GPIO
definitions and SDIO wiring paths; choosing one without extracting the stock
board values is unsafe.

The MT5931 Kconfig symbols are boolean selections that depend on the wireless
and MMC subsystems and select legacy WEXT/cfg80211 support. The normal
in-tree Makefile builds the driver into the kernel; a separate legacy module
Makefile exists. That distinction matters when comparing the stock mt5931.ko
to a Linux3188 build.

Bluetooth should be scored separately from Wi-Fi. The stock Android image has
an MT6622 patch file and the live Android kernel powers the companion, but the
old Linux source mainly supplies UART/HCI and RK30 GPIO/IRQ glue. No complete,
target-verified MT6622 initialization/patch loader was found in the named
Linux trees. Native Linux Bluetooth is therefore a higher-risk follow-on than
MT5931 station mode.

### Mali and display

The same source tree includes a legacy Mali-400/UMP implementation:

- [Mali Kconfig](https://raw.githubusercontent.com/Galland/Linux3188/master/drivers/gpu/mali/Kconfig) selects UMP and Mali-400 when CONFIG_MALI is enabled.
- [Mali Makefile](https://raw.githubusercontent.com/Galland/Linux3188/master/drivers/gpu/mali/Makefile) selects the RK30 Mali-400 platform, MMU, UMP, and PMM settings.
- [RK30 Mali resource map](https://raw.githubusercontent.com/Galland/Linux3188/master/drivers/gpu/mali/mali/arch-pb-rk30-m400-4/config.h) describes the old GP/PP/MMU register and interrupt layout.

However, the checked-in default .config has CONFIG_MALI and CONFIG_UMP
disabled. The old driver is therefore a build ingredient, not proof that the
published kernel enables 3D. A successful graphics system also needs matching
EGL/GLES/UMP user-space libraries, display memory reservations, clocks, power,
and board display initialization. The Android modules being loaded prove only
that the stock kernel has a live legacy path.

### Why this route remains useful

It is the only source family in this review that combines the exact MT5931
driver lineage with RK3066-era board code and the legacy Mali stack. It is also
the route most likely to preserve the original BT/Wi-Fi behavior. The costs
are an end-of-life kernel, an old user-space ABI, uncertain board GPIOs, and
the need for a carefully matched boot image.

## 3. Current mainline: the GPU path is real

Current [Linux mainline RK3066 source](https://github.com/torvalds/linux/tree/master/arch/arm/boot/dts/rockchip)
contains RK3066 device trees, and the current tree contains:

- [RK3066 SoC device tree](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm/boot/dts/rockchip/rk3066a.dtsi), including VOP/display-subsystem nodes, RK3066 HDMI, MMC/SDIO, power domains, and a Mali node.
- [RK3066 reference board DTS](https://github.com/torvalds/linux/blob/master/arch/arm/boot/dts/rockchip/rk3066a-mk808.dts), which enables a VOP/HDMI path and an SDIO device.
- [RK3066 HDMI DRM driver](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/rockchip/rk3066_hdmi.c).
- [Rockchip DRM Kconfig](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/rockchip/Kconfig), including RK3066 HDMI and VOP symbols.
- [Lima DRM driver](https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/lima), with a Kconfig entry for ARM Mali-400/450.
- [Mali Utgard device-tree binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/gpu/arm%2Cmali-utgard.yaml), which explicitly accepts rockchip,rk3066-mali plus arm,mali-400.
- [RK3066 HDMI binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/display/rockchip/rockchip%2Crk3066-hdmi.yaml).

The relevant mainline build ingredients are DRM_ROCKCHIP, ROCKCHIP_VOP,
ROCKCHIP_RK3066_HDMI, and DRM_LIMA, plus the normal ARM device-tree, clock,
MMC/SDIO, and power-domain support. The exact final symbol set depends on the
chosen kernel release and board description.

The official [Mesa Lima documentation](https://docs.mesa3d.org/drivers/lima.html)
states that Lima supports ARM Mali Utgard GPUs, including Mali-400, with a
modern DRM/KMS user-space stack. It targets OpenGL ES 2.0 and OpenGL 2.1.
Lima is a GPU driver; it does not by itself provide a display pipeline, video
decode, or a board-specific power configuration.

### Reference-board limitation

The mainline MK808 DTS is not the attached board. Its SDIO child is a
Broadcom BCM4329 device and its Wi-Fi regulator uses a board-specific GPIO.
That is useful evidence for the RK3066 display/GPU plumbing, not a DTS to flash
or copy unchanged. The rk30mtk device needs its own:

- compatible/model and boot aliases;
- DRAM and reserved-memory settings;
- Mali interrupts, clocks, power domain, and regulator;
- VOP/HDMI connector and pinctrl graph;
- SDIO bus, MT5931 child, regulator, reset/interrupt GPIOs;
- MT6622 companion control;
- NAND/partition and bootloader handoff.

### What mainline can and cannot improve

Mainline plus Lima can provide a modern GPU/DRM/KMS foundation and is a much
more credible long-term graphics path than the legacy Android Mali ABI.
It cannot make the MT5931 work: the current
[mainline MediaTek wireless tree](https://github.com/torvalds/linux/tree/master/drivers/net/wireless/mediatek)
does not contain an MT5931 driver. It also does not automatically provide the
old Rockchip VPU hardware-decoder path.

The practical modern combination is therefore:

    mainline RK3066 DT + Lima + RK3066 HDMI + external in-tree Wi-Fi

or, during development, mainline graphics with networking supplied by the
Android host through a chroot.

## 4. Why an MT5931 mainline port is a separate project

The old driver depends on Linux 3.0-era interfaces including legacy cfg80211
callbacks, WEXT, Android early-suspend assumptions, old netdevice APIs, and
set_fs-based firmware file access. Modern kernels removed or changed several
of these interfaces. The SDIO primitives themselves are less problematic,
but that does not remove the driver and firmware integration work.

The port would still need:

1. a request_firmware-based loading path;
2. modern cfg80211/nl80211 operations for station mode;
3. netdevice and power-management cleanup;
4. an RK3066 DT node and regulator/GPIO sequencing;
5. firmware boot, scan, authentication, suspend, and recovery tests;
6. a decision about the MT6622 companion driver and its missing/board-specific
   initialization path.

For a working station-only port, the existing two-to-four person-month
estimate remains a planning heuristic, not a promise. It is not justified for
the first bring-up when a USB adapter or Android-host networking is available.

## 5. Recommended decision

If the objective is usable Linux software on this attached unit, start with an
Alpine or minimal Debian chroot and leave Android's kernel, Wi-Fi, GPU, and
display stack intact.

If the objective is native Linux with modern GPU acceleration, prototype a
mainline RK3066 board description and Lima/HDMI path while using an external
Wi-Fi adapter. Do not sacrifice the working MT5931 until the exact board
description is reconstructed.

If the objective is every original peripheral, use Linux3188 as a controlled
legacy experiment. Enable MT5931/MT6622 and Mali deliberately, derive GPIOs
from the stock image/PCB, treat Bluetooth as a separate bring-up, boot a
removable rootfs first, and keep the current NAND layout unchanged until
recovery is proven.

## Related primary repositories

- [Galland/Linux3188](https://github.com/Galland/Linux3188)
- [Galland/MTK5931](https://github.com/Galland/MTK5931)
- [Galland/rk3x_kernel_3.0.36](https://github.com/Galland/rk3x_kernel_3.0.36)
- [omegamoon/rockchip-rk30xx-mk808](https://github.com/omegamoon/rockchip-rk30xx-mk808)
- [olegk0/rk3x_kernel_3.0.36](https://github.com/olegk0/rk3x_kernel_3.0.36)
- [MediaTek-Connectivity/mt6620](https://github.com/MediaTek-Connectivity/mt6620)
