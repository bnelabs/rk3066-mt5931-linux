#!/system/bin/sh

# Enter the Alpine ARMv7 userland installed by the RK3066 deployment notes.
# This binds the stock Android kernel views for one session and unmounts them
# on exit. It does not modify boot, recovery, kernel, or NAND partitions.

set -u

ALP=/data/local/alpine
BB=/sbin/busybox

case "$($BB id)" in
	uid=0*) ;;
	*)
	 echo "root is required" >&2
	 exit 1
	;;
esac

if [ ! -f "$ALP/bin/busybox" ]; then
	 echo "Alpine rootfs not found at $ALP" >&2
	 exit 1
fi

mkdir -p "$ALP/dev/pts" "$ALP/run"

dns=$(getprop net.dns1)
[ -n "$dns" ] || dns=1.1.1.1
echo "nameserver $dns" > "$ALP/etc/resolv.conf"

cleanup() {
	$BB umount "$ALP/dev/pts" >/dev/null 2>&1
	$BB umount "$ALP/dev" >/dev/null 2>&1
	$BB umount "$ALP/proc" >/dev/null 2>&1
	$BB umount "$ALP/sys" >/dev/null 2>&1
}

trap cleanup EXIT HUP INT TERM

$BB mount -o bind /dev "$ALP/dev" || exit 1
$BB mount -o bind /dev/pts "$ALP/dev/pts" || exit 1
$BB mount -o bind /proc "$ALP/proc" || exit 1
$BB mount -o bind /sys "$ALP/sys" || exit 1

if [ "$#" -gt 0 ]; then
	$BB chroot "$ALP" /bin/sh -c 'export PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/root; exec "$@"' alpine-chroot "$@"
else
	$BB chroot "$ALP" /bin/sh -c 'export PATH=/sbin:/usr/sbin:/bin:/usr/bin HOME=/root; exec /bin/sh -l'
fi
