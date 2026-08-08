# Path D — Linux userland in a stock-Android chroot

**Verdict:** recommended first experiment.

The attached device is already rooted over ADB, already has a working
MT5931/MT6622 kernel stack, and already has its Android display/GPU stack.
A chroot can add a useful ARMv7 Linux userland without changing any of those
components. It is the lowest-risk way to test compilers, servers, scripting,
network tools, and package availability.

## What to use

1. Alpine armv7 standard for the smallest command-line environment.
2. OpenWrt armsr/armv7 for a tiny networking-focused toolset.
3. Debian armhf minbase for the broadest package compatibility.
4. Ubuntu armhf only as a minimal compatibility experiment; modern Ubuntu
   Server's memory baseline is already above this unit's reported RAM.
5. Kali only as a Debian-based tool selection inside one of the above
   userlands; there is no generic RK3066 Kali image.

The detailed comparison and storage requirements are in
[chroot-options.md](chroot-options.md).

## Hardware behavior

- Wi-Fi comes from Android's MT5931 driver and the host wlan0.
- The chroot does not add an MT5931 driver.
- The chroot does not add Lima or any other GPU driver.
- The chroot does not become a security boundary.
- GUI/GPU access needs a separate experiment against the Android kernel's
  device nodes and vendor libraries; command-line networking is the sensible
  baseline.

## Storage rule

The large Android user partition is vfat. Store an ext4 loop image there, use
an ext4 external SD card, or use the smaller /data ext4 partition for a
minimal rootfs. Do not extract a normal Linux rootfs directly onto vfat.

## Stop conditions

Stop and return to the stock Android environment if a test requires:

- repartitioning or erasing NAND;
- replacing the boot, recovery, or kernel partition;
- unloading or replacing the stock Wi-Fi/GPU modules;
- changing the Android network manager before the inherited-network test is
  complete.

Those actions belong to the separate native Linux tracks and require a
device-specific backup and recovery plan.
