# Build validation and deployment boundary

Date: 2026-08-08

This note records what was actually compiled from the attached device's
hardware/source context. It deliberately separates source compilation from a
bootable deployment: no NAND, kernel, boot, recovery, or system partition was
written.

## Device facts used for the build decision

- Android 4.2.2, API 17, stock kernel `3.0.36+`, ARMv7 RK3066.
- Mali-400 is already hardware-accelerated by Android through `/dev/mali` and
  `/dev/ump`; the device has no `/dev/dri` or DRM sysfs interface.
- Wi-Fi is MediaTek MT5931 over SDIO (`037a:5931`); Bluetooth is MT6622.
- The historical MT5931 source and `WIFI_RAM_CODE` firmware are present in
  the Galland Linux3188/MTK5931 lineage.
- The live device exposes no `/proc/config.gz` and no readable board device
  tree, so the exact vendor board GPIO, regulator, display, NAND, and SDIO
  wiring is not recoverable from the running Android kernel alone.

## Results

### Legacy Linux3188 / MT5931 / vendor Mali

The Docker component build passed using the historical source tree at local
commit `3935f967` (the Galland/Linux3188 snapshot):

```text
CONFIG_WLAN_80211=y
CONFIG_MT5931_MT6622=y
CONFIG_MALI=y
CONFIG_MALI400=m
CONFIG_MALI400_UMP=y
CONFIG_UMP=m
CONFIG_MMC=y
```

The MT5931 driver compiled and linked to its legacy in-tree
`drivers/net/wireless/mt5931/built-in.o`. The vendor Mali and UMP stacks also
compiled and linked to their component objects. The build needs the soft-float
ARM cross compiler, GCC 12 compatibility glue, GNU89 inline semantics, and a
serial Mali component build because this old vendor Kbuild reuses unsafe
intermediate paths under parallel make.

The complete legacy kernel did **not** become a bootable image. The source
snapshot references board objects such as
`arch/arm/mach-rk30/board-rk3066b-m701.o`, but the corresponding board source
is absent. `clock_data.uu` is present and can be decoded, but that does not
replace the board file: board code controls clocks, GPIO, power, display,
NAND, and the MT5931 SDIO wiring. Inventing it would be an unsafe deployment
step.

Conclusion: the legacy route is the only proven MT5931 kernel-source route,
but it needs the exact TCL/rk30mtk board source or a known-good vendor image
from the same hardware before a kernel can be safely boot-tested.

### Mainline Linux / Lima / RK3066 reference

A Linux mainline reference build completed at source commit
`a59f57e2aa127c5354168d2ec4bac920df1be4f4` in a Linux-native ARM64 Docker
volume (needed because the macOS filesystem is case-insensitive):

```text
CONFIG_ARCH_ROCKCHIP=y
CONFIG_DRM=y
CONFIG_DRM_LIMA=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_VOP=y
CONFIG_ROCKCHIP_RK3066_HDMI=y
```

The build produced an ARM `zImage` and the RK3066 reference DTB:

```text
arch/arm/boot/zImage                         12 MiB
arch/arm/boot/dts/rockchip/rk3066a-mk808.dtb 24 KiB
```

The artifacts are disposable validation outputs under `/tmp`, not committed
firmware and not device-specific. The reference DTB is for an MK808-style
board, not this TCL `rk30mtk` device. Mainline's MediaTek wireless tree does
not contain MT5931, so this build validates the GPU/display direction only;
it does not provide the tablet's Wi-Fi.

## Reproduce on an Apple-silicon Mac

Docker Desktop's native `linux/arm64` engine was used. The legacy source is
kept in a disposable writable copy because the original checkout contains
unrelated user changes.

### Legacy component validation

```sh
rsync -a --exclude .git --exclude .config \
  --exclude include/config --exclude include/generated \
  /tmp/Linux3188/ /tmp/Linux3188-build/

docker build --platform linux/arm64 \
  -t rk3066-linux3188-builder:bookworm build/linux3188

docker run --rm --platform linux/arm64 \
  -v /tmp/Linux3188-build:/src:rw \
  -e KERNEL_SRC=/src -e OUTPUT=/src -e JOBS=4 -e MALI_JOBS=1 \
  rk3066-linux3188-builder:bookworm \
  sh /usr/local/bin/rk3066-linux3188-components
```

The full legacy attempt uses the same image and `build.sh`; it is expected to
stop at the absent exact-board object described above until that source is
recovered.

### Mainline GPU reference validation

Use a Docker-managed volume for the Linux source. Do not checkout the Linux
tree directly onto the case-insensitive macOS filesystem.

```sh
docker volume create rk3066-mainline-src-20260808

# Populate the volume once, using a temporary Linux container. The source
# snapshot used for this result was torvalds/linux at a59f57e2.
docker run --rm --platform linux/arm64 \
  -v rk3066-mainline-src-20260808:/src \
  debian:bookworm sh -c \
  'apt-get update >/dev/null && apt-get install -y --no-install-recommends git rsync >/dev/null && \
   git clone --depth=1 https://github.com/torvalds/linux /src/linux && \
   rsync -a /src/linux/ /src/ && rm -rf /src/linux'

docker build --platform linux/arm64 \
  -t rk3066-mainline-builder:bookworm build/mainline

mkdir -p /tmp/rk3066-mainline-out
docker run --rm --platform linux/arm64 \
  -v rk3066-mainline-src-20260808:/src \
  -v /tmp/rk3066-mainline-out:/out \
  -v "$PWD/research":/config:ro \
  -e KERNEL_SRC=/src -e OUTPUT=/out \
  -e CONFIG_FRAGMENT=/config/rk3066-lima.config \
  -e JOBS=4 -e TARGETS='zImage dtbs' \
  rk3066-mainline-builder:bookworm
```

## Deployment decision

| Route | What is proven | Current decision |
|---|---|---|
| Stock Android + chroot | Existing MT5931 and Mali remain usable through Android | Best immediate option; safe to keep testing user space |
| Legacy Linux3188 | MT5931 and vendor Mali source components compile | Best future Wi-Fi kernel route, blocked by exact board source |
| Mainline Lima | RK3066 reference GPU kernel/DTB compiles | Good GPU research route, not tablet-bootable yet and no MT5931 |
| Flash either kernel now | No exact board DT, partition/image contract, or recovery path | Not reasonable; do not flash |

The next safe technical step is recovery of the exact TCL board source or a
matching stock boot image/kernel configuration, followed by offline DT and
boot-image construction. Until then, use the already-working Android GPU and
Wi-Fi from a chroot; a chroot adds user-space tools but cannot add a kernel
driver or DRM device.
