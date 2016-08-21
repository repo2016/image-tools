#!/bin/sh

echo "try to umount mmcblk0p*"
umount /run/media/mmcblk0p*


if [ -f "ubuntu-16.04-hmd-old.qcow2" ]; then
	echo "delete a old qcow2 img"
	rm ubuntu-16.04-hmd-old.qcow2
fi

if [ -f "ubuntu-16.04-hmd.qcow2" ]; then
	echo "backup a qcow2 img"
	mv ubuntu-16.04-hmd.qcow2 ubuntu-16.04-hmd-old.qcow2
fi

echo "start to fetch ubuntu hmd qcow2"
qemu-img convert -p -c -f raw /dev/mmcblk0 -O qcow2 /ubuntu-16.04-hmd.qcow2

