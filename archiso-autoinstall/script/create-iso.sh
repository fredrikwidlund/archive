#!/bin/bash

function abort
{
    echo Error: "$1"
    exit 1
}

function download
{
    name=$(pacman -Syw --noconfirm $1 | grep Packages | awk '{print $3}')
    cp /var/cache/pacman/pkg/$1-* $2
}

ISO=$1 && [ -f "$ISO" ] || abort "iso image not found"
LABEL=$(file "$ISO" | sed 's/.*\(ARCH_[0-9]*\).*/\1/g')
WORK=$(pwd)/work

echo mounting image
mkdir -p $WORK/mnt
mount -r -t iso9660 -o loop $ISO $WORK/mnt
cp -a $WORK/mnt/ $WORK/custom

echo uncompressing root filesystem
unsquashfs -d $WORK/squashfs-root $WORK/custom/arch/x86_64/airootfs.sfs || abort "uncompressing root filesystem failed"
mkdir $WORK/root
mount -o loop $WORK/squashfs-root/airootfs.img $WORK/root

echo adding autoinstall
cp script/autoinstall.sh $WORK/root/root/.automated_script.sh
chmod +x $WORK/root/root/.automated_script.sh
mkdir -p $WORK/root/root/packages/
download jansson $WORK/root/root/packages/
download jshon $WORK/root/root/packages/
arch-chroot $WORK/root/ bash -c "pacman -U --noconfirm /root/packages/*"
rm -rf $WORK/root/root/packages
rm $WORK/root/etc/udev/rules.d/81-dhcpcd.rules
sed -i -e '1iTIMEOUT 10\' $WORK/custom/arch/boot/syslinux/archiso_head.cfg

echo compressing root filesystem
umount $WORK/root
rm $WORK/custom/arch/x86_64/airootfs.sfs
mksquashfs $WORK/squashfs-root $WORK/custom/arch/x86_64/airootfs.sfs
rm -rf $WORK/squashfs-root
md5sum $WORK/custom/arch/x86_64/airootfs.sfs > $WORK/custom/arch/x86_64/airootfs.md5

echo creating iso image
CUSTOM=${ISO/.iso/-autoinstall.iso}
cp config.json $WORK/custom/
genisoimage -quiet -l -r -J -V $LABEL -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -c isolinux/boot.cat -o $CUSTOM $WORK/custom/

echo cleaning up
umount $WORK/mnt
rmdir $WORK/root $WORK/mnt
rm -rf $WORK/custom
