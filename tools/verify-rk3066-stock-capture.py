#!/usr/bin/env python3
"""Verify the structural facts recorded for a read-only RK3066 capture.

The script never opens a device node and never writes to the capture. It
expects the following files in its argument directory:

  mtd1-kernel.bin, mtd2-boot.bin, mtd3-recovery.bin

Optional files such as WIFI_RAM_CODE are checked when present. The expected
hashes are deliberately fixed to the 2026-08-08 capture documented in
research/stock-capture-sha256.txt.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import struct
import sys
from pathlib import Path


EXPECTED_RAW = {
    "mtd1-kernel.bin": "4a30c562fba277bfa2831982c45d907de81cb3f6206f9520494b1f0ff336be95",
    "mtd2-boot.bin": "00168d66c53e68e714dcbed38ccfad93082b902e2a542299435f1cdcccc13549",
    "mtd3-recovery.bin": "34f2680828d3bb3dd54c352c0967ce9b9f2699848b05790b2fc37703d8a959f8",
}
EXPECTED_OPTIONAL = {
    "WIFI_RAM_CODE": "af345785369ee0a53efd85654810ba47463833186201fb3d3e9f9ac8195ca53c",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def unpack_krnl(path: Path) -> bytes:
    data = path.read_bytes()
    if data[:4] != b"KRNL":
        fail(f"{path.name}: missing KRNL magic")
    if len(data) < 12:
        fail(f"{path.name}: shorter than KRNL header and CRC")
    length = struct.unpack_from("<I", data, 4)[0]
    end = 8 + length
    if end + 4 > len(data):
        fail(f"{path.name}: payload length 0x{length:x} exceeds file")
    payload = data[8:end]
    print(f"{path.name}: KRNL payload={length} crc_offset=0x{end:x}")
    return payload


def unpack_android_boot(path: Path) -> tuple[bytes, bytes]:
    data = path.read_bytes()
    if data[:8] != b"ANDROID!":
        fail(f"{path.name}: missing Android boot magic")
    if len(data) < 40:
        fail(f"{path.name}: shorter than Android boot header")
    kernel_size, kernel_addr, ramdisk_size, ramdisk_addr = struct.unpack_from(
        "<4I", data, 8
    )
    second_size, second_addr, tags_addr, page_size = struct.unpack_from(
        "<4I", data, 24
    )
    if page_size == 0 or page_size & (page_size - 1):
        fail(f"{path.name}: invalid page size {page_size}")
    kernel_offset = page_size
    ramdisk_offset = kernel_offset + ((kernel_size + page_size - 1) // page_size) * page_size
    kernel_end = kernel_offset + kernel_size
    ramdisk_end = ramdisk_offset + ramdisk_size
    if ramdisk_end > len(data):
        fail(f"{path.name}: kernel/ramdisk extends beyond file")
    kernel = data[kernel_offset:kernel_end]
    ramdisk = data[ramdisk_offset:ramdisk_end]
    print(
        f"{path.name}: Android boot page={page_size} kernel={kernel_size} "
        f"ramdisk={ramdisk_size} kernel_addr=0x{kernel_addr:x} "
        f"ramdisk_addr=0x{ramdisk_addr:x} tags=0x{tags_addr:x} "
        f"second={second_size} second_addr=0x{second_addr:x}"
    )
    gzip.decompress(ramdisk)
    return kernel, ramdisk


def check_hash(path: Path, expected: str) -> None:
    actual = sha256(path.read_bytes())
    if actual != expected:
        fail(f"{path.name}: SHA-256 {actual}, expected {expected}")
    print(f"{path.name}: SHA-256 OK {actual}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_dir", type=Path)
    args = parser.parse_args()
    root = args.capture_dir

    try:
        for name, expected in EXPECTED_RAW.items():
            path = root / name
            if not path.is_file():
                fail(f"missing required capture file: {path}")
            check_hash(path, expected)

        kernel_payload = unpack_krnl(root / "mtd1-kernel.bin")
        boot_payload = unpack_krnl(root / "mtd2-boot.bin")
        if sha256(kernel_payload) != "6ccff2f036b4b9a6c8007e2dce9cf5850d03305c0ee0df450c18bca166954679":
            fail("mtd1 kernel payload hash does not match the recorded capture")
        if sha256(boot_payload) != "4f31fd29d925e350fa09b6ec1bdeb2539da906b0ee64af4c5cbb00082efcce2e":
            fail("mtd2 boot payload hash does not match the recorded capture")
        gzip.decompress(boot_payload)
        print("mtd2 boot payload: gzip OK")

        recovery_kernel, _ = unpack_android_boot(root / "mtd3-recovery.bin")
        if recovery_kernel != kernel_payload:
            fail("recovery kernel is not byte-identical to mtd1 KRNL payload")
        print("recovery kernel: byte-identical to mtd1 KRNL payload")

        for name, expected in EXPECTED_OPTIONAL.items():
            path = root / name
            if path.is_file():
                check_hash(path, expected)
            else:
                print(f"{name}: not present; optional check skipped")
    except (OSError, ValueError, EOFError, gzip.BadGzipFile) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print("RK3066 stock capture verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
