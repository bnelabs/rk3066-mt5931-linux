# Chroot options on the stock Android kernel

Review date: 2026-08-08

## Decision in one paragraph

A root chroot is the most reasonable first Linux environment for this device.
The attached Android kernel already initializes the MT5931/MT6622 hardware,
the unit has uid 0 over ADB, BusyBox provides chroot and tar, and the large
user partition has room for a carefully prepared rootfs. A chroot adds a
Linux userland; it does not replace the kernel, add a driver, change the
display server, or create a security boundary. Android's wlan0 can be used by
processes inside the chroot because they share the host kernel/network
namespace, subject to the Android firewall and interface state.

## Live constraints

The attached unit reports:

- ARMv7 with VFPv3 and NEON.
- Approximately 877,540 kB RAM.
- Approximately 576 MB free in the 1 GB /data ext4 partition at audit time.
- Approximately 5.4 GB free on /mnt/sdcard, which is the 5.7 GB vfat user
  partition.
- A working stock 3.0.36+ kernel with MT5931 Wi-Fi and Mali-400 modules.
- BusyBox 1.11.1 with chroot and tar applets.

The vfat user partition is useful for storing an ext4 image or archive, but it
is not a suitable place to unpack a Unix rootfs directly: ownership, modes,
symlinks, device nodes, and special files will not be represented reliably.
Use one of these instead:

1. an ext4 filesystem on an external SD card;
2. an ext4 loop image stored on the large vfat partition, if loop mounting is
   confirmed on the device;
3. the smaller /data ext4 partition for a minimal rootfs and package cache.

The first option has the cleanest recovery story. The second preserves the
stock NAND partition map but still needs a tested loop-mount sequence. The
third is convenient but leaves little room for a full package set.

## Distribution comparison

| Userland | Current official evidence | Fit as a chroot | GPU/Wi-Fi result |
|---|---|---|---|
| Alpine 3.24.1 armv7 | [Official downloads](https://alpinelinux.org/downloads/) and the [armv7 minirootfs](https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7/alpine-minirootfs-3.24.1-armv7.tar.gz) publish a small chroot rootfs | Best size and simplest CLI base; musl can expose compatibility issues for old binaries | Uses host wlan0; does not add a GPU driver; good first choice |
| OpenWrt 25.12.5 armsr/armv7 | [Official armv7 index](https://downloads.openwrt.org/releases/25.12.5/targets/armsr/armv7/) publishes a generic rootfs tarball | Excellent for a very small networking/BusyBox toolset; its packages and service model are OpenWrt-specific | Uses host wlan0; do not start its router/kernel service stack inside Android |
| Debian 13 armhf | [Debian arm ports](https://www.debian.org/ports/arm/) and [stable armhf requirements](https://www.debian.org/releases/stable/armhf/ch02s01.en.html) cover ARMv7 with VFPv3 | Best general package compatibility; choose a minbase-style rootfs and avoid systemd in the chroot | Uses host wlan0; Mesa inside the chroot cannot bypass the Android kernel GPU ABI |
| Ubuntu armhf | [Ubuntu supported architectures](https://ubuntu.com/project/docs/how-ubuntu-is-made/concepts/supported-architectures/) include ARMv7 hard-float; [current Server requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) state a 1 GB minimum for modern server installation | Architecture is plausible, but the unit is below the current 1 GB memory minimum and old Picuntu Ubuntu rootfs images are end-of-life | Reasonable only as a minimal userland experiment, not a native modern Server install |
| Kali ARM | [Kali ARM documentation](https://www.kali.org/docs/arm/) and [official image list](https://arm.kali.org/images.html) are device/image specific; no generic RK3066 target was found | Use as a Debian-based toolset inside a chroot only if there is a specific need; it is not a board-support solution | No new driver or GPU path |
| Buildroot | [Buildroot manual](https://buildroot.org/downloads/manual/manual.html) builds a complete custom kernel/rootfs/toolchain for ARM | Excellent for a small native appliance, but not a package-rich chroot and not a shortcut around the board port | Kernel, DT, boot, Wi-Fi, and GPU still need to be solved separately |
| BusyBox only | The stock BusyBox already supplies the basic shell/chroot tools | Smallest diagnostic environment; not a full distribution or package ecosystem | Entirely dependent on Android's existing driver and device nodes |

Alpine is the most reasonable first rootfs. OpenWrt is a strong alternative
when the goal is networking utilities rather than a general Linux environment.
Debian is the most useful general second choice if package compatibility
matters more than footprint. Ubuntu is architecturally compatible, but modern
glibc userlands should be checked against the device's 3.0.36 kernel before
deployment; the commonly documented glibc support floor is newer than this
kernel. Kali and Buildroot are purpose choices, not better defaults.

## What chroot can and cannot expose

### Wi-Fi

The chroot can run ordinary networking tools against Android's existing
wlan0, provided the host has associated and has assigned an address. It does
not need an MT5931 driver of its own. It also cannot make a disconnected
interface associate if the Android framework or vendor driver has disabled it.
NetworkManager, wpa_supplicant ownership, rfkill, and DNS behavior may remain
controlled by Android.

The most reliable first test is read-only: enter the rootfs, inspect the
inherited interfaces and routes, query DNS, and run a small package download.
Do not stop Android services or replace its networking stack during the first
experiment.

### GPU and display

The chroot does not install a new GPU kernel driver. The Android kernel's
mali.ko, ump.ko, framebuffer/display stack, and vendor EGL/GLES libraries
remain the controlling pieces. A Linux userland can use the host network
without owning the GPU, but graphical acceleration is a separate ABI problem.

Binding /dev/mali or copying Android EGL libraries into a foreign rootfs might
be possible on some vendor images, but it is not a portable or safe plan:
ioctl ABI, library paths, linker behavior, display ownership, and Android
surface services all matter. Treat this as an experimental follow-on, not as
an expected consequence of chrooting.

For a real Linux display/GPU stack, use the native mainline route described in
[kernel-gpu-wifi.md](kernel-gpu-wifi.md): RK3066 device tree plus DRM/KMS,
Lima, and an RK3066 HDMI graph. That route is independent of the chroot.

### Init and services

Do not expect systemd, udev, NetworkManager, or a normal boot sequence inside
this chroot. A practical rootfs can run a shell, package manager, compilers,
Python, SSH, and selected daemons if their dependencies fit. Mount proc, sys,
dev, and dev/pts deliberately; use the host's clock, kernel, and network.

## Recommended implementation order

1. Create a rootfs outside the device and verify it is ARMv7 hard-float.
2. Put it in an ext4 image or on an ext4 external card.
3. Copy, do not move, the stock DNS configuration and define a small bind-mount
   set for proc, sys, dev, and dev/pts.
4. Enter with BusyBox chroot and verify uname, memory, interfaces, routes,
   DNS, storage, and package-manager access.
5. Add only the packages needed for the intended workload.
6. Keep GPU experiments separate from the networking baseline.

No kernel or partition change is needed for this path. It is reversible by
unmounting the rootfs and removing its image/directory.

Current glibc packaging documents a Linux 3.2 minimum in the Ubuntu and Debian
source trees:

- [Ubuntu Noble glibc kernel floor](https://git.launchpad.net/ubuntu/+source/glibc/plain/debian/sysdeps/linux.mk?h=ubuntu/noble)
- [Debian glibc kernel floor](https://sources.debian.org/data/main/g/glibc/2.41-11/debian/sysdeps/linux.mk)

That is a package/support boundary rather than a guarantee that every binary
will fail identically. It is enough reason to start with Alpine/OpenWrt or a
custom Buildroot rootfs and test Debian/Ubuntu binaries before investing in a
large rootfs. Arch Linux ARM and Void Linux ARMv7l are additional possible
rootfs sources, but their rolling libc/package streams make them lower
priority on a 3.0.36 kernel; see [Arch ARM downloads](https://archlinuxarm.org/about/downloads)
and the [Void ARM images](https://repo-default.voidlinux.org/live/current/).

## Native-install boundary

A chroot is not a native Linux installation. Native Alpine, Debian, Ubuntu,
or a Buildroot image still requires a board-compatible kernel, boot image,
loader handoff, storage layout, and hardware drivers. The exact NAND map for
this unit is documented in [hardware-firmware-boot.md](../docs/hardware-firmware-boot.md);
the historical Path A sample offsets must not be reused.
