#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 rpm output_dir" >&2
    exit 1
fi

set -eux -o pipefail

RPM="$(readlink -f "$1")"
OUTPUTDIR="$(readlink -f "$2")"

WORKDIR="$(mktemp -d)"
MNTDIR="${WORKDIR}/mnt"

function cleanup() {
    local workdir="$1"
    local mountdir="${workdir}/mnt"

    if mountpoint -q "${mountdir}"; then
        umount -f -l "${mountdir}" || true
    fi

    if [ -n "${IMG_LOOP:-}" ]; then
        losetup -d "${IMG_LOOP:-}"
    fi

    rm -rf "${workdir}"
}

# Trap for cleanup mount points
trap "cleanup ${WORKDIR}" 0 1 2 3 6 15

# Create mount point directory and output directory
mkdir -p "${MNTDIR}" "${OUTPUTDIR}"

# Create raw image
IMG="${OUTPUTDIR}/boot.img"
rm -f "${IMG}"
truncate -s 128MiB "${IMG}"

# Have static UUIDs to make partition table reproducible
/usr/sbin/sfdisk "$IMG" <<EOF || exit 1
label: gpt
label-id: f4796a2a-e377-45bd-b539-d6d49e569055
size=100MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=fa4d6529-56da-47c7-ae88-e2dfecb72621, name="EFI System"
EOF

# Create loop device associated to the boot image
IMG_LOOP=$(/sbin/losetup -P -f --show "$IMG")
EFI_IMG_DEV=${IMG_LOOP}p1
/sbin/mkfs.vfat "${EFI_IMG_DEV}"

# Mount loop device and copy EFI binary
mount "${EFI_IMG_DEV}" "${MNTDIR}"
mkdir -p "${MNTDIR}/EFI/BOOT/"
rpm2cpio "${RPM}" | cpio -i --to-stdout './boot/xen-signed-*.efi' > "${MNTDIR}/EFI/BOOT/bootx64.efi"

# Debug info
tree "${MNTDIR}"
sha256sum "${MNTDIR}/EFI/BOOT/bootx64.efi"
