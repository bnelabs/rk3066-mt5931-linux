#!/bin/sh
set -eu

KERNEL_SRC=${KERNEL_SRC:-/src}
OUTPUT=${OUTPUT:-$KERNEL_SRC}
ARCH=${ARCH:-arm}
CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabi-}
DEFCONFIG=${DEFCONFIG:-rk3066b_m701_defconfig}
JOBS=${JOBS:-4}
KCFLAGS=${KCFLAGS:--fgnu89-inline}

# GCC 12 is newer than this kernel's compiler-header dispatch table.  Install
# the small compatibility header into the disposable build tree if needed.
if [ ! -e "$KERNEL_SRC/include/linux/compiler-gcc12.h" ]; then
	cp /usr/share/rk3066-linux3188/compiler-gcc12.h \
		"$KERNEL_SRC/include/linux/compiler-gcc12.h"
fi

# The vendor tree stores RK3066B clock data as a uuencoded relocatable object.
# Decode it into the disposable build tree because the board Makefile expects
# the object at build time.
CLOCK_DATA_DIR="$KERNEL_SRC/arch/arm/mach-rk30"
if [ -f "$CLOCK_DATA_DIR/clock_data.uu" ] && [ ! -e "$CLOCK_DATA_DIR/clock_data.o" ]; then
	(cd "$CLOCK_DATA_DIR" && uudecode clock_data.uu)
fi
if [ -e "$CLOCK_DATA_DIR/clock_data.o" ] && [ ! -e "$CLOCK_DATA_DIR/clock_data-rk3066b.o" ]; then
	cp "$CLOCK_DATA_DIR/clock_data.o" "$CLOCK_DATA_DIR/clock_data-rk3066b.o"
fi

make_kernel() {
	if [ "$OUTPUT" = "$KERNEL_SRC" ]; then
		# The vendor Mali Kbuild uses a relative $(src) in a license-header
		# check; Linux 3.0.36 therefore needs a true in-tree build here.
		make -C "$KERNEL_SRC" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" KCFLAGS="$KCFLAGS" "$@"
	else
		make -C "$KERNEL_SRC" O="$OUTPUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" KCFLAGS="$KCFLAGS" "$@"
	fi
}

mkdir -p "$OUTPUT"
make_kernel "$DEFCONFIG"

# Linux 3.0.36 does not have olddefconfig. Set the required options, then
# answer any remaining configuration questions with their upstream defaults.
"$KERNEL_SRC/scripts/config" --file "$OUTPUT/.config" \
	--enable WLAN_80211 \
	--enable MT5931_MT6622 \
	--enable MALI \
	--enable MALI400_UMP \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING

yes "" | make_kernel oldconfig

# The old vendor Kconfig marks Mali profiling as enabled by default, but the
# accompanying driver is not GPL-compatible.  Set these after oldconfig so
# its prompts cannot restore the incompatible defaults.
"$KERNEL_SRC/scripts/config" --file "$OUTPUT/.config" \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING

grep -E '^(CONFIG_(WLAN_80211|MT5931_MT6622|MALI|MALI400|MALI400_UMP|UMP|MMC))=' "$OUTPUT/.config"
grep -E '^(# CONFIG_MALI400_(PROFILING|INTERNAL_PROFILING) is not set)$' "$OUTPUT/.config"
make_kernel -j"$JOBS" zImage modules

printf '%s\n' "Linux3188 build completed in $OUTPUT"
