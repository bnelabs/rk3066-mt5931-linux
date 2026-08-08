# Reproducible source lock

Review date: 2026-08-08

This is the source inventory used for the RK3066/rk30mtk investigation. Git
repositories are pinned to the exact `HEAD` commit observed on the date above
or, where a historical build was performed, to the exact tested commit. Web
documentation and gists are recorded by URL and retrieval date because they
do not provide a Git commit to lock.

The repository stores source references, build recipes, and hashes for the
attached unit. It does not vendor complete third-party trees, factory NAND
images, or proprietary device firmware. Several historical repositories have
no declared license or only `NOASSERTION` metadata; copying them into this
repository would create an avoidable redistribution problem. The source
owners' repositories remain the authoritative copies.

## Device, boot, and Rockchip tooling

| Source | Pinned revision / retrieval | Role in this work | Reuse boundary |
|---|---|---|---|
| [bnelabs/rk3066-mt5931-linux](https://github.com/bnelabs/rk3066-mt5931-linux) | `main` at the commit containing this file | Device audit, evidence, build recipes | Device-specific observations are not a factory image |
| [RK3066 datasheet](https://www.rock-chips.com/upload/DatasheetRK3066.pdf) | Retrieved 2026-08-08 | SoC architecture and peripheral reference | Does not describe the TCL PCB or DRAM timing |
| [U-Boot RK3066 board documentation](https://docs.u-boot.org/en/v2023.10/board/rockchip/rockchip.html) | Retrieved 2026-08-08 | Boot-ROM and loader constraints | General documentation, not a board loader |
| [rockchip-linux/rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool/tree/304f073752fd25c854e1bcf05d8e7f925b1f4e14) | `304f073752fd25c854e1bcf05d8e7f925b1f4e14` | Rockusb download/write protocol reference | Requires a compatible loader and download-mode device |
| [rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin/tree/ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4) | `ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4` | Public Rockchip loader/bin inventory | No matching TCL RK3066 loader was established |
| [Galland/rkflashtool_rk3066](https://github.com/Galland/rkflashtool_rk3066/tree/b92f18baf3f9693c706cdce5a71fc6a00d1c02da) | `b92f18baf3f9693c706cdce5a71fc6a00d1c02da` | Historical RK3066 backup/flash syntax | Fixed-block behavior must be checked before use |
| [linuxerwang/rkflashkit](https://github.com/linuxerwang/rkflashkit/tree/5628330e5ba3e87d67b2437755ca6d9593e8479b) | `5628330e5ba3e87d67b2437755ca6d9593e8479b` | Alternative Rockchip image toolkit | Tool capability is not board compatibility |
| [neo-technologies/rockchip-bootloader](https://github.com/neo-technologies/rockchip-bootloader/tree/2035ddf6a4fd79131b0c981b982569b9b359b213) | `2035ddf6a4fd79131b0c981b982569b9b359b213` | Bootloader source/reference | Not a verified TCL image or loader |
| [Galland/rk30_linux_initramfs](https://github.com/Galland/rk30_linux_initramfs/tree/0f8921d625acf4a91395b08837f506b1a7fdbbc0) | `0f8921d625acf4a91395b08837f506b1a7fdbbc0` | RK30 initramfs and image-layout reference | Historical format material only |
| [linuxium/3066-NAND](https://github.com/linuxium/3066-NAND/tree/e17db9c0e52965dbcd104b5a284a700778b00412) | `e17db9c0e52965dbcd104b5a284a700778b00412` | NAND-only Linux layout reference | Its partition map does not match this unit |
| [mpata/pytclfirmware](https://github.com/mpata/pytclfirmware/tree/841d982e5ad93df51e05cec69fd31c4c7ce7ac2f) | `841d982e5ad93df51e05cec69fd31c4c7ce7ac2f` | TCL firmware parsing/tooling clue | Not evidence of this model's image format |

## Legacy kernel, board, Wi-Fi, and graphics sources

| Source | Pinned revision / retrieval | Role in this work | Reuse boundary |
|---|---|---|---|
| [Galland/Linux3188](https://github.com/Galland/Linux3188/tree/3935f967e677948aee878a0ee29c4681b8fbe623) | `3935f967e677948aee878a0ee29c4681b8fbe623` | Tested 3.0.36 RK30 board, MT5931/MT6622, Mali/UMP, NAND and display tree | Closest source lineage; exact TCL board remains unproven |
| [Galland/MTK5931](https://github.com/Galland/MTK5931/tree/462989f3998e9818f5be76d5e43bac08720098c7) | `462989f3998e9818f5be76d5e43bac08720098c7` | Related MediaTek WCN driver source | Old vendor source; not mainline |
| [Galland/rk3x_kernel_3.0.36](https://github.com/Galland/rk3x_kernel_3.0.36/tree/7f18e42eb0423e27b431624f29d5d93af153c85f) | `7f18e42eb0423e27b431624f29d5d93af153c85f` | Older RK3066/Picuntu kernel comparison | Historical board assumptions |
| [omegamoon/rockchip-rk30xx-mk808](https://github.com/omegamoon/rockchip-rk30xx-mk808/tree/f5060af193af64d1748f5a68f91eb24c97e016ed) | `f5060af193af64d1748f5a68f91eb24c97e016ed` | MK808 RK3066 board comparison | MK808 GPIO and Wi-Fi are not TCL evidence |
| [olegk0/rk3x_kernel_3.0.36](https://github.com/olegk0/rk3x_kernel_3.0.36/tree/625c6e6759f72c0416e58b1bbe0ebd9e4ec17605) | `625c6e6759f72c0416e58b1bbe0ebd9e4ec17605` | RK3066 hard-float kernel comparison | Uses different board/wireless assumptions |
| [aloksinha2001/picuntu-3.0.8-alok](https://github.com/aloksinha2001/picuntu-3.0.8-alok/tree/008b8155d343dba447a1885b0acdb81a1a6f964a) | `008b8155d343dba447a1885b0acdb81a1a6f964a` | Picuntu lineage and MT5931 discussion | Historical image/source reference only |
| [MediaTek-Connectivity/mt6620](https://github.com/MediaTek-Connectivity/mt6620/tree/ebc1b2bf704c79438b277c673d411fc6258be6a6) | `ebc1b2bf704c79438b277c673d411fc6258be6a6` | Sibling WCN combo-driver design clues | Not a drop-in MT5931 driver |
| [rockchip-linux/mpp](https://github.com/rockchip-linux/mpp/tree/8f922ed34d240d71788613a327b7c2da8d35134f) | `8f922ed34d240d71788613a327b7c2da8d35134f` | Modern Rockchip media reference | Does not provide this board's VPU integration |
| [TCLOpenSource/TCL_Kernel_OpenSource](https://github.com/TCLOpenSource/TCL_Kernel_OpenSource/tree/4dc005f2828b38238f1481cefcad2a683e18d99f) | `4dc005f2828b38238f1481cefcad2a683e18d99f` | Search target for TCL kernel source | Repository contained no usable matching source in this review; no license asserted |

> The link above for the TCL repository is intentionally keyed to the exact
> observed commit in the table. It is a negative search result, not a claim
> that the repository contains a usable RK3066 tree.

## Image-format references

| Source | Pinned revision | Role |
|---|---|---|
| [dayongxie/rk2918_tools](https://github.com/dayongxie/rk2918_tools/tree/761b9f67df1c43abb46198671658d86a9c421282) | `761b9f67df1c43abb46198671658d86a9c421282` | `mkkrnlimg` KRNL header/CRC pack-unpack reference |
| [paxx12 Snapmaker `mkkrnlimg.c`](https://github.com/paxx12-snapmaker-u1/SnapmakerU1-Extended-Firmware/tree/e47e7ea9861723feefd5b9f7f8736fc038a6ab1e/tools/rk2918_tools) | `e47e7ea9861723feefd5b9f7f8736fc038a6ab1e` | Independent KRNL implementation comparison |
| [neo-technologies/rkflashtool `rkcrc.c`](https://github.com/neo-technologies/rkflashtool/blob/0a5ad3a81ad8fc993075ccf81377859b8745ff36/rkcrc.c) | `0a5ad3a81ad8fc993075ccf81377859b8745ff36` | Rockchip CRC implementation reference |
| [RubCaj RK30 SDMMC gist](https://gist.github.com/RubCaj/5841962) | Retrieved 2026-08-08 | MT5931 board/GPIO source comparison | Gist has no Git commit; verify before reuse |

## Mainline GPU/display and userland sources

| Source | Pinned revision / retrieval | Role | Boundary |
|---|---|---|---|
| [torvalds/linux](https://github.com/torvalds/linux/tree/a59f57e2aa127c5354168d2ec4bac920df1be4f4) | `a59f57e2aa127c5354168d2ec4bac920df1be4f4` | Tested ARM zImage, RK3066 reference DTB, Lima, VOP, HDMI | Reference board is not rk30mtk; no MT5931 driver |
| [Linux RK3066 DT directory](https://github.com/torvalds/linux/tree/a59f57e2aa127c5354168d2ec4bac920df1be4f4/arch/arm/boot/dts/rockchip) | Same Linux commit | Reference device-tree topology | Must be rewritten for exact power/GPIO/DRAM |
| [Linux Lima driver](https://github.com/torvalds/linux/tree/a59f57e2aa127c5354168d2ec4bac920df1be4f4/drivers/gpu/drm/lima) | Same Linux commit | Mali-400/450 DRM driver | Requires board DT and modern user space |
| [Mali Utgard binding](https://github.com/torvalds/linux/blob/a59f57e2aa127c5354168d2ec4bac920df1be4f4/Documentation/devicetree/bindings/gpu/arm%2Cmali-utgard.yaml) | Same Linux commit | RK3066 Mali binding | Binding support is not board bring-up |
| [Mesa Lima documentation](https://docs.mesa3d.org/drivers/lima.html) | Retrieved 2026-08-08 | User-space Mali-400 support | No kernel, Wi-Fi, VPU, or board support |
| [Debian ARM ports](https://www.debian.org/ports/arm/) | Retrieved 2026-08-08 | ARMv7 hard-float chroot target | User space only on stock Android |
| [Alpine downloads](https://alpinelinux.org/downloads/) | Retrieved 2026-08-08 | Small armv7 chroot target | User space only; no kernel driver |
| [OpenWrt armv7 rootfs](https://downloads.openwrt.org/releases/25.12.5/targets/armsr/armv7/) | Retrieved 2026-08-08 | Small networking-focused rootfs reference | Generic armsr image is not an RK3066 firmware |
| [Ubuntu supported architectures](https://ubuntu.com/project/docs/how-ubuntu-is-made/concepts/supported-architectures/) | Retrieved 2026-08-08 | ARMv7/armhf compatibility reference | Current server packages exceed this unit's practical memory budget |
| [Ubuntu Server requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) | Retrieved 2026-08-08 | Memory-fit constraint | Not a recommendation to flash Ubuntu |
| [Kali ARM documentation](https://www.kali.org/docs/arm/) | Retrieved 2026-08-08 | Purpose-built ARM userland reference | No generic RK3066 target found |
| [Buildroot manual](https://buildroot.org/downloads/manual/manual.html) | Retrieved 2026-08-08 | Custom rootfs/kernel/appliance route | Requires exact board bring-up |

## How to refresh this lock

Run `git ls-remote --symref URL HEAD` for each Git source, record the full
40-character object ID, and rerun the repository's capture verifier against a
fresh read-only device capture. A new source revision is a research change:
record what was actually tested rather than silently moving a floating link.
