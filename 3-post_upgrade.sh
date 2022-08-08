#!/bin/sh

OVERLAY_MEDIA=/mnt/sda3

if [ -z "$NO_NEW_OVERLAY" ]; then
	mkdir -p "${OVERLAY_MEDIA}/upper/etc/config"
	cp /etc/config/network "${OVERLAY_MEDIA}/upper/etc/config/"
	mkdir -p "${OVERLAY_MEDIA}/upper/etc/dropbear"
	cp /etc/dropbear/dropbear_rsa_host_key "${OVERLAY_MEDIA}/upper/etc/dropbear/"
	cp /etc/dropbear/authorized_keys "${OVERLAY_MEDIA}/upper/etc/dropbear/"
    if [ -f "${OVERLAY_MEDIA}/etc/.extroot-uuid" ]; then
        rm -f "${OVERLAY_MEDIA}/etc/.extroot-uuid"
    fi
fi
uci set 'fstab.overlay_extroot.enabled=1'
uci set 'fstab.overlay_ori.enabled=1'
NEW_UUID="$(/sbin/block info | grep "/dev/loop0" | cut -d' ' -f2 | sed -e 's/UUID=//' -e 's/"//g')"
if [ -z "$NEW_UUID" ]; then
	echo "No UUID of new overlay detected" >&2
else
	echo "New UUID: ${NEW_UUID}"
	uci set "fstab.overlay_ori.uuid=${NEW_UUID}"
fi
uci commit fstab

