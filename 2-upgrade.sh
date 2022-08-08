#!/bin/sh

set -eo pipefail

# BACKUP_MEDIA=/mnt/sdb1
BACKUP_MEDIA=/mnt/disk
OVERLAY_MEDIA=/mnt/sda5
UPGRADE_IMG=/tmp/openwrt-x86-64-generic-squashfs-combined-efi.img

umount "${BACKUP_MEDIA}"
if [ -z $NO_NEW_OVERLAY ]; then
    BACKUP_UPPER="${OVERLAY_MEDIA}/upper_old_$(date +%Y%m%d%H%M%S)"

    mv "${OVERLAY_MEDIA}/upper" "${BACKUP_UPPER}"
    mkdir "${OVERLAY_MEDIA}/upper"
    # These folders do not need extra backup
    mv "${BACKUP_UPPER}/opt" "${BACKUP_UPPER}/root" "${BACKUP_UPPER}/home" "${OVERLAY_MEDIA}/upper/"
fi

sysupgrade "${UPGRADE_IMG}"

