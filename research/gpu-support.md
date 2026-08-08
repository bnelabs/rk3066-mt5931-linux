# RK3066 Mali-400 GPU support research

**Device:** TCL `rk30mtk`, Rockchip RK3066, ARM Mali-400 MP, Android 4.2.2

**Research date:** 2026-08-08

## Bottom line

The attached device already has working hardware-accelerated graphics under its stock Android image. The Android kernel exposes the vendor Mali/UMP interface and Android's SurfaceFlinger reports `ARM, Mali-400 MP` using the vendor EGL implementation.

The Alpine chroot does not currently have Linux GPU acceleration. It inherits the Android kernel, but the kernel exposes `/dev/mali` and `/dev/ump`, not the Linux DRM render/display devices (`/dev/dri/*` and `/sys/class/drm`). Installing Linux user-space libraries alone cannot create that missing kernel interface.

The best native-Linux target is a new mainline kernel using:

1. the upstream Lima DRM driver for Mali-400;
2. the upstream Rockchip DRM/VOP driver;
3. the upstream RK3066 HDMI driver; and
4. a board-specific device tree based on the live board's memory, power, pinctrl, display, NAND, and boot details.

This repository now contains a **review-only kernel config fragment** and a **DTS enablement fragment** for that target. They are not a boot image, standalone device tree, or safe-to-flash deployment.

## What was verified on the attached device

The checks were read-only apart from the already-deployed Alpine userland. No kernel, boot, recovery, system, or NAND partition was changed.

| Check | Live result | Meaning |
|---|---|---|
| Android EGL selection | `android`, `mali` in `/system/lib/egl/egl.cfg` | Android selects the vendor Mali path |
| Android OpenGL property | `ro.opengles.version=131072` | OpenGL ES capability is enabled |
| SurfaceFlinger renderer | `ARM, Mali-400 MP, OpenGL ES-CM 1.1` | Android is actually using the Mali renderer |
| Android EGL | `1.4 Linux-r3p2-01rel0` | Vendor Mali EGL is loaded |
| Kernel modules | `mali`, `ump`, `vpu_service` loaded | Legacy Android GPU/video path is live |
| GPU nodes | `/dev/mali` (10,39), `/dev/ump` (246,0) | Vendor kernel ABI, not DRM |
| Linux DRM nodes | `/dev/dri` absent; `/sys/class/drm` absent | No native DRM/KMS path is available to Alpine |
| Live Mali register space | `0x10090000` through `0x1009f100` | Matches the RK30 Mali-400 resource layout |
| Live GPU IRQs | Linux IRQs 37, 38, 39 | Correspond to GIC hwirqs 5, 6, 7 used by mainline RK3066 DTS |

The address match is particularly useful: the old Linux3188 Mali source defines `RK30_GPU_PHYS` as `0x10090000`, with GP, L2, MMU, and PP blocks at the same offsets observed in `/proc/iomem` on this device. This means a new GPU driver is not the missing piece; kernel/DTS/boot integration is.

## Options

### 1. Keep Android for graphics — recommended immediately

This is the only option already proven on this exact board. Run Linux tools in the Alpine chroot for networking and user-space services while Android retains display ownership and GPU acceleration.

This is useful for command-line workloads and services, but it does not give Linux applications an ordinary Mesa/DRM device.

### 2. Bridge Android's GPU into Alpine with libhybris — technically possible, not reasonable here

`libhybris` can load Android drivers linked against bionic from glibc or musl Linux processes. Its own documentation makes clear that a usable deployment normally needs a stripped Android hardware-adaptation service and a graphics compositor integration, not merely a chroot and copied `.so` files. Android's hardware-composer/display ownership must also be integrated.

This device runs Android 4.2.2 with an old vendor EGL/gralloc stack. Building a compatible bionic bridge and compositor path would be a substantial port, and it would still depend on Android's legacy display stack. It is a research project, not the recommended way to get a Linux GPU on this stick.

`gl4es` is only an OpenGL-to-OpenGL-ES compatibility layer. It can help an application once a working GLES provider exists; it does not supply a kernel driver, DRM nodes, EGL implementation, or display ownership.

### 3. Mainline Linux + Lima — recommended native-Linux direction

Upstream Mesa documents Mali-400 as supported by Lima. Lima targets OpenGL ES 2.0/OpenGL 2.1-class use and explicitly requires a separate display driver. The same documentation lists Rockchip DRM among tested display drivers.

Current mainline Linux already contains the relevant RK3066 building blocks:

- RK3066 Mali compatible data, GPU power domain, clocks, resets, and interrupts in the Rockchip device tree;
- RK3066 VOP0 and HDMI nodes;
- `DRM_LIMA` for Mali-400/450;
- `DRM_ROCKCHIP`, `ROCKCHIP_VOP`, and `ROCKCHIP_RK3066_HDMI`.

The live register and IRQ mapping makes this path credible for the device. The unresolved work is the exact board description and boot process, not inventing a GPU driver.

Required before generating a bootable image:

- confirm RAM base and size from the bootloader/partition image;
- identify GPU and display regulator supplies, reset state, and clock handoff;
- identify HDMI HPD/I2C pinctrl and the connector/endpoint topology;
- describe the actual NAND controller, partitions, and bootloader expectations;
- build a complete board DTS, kernel, DTB, modules, Mesa, and a recovery path;
- test first from a recoverable boot method with serial/recovery access.

### 4. Legacy Linux3188 + vendor Mali/UMP — lower initial kernel effort, worse long-term result

The Galland/Linux3188 tree contains a Rockchip-specific Mali-400/UMP implementation with the same `0x10090000` base and four PP resource blocks. Its top-level Mali Kconfig selects UMP and MALI400, but the checked-in Linux3188 configuration has both `CONFIG_MALI` and `CONFIG_UMP` disabled.

This route would keep the old 3.0.36 kernel ABI and require the matching vendor EGL/UMP userland. It may be easier to adapt to the Android board than a fresh mainline port, but it does not provide modern DRM/Mesa integration and is a poor foundation for an Alpine desktop.

## Generated artifacts

### `research/rk3066-lima.config`

A minimal mainline kernel choice set:

```text
CONFIG_DRM=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_VOP=y
CONFIG_ROCKCHIP_RK3066_HDMI=y
CONFIG_DRM_LIMA=y
```

This is a fragment, not a complete `.config`. The target kernel must already select the Rockchip ARM SoC architecture and all board-specific storage, console, clock, power, and networking options.

### `research/rk3066-gpu-enable.fragment.dtsi`

This enables the existing mainline GPU/VOP/HDMI nodes when included from a verified board DTS. It intentionally does not guess memory, regulators, pinctrl, connector endpoints, or bootloader properties.

## Validation performed

- Confirmed Android SurfaceFlinger is using Mali-400 rather than software rendering.
- Confirmed Alpine sees the inherited Android network and can reach Alpine repositories over HTTPS.
- Confirmed Alpine package indexes offer Mesa 26.1.6 ARMv7 packages (`mesa`, `mesa-dri-gallium`, `mesa-egl`, `mesa-gles`, `mesa-gbm`, and `mesa-utils`).
- Attempted to deploy Mesa test packages inside Alpine. The Alpine `apk` process segfaulted during package download on the old Android 3.0.36 environment, before any Mesa package was installed; no Mesa package remains installed. This is a package-manager/runtime issue, not evidence that Mesa can accelerate the current `/dev/mali` ABI.
- Confirmed the required DRM devices remain absent from the chroot.

## Recommendation

Use the existing Android GPU path for now. Treat mainline Lima + RK3066 DRM as the only worthwhile native-Linux GPU project, and proceed next with board identification and a complete, non-booted DTS review. Do not flash the generated fragments or a guessed kernel image.

## Primary sources

- [Mesa Lima documentation](https://docs.mesa3d.org/drivers/lima.html)
- [Mainline RK3066A device-tree definitions](https://github.com/torvalds/linux/blob/master/arch/arm/boot/dts/rockchip/rk3066a.dtsi)
- [Mainline RK3066 MK808 board DTS reference](https://github.com/torvalds/linux/blob/master/arch/arm/boot/dts/rockchip/rk3066a-mk808.dts)
- [Mainline RK3066 Marsboard DTS reference](https://github.com/torvalds/linux/blob/master/arch/arm/boot/dts/rockchip/rk3066a-marsboard.dts)
- [Mainline Lima Kconfig](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/lima/Kconfig)
- [Mainline Rockchip DRM Kconfig](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/rockchip/Kconfig)
- [Mainline Mali Utgard device-tree binding](https://github.com/torvalds/linux/blob/master/Documentation/devicetree/bindings/gpu/arm%2Cmali-utgard.yaml)
- [libhybris source and graphics-bridge rationale](https://github.com/libhybris/libhybris)
- [gl4es source and scope](https://github.com/ptitSeb/gl4es)
- [Legacy Linux3188 RK30 Mali resource map](https://github.com/Galland/Linux3188/blob/master/drivers/gpu/mali/mali/arch-pb-rk30-m400-4/config.h)
