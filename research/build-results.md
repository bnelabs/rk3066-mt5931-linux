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

The original M701 configuration did not produce a bootable image. Its source
snapshot references board object
arch/arm/mach-rk30/board-rk3066b-m701.o, but the corresponding board source
is absent. clock_data.uu is present and can be decoded, but it does not replace
board code: that code controls clocks, GPIO, power, display, NAND, and the
MT5931 SDIO wiring. Inventing the missing M701 file would be unsafe.

The generic RBox candidate below is a separate source configuration and is
compile-confirmed at the component level. It does not remove the need for
exact TCL board/runtime evidence before booting.

### RK30-box / RK3066 Pizza candidate

The public generic RBox source was configured as SOC_RK3066 with
MACH_RK30_BOX_PIZZA, after disabling unrelated RK3066B/M701 and generic
RKWIFI choices and selecting the stock TPS65910 PMIC path. These component
objects compiled together:

    arch/arm/mach-rk30/board-rk30-box.o
    arch/arm/mach-rk30/board-rk30-sdk-rfkill.o
    drivers/net/wireless/mt5931/built-in.o
    drivers/gpu/mali/mali/mali.o
    drivers/gpu/mali/ump/ump.o
    drivers/video/rockchip/lcdc/rk30_lcdc.o
    drivers/video/rockchip/hdmi/rk30/rk30_hdmi.o
    drivers/video/rockchip/hdmi/rk30/rk30_hdmi_hw.o

The MT5931 target required NL80211_TESTMODE. This is a compile-confirmed
source candidate, not a bootable image: the RBox Pizza variant could still
have different GPIO, regulator, DRAM, NAND, or display values from the TCL
board.

The full legacy zImage attempt stopped because GCC 12 triggers generic Linux
3.0.36 ARM put_user inline-assembly assertions in fs/fat/dir.c. This is
outside the board, Wi-Fi, GPU, and display targets. It is recorded as a
toolchain compatibility blocker rather than hidden behind an unreviewed
kernel patch.

The reproducible candidate configuration is driven by
build/linux3188/build-rk30box-components.sh and summarized in
research/rk3066-linux3188-rk30box-pizza.config. The expected success marker
with display enabled is RK30BOX-MT5931-MALI-HDMI-COMPONENTS-OK.

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

docker run --rm --platform linux/arm64 --entrypoint sh \
  -v /tmp/Linux3188-build:/src:rw \
  -e KERNEL_SRC=/src -e OUTPUT=/src -e JOBS=4 -e MALI_JOBS=1 \
  rk3066-linux3188-builder:bookworm \
  -c 'sh /usr/local/bin/rk3066-linux3188-components'
```

The legacy full-kernel attempt still uses the same image and build.sh. It
remains a separate deployment path: the original M701 board object is absent,
and the fresh GCC 12 run reaches the generic Linux 3.0.36 FAT inline-assembly
compatibility blocker before a bootable image can be produced.

### RK30-box candidate component validation

The Docker image has a default full-build entrypoint. Override it when
running the candidate component recipe:

    docker run --rm --platform linux/arm64 --entrypoint sh \
      -v /tmp/Linux3188-build:/src:rw \
      -e KERNEL_SRC=/src -e JOBS=4 -e MALI_JOBS=1 \
      rk3066-linux3188-builder:bookworm \
      -c 'sh /usr/local/bin/rk3066-linux3188-rk30box-components'

The expected marker is
RK30BOX-MT5931-MALI-HDMI-COMPONENTS-OK. The recipe injects one declaration-only
compatibility header because the public board file references hdmi_init_lcdc
without a prototype; it changes no driver behavior. This command builds
source components only and does not create or flash a device image.

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

The earlier M701-specific paragraph above describes why the original default
configuration could not produce a full kernel. The generic RK30-box candidate
now compiles the board, MT5931/MT6622, Mali/UMP, and display/HDMI components;
the exact TCL board/runtime and the generic GCC-12 full-kernel compatibility
issue remain open.

| Route | What is proven | Current decision |
|---|---|---|
| Stock Android + chroot | Existing MT5931 and Mali remain usable through Android | Best immediate option; safe to keep testing user space |
| Legacy Linux3188 + RBox candidate | MT5931/MT6622, vendor Mali/UMP, display/HDMI, and generic RK30 board components compile | Best future Wi-Fi kernel route; exact TCL board/runtime and a GCC-12 full-kernel fix remain open |
| Mainline Lima | RK3066 reference GPU kernel/DTB compiles | Good GPU research route, not tablet-bootable yet and no MT5931 |
| Flash either kernel now | No exact board DT, partition/image contract, or recovery path | Not reasonable; do not flash |

The next safe technical step is recovery of the exact TCL board source or a
matching stock boot image/kernel configuration, followed by offline DT and
boot-image construction. Until then, use the already-working Android GPU and
Wi-Fi from a chroot; a chroot adds user-space tools but cannot add a kernel
driver or DRM device.
