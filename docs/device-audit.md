# Device Audit — rk30mtk Android TV stick

Audit performed via `adb` shell on the live device. Serial `HNPKB1AIA4`.

## System

```
Build: rk30sdk-eng 4.2.2 JDQ39
Kernel: Linux version 3.0.36+ (arron@cyxtech-server) (gcc version 4.6.x-google 20120106 (prerelease) (GCC)) #67 SMP PREEMPT Wed Jun 26 19:00:44 CST 2013
CPU: ARMv7, dual-core Cortex-A9 (RK3066)
ADB: /opt/homebrew/bin/adb
```

## Hardware

| Component | Detail |
|---|---|
| SoC | Rockchip RK3066 (RK30board, ARMv7 Cortex-A9, NEON, max 1.6GHz, idle 252MHz) |
| GPU | Mali-400 |
| RAM | 857 MB total, ~488 MB free (after debloat) |
| NAND | 5.7 GB internal (FAT32, label `ROCKCHIPS`, `/dev/block/mtdblock9`, i.e. the Android `userdata` partition of the rk29xxnand layout) |
| /data | 1 GB (~576 MB free after debloat) |
| /system | ~209 MB free |
| Display | 720x1280 @ 60Hz, density 160 |
| Video decode | HW: H.264, VP8, H.263, MPEG4. NO HEVC / VP9 |
| WiFi | MediaTek **MT5931**, SDIO `037a:5931` (full-MAC) |
| BT | MediaTek **MT6622** (paired: `TCL MOVE AUDIO S106`) |
| Ethernet | none |
| SD slot | exists (`/mnt/external_sd`, rk29_sdmmc.0) but empty |
| USB | `vold.fstab` exposes 6 USB slots (`udisk0-5`) |

## Software / root

- Android 4.2.2 (API 17), userdebug/test-keys build
- **Full root via adb** (`uid=0` on `adb shell`)
- `/system` remount RW possible (needs a fresh boot; occasionally flaky, retry after reboot)
- WiFi not connected to a network at time of audit

## Kernel + driver facts (important for Path B)

- `/proc/version`: `3.0.36+ ... #67 SMP PREEMPT` — the **`+`** comes from `setlocalversion` on a tarball build; a rebuilt module must reproduce `vermagic=3.0.36+ SMP preempt mod_unload ARMv7`.
- `/proc/config.gz` does **not** exist → `CONFIG_IKCONFIG` is off; exact kernel config must come from a matching source tree (omegamoon, Galland/Linux3188, olegk0).
- `/system/lib/modules/` contains:
  - `mt5931.ko` (402,614 B) — the real driver, internally named `wlan`, `vermagic=3.0.36+`, **no `__versions` section** (built without `CONFIG_MODVERSIONS`), driver version `Ver 3.08`, alias `sdio:c*v037Ad5931*`
  - `wlan.ko` (2,778 B) — Rockchip launcher shim (calls `rockchip_wifi_init_module`)
  - `rkwifi.ko` (577,318 B) — WiFi power/platform control (`wifi_power.c`)
  - also `mali.ko`, `ump.ko`, `rk29-ipp.ko`, `vpu_service.ko`, `rk30_mirroring.ko`, and Ralink/Realtek/Broadcom alternatives (`8188eu.ko`, `8192cu.ko`, `rt5370sta.ko`, etc.)
- Firmware on device: `/etc/firmware/WIFI_RAM_CODE` (139,776 B) + `/etc/firmware/MTK_MT6622_E2_Patch.nb0` (7,976 B, BT coexistence)
- Boot log: `MT5931 SDIO WiFi driver (Powered by Rockchip,Ver 3.08) init.` → `mmc1: new high speed SDIO card` → `wlan0: link is not ready`; `/proc/net/wireless` shows **WE=22** (Wireless Extensions v22, the WEXT path).
- `/proc/cmdline` provides the `mtdparts=rk29xxnand:...` NAND layout (recoverable for Path A flashing).

## Reproducible commands

```sh
adb shell "cat /proc/version"
adb shell "cat /proc/cpuinfo; cat /proc/cmdline"
adb pull /system/lib/modules/mt5931.ko .
adb pull /system/lib/modules/wlan.ko .
adb pull /system/lib/modules/rkwifi.ko .
adb pull /etc/firmware/WIFI_RAM_CODE .
adb shell "dmesg | grep -i MT5931; lsmod; cat /proc/net/wireless"
```
