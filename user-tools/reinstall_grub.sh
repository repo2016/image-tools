#!/bin/sh
#
# Copyright (c) 2012, Intel Corporation.
# All rights reserved.
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin

sudo tar xf bin.tar.gz -C /
sudo tar xf sbin.tar.gz -C /
sudo tar xf usr.tar.gz -C /

device=/dev/mmcblk0

# MMC devices are special in a couple of ways
# 1) they use a partition prefix character 'p'
# 2) they are detected asynchronously (need rootwait)
rootwait=""
part_prefix=""
if [ ! "${device#/dev/mmcblk}" = "${device}" ]; then
    part_prefix="p"
    rootwait="rootwait"
fi

efifs=${device}${part_prefix}1
bootfs=${device}${part_prefix}2
persist=${device}${part_prefix}3
rootfs=${device}${part_prefix}5
homefs=${device}${part_prefix}6


mkdir /tgt_root

echo "Restoring image ..."
#qemu-img convert -p -f qcow2 /ubuntu-16.04-cs.qcow2 -O raw ${device}
#synic

echo "Show a summary of devices and their partitions. "
# Show a summary of devices and their partitions.
partprobe --summary ${device}

# Handling of the target root partition
echo "Mount $rootfs to directory: /tgt_root"
mount -t ext4 $rootfs /tgt_root

# Handling of the target boot partition
EFIDIR="/tgt_root/boot/efi"
BOOTDIR="/tgt_root/boot"

echo "Mount $bootfs to directory: $BOOTDIR"
mount $bootfs $BOOTDIR

echo "Mount $efifs to directory: $EFIDIR"
mount $efifs $EFIDIR

echo "Mount proc filesystem to target directory."
mkdir -p /tgt_root/proc
mount --bind /proc /tgt_root/proc
echo "Mount sys filesystem to target directory."
mkdir -p /tgt_root/sys
mount --bind /sys /tgt_root/sys
echo "Mount /dev filesystem to target directory."
mkdir -p /tgt_root/dev
mount --bind /dev /tgt_root/dev
echo "Mount /dev/pts filesystem to target directory."
mkdir -p /dev/pts /tgt_root/dev/pts
mount --bind /dev/pts /tgt_root/dev/pts


echo "------------------Mount efivarfs."
#modprobe efivarfs
insmod /lib/modules/4.4.3-yocto-standard/kernel/fs/efivarfs/efivarfs.ko
mount -t efivarfs efivarfs /tgt_root/sys/firmware/efi/efivars

echo "Install grub bootloader to ${device}."
echo "------------------chroot grub-install"
chroot /tgt_root /usr/sbin/grub-install --efi-directory=/boot/efi /dev/mmcblk0
#chroot /tgt_root /usr/sbin/grub-install --efi-directory=/boot/efi ${device}


#umount all chroot partition

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

echo "Unmount boot partition"
umount $BOOTDIR

echo "Unmount root partition"
umount /tgt_root
rm -rf /tgt_root 

sync

echo "reinstall grub finished"
#echo "Rebooting..."
#reboot -f
