#!/bin/sh

echo "try to umount mmcblk0p*"
umount /run/media/mmcblk0p*

echo "start to install ubuntu hmd qcow2"
qemu-img convert -p -f qcow2 /ubuntu-16.04-hmd.qcow2 -O raw /dev/mmcblk0

reboot -f
