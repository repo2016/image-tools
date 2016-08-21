#!/bin/sh

echo "try to umount mmcblk0p*"
umount /run/media/mmcblk0p*

echo "start to install cloudrest qcow2"
qemu-img convert -p -f qcow2 /cloudrest.qcow2 -O raw /dev/mmcblk0

reboot -f
