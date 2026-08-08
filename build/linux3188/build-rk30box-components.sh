#!/bin/sh
set -eu

KERNEL_SRC=${KERNEL_SRC:-/src}
ARCH=${ARCH:-arm}
CROSS_COMPILE=${CROSS_COMPILE:-arm-linux-gnueabi-}
DEFCONFIG=${DEFCONFIG:-rk3066b_sdk_defconfig}
JOBS=${JOBS:-4}
MALI_JOBS=${MALI_JOBS:-1}
KCFLAGS=${KCFLAGS:--fgnu89-inline -DCONFIG_ARCH_SUPPORTS_OPTIMIZED_INLINING -DCONFIG_OPTIMIZE_INLINING}
ENABLE_DISPLAY=${RK30BOX_ENABLE_DISPLAY:-1}
CONFIG_ONLY=${RK30BOX_CONFIG_ONLY:-0}

if [ "$ENABLE_DISPLAY" = 1 ]; then
	KCFLAGS="$KCFLAGS -include /usr/share/rk3066-linux3188/board-rk30-box-hdmi-decl.h"
fi

if [ ! -x "$KERNEL_SRC/scripts/config" ]; then
	echo "missing Linux 3.0.36 scripts/config in $KERNEL_SRC" >&2
	exit 1
fi

# The old vendor source must be writable: its Kbuild emits generated headers
# and the vendor Mali makefiles use relative source paths.
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
CONFIG_TOOL="$KERNEL_SRC/scripts/config"

# Select the generic RK30/RBox source family. In particular, do not leave the
# historical rk3066b_m701 choice active: that source file is absent in the
# public tree and does not match the attached kernel's Machine: RK30board
# evidence. Kconfig can restore choice defaults during oldconfig, so this is
# called both before and after oldconfig.
disable_incompatible_choices() {
	for symbol in \
		ARCH_RK3066B \
		SOC_RK3000 SOC_RK3068 SOC_RK3066B SOC_RK3108 SOC_RK3168 SOC_RK3168M \
		MACH_RK30_SDK MACH_RK30_DS975 MACH_RK3066_SDK MACH_RK30_DS1001B \
		MACH_RK30_PHONE MACH_RK30_BOX_HAMBURGER MACH_RK30_BOX_HOTDOG \
		MACH_RK30_PHONE_LOQUAT MACH_RK30_PHONE_A22 MACH_RK30_PHONE_PAD \
		MACH_RK30_PHONE_PAD_DS763 MACH_RK30_PHONE_PAD_C8003 \
		MACH_RK3066B_FPGA MACH_RK3066B_SDK MACH_RK3066B_M701 \
		MACH_RK3168M_TB MACH_RK3108_TB MACH_RK3168_TB MACH_RK3168_LR097 \
		MACH_RK3168_DS1006H MACH_RK3168_86V \
		RKWIFI RK903 RK901 BCM4330 AP6181 AP6210 AP6330 AP6476 AP6494 \
		MFD_WM831X MFD_WM831X_I2C RTC_DRV_WM831X \
		MALI400_PROFILING MALI400_INTERNAL_PROFILING
	do
		"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" --disable "$symbol"
	done
}

disable_incompatible_choices

"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" \
	--enable SOC_RK3066 \
	--enable MACH_RK30_BOX_PIZZA \
	--enable SDMMC_RK29 \
	--enable SDMMC0_RK29 \
	--enable SDMMC1_RK29 \
	--enable WLAN_80211 \
	--enable NL80211_TESTMODE \
	--enable MT5931_MT6622 \
	--enable WIFI_CONTROL_FUNC \
	--enable MALI \
	--enable MALI400_UMP \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING \
	--enable MFD_TPS65910

if [ "$ENABLE_DISPLAY" = 1 ]; then
	"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" \
		--enable FB_ROCKCHIP \
		--enable LCDC_RK30 \
		--enable LCDC0_RK30 \
		--enable LCDC1_RK30 \
		--enable RK_HDMI \
		--enable HDMI_RK30 \
		--enable BOX_FB_720P \
		--disable BOX_FB_480P \
		--disable BOX_FB_1080P \
		--disable LCD_B101EW05 \
		--disable DUAL_LCDC_DUAL_DISP_IN_KERNEL \
		--disable ONE_LCDC_DUAL_OUTPUT_INF \
		--enable NO_DUAL_DISP \
		--disable HDCP_RK30
else
	"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" \
		--disable FB_ROCKCHIP \
		--disable LCDC_RK30 \
		--disable RK_HDMI \
		--disable HDMI_RK30
fi

# Linux 3.0.36 has no olddefconfig. Empty answers retain the vendor defaults
# for unrelated options while resolving the choices above.
yes "" | make_kernel oldconfig

# oldconfig can restore choice defaults. Re-assert the deployment-relevant
# selections after it has finished.
disable_incompatible_choices
"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" \
	--enable SOC_RK3066 \
	--enable MACH_RK30_BOX_PIZZA \
	--enable MT5931_MT6622 \
	--disable RKWIFI \
	--enable MALI \
	--enable MALI400_UMP \
	--disable MALI400_PROFILING \
	--disable MALI400_INTERNAL_PROFILING \
	--enable MFD_TPS65910 \
	--disable MFD_WM831X \
	--disable MFD_WM831X_I2C \
	--disable RTC_DRV_WM831X \
	--enable NL80211_TESTMODE

if [ "$ENABLE_DISPLAY" = 1 ]; then
	"$CONFIG_TOOL" --file "$KERNEL_SRC/.config" \
		--enable FB_ROCKCHIP \
		--enable LCDC_RK30 \
		--enable RK_HDMI \
		--enable HDMI_RK30 \
		--enable BOX_FB_720P \
		--enable NO_DUAL_DISP \
		--disable HDCP_RK30
fi

grep -E '^(CONFIG_(SOC_RK3066|MACH_RK30_BOX_PIZZA|MT5931_MT6622|MALI|MALI400|MALI400_UMP|UMP|MFD_TPS65910|NL80211_TESTMODE))=' "$KERNEL_SRC/.config"
grep -E '^(# CONFIG_(RKWIFI|MFD_WM831X|MFD_WM831X_I2C|RTC_DRV_WM831X|MALI400_(PROFILING|INTERNAL_PROFILING)) is not set)$' "$KERNEL_SRC/.config"

if [ "$CONFIG_ONLY" = 1 ]; then
	printf '%s\n' "RK30BOX-CONFIG-OK"
	exit 0
fi

# Request the board/display objects explicitly. The MT5931 and Mali vendor
# Kbuild branches require their component directory targets; keeping them
# separate from the board/display objects avoids the known generic GCC-12
# full-kernel blocker. Mali/UMP has legacy shared paths, so compile it
# separately and serially.
make_kernel -j"$JOBS" \
	arch/arm/mach-rk30/board-rk30-box.o \
	arch/arm/mach-rk30/board-rk30-sdk-rfkill.o \
	drivers/net/wireless/mt5931/ \
	drivers/video/rockchip/lcdc/rk30_lcdc.o \
	drivers/video/rockchip/hdmi/rk30/rk30_hdmi.o \
	drivers/video/rockchip/hdmi/rk30/rk30_hdmi_hw.o \
	drivers/video/display/screen/lcd_720p.o
make_kernel -j"$MALI_JOBS" drivers/gpu/mali/

for object in \
	arch/arm/mach-rk30/board-rk30-box.o \
	arch/arm/mach-rk30/board-rk30-sdk-rfkill.o \
	drivers/net/wireless/mt5931/built-in.o \
	drivers/gpu/mali/mali/mali.o \
	drivers/gpu/mali/ump/ump.o
do
	test -s "$KERNEL_SRC/$object"
done

if [ "$ENABLE_DISPLAY" = 1 ]; then
	for object in \
		drivers/video/rockchip/lcdc/rk30_lcdc.o \
		drivers/video/rockchip/hdmi/rk30/rk30_hdmi.o \
		drivers/video/rockchip/hdmi/rk30/rk30_hdmi_hw.o \
		drivers/video/display/screen/lcd_720p.o
	do
		test -s "$KERNEL_SRC/$object"
	done
	printf '%s\n' "RK30BOX-MT5931-MALI-HDMI-COMPONENTS-OK"
else
	printf '%s\n' "RK30BOX-MT5931-MALI-COMPONENTS-OK"
fi
