#!/bin/bash

conf=/config.json

function abort
{
    echo Error: "$1"
    exit 1
}

function try_load_config
{
    mount /dev/$1 /mnt && cp /mnt/config.json /
    umount /dev/$1
}

function lookup_interface
{
    grep -E "^ *[[:alnum:]]+:" /proc/net/dev | sed -r 's/ *([[:alnum:]]+):.*/\1/g' | grep -E "^en.*$|^eth.*$" | head -n 1
}

function configure_network
{
    nic=$(lookup_interface)
    ip=$(jshon -e network -e ip -u < $conf)
    broadcast=$(jshon -e network -e broadcast -u < $conf)
    dns=$(jshon -e network -e dns -u < $conf)
    gateway=$(jshon -e network -e gateway -u < $conf)

    cat > /etc/netctl/ethernet-static <<EOF
Interface=$nic
Connection=ethernet
IP=static
Address=('$ip')
Gateway='$gateway'
DNS=('$dns')
EOF
    netctl start ethernet-static
}

function lookup_disk
{
    lsblk -l | grep -v fd | grep disk | awk '{print $1}'
}

function configure_disk
{
    dev=$(lookup_disk)

    modprobe dm-mod
    sgdisk -o /dev/$dev
    sgdisk -n 1:0:+32M /dev/$dev
    sgdisk -t 1:ef02 /dev/$dev
    sgdisk -n 2:0:0 /dev/$dev
    sgdisk -t 2:8e00 /dev/$dev
    pvcreate /dev/${dev}2
    vgcreate arch /dev/${dev}2
    lvcreate -L 256M -n boot arch
    lvcreate -C y -L 1G -n swap arch
    lvcreate -L 10G -n root arch
    lvcreate -l100%FREE -n home arch
    mkswap /dev/arch/swap
    mkfs.xfs /dev/arch/root
    mkfs.xfs /dev/arch/home
    mkfs.xfs /dev/arch/boot
}

function install_os
{
    mount /dev/arch/root /mnt
    mkdir /mnt/boot /mnt/home
    mount /dev/arch/boot /mnt/boot
    mount /dev/arch/home /mnt/home

    MIRROR=$(jshon -e mirror -u < $conf 2>/dev/null)
    if [ -n "$MIRROR" ]
    then
	sed -i -e '1iServer = '$MIRROR'\' /etc/pacman.d/mirrorlist
    fi
    
    pacstrap /mnt base base-devel
    genfstab /mnt >> /mnt/etc/fstab
    arch-chroot /mnt pacman -Syy --noconfirm
    arch-chroot /mnt pacman -S --noconfirm grub
    arch-chroot /mnt grub-install --boot-directory=/boot --no-floppy --recheck --debug /dev/$(lookup_disk)
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    sed -i 's/filesystems /lvm2 filesystems /g' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux
    cp /etc/netctl/ethernet-static /mnt/etc/netctl
    arch-chroot /mnt netctl enable ethernet-static
    arch-chroot /mnt pacman -S --noconfirm openssh
    arch-chroot /mnt systemctl enable sshd
    umount /mnt/boot
    umount /mnt/home
    umount /mnt
}

echo --- load configuration
for dev in $(lsblk  | grep -E 'disk|rom' | awk '{print $1}')
do
    try_load_config $dev 2>/dev/null
done
[ -f $conf ] || abort "no configuration found"

echo --- configure network
configure_network
pacman -Sy >/dev/null 2>&1 || abort "network configuration not working"

echo --- configure disk
configure_disk

echo --- install os
install_os

echo --- rebooting
reboot
