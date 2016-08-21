#!/bin/sh -e
#
# Copyright (c) 2012, Intel Corporation.
# All rights reserved.
#
# install.sh [device_name] [rootfs_name]
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# We need 64 Mb for the boot partition
boot_size=64

# 5% for swap
swap_ratio=5

# Get a list of hard drives
hdnamelist=""
live_dev_name=`cat /proc/mounts | grep ${1%/} | awk '{print $1}'`
live_dev_name=${live_dev_name#\/dev/}
# Only strip the digit identifier if the device is not an mmc
case $live_dev_name in
    mmcblk*)
    ;;
    *)
        live_dev_name=${live_dev_name%%[0-9]*}
    ;;
esac

echo "Searching for hard drives ..."

for device in `ls /sys/block/`; do
    case $device in
        loop*)
            # skip loop device
            ;;
        sr*)
            # skip CDROM device
            ;;
        ram*)
            # skip ram device
            ;;
        *)
            # skip the device LiveOS is on
            # Add valid hard drive name to the list
            case $device in
                $live_dev_name*)
                # skip the device we are running from
                ;;
                *)
                    hdnamelist="$hdnamelist $device"
                ;;
            esac
            ;;
    esac
done

if [ -z "${hdnamelist}" ]; then
    echo "You need another device (besides the live device /dev/${live_dev_name}) to install the image. Installation aborted."
    exit 1
fi

TARGET_DEVICE_NAME=""
for hdname in $hdnamelist; do
    # Display found hard drives and their basic info
    echo "-------------------------------"
    echo /dev/$hdname
    if [ -r /sys/block/$hdname/device/vendor ]; then
        echo -n "VENDOR="
        cat /sys/block/$hdname/device/vendor
    fi
    if [ -r /sys/block/$hdname/device/model ]; then
        echo -n "MODEL="
        cat /sys/block/$hdname/device/model
    fi
    if [ -r /sys/block/$hdname/device/uevent ]; then
        echo -n "UEVENT="
        cat /sys/block/$hdname/device/uevent
    fi
    echo
    # Get user choice
    while true; do
        echo -n "Do you want to install this image there? [y/n] "
        read answer
        if [ "$answer" = "y" -o "$answer" = "n" ]; then
            break
        fi
        echo "Please answer y or n"
    done
    if [ "$answer" = "y" ]; then
        TARGET_DEVICE_NAME=$hdname
        break
    fi
done

if [ -n "$TARGET_DEVICE_NAME" ]; then
    echo "Installing image on /dev/$TARGET_DEVICE_NAME ..."
else
    echo "No hard drive selected. Installation aborted."
    exit 1
fi

device=/dev/$TARGET_DEVICE_NAME

#
# The udev automounter can cause pain here, kill it
#
rm -f /etc/udev/rules.d/automount.rules
rm -f /etc/udev/scripts/mount*

#
# Unmount anything the automounter had mounted
#
umount ${device}* 2> /dev/null || /bin/true

mkdir -p /tmp

# Create /etc/mtab if not present
if [ ! -e /etc/mtab ]; then
    cat /proc/mounts > /etc/mtab
fi

#disk_size=$(parted --script ${device} unit mb print | grep '^Disk .*: .*MB' | cut -d" " -f 3 | sed -e "s/MB//")

#swap_size=$((disk_size*swap_ratio/100))
#rootfs_size=$((disk_size-boot_size-swap_size))

#rootfs_start=$((boot_size))
#rootfs_end=$((rootfs_start+rootfs_size))
#swap_start=$((rootfs_end))

# MMC devices are special in a couple of ways
# 1) they use a partition prefix character 'p'
# 2) they are detected asynchronously (need rootwait)
rootwait=""
part_prefix=""
if [ ! "${device#/dev/mmcblk}" = "${device}" ]; then
    part_prefix="p"
    rootwait="rootwait"
fi
bootfs=${device}${part_prefix}1
rootfs=${device}${part_prefix}2
swap=${device}${part_prefix}3

#echo "*****************"
#echo "Boot partition size:   $boot_size MB ($bootfs)"
#echo "Rootfs partition size: $rootfs_size MB ($rootfs)"
#echo "Swap partition size:   $swap_size MB ($swap)"
#echo "*****************"
echo "Deleting partition table on ${device} ..."
dd if=/dev/zero of=${device} bs=512 count=35

#echo "Creating new partition table on ${device} ..."
#parted ${device} mklabel gpt

#echo "Creating boot partition on $bootfs"
#parted ${device} mkpart boot fat32 0% $boot_size
#parted ${device} set 1 boot on

#echo "Creating rootfs partition on $rootfs"
#parted ${device} mkpart root ext4 $rootfs_start $rootfs_end

#echo "Creating swap partition on $swap"
#parted ${device} mkpart swap linux-swap $swap_start 100%

#parted ${device} print

#echo "Formatting $bootfs to vfat..."
#mkfs.vfat $bootfs

#echo "Formatting $rootfs to ext4..."
#mkfs.ext4 -F $rootfs

#echo "Formatting swap partition...($swap)"
#mkswap $swap

mkdir /tgt_root
#mkdir /src_root
#mkdir -p /boot

# Handling of the target root partition
#mount -t ext4 $rootfs /tgt_root
#mount -o rw,loop,noatime,nodiratime /run/media/$1/$2 /src_root
echo "Restoring image ..."
qemu-img convert -p -f qcow2 /run/media/$1/ubuntu-16.04.qcow2 -O raw ${device}
sync


need=0

#this part used for update-grub action, to generate new /boot/grub/grub.cfg, by old bios not supportting ubuntu efi boot 
#if you need, change need to 1
if [ $need -eq 1 ]; then
# Show a summary of devices and their partitions.
partprobe --summary ${device}
# Handling of the target root partition
echo "Mount $rootfs to directory: /tgt_root"
mount -t ext4 $rootfs /tgt_root
# Handling of the target boot partition
EFIDIR="/tgt_root/boot/efi"
mkdir -p $EFIDIR
echo "Mount $bootfs to directory: $EFIDIR"
mount $bootfs $EFIDIR

echo "Mount proc filesystem to target directory."
mount --bind /proc /tgt_root/proc
echo "Mount sys filesystem to target directory."
mount --bind /sys /tgt_root/sys
echo "Mount /dev filesystem to target directory."
mount --bind /dev /tgt_root/dev
echo "Mount /dev/pts filesystem to target directory."
mkdir -p /dev/pts /tgt_root/dev/pts
mount --bind /dev/pts /tgt_root/dev/pts

echo "Mount efivarfs."
#modprobe efivarfs
insmod /lib/modules/4.4.3-yocto-standard/kernel/fs/efivarfs/efivarfs.ko
#mount -t efivarfs efivarfs /sys/firmware/efi/efivars
mount -t efivarfs efivarfs /tgt_root/sys/firmware/efi/efivars

echo "Install grub bootloader to ${device}."
chroot /tgt_root /usr/sbin/grub-install --efi-directory=/boot/efi ${device}

echo "Unmount efivarfs."
umount /tgt_root/sys/firmware/efi/efivars

echo "Unmount /dev/pts"
umount /tgt_root/dev/pts
echo "Unmount /dev"
umount /tgt_root/dev
echo "Unmount sys"
umount /tgt_root/sys
echo "Unmount proc"
umount /tgt_root/proc

echo "Unmount EFI partition"
umount $EFIDIR

echo "Unmount root partition"
umount /tgt_root

sync

#sleep 1

echo "Remove your installation media, and press ENTER"

read enter

fi
#end of this part

echo "Rebooting..."
reboot -f
