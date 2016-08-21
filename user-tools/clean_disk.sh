#!/bin/sh

#echo "process mmcblk0p1 clean"
#tar zcvf mmcblk0p1.tar.gz /run/media/mmcblk0p1
#umount /run/media/mmcblk0p1
#sudo dd if=/dev/zero of=/dev/mmcblk0p1
#sudo mkfs.vfat -I /dev/mmcblk0p1
#mount -t vfat /dev/mmcblk0p1 /run/media/mmcblk0p1
#tar xf mmcblk0p1.tar.gz -C /

echo "process mmcblk0p2 clean"
tar zcvf mmcblk0p2.tar.gz /run/media/mmcblk0p2
umount /run/media/mmcblk0p2
sudo dd if=/dev/zero of=/dev/mmcblk0p2
sudo mkfs.ext4 /dev/mmcblk0p2
mount -t ext4 /dev/mmcblk0p2 /run/media/mmcblk0p2
tar xf mmcblk0p2.tar.gz -C /

echo "process mmcblk0p3 clean"
tar zcvf mmcblk0p3.tar.gz /run/media/mmcblk0p3
umount /run/media/mmcblk0p3
sudo dd if=/dev/zero of=/dev/mmcblk0p3
sudo mkfs.ext4 /dev/mmcblk0p3
mount -t ext4 /dev/mmcblk0p3 /run/media/mmcblk0p3
tar xf mmcblk0p3.tar.gz -C /

echo "process mmcblk0p6 clean"
tar zcvf mmcblk0p6.tar.gz /run/media/mmcblk0p6
umount /run/media/mmcblk0p6
sudo dd if=/dev/zero of=/dev/mmcblk0p6
sudo mkfs.ext4 /dev/mmcblk0p6
mount -t ext4 /dev/mmcblk0p6 /run/media/mmcblk0p6
tar xf mmcblk0p6.tar.gz -C /

echo "process mmcblk0p5 clean"
tar zcvf mmcblk0p5.tar.gz /run/media/mmcblk0p5
umount /run/media/mmcblk0p5
sudo dd if=/dev/zero of=/dev/mmcblk0p5
sudo mkfs.ext4 /dev/mmcblk0p5
mount -t ext4 /dev/mmcblk0p5 /run/media/mmcblk0p5
tar xf mmcblk0p5.tar.gz -C /

