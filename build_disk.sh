#!/bin/bash

#$1 = disk
#$2 = pool name

# theoretical 	==> 	g1 ... snap g1@safe
#				==> 	g1@safe clone to g2
#				==>		g2@variant clone to g3 on boot
#				<><>	g2@variant clone to build-test, new builds go to g2@variant_build :: g2@gnome_20220131

# g2@variant_current = current build/revisions w/ respect to portage
# g2@variant_version = posted at kernel version change, only that kernel's modules
# g2@variant 		 = the variant built on machine, from the original spawn
# g1@safe			 = rescue partition - clones from this - becomes g3
# g2				 = SECURED by another key (usb), used to spawn a variant

# spawn g1, g1 snapshot safe, g1@safe clone to g2 
# g1_hardened -> g1_hardened@safe clone to g2_hardened :: update, snapshot::clone to g2_hardened_version@BUILD :: boot to g3_hardened
# update : g2_hardened@version (clone to g2_hardened_current_build_test) ... order rebuild, new kernel, etc.. test cycle
# update : if successful, g2_hardened@version clone g2_hardened_version, snapshot to g2_hardened_version@BUILD (build date)
# 
# 
# 
# 
# 

# a variant can be like plasma, gnome, gnome-d, plasma-d, selinux-hardened, etc...
# the variant is a first order derivative, from which updates can be applied
# the variant_version is working updated variant, the original variant is not touched after the first version is confirmed
# the variant_version_build is an attempt to update a variant, which then becomes the next variant-version ::
# an example would be g2@plasmad-5.18.1_build1, which would then becomes g2@plasma-15.18.2
# g2@variant-versioned ... clone to build_next, [ test install, build packages, download distfiles ] /// if successful, update (clone from g2@variant) g2_variant_version

# generates a standard disk,  EFI partition, zfs encrypted partition using the current system's key

# look for existing key
# verify the current drive is not mounted
# verify gdisk and parted are installed


pool=$2
disk=$1

##################################################################
if false; then

sgdisk --zap-all $disk

partprobe

echo "ignore sr0..."

sgdisk --new 1:0:+32M -t 1:EF02 $disk
sgdisk --new 2:0:+8G -t 2:EF00 $disk
sgdisk --new 3:0:+16G -t 3:8200 $disk
sgdisk --new 4:0 -t 4:8300 $disk

#disk="/dev/vda4"
#pool="virtual"

#pool = $2

# mirror raidz raidz2

# in the future a yaml file will exist such that the pool type, configuration, set of disks, and disk partition map(s) {zfs+swap-stripe} will be denoted
# it should also allow a usb key option, such that the boot MBR, EFI part, and rescue zfs partition are allocatable and mappable.

#disks.yml
#	system = zpool { || mdm, ext4, ext3, btrfs }
#	type = raidz2
#	disks = { ...# } ... example { /dev/vda2 , /dev/vdb2 , ... }
#	sizeof = { 10GB }
#	options = {  ... }
#
#	swap = mdmSwap
#	type = mdm
#	disks = { ...# }
#	sizeof = { REMAINING }
# 	options = { ... }
#
#	boot = efi
#	type = vfat
#	disks = { /dev/vda }
#	sizeof = { 16GB }
#	options = { label = ... }

# the subroutine pulls in all the relavent disks, eyeballs the #'s and deduces priority of allocation is assigned by order of entry
# all calculations are made before processing disks, and a warning or error will stop execution and prompt the user


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
	-O mountpoint=/srv/zfs/$pool \
	$pool \
	$disk4 -f

zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key $pool

mkfs.vfat $disk2
mkswap $disk3

mnt="/tmp/build_disk_mnt"

mkdir -p $mnt
mount $12 $mnt
cp /boot/* $mnt -R

new_uuid=$(blkid | grep $disk4 | awk '{print $3}' | tr -d '"')
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

#next_pool=$pool
sed -i "s/root=ZFS=$curr_pool/root=ZFS=$next_pool/" $mnt/EFI/boot/refind.conf

#update autofs with the new drive ... 

# ZFS SEND RECV + PV


echo "preparing for send"
sleep 10
zfs send $curr_pool/g2@snape | pv | zfs recv $pool/g2

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
	./batch.sh deploy=/srv/zfs/$pool/$x clear profile=$x

done

# UPDATE autofs for /boot !!!!
# UPDATE fstab for swap

# CREATE newpool/distfiles ; /binpkgs ; /usr/local ; /root ;; snap root to /root@user ; /var/lib/lxd ; /var/lib/libvirt
# root@user will serve as a template for regular users



