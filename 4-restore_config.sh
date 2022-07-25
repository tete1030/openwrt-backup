#!/bin/sh

# BACKUP_MEDIA=/mnt/sdb1
BACKUP_MEDIA=/mnt/disk

BACKUP_DIR="$(ls -d "${BACKUP_MEDIA}"/router_backups/backup_* | sort | tail -n 1)"
if [ -z $BACKUP_DIR ]; then
	echo "No backup found"
else
	echo "Backup found: $BACKUP_DIR"
	if [ -z "$SKIP" ]; then
		while true; do
			read -p "Continue?" yn
			case $yn in
			[Yy]* )
				echo "Restoring..."
				sysupgrade -r "${BACKUP_DIR}/config.tar.gz"
				break
				;;
			[Nn]* ) echo "Config not restored"; exit ;;
			* ) echo "Please answer yes or no.";;
			esac
		done
	fi
	NEW_UUID="$(/sbin/block info | grep "/dev/loop0" | cut -d' ' -f2 | sed -e 's/UUID=//' -e 's/"//g')"
	if [ -z "$NEW_UUID" ]; then
		echo "No UUID of new overlay detected" >&2
	else
		echo "New UUID: ${NEW_UUID}"
		uci set "fstab.overlay_ori.uuid=${NEW_UUID}"
	fi
	uci commit fstab
fi
