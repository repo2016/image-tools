#!/bin/sh

echo "try to umount mmcblk0p*"
umount /run/media/mmcblk0p*

echo "start to install ubuntu cs qcow2"
qemu-img convert -p -f qcow2 /ubuntu-16.04-cs.qcow2 -O raw /dev/mmcblk0

reboot -f
