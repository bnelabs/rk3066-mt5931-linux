#!/bin/sh
set -eu

KERNEL_SRC=${KERNEL_SRC:-/src}
ARCH=${ARCH:-arm}
CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabi-}
DEFCONFIG=${DEFCONFIG:-rk3066b_m701_defconfig}
JOBS=${JOBS:-4}
MALI_JOBS=${MALI_JOBS:-1}
KCFLAGS=${KCFLAGS:--fgnu89-inline -DCONFIG_ARCH_SUPPORTS_OPTIMIZED_INLINING -DCONFIG_OPTIMIZE_INLINING}

# Prepare the disposable vendor tree in the same way as the full-kernel
# builder. The source tree must be writable because this vendor Kbuild uses
# relative $(src) paths and emits generated headers beside the sources.
if [ ! -e "$KERNEL_SRC/include/linux/compiler-gcc12.h" ]; then
	cp /usr/share/rk3066-linux3188/compiler-gcc12.h \
		"$KERNEL_SRC/include/linux/compiler-gcc12.h"
fi

CLOCK_DATA_DIR="$KERNEL_SRC/arch/arm/mach-rk30"
if [ -f "$CLOCK_DATA_DIR/clock_data.uu" ] && [ ! -e "$CLOCK_DATA_DIR/clock_data.o" ]; then
	(cd "$CLOCK_DATA_DIR" && uudecode clock_data.uu)
fi
if [ -e "$CLOCK_DATA_DIR/clock_data.o" ] && [ ! -e "$CLOCK_DATA_DIR/clock_data-rk3066b.o" ]; then
	cp "$CLOCK_DATA_DIR/clock_data.o" "$CLOCK_DATA_DIR/clock_data-rk3066b.o"
fi

make_kernel() {
	make -C "$KERNEL_SRC" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" KCFLAGS="$KCFLAGS" "$@"
}

make_kernel "$DEFCONFIG"
"$KERNEL_SRC/scripts/config" --file "$KERNEL_SRC/.config" \
	--enable WLAN_80211 \
	--enable MT5931_MT6622 \
	--enable MALI \
	--enable MALI400_UMP \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING
yes "" | make_kernel oldconfig
"$KERNEL_SRC/scripts/config" --file "$KERNEL_SRC/.config" \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING

grep -E '^(CONFIG_(WLAN_80211|MT5931_MT6622|MALI|MALI400|MALI400_UMP|UMP|MMC))=' "$KERNEL_SRC/.config"

# The MT5931 tree is a built-in-only vendor target in this kernel fork.
make_kernel -j"$JOBS" drivers/net/wireless/mt5931/

# Mali and UMP share a few legacy source paths. Serializing this target avoids
# two Kbuild branches writing the same object simultaneously on modern hosts.
make_kernel -j"$MALI_JOBS" drivers/gpu/mali/

test -s "$KERNEL_SRC/drivers/net/wireless/mt5931/built-in.o"
test -s "$KERNEL_SRC/drivers/gpu/mali/mali/mali.o"
test -s "$KERNEL_SRC/drivers/gpu/mali/ump/ump.o"
printf '%s\n' "Linux3188 MT5931 and Mali component targets completed"
