#!/bin/sh
set -eu

KERNEL_SRC=${KERNEL_SRC:-/src}
OUTPUT=${OUTPUT:-/out}
ARCH=${ARCH:-arm}
CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabi-}
DEFCONFIG=${DEFCONFIG:-multi_v7_defconfig}
CONFIG_FRAGMENT=${CONFIG_FRAGMENT:-/config/rk3066-lima.config}
JOBS=${JOBS:-4}
TARGETS=${TARGETS:-zImage modules dtbs}

make_kernel() {
	make -C "$KERNEL_SRC" O="$OUTPUT" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" "$@"
}

mkdir -p "$OUTPUT"
make_kernel "$DEFCONFIG"

if [ -f "$CONFIG_FRAGMENT" ]; then
	"$KERNEL_SRC/scripts/kconfig/merge_config.sh" -m -O "$OUTPUT" \
		"$OUTPUT/.config" "$CONFIG_FRAGMENT"
fi

make_kernel olddefconfig
grep -E '^(CONFIG_(ARCH_ROCKCHIP|DRM|DRM_ROCKCHIP|ROCKCHIP_VOP|ROCKCHIP_RK3066_HDMI|DRM_LIMA))=' "$OUTPUT/.config"
# The out-of-tree ARM Kbuild target is the aggregate `dtbs` target; passing a
# source-tree DTB path directly gets prefixed twice by the recursive DTS make.
# Build the complete DTB set, then verify the RK3066 reference board artifact
# we care about is present.
make_kernel -j"$JOBS" $TARGETS
test -s "$OUTPUT/arch/arm/boot/dts/rockchip/rk3066a-mk808.dtb"

printf '%s\n' "Mainline reference build completed in $OUTPUT"
