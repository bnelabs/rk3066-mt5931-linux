# Hardware and software source matrix

Review date: 2026-08-08

This matrix records what each source actually contributes. Most Rockchip
repositories are historical, board-specific, or both. A repository being
public or recently mirrored does not mean that its image, loader, partition
file, or firmware is suitable for rk30mtk.

## Device and boot sources

| Source | Useful evidence | Reuse boundary |
|---|---|---|
| [Rockchip RK3066 datasheet](https://www.rock-chips.com/upload/DatasheetRK3066.pdf) | SoC-level CPU, memory, peripheral, and boot reference | Does not describe the TCL PCB, DRAM timing, loader, or GPIO wiring |
| [bnelabs/rk3066-mt5931-linux](https://github.com/bnelabs/rk3066-mt5931-linux) | Live ADB audit, module/firmware inventory, exact cmdline and current feasibility notes | Device-specific evidence, but the audit is not an independently signed factory image |
| [rockchip-linux/rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool) | Rockchip USB download/write protocol and current scanner source | Needs a compatible loader and the correct USB download state |
| [rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin) | Public Rockchip bootloader/bin repository for several SoC families | No matching rk30mtk RK3066 loader was established; do not substitute binaries |
| [Galland/rkflashtool_rk3066](https://github.com/Galland/rkflashtool_rk3066) | Linux RK3066/RK3188 backup and flash utility | Historical tool with fixed-block behavior; verify sector units and target partition first |
| [linuxerwang/rkflashkit](https://github.com/linuxerwang/rkflashkit) | Alternative open-source Rockchip image toolkit | General Rockchip tool, not proof of this board's loader compatibility |
| [Galland/rk30_linux_initramfs](https://github.com/Galland/rk30_linux_initramfs) | Historical RK30/RK31 initramfs and fake-ramdisk material | Boot-image format reference only |
| [linuxium/3066-NAND](https://github.com/linuxium/3066-NAND) | NAND-only Ubuntu layout and historical boot procedure | Its repartitioning and mtdblock0 assumptions do not match the untouched attached unit |

The attached USB identity is 0x2207:0x0010 in Android ADB mode. Rockusb tools
expect 0x2207:0x300a. The [U-Boot RK3066 board documentation](https://docs.u-boot.org/en/v2023.10/board/rockchip/rockchip.html)
also records no direct RK3066 BootROM SDMMC boot. These facts make loader and
recovery verification a prerequisite, not an implementation detail.

## Kernel, board, and peripheral sources

| Source | Useful evidence | Reuse boundary |
|---|---|---|
| [Galland/Linux3188](https://github.com/Galland/Linux3188) | 3.0.36 RK30/RK31 board code, MT5931/MT6622 driver, legacy Mali-400/UMP, NAND, Rockchip display | Closest source lineage; checked default config targets RK3188 and disables MT5931/Mali |
| [Galland/MTK5931](https://github.com/Galland/MTK5931) | Related MediaTek WCN Wi-Fi/BT source | Old vendor source; no exact TCL board integration |
| [Galland/rk3x_kernel_3.0.36](https://github.com/Galland/rk3x_kernel_3.0.36) | Older Picuntu-oriented RK3066 kernel source | Historical alternative; still needs exact board and peripheral values |
| [omegamoon/rockchip-rk30xx-mk808](https://github.com/omegamoon/rockchip-rk30xx-mk808) | MK808 RK3066 board/kernel reference | MK808 hardware and Wi-Fi assumptions are not rk30mtk evidence |
| [olegk0/rk3x_kernel_3.0.36](https://github.com/olegk0/rk3x_kernel_3.0.36) | RK3066/MK808 reference with RK901 Wi-Fi | Useful kernel history; wrong wireless hardware |
| [aloksinha2001/picuntu-3.0.8-alok](https://github.com/aloksinha2001/picuntu-3.0.8-alok) | Picuntu integrated kernel and historical MT5931 discussion | Old image/source lineage; not a verified TCL image |
| [MediaTek-Connectivity/mt6620](https://github.com/MediaTek-Connectivity/mt6620) | Sibling MT6620 combo driver and WCN design clues | Not a drop-in MT5931 driver and not mainline |

No inspected public repository contained a target-specific rk30mtk DTS,
schematic, serial-specific loader, or complete verified TCL NAND image. The
generic board files are therefore starting points for source archaeology, not
flash candidates.

## Modern kernel and graphics sources

| Source | Finding | Reuse boundary |
|---|---|---|
| [Linux mainline RK3066 DTs](https://github.com/torvalds/linux/tree/master/arch/arm/boot/dts/rockchip) | RK3066 SoC/reference DTs, VOP, HDMI, SDIO, power domains, and GPU nodes | Reference-board DTS must be rewritten for rk30mtk |
| [Linux Lima DRM driver](https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/lima) | Current DRM driver for Mali-400/450 | Requires a correct DT, clocks, interrupts, power, and modern Mesa |
| [Mali Utgard binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/gpu/arm%2Cmali-utgard.yaml) | Explicit rockchip,rk3066-mali plus arm,mali-400 binding | Binding support is not proof of this board's wiring |
| [RK3066 HDMI driver](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/rockchip/rk3066_hdmi.c) | Current display-controller support | HDMI pinctrl/connector graph is still board-specific |
| [Mesa Lima documentation](https://docs.mesa3d.org/drivers/lima.html) | Mali-400 user-space driver support and OpenGL ES 2.0/OpenGL 2.1 target | Does not provide Wi-Fi, VPU decode, or board bring-up |
| [Mainline MediaTek wireless tree](https://github.com/torvalds/linux/tree/master/drivers/net/wireless/mediatek) | Current MediaTek tree does not contain MT5931 | Built-in stock Wi-Fi remains the mainline gap |

## Userland sources

| Source | Current official position | Fit |
|---|---|---|
| [Debian ARM ports](https://www.debian.org/ports/arm/) | armhf targets ARMv7 hard-float devices; stable armhf documentation covers VFPv3 | Best general-purpose chroot |
| [Alpine downloads](https://alpinelinux.org/downloads/) | Official armv7 standard image is available | Best lightweight chroot |
| [OpenWrt armsr/armv7](https://downloads.openwrt.org/releases/25.12.5/targets/armsr/armv7/) | Official generic armv7 rootfs and kernel artifacts are published | Very small networking-focused chroot; not a replacement kernel for this board |
| [Ubuntu supported architectures](https://ubuntu.com/project/docs/how-ubuntu-is-made/concepts/supported-architectures/) | armhf covers ARMv7 hard-float/VFPv3-D16 | Architecture fits, but current server memory minimum is too tight |
| [Ubuntu Server requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) | Current server guidance lists a 1 GB minimum | Do not treat modern Ubuntu Server as a native target for 877,540 kB RAM |
| [Kali ARM](https://www.kali.org/docs/arm/) and [official images](https://arm.kali.org/images.html) | Device-specific images; no generic RK3066 target found | Use only as a purpose-built Debian chroot |
| [Buildroot manual](https://buildroot.org/downloads/manual/manual.html) | Builds custom ARM kernels, bootloaders, toolchains, and root filesystems | Best native appliance builder, not a ready chroot |

## Evidence ranking

1. Live ADB observations and the exact device audit are strongest for this
   unit.
2. Source files in a matching kernel family prove that a component existed,
   not that the board configuration is correct.
3. Generic RK3066/MK808 images, loaders, and partition files are historical
   references only.
4. Current mainline/Mesa sources materially improve the GPU outlook, but do
   not close the exact-board or MT5931 gaps.
