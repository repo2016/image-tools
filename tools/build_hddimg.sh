#!/bin/sh

# Emit a useful diagnostic if something fails:
bb_exit_handler() {
    ret=$?
    case $ret in
    0)  ;;
    *)  case $BASH_VERSION in
        "") echo "WARNING: exit code $ret from a shell command.";;
        *)  echo "WARNING: ${BASH_SOURCE[0]}:${BASH_LINENO[0]} exit $ret from '$BASH_COMMAND'";;
        esac
        exit $ret
    esac
}
trap 'bb_exit_handler' 0
set -e

VERSION_ID=`date +%Y%m%d%H%M%S`

export TOP_DIR=$PWD

build_hddimg() {
	# clean
	rm -rf ${TOP_DIR}/hddimg/*
	# Create an HDD image
	populate_live ${TOP_DIR}/hddimg

	syslinux_hddimg_populate ${TOP_DIR}/hddimg
	efi_hddimg_populate ${TOP_DIR}/hddimg

	# Check the size of ${TOP_DIR}/hddimg/rootfs.img, error out if it
	# exceeds 4GB, it is the single file's max size of FAT fs.
	if [ -f ${TOP_DIR}/hddimg/rootfs.img ]; then
		rootfs_img_size=`stat -c '%s' ${TOP_DIR}/hddimg/rootfs.img`
		max_size=`expr 4 \* 1024 \* 1024 \* 1024`
		if [ $rootfs_img_size -gt $max_size ]; then
			bberror "${TOP_DIR}/hddimg/rootfs.img execeeds 4GB,"
			bberror "this doesn't work on FAT filesystem, you can try either of:"
			bberror "1) Reduce the size of rootfs.img"
			bbfatal "2) Use iso, vmdk or vdi to instead of hddimg\n"
		fi
	fi

	build_fat_img ${TOP_DIR}/hddimg ${TOP_DIR}/images/ubuntu-16.04-install.hddimg

	syslinux_hddimg_install

	chmod 644 ${TOP_DIR}/images/ubuntu-16.04-install.hddimg
}

syslinux_hddimg_install() {
	syslinux ${TOP_DIR}/images/ubuntu-16.04-install.hddimg
}

syslinux_hddimg_populate() {
	hdd_dir=$1
	syslinux_populate $hdd_dir / syslinux.cfg
}

bbfatal() {
	echo "ERROR: $*"
	exit 1
}

build_fat_img() {
	FATSOURCEDIR=$1
	FATIMG=$2

	# Calculate the size required for the final image including the
	# data and filesystem overhead.
	# Sectors: 512 bytes
	#  Blocks: 1024 bytes

	# Determine the sector count just for the data
	SECTORS=$(expr $(du --apparent-size -ks ${FATSOURCEDIR} | cut -f 1) \* 2)

	# Account for the filesystem overhead. This includes directory
	# entries in the clusters as well as the FAT itself.
	# Assumptions:
	#   FAT32 (12 or 16 may be selected by mkdosfs, but the extra
	#   padding will be minimal on those smaller images and not
	#   worth the logic here to caclulate the smaller FAT sizes)
	#   < 16 entries per directory
	#   8.3 filenames only

	# 32 bytes per dir entry
	DIR_BYTES=$(expr $(find ${FATSOURCEDIR} | tail -n +2 | wc -l) \* 32)
	# 32 bytes for every end-of-directory dir entry
	DIR_BYTES=$(expr $DIR_BYTES + $(expr $(find ${FATSOURCEDIR} -type d | tail -n +2 | wc -l) \* 32))
	# 4 bytes per FAT entry per sector of data
	FAT_BYTES=$(expr $SECTORS \* 4)
	# 4 bytes per FAT entry per end-of-cluster list
	FAT_BYTES=$(expr $FAT_BYTES + $(expr $(find ${FATSOURCEDIR} -type d | tail -n +2 | wc -l) \* 4))

	# Use a ceiling function to determine FS overhead in sectors
	DIR_SECTORS=$(expr $(expr $DIR_BYTES + 511) / 512)
	# There are two FATs on the image
	FAT_SECTORS=$(expr $(expr $(expr $FAT_BYTES + 511) / 512) \* 2)
	SECTORS=$(expr $SECTORS + $(expr $DIR_SECTORS + $FAT_SECTORS))

	# Determine the final size in blocks accounting for some padding
	BLOCKS=$(expr $(expr $SECTORS / 2) + 512)

	# Ensure total sectors is an integral number of sectors per
	# track or mcopy will complain. Sectors are 512 bytes, and we
	# generate images with 32 sectors per track. This calculation is
	# done in blocks, thus the mod by 16 instead of 32.
	BLOCKS=$(expr $BLOCKS + $(expr 16 - $(expr $BLOCKS % 16)))

	# mkdosfs will sometimes use FAT16 when it is not appropriate,
	# resulting in a boot failure from SYSLINUX. Use FAT32 for
	# images larger than 512MB, otherwise let mkdosfs decide.
	if [ $(expr $BLOCKS / 1024) -gt 512 ]; then
		FATSIZE="-F 32"
	fi

	# mkdosfs will fail if ${FATIMG} exists. Since we are creating an
	# new image, it is safe to delete any previous image.
	if [ -e ${FATIMG} ]; then
		rm ${FATIMG}
	fi

	if [ -z "${HDDIMG_ID}" ]; then
		mkdosfs ${FATSIZE} -n boot -S 512 -C ${FATIMG} \
			${BLOCKS}
	else
		mkdosfs ${FATSIZE} -n boot -S 512 -C ${FATIMG} \
		${BLOCKS} -i ${HDDIMG_ID}
	fi

	# Copy FATSOURCEDIR recursively into the image file directly
	mcopy -i ${FATIMG} -s ${FATSOURCEDIR}/* ::/
}

efi_hddimg_populate() {
	efi_populate $1
}

bberror() {
	echo "ERROR: $*"
}

populate_live() {
	populate_initrd $1
	install -m 0644 ${TOP_DIR}/images/ubuntu-16.04.qcow2 $1/ubuntu-16.04.qcow2
}

efi_populate() {
	# DEST must be the root of the image so that EFIDIR is not
	# nested under a top level directory.
	DEST=$1

	install -d ${DEST}/EFI/BOOT

	# x86
	#echo "Install grub EFI 32bit"
	#GRUB_IMAGE="bootia32.efi"
	# x86_64
	#echo "Install grub EFI 64bit"
	#GRUB_IMAGE="bootx64.efi"
	#install -m 0644 ${TOP_DIR}/images/${GRUB_IMAGE} ${DEST}/EFI/BOOT

	install -m 0644 ${TOP_DIR}/setting/grub.cfg ${DEST}/EFI/BOOT/grub.cfg
}

syslinux_populate() {
	DEST=$1
	BOOTDIR=$2
	CFGNAME=$3

	install -d ${DEST}${BOOTDIR}

	# Install the config files
	#install -m 0644 ${TOP_DIR}/setting/syslinux.cfg ${DEST}${BOOTDIR}/${CFGNAME}
	#install -m 0644 /usr/lib/syslinux/modules/bios/vesamenu.c32 ${DEST}${BOOTDIR}/vesamenu.c32
	#install -m 0444 /usr/lib/syslinux/modules/bios/libcom32.c32 ${DEST}${BOOTDIR}/libcom32.c32
	#install -m 0444 /usr/lib/syslinux/modules/bios/libutil.c32  ${DEST}${BOOTDIR}/libutil.c32
	#install -m 0444 /usr/lib/syslinux/modules/bios/ldlinux.c32  ${DEST}${BOOTDIR}/libcom32.c32
}

populate_initrd() {
	dest=$1
	install -d $dest

	# Install initrd in DEST for all loaders to use.
	rm -rf ${TOP_DIR}/initramfs.rootfs/*
	tar xf ${TOP_DIR}/images/qemu-img.tar.gz -C ${TOP_DIR}/initramfs.rootfs
	cp -a ${TOP_DIR}/setting/install-ubuntu.sh  ${TOP_DIR}/initramfs.rootfs
	cp -a ${TOP_DIR}/setting/lib                ${TOP_DIR}/initramfs.rootfs
	(cd ${TOP_DIR}/initramfs.rootfs && find . | cpio -o -H newc) | gzip -9 -c > ${TOP_DIR}/images/qemu-img.cpio.gz

	sudo mount -o loop ${TOP_DIR}/images/core-image-sato.hddimg ${TOP_DIR}/rootfs
	cp -a ${TOP_DIR}/rootfs/* $dest/
	sleep 1
	sudo umount ${TOP_DIR}/rootfs

	# initrd is made of concatenation of multiple filesystem images
	cat $dest/initrd ${TOP_DIR}/images/qemu-img.cpio.gz > $dest/initrd.new
	mv $dest/initrd.new $dest/initrd
	chmod 0644 $dest/initrd

	sudo mount $dest/rootfs.img ${TOP_DIR}/rootfs
	sudo cp -a ${TOP_DIR}/initramfs.rootfs/usr/bin/qemu-img ${TOP_DIR}/rootfs/usr/bin/
	sleep 1
	sudo umount ${TOP_DIR}/rootfs
	
	# clean
	rm -f ${TOP_DIR}/images/qemu-img.cpio.gz
}

build_hddimg

# cleanup
ret=$?
trap '' 0
exit $ret

