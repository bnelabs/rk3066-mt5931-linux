# Path B — Build MT5931 as an external module for kernel 3.0.36

**Goal:** build the MT5931 driver (`wlan.ko` / `wlan_mt6620.ko`) out-of-tree against a 3.0.36 kernel.

**Verdict: technically feasible and well-trodden, but on the stock Android device it is almost always *unnecessary*** — the driver already ships as a working `.ko`. Path B matters only for a **standalone Linux** boot (or a kernel you build yourself).

## What the driver produces

- `Galland/MTK5931/wifi/mtk_5931/Makefile` → `MODULE_NAME := wlan_mt6620`, `obj-$(CONFIG_MT5931) += wlan_mt6620.o`, `-DLINUX -DMT5931 -D_HIF_SDIO=1`. Composite module: common + nic + os + mgmt + `hif/sdio/{arm,sdio}.o` + P2P.
- `Linux3188` variant: `Makefile.module` → `MODULE_NAME := wlan`, **`obj-m`** (forces module build, no `CONFIG_MT5931=y` needed), plus the tiny launcher shim `drivers/net/wireless/wifi_launcher/wlan.ko` that calls the driver's exported `rockchip_wifi_init_module()`.
- Build pattern: `make -C $(KDIR) M=$(PWD) modules`.

## Toolchain (by scenario)

| Scenario | Toolchain | Why |
|---|---|---|
| Load on stock Android kernel | **Android `arm-eabi-4.6`** (`gcc 4.6.x-google 20120106`) | Exactly what built the device kernel + shipped `mt5931.ko` (verified: both `GCC: (GNU) 4.6.x-google`) |
| Standalone Linux | `arm-linux-gnueabihf-` (Linaro 4.6–4.9) | olegk0's mk808 kernel built with this; module ABI must match running kernel |

- **gcc gotcha:** kernel 3.0.x needs era-correct gcc (4.4–4.9). Modern gcc (≥7, certainly 10+) fails on old ARM inline asm; gcc 14 turns implicit-function-declarations into hard errors.
- Downloads: Linaro `releases.linaro.org/components/toolchain/binaries/`; Android `android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/`.

## Kernel headers

Need the **full 3.0.36 source tree** (headers alone insufficient), prepared with `make ARCH=arm CROSS_COMPILE=... defconfig` + `make modules_prepare` so `scripts/mod/modpost`, `include/generated/autoconf.h`, `utsrelease.h`, `Module.symvers` exist.

Android build extra: fix `scripts/mod/modpost.h` to `#include "elf.h"` (NDK headers lack `<elf.h>`).

## Vermagic (critical)

Module `vermagic=` must equal the kernel's exactly. On this device it is literally `3.0.36+ SMP preempt mod_unload ARMv7`. The `+` comes from `scripts/setlocalversion` on a non-git tarball build. Rebuild a matching kernel or the module refuses to load.

## What's already on the device

- `/proc/version`: `3.0.36+ (arron@cyxtech-server) (gcc 4.6.x-google 20120106) #67 SMP PREEMPT ... 2013`
- **No `/proc/config.gz`** (`CONFIG_IKCONFIG` off) → use matching source trees instead (omegamoon `rockchip-rk30xx-mk808`, `Galland/Linux3188`, olegk0 `rk3x_kernel_3.0.36`, Dealaxer `rk3066-kernel-KK3.0.36`)
- `/system/lib/modules/mt5931.ko` — real driver, `vermagic=3.0.36+`, **no `__versions`** (built without MODVERSIONS → your module won't be CRC-rejected), `Ver 3.08`, alias `sdio:c*v037Ad5931*`
- `wlan.ko` (2,778 B) — launcher shim, calls `rockchip_wifi_init_module`
- `rkwifi.ko` — power/platform (`wifi_power.c`, needs `CONFIG_WIFI_CONTROL_FUNC=y`)
- Firmware on device: `/etc/firmware/WIFI_RAM_CODE` (139,776 B) — byte-identical size to the Linux3188 tree blob

## Build recipe (out-of-tree)

```sh
export ARCH=arm
export CROSS_COMPILE=/path/to/arm-eabi-4.6/bin/arm-eabi-    # Android
# or: CROSS_COMPILE=arm-linux-gnueabihf-                    # standalone Linux
cd <kernel 3.0.36 source>
cp <matching tree>.config .config    # or make <board>_defconfig
make oldconfig && make modules_prepare
# (Android host only) fix scripts/mod/modpost.h: add #include "elf.h"
make CFLAGS_MODULE=-fno-pic M=/path/to/Linux3188/drivers/net/wireless/mt5931 modules
make M=/path/to/Linux3188/drivers/net/wireless/wifi_launcher modules
${CROSS_COMPILE}strip --strip-debug .../wlan.ko
```

- **`-fno-pic` is mandatory** for Android-loaded modules; otherwise `insmod` fails with `unknown relocation: 27` / `_GLOBAL_OFFSET_TABLE_`. (Most common documented failure for 2013-era Rockchip modules.)
- Loading: `adb push wlan.ko /data/local/ && adb shell insmod /data/local/wlan.ko`, then `dmesg`.

## Is it needed?

- **Stock Android: no.** WiFi already works (built-in `mt5931.ko` + shim + `rkwifi.ko` + firmware). Only worth it if modifying the driver source.
- **Standalone Linux on this stick: yes.** The Android `/system/lib/modules` are absent; you boot your own 3.0.36 kernel and must build `wlan.ko` against it. This is the canonical Path B case.
- **Chroot on Android: no** — the in-tree Android module already runs; a chroot just uses `wlan0` over the running kernel.
- **Rebuilding the kernel yourself:** then the shipped module may not match (vermagic/config drift) and you must rebuild in lockstep.

## Runtime firmware loading

`kalFirmwareOpen()` (`gl_kal.c:789`): saves fsuid, `set_fs(get_ds())` (KERNEL_DS), then `filp_open`:
- MT5931 + `CFG_MULTI_ECOVER_SUPPORT` → on E1/E2 silicon wants `/etc/firmware/WIFI_RAM_CODE_E2`; E3+/default wants `/etc/firmware/WIFI_RAM_CODE`
- `CFG_FW_FILENAME = "WIFI_RAM_CODE"` (`include/config.h:913-916`)
- No hotplug/udev needed, but the file must exist and be root-readable at that exact path

Standalone Linux requirements:
1. `/etc/firmware/WIFI_RAM_CODE` (139,776 B) from device or Linux3188 tree
2. `/etc/firmware/MTK_MT6622_E2_Patch.nb0` (7,976 B) for BT coexistence
3. Load order: `insmod rkwifi.ko` → `insmod wlan.ko` (driver) → shim, then `wpa_supplicant` (WEXT v22, `wlan0`)

## References

- `github.com/Galland/MTK5931` (`wifi/mtk_5931/`), `github.com/Galland/Linux3188` (`drivers/net/wireless/mt5931/`, `Makefile.module`, `wifi_launcher/`)
- Kernel trees: omegamoon `rockchip-rk30xx-mk808`, olegk0 `rk3x_kernel_3.0.36`, Dealaxer `rk3066-kernel-KK3.0.36`
- Marco Pratesi `Android-Build-Kernel-Modules-HOWTO.txt`; peterh RK3066 DVB build; SO/11614441 (`-fno-pic` relocation 27); SO/27308093; kernel `Documentation/kbuild/modules.html`
