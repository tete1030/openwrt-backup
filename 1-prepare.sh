#!/bin/sh

FILE_EXCLUDES="
./upper/opt/netdata
./upper/mnt
./docker
"
DISABLE_FSTAB_OVERLAY="overlay_extroot overlay_ori"
LGC_OVERLAY_EXTROOT="/overlay"
LGC_OVERLAY_INT_DEF="/mnt/loop0"
LGC_OVERLAY_INT_SPEC="/mnt/overlay-boot"
# BACKUP_MEDIA="/mnt/sdb1"
BACKUP_MEDIA="/mnt/disk"

BACKUP_TIME="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${BACKUP_MEDIA}/router_backups/backup_${BACKUP_TIME}"

if [ -d "${LGC_OVERLAY_INT_SPEC}" ] && mountpoint -q ${LGC_OVERLAY_INT_SPEC} ; then
	LGC_OVERLAY_INTERNAL="${LGC_OVERLAY_INT_SPEC}"
else
	if [ -d "${LGC_OVERLAY_INT_DEF}" ] && mountpoint -q ${LGC_OVERLAY_INT_DEF} ; then
        echo "Using default internal overlay name"
		LGC_OVERLAY_INTERNAL="${LGC_OVERLAY_INT_DEF}"
	else
		echo "No internal overlay found, exit" >&2
		exit 1
	fi
fi
EXTROOT_EXIST=1
if [ ! -d "${LGC_OVERLAY_EXTROOT}" ] || ! mountpoint -q ${LGC_OVERLAY_EXTROOT} ; then
	echo "No extroot overlay found" >&2
    EXTROOT_EXIST=0
fi

exclude_opts() {
    (
    cd "$1"
    printf '%s' "${FILE_EXCLUDES}" | while IFS=$'\n' read -r line ; do
        if [ -z "${line}" ]; then
            continue
        fi
        if [ ! -f "${line}" ] && [ ! -d "${line}" ]; then
            continue
        fi
        printf " --exclude='%s'" "${line}"
    done
    )
}

mountpoint -q "${BACKUP_MEDIA}"
retval=$?
if [ $retval -ne 0 ]; then
	echo "${BACKUP_MEDIA} not mounted"
	exit 1
fi

mkdir -p "${BACKUP_DIR}"

if [ -z $NO_NEW_OVERLAY ]; then
    eval "tar $(exclude_opts "${LGC_OVERLAY_INTERNAL}") --exclude='./upper_old*' -czvf '${BACKUP_DIR}/internal_overlay.tar.gz' -C '${LGC_OVERLAY_INTERNAL}' ."

    [ $EXTROOT_EXIST -eq 0 ] || (
        eval "tar $(exclude_opts "${LGC_OVERLAY_EXTROOT}") --exclude='./upper_old*' -czvf '${BACKUP_DIR}/extroot_overlay.tar.gz' -C '${LGC_OVERLAY_EXTROOT}' ."
    )

fi

sysupgrade -b "${BACKUP_DIR}/config.tar.gz"

cat << "EOF" > /tmp/listuserpackages.awk
#!/usr/bin/awk -f
BEGIN {
    ARGV[ARGC++] = "/usr/lib/opkg/status"
    cmd="opkg info busybox | grep '^Installed-Time: '"
    cmd | getline FLASH_TIME
    close(cmd)
    FLASH_TIME=substr(FLASH_TIME,17)
}
/^Package:/{PKG= $2}
/^Installed-Time:/{
    INSTALLED_TIME= $2
    # Find all packages installed after FLASH_TIME
    if ( INSTALLED_TIME > FLASH_TIME ) {
        cmd="opkg whatdepends " PKG " | wc -l"
        cmd | getline WHATDEPENDS
        close(cmd)
        # If nothing depends on the package, it is installed by user
        if ( WHATDEPENDS == 3 ) print PKG
    }
}
EOF

# Run the script
chmod +x /tmp/listuserpackages.awk
/tmp/listuserpackages.awk > "${BACKUP_DIR}/userpackages.txt"

if [ -n "${DISABLE_FSTAB_OVERLAY}" ]; then
    printf '%s' "${DISABLE_FSTAB_OVERLAY}" | while IFS=' ' read -r overlay ; do
        if [ -z "${overlay}" ]; then
            continue
        fi
        uci -c "${LGC_OVERLAY_INTERNAL}/upper/etc/config" set "fstab.${overlay}.enabled=0"
    done
    uci -c "${LGC_OVERLAY_INTERNAL}/upper/etc/config" commit fstab
fi

# Allow regenerating .extroot-uuid, avoiding mismatch problem
[ $EXTROOT_EXIST -eq 0 ] || rm "${LGC_OVERLAY_EXTROOT}/etc/.extroot-uuid"

