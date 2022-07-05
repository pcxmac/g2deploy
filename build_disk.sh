#!/bin/bash

#$1 = disk

# generates a standard disk,  EFI partition, zfs encrypted partition using the current system's key

# look for existing key
# verify the current drive is not mounted
# verify gdisk and parted are installed

sgdisk --zap-all $1

partprobe

sgdisk --new 1:0:+32M -t 1:EF02 /dev/vda
sgdisk --new 2:0:+8G -t 2:EF00 /dev/vda
sgdisk --new 3:0:+16G -t 3:8200 /dev/vda
sgdisk --new 4:0 -t 4:8300 /dev/vda

#!/bin/bash

#disk="/dev/vda4"
#pool="virtual"

#pool = $2

# mirror
zpool create \
	-O acltype=posixacl \
	-O compression=lz4 \
	-O dnodesize=auto \
	-O normalization=formD \
	-O relatime=on \
	-O xattr=sa \
	-O encryption=aes-256-gcm \
	-O keyformat=passphrase \
	-O keylocation=prompt \
	-O mountpoint=/srv/zfs/$2 $2 \
	$14

zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key $2

mkfs.vfat $12
mkswap $13

mnt="/tmp/build_disk_mnt"

mkdir -p $mnt
mount $12 $mnt
cp /boot/* $mnt -R

new_uuid=$(blkid | grep $14 | awk '{print $3}' | tr -d '"')
old_uuid=$(cat /boot/EFI/boot/refind.conf | grep 'options' | awk '{print $2}' | uniq | tr -d '"')

new_uuid=${new_uuid#*=}
old_uuid=${old_uuid#*=}

echo "new uuid = $new_uuid"
echo "old uuid = $old_uuid"

sed -i "s/UUID=$old_uuid/UUID=$new_uuid/" $mnt/EFI/boot/refind.conf

# need to replace pool as well

# current pool
curr_pool=$(cat /boot/EFI/boot/refind.conf | grep options | awk '{print $4}' | head -n 1)
curr_pool=${curr_pool##*=}
curr_pool=${curr_pool%/*}

next_pool=$2
sed -i "s/root=ZFS=$curr_pool/root=ZFS=$next_pool/" $mnt/EFI/boot/refind.conf

#update autofs with the new drive ... 

# ZFS SEND RECV + PV

# UPDATE autofs
