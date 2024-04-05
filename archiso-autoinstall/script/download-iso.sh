#!/bin/bash

MIRROR=http://mirror.rackspace.com/archlinux/iso

echo retrieving iso image
sums=$(curl mirror.rackspace.com/archlinux/iso/latest/sha1sums.txt 2>/dev/null | grep -e 'archlinux.*iso')
set -- $sums
sum="$1"
name="$2"
wget -qN "$MIRROR/latest/$name" -P work
[[ $(shasum < work/$name | awk '{print $1}') == $sum ]] || echo ERROR: invalid checksum
