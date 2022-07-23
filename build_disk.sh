#!/bin/bash

#$1 = disk
#$2 = pool name

# theoretical 	==> 	g1 ... snap g1@safe
#				==> 	g1@safe clone to g2
#				==>		g2@variant clone to g3 on boot
#				<><>	g2@variant clone to build-test, new builds go to g2@variant_build :: g2@gnome_20220131

# generates a standard disk,  EFI partition, zfs encrypted partition using the current system's key

# look for existing key
# verify the current drive is not mounted
# verify gdisk and parted are installed


##################################################################
if false; then

sgdisk --zap-all $1

partprobe

echo "ignore sr0..."

sgdisk --new 1:0:+32M -t 1:EF02 $1
sgdisk --new 2:0:+8G -t 2:EF00 $1
sgdisk --new 3:0:+16G -t 3:8200 $1
sgdisk --new 4:0 -t 4:8300 $1

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
	$14 -f

zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key $2

mkfs.vfat $12
mkswap $13

mnt="/tmp/build_disk_mnt"

mkdir -p $mnt
mount $12 $mnt
cp /boot/* $mnt -R

new_uuid=$(blkid | grep $14 | awk '{print $3}' | tr -d '"')
#old_uuid=$(cat /boot/EFI/boot/refind.conf | grep 'options' | awk '{print $2}' | uniq | tr -d '"')

new_uuid=${new_uuid#*=}
#old_uuid=${old_uuid#*=}

echo "new uuid = $new_uuid"
#echo "old uuid = $old_uuid"

sed -iE "s/UUID=[0-9]+ /$new_uuid/g" $mnt/EFI/boot/refind.conf

# need to replace pool as well

# current pool
curr_pool=$(cat /boot/EFI/boot/refind.conf | grep options | awk '{print $4}' | head -n 1)
curr_pool=${curr_pool##*=}
curr_pool=${curr_pool%/*}

next_pool=$2
sed -i "s/root=ZFS=$curr_pool/root=ZFS=$next_pool/" $mnt/EFI/boot/refind.conf

#update autofs with the new drive ... 

# ZFS SEND RECV + PV


echo "preparing for send"
sleep 10
zfs send $curr_pool/g2@snape | pv | zfs recv $2/g2

####################################################################
fi

echo "preparing for partitions"

#partitions=(hardened systemd plasma plasmad gnome gnomed)
partitions=(plasmad gnomed)

for x in ${partitions[@]}
do
	echo "partition:: $x"
#	zfs create $2/$x
#	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key $2/$x

#	screen -S "$next_pool/$x" -d -m ./batch.sh deploy=/srv/zfs/$next_pool/$x clear profile=$x
	./batch.sh deploy=/srv/zfs/$next_pool/$x clear profile=$x

done

# UPDATE autofs for /boot !!!!
# UPDATE fstab for swap

# CREATE newpool/distfiles ; /binpkgs ; /usr/local ; /root ;; snap root to /root@user ; /var/lib/lxd ; /var/lib/libvirt
# root@user will serve as a template for regular users



