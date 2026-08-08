# rk3066-mt5931-linux

Bringing real Linux to a TCL Android TV stick with Rockchip RK3066, MediaTek MT5931 WiFi, and MT6622 Bluetooth.

## The device

| | |
|---|---|
| Model / ID | `rk30mtk` Android TV stick, serial `HNPKB1AIA4`, adb ID `HNPKB1AIA4` |
| SoC | Rockchip RK3066 (RK30board, dual ARMv7 Cortex-A9, NEON, max 1.6GHz) |
| GPU | Mali-400 (drivers/gpu/mali, r3p2 lineage) |
| RAM | 857 MB total (~488 MB free after debloat) |
| Storage | 5.7 GB internal NAND (FAT32, label `ROCKCHIPS`, mtdblock9), /data 1 GB, /system ~209 MB free |
| Display | 720x1280 @ 60Hz, density 160 |
| Codecs | HW decode H.264 / VP8 / H.263 / MPEG4 only (no HEVC/VP9) |
| WiFi | MediaTek **MT5931**, SDIO `037a:5931` (full-MAC combo chip) |
| BT | MediaTek **MT6622** (paired TCL MOVE AUDIO S106 soundbar) |
| OS | Android 4.2.2 (API 17), kernel **3.0.36+** (`arron@cyxtech-server`, gcc 4.6.x-google), full root via adb |

## TL;DR findings

1. **The MT5931 Linux driver already exists.** My earlier assumption ("no driver") was wrong. Working source is in `Galland/MTK5931` (113k lines of MediaTek WCN vendor driver) and integrated into `Galland/Linux3188` — a complete RK3066/RK3188 kernel **at exactly kernel 3.0.36**, with the firmware blob (`WIFI_RAM_CODE`, 139,776 bytes) in-tree. Writing from scratch would be pointless.
2. **Realistic path to Linux on this stick:** `Galland/Linux3188` (Picuntu lineage) — a full 3.0.36 kernel with MT5931 + MT6622 + Mali + NAND support. Not literally "as-is" (needs a RK3066 config + GPIO tweaks) but this is how RK3066 boxes actually ran Linux.
3. **Mainline port (5.x/6.x):** technically feasible for a minimal STA subset but a large job (~2-4 person-months) with hard API breakages and a firmware ownership problem. Monitor/injection is effectively impossible (full-MAC chip).
4. **Chroot on stock Android:** simplest — the driver already works in Android; a Debian/Kali ARMv7 chroot just uses `wlan0` over the running kernel. No WiFi driver work needed.

## Repo layout

```
docs/
  device-audit.md          # Full hardware + software audit of the stick
  debloat-log.md           # What was removed (with restore notes)
research/
  path-a-linux3188.md      # Use Galland/Linux3188 kernel as-is (Picuntu path)
  path-b-external-module.md# Build mt5931 as external module for 3.0.36
  path-c-mainline.md       # Port MT5931 to mainline (API breakage + verdict)
```

## Key sources

- `github.com/Galland/Linux3188` — RK3066/RK3188 3.0.36 kernel with MT5931/MT6622 + firmware
- `github.com/Galland/MTK5931` — MediaTek WCN combo driver source (MT6620/5931/6622/6628)
- `github.com/aloksinha2001/picuntu-3.0.8-alok` — Picuntu, Issue #2 = the MT5931 bring-up thread
- `github.com/Galland/rk3x_kernel_3.0.36` — older recommended RK3066 kernel
- `github.com/linuxium/3066-NAND` — NAND-only (SD-free) Linux boot on RK3066
- `github.com/olegk0/rk3x_kernel_3.0.36` — hardfp Linux build of the same 3.0.36
- `github.com/omegamoon/rockchip-rk30xx-mk808` — matching 3.0.36 Android kernel tree

## Status

- [x] Device audit (hardware, software, root)
- [x] Debloat (10 packages removed, Logitech keyboard + YouTube kept)
- [x] Driver availability research (exists, wrong earlier claim corrected)
- [x] Path A / B / C feasibility research
- [ ] Decide which path to pursue (A = Linux3188 full Linux, B = external module, C = mainline, D = chroot on Android)
