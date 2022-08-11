#	systemd needs a different suite of use.files (hardened vs systemd)
#	systemd needs a service setup different from openrc
#
#

## need to add support for integrating the build_disk ...
#  need to support building new kernels on the host env and integrating those in to the new clients
# option = { install=/dev/vdX } ... performs disk geometry and installation on to NEW POOL
# try to mask a lot of the output (like news read all) that clutters output :: option = { verbose=no }

#!/bin/bash
#set -x
# setup resolv.conf and file system...

# ARGS $2 = destination $1= profile (default openrc,current directory)


##################################################################################################

#
#	reusables
#

function getPkgs() {
	
	profile=$1
	
	if [-z "$(eselect profile list | grep "$profile ")" ]
	then
		echo "getPkgs::invalid profile @ $profile"
		
		exit
	else
		if [ -f ./packages/$profile.pkgs ]
		then
			echo -e "$(cat ./packages/common.pkgs)\n$(cat ./packages/$profile.pkgs)"
			
		else
			echo "getPkgs::$profile.pkgs not configured"
			
		fi
	fi
}

function getG2Profile() {
	current="17.1"
	dataset=$1 
	mountpoint=getZFSMountPoint $dataset
	result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*/$current/}"
	echo $result
}

function getHostZPool () {

	pool="$(mount | grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo ${pool}

}

function getZFSMountPoint (){
	dataset=$1
	echo "$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
}

function decompress() {
	src=$1
	dst=$2
	pv $src | tar xz -C $dst
}

function compress_list() {
	src=$1
	dst=$2
	tar cf - -T $src | (pv -p --timer --rate --bytes > $dst)
}

function sync() {
	src=$1
	dst=$2
	echo "rsync from $src to $dst"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 $src $dst
}

function getKVER() {
	temp="$(readlink /usr/src/linux)"
	echo "${temp#linux-*}"
}

# sig_check $directory $list
function sig_check() {
	srcDirectory = $1
	validSums = "$(cat $2)"
	# verify md5sums and if file exists, echo invalid md5sums, report error or 0
	cDir=$(pwd)
	cd $srcDirectory
	error=0
	for line in $validSums
	do
		lineSum="$(echo $line | awk '{print $1}')"
		lineFile="$(echo $line | awk '{print $2}')"
		if [ ! -f $lineFile ]; then echo "missing file @$lineFile"; error=1;
		else
			thisSum="$(md5sum $lineFile | awk '{print $1}')"
			if [ "$thisSum" != "$lineSum" ];then echo "invalid md5sum @$lineSum"; error=1; fi
			# this sum is valid
		fi
	done
	return $error
}

###################################################################################################

function zfs_keys() {
	# ALL POOLS ON SYSTEM, FOR GENKERNEL
	# pools="$(zpool list | awk '{print $1}') | sed '1 d')"
	
	# THE POOL BEING DEPLOYED TO ... -- DEPLOYMENT SCRIPT
	#limit pools to just the deployed pool / not valid for genkernel which would attach all pools & datasets
	dataset=$1
	offset="$(getZFSMountPoint $dataset)"
	pools="$dataset"
	pools="${pools%/*}"
	
	for i in $pools
	do
		# query datasets
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"
		echo "$listing"
		#sleep 5
		for j in $listing
		do
			#dSet="$(zpool get bootfs $i | awk '{print $3}' | sed -n '2 p')"
			dSet="$j"
			if [ "$dSet" == '-' ]
			then
				format="N/A"
				location="N/A"
				else
				format="$(zfs get keyformat $dSet | awk '{print $3}' | sed -n '2 p')"
				location="$(zfs get keylocation $dSet | awk '{print $3}' | sed -n '2 p')"
			fi
			# if format == raw or hex & location is a valid file ... if not a valid file , complain
			# ie, not none or passphrase, indicating no key or passphrase, thus implying partition or keyfile type
			if [ $format == 'raw' ] || [ $format == 'hex' ]
			then
				# possible locations are : http/s, file:///, prompt, pkcs11:
				# only concerned with file:///
				location_type="${location%:///*}"
				if [ $location_type == 'file' ]
				then
					# if not, then probably https:/// ....
					# put key file in to initramfs
					source="${location#*//}"
					destination="${source%/*}"
					destination="$offset$destination"
					mkdir -p $destination
					if test -f "$source"; then
						echo "copying $source to $destination"
						cp $source $destination
					else
						echo "key not found for $j"
					fi
					echo "coppied $source to $destination for $j"
				else
					echo "nothing to do for $j ..."
				fi
			fi
		done
	done
}

check_mounts() {
	dir="$(echo "$1" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			echo "umount $mountpoint"
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir\/" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	done
}

function clear_fs() {
	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ $1"
	echo "deleting old files (calculating...)"
	count="$(find $1/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $1/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... $1"
}

function config_env()
{
	mkdir -p $1/var/lib/portage/binpkgs
	mkdir -p $1/var/lib/portage/distfiles
	mkdir -p $1/srv/crypto/
	mkdir -p $1/var/db/repos/gentoo

	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"

	# MOUNTS
	echo "msize = $mSize"
	mount -t proc proc $1/proc
	mount --rbind /sys $1/sys
	mount --make-rslave $1/sys
	mount --rbind /dev $1/dev
	mount --make-rslave $1/dev
	# because autofs doesn't work right in a chroot ...
	mount -t tmpfs -o size=$mSize tmpfs $1/tmp
	mount -t tmpfs tmpfs $1/var/tmp
	mount -t tmpfs tmpfs $1/run
	mount --bind /var/lib/portage/binpkgs $1/var/lib/portage/binpkgs
	mount --bind /var/lib/portage/distfiles $1/var/lib/portage/distfiles

}

function copymodules() {

			# INPUTS : ${x#*=} - dataset

			dataset=$1
			mntpt="$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
			src=/usr/src/linux
			src="$(getKVER)"
			src=/lib/modules/$src
			dst=${mntpt}/lib/modules
			echo "copying over kernel modules... $src --> $dst"
			mkdir -p $dst
			rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst
}

function copykernel() {

			# INPUTS : ${x#*=} - dataset
			dataset=$1
			mntpt="$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
			dst="linux-$(getKVER)"
			dst=$mntpt/usr/src/$src
			echo "copying over kernel source... /usr/src/$src --> $dst"
			rsync -a -r -l -H -p --delete-before --info=progress2 /usr/src/$src $dst

}

function editboot() {

			# INPUTS : ${x#*=} - dataset
			dataset=$1
			bootref="/boot/EFI/boot/refind.conf"
			src=getKVER
			# find section in refind.conf
			line_number=$(grep -n "$dataset " $bootref  | cut -f1 -d:)
			loadL=$((line_number-2))
			initrdL=$((line_number-1))
			##### DEBUG #################################################################
			#echo "line # $line_number , src=  $src"
			#grep -n "$dataset " $bootref
			#sed -n "${loadL}s/loader.*/loader \\/linux\\/$src\\/vmlinuz/p" $bootref
			#sed -n "${initrdL}s/initrd.*/initrd \\/linux\\/$src\\/initramfs/p" $bootref
			sed -i "${loadL}s/loader.*/loader \\/linux\\/$src\\/vmlinuz/" $bootref
			sed -i "${initrdL}s/initrd.*/initrd \\/linux\\/$src\\/initramfs/" $bootref
}


# update_kernel [ no args ] ... builds new kernel into g2deployment folder for copying to boot drives

function updateKernel() {

	#emerge --sync
	#emerge gentoo-sources
	#zcat /proc/config.gz > /usr/src/linux/.config

	# assumes that the kernel has been configured properly and installed through portage and eselect is accurate

	cDir="$(pwd)"
	cd /usr/src/linux
	make clean

	cores="$(cat /proc/cpuinfo | grep 'cpu cores' | wc -l)"
	make -j$cores
	make modules_install
	make install
	emerge zfs-kmod zfs
	genkernel --install initramfs --compress-initramfs-type=lz4 --zfs
	sync

	cd $cDir

	version=getKVER

	mkdir -p $cDir/boot/LINUX/TEMP

	mv /boot/config-${version} $cDir/boot/LINUX/TEMP
	mv /boot/System.map-${version} $cDir/boot/LINUX/TEMP
	mv /boot/initramfs-${version}.img $cDir/boot/LINUX/TEMP/initramfs
	mv /boot/vmlinuz-${version} $cDir/boot/LINUX/TEMP/vmlinuz

	tar cfvz $cDir/boot/LINUX/TEMP/modules.tar.gz /lib/modules/${version}

	echo "transferring over kernel files"
	rsync -a -r -l -H -p -c --delete-before --progress /boot/TEMP $cDir/LINUX/
	rm $cDir/boot/LINUX/TEMP -R
}

# add_efi_entry $version $profile $pool/dataset
function add_efi_entry() {

	VERSION=$1
	#PROFILE=$2
	DATASET=$2
	POOL="${DATASET%/*}"

	echo "DATASET = $DATASET ;; POOL = $POOL"

	UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"

	echo "version = $VERSION"
	echo "pool = $POOL"
	echo "uuid = $UUID"

	offset="$(getZFSMountPoint $DATASET)"

	echo "offset for add_efi_entry = $offset"

	################################# HIGHLY RELATIVE OFFSET !!!!!!!!!!!!!!!!!!!!!!!!
	offset="$(getZFSMountPoint $DATASET)/boot/EFI/boot/refind.conf"
	################################################################################

	echo "offset for add_efi_entry = $offset"

	echo '' >> $offset
	echo "menuentry \"Gentoo Linux $VERSION $DATASET\"" >> $offset
	echo '{' >> $offset
	echo '	icon /EFI/boot/icons/os_gentoo.png' >> $offset
	echo "	loader /linux/$VERSION/vmlinuz" >> $offset
	echo "	initrd /linux/$VERSION/initramfs" >> $offset
	echo "	options \"$UUID dozfs root=ZFS=$DATASET default delayacct rw\"" >> $offset
	echo '	#disabled' >> $offset
	echo '}' >> $offset

}


# boot_install $DISK $SRC_DIR $PROFILE $TARGET(pool/dataset)
function boot_install() {
	
	#boot=/dev/EFI_partition
	# this will copy the EFI partition contents over from $DEPLOY/boot, it will alter the refind.conf by searching for the
	# pool/dataset, it will adjust the /etc/autofs, after the stage3 is employed & packages installed. kernel
	# version is updated as well. Aswell the title. Perhaps even ADD a profile to refind.conf
	# verify valid partition and file system exists. (check vfat + verify refind

	#echo "args = $@"

	disk=$1				# partition to install/regulate
	#sigFile=./boot.sig	# sorted IO
	source=$2
	# can include snapshots ... which will be sourced from
	target=$3	#pool/dataset
	
	# filter for snapshots
	pdset="${target%@*}"
	#echo "PDSET = $pdset"
	version=$(getKVER)
	offset=$(getZFSMountPoint $pdset)
	#echo "KVER = $version ;; OFFSET = $offset"
	tmpMount="$offset/boot"

	if [ ! -d $tmpMount ]
	then
		mkdir -p $tmpMount
	fi

	fsType=$(blkid ${disk}2 | awk '{print $4}')
	fsType=${fsType#=*}
	fsType="$(echo $fsType | tr -d '"')"
	fsType=${fsType#TYPE=*}
	#echo "FSTYPE @ $fsType"

	if [ "$fsType" = 'vfat' ]
	then
		mount -v ${disk}2 $tmpMount
		#echo "mounting ${disk}2 to $tmpMount"
		# could have used rsync with hash check anyways ...
		#echo "checking for file consistency [ $source $tmpMount]"
		rsync -r -l -H -p -c --delete-before --info=progress2 $source/* $tmpMount
		
		# MODIFY FILES
		#echo "adding EFI ENTRY to template location $version ;; $pdset"
		add_efi_entry $version $pdset
		
	fi

	if [ ! "$fsType" = 'vfat' ]
	then
		echo "invalid partition"
	fi

	if [ -z "$fsType" ]
	then
		echo "...no parition detected"
	fi

	umount -v $tmpMount
}


function configure_boot_disk() {

	disk=$1 #(strip from boot=)

	# prepare_disk /dev/disk 
	# create partition map
	# echo "ignore sr0..."

	lresult="$(ls /dev | grep ${disk##*/} | wc -l)"

	# if 1, disk is not configured
	if [[ "$lresult" -eq 1 ]]; then 
		echo "$disk is present, press enter to configure disk";
		read 
	# if >1, disk is configured ?
	elif [[ "$lresult" -gt 1 ]]; then 
		echo "$disk is configured, exiting...";
		# sgdisk --zap-all $disk
		# partprobe
		exit
	# if 0 disk is not present
	elif [[ "$lresult" -eq 0 ]]; then echo "$disk is NOT configured"; 
		echo "$disk is missing, exiting..."
		exit
	fi
	
	sgdisk --new 1:0:+32M -t 1:EF02 ${disk}
	sgdisk --new 2:0:+8G -t 2:EF00 ${disk}
	#sgdisk --new 3:0:+16G -t 3:8200 $disk
	#mkswap $disk3
	sgdisk --new 3:0 -t 3:8300 ${disk}

	# install boot contents
	mkfs.vfat ${disk}2
	#boot_install ${disk}2	
	options=""
	#echo "disk = ${disk}3"

	# install safe image
	zpool create ${options} \
		-O acltype=posixacl \
		-O compression=lz4 \
		-O dnodesize=auto \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O encryption=aes-256-gcm \
		-O keyformat=hex \
		-O keylocation=file:///srv/crypto/zfs.key \
		-O mountpoint=/srv/zfs/safe safe \
		${disk}3

	# create boot entry for safe image
}

function config_mngmt() {

	offset=$2
	profile=$1
##	echo "$profile"
#	echo "$(getPkgs $profile)"
	pkgs="$(getPkgs $profile)"
	tar cfv $offset/config.tar -T ./config/files.cfg
	tar xfv $offset/config.tar -C $offset
	rm $offset/config.tar
	cp /root $offset -Rp
	cp /home $offset -Rp
	uses="$(cat ./packages/$profile.conf)"
	sed -i "/USE/c $uses" $offset/etc/portage/make.conf
	echo "$pkgs" > $offset/package.list
	cat $offset/package.list
}


function get_stage3() {
	#echo "getting stage 3"
	str=$1
	offset=$2
	case $str in
		"gnome")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"plasma")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"hardened")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"gnome/systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"plasma/systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		*)
			mirror="default"
			file="default"
		;;
	esac

	echo "mirror = $mirror, file = $file"
	wget $mirror$file --directory-prefix=$offset
	wget $mirror$file.asc --directory-prefix=$offset
	gpg --verify $offset/$file.asc
	rm $offset/$file.asc

	echo "decompressing $file..."
	tar xf $offset/$file -C $offset
	rm $offset/$file
}


function common() {
	emergeOpts="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99 --exclude=sys-fs/zfs-kmod --exclude=sys-kernel/gentoo-sources --exclude=sys-kernel/git-sources"
	emergeOpts2="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99"
	mkdir -p /var/db/repos/gentoo
	emerge-webrsync
	locale-gen -A
	eselect locale set en_US.utf8
	echo "SYNC EMERGE !!!!!"
	emerge $emergeOpts --sync --ask=n
	eselect news read all
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
	eselect profile set default/linux/amd64/$1
	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh tmux app-arch/lz4 elfutils --ask=n
	echo "ZFS EMERGE BUILD DEPS ONLY !!!!!"
	emerge $emergeOpts --onlydeps =zfs-9999 =zfs-kmod-9999
	# seems outmoded ... perhahs redundant ... maybenot ...
	echo "BUILDING KERNEL ..."
	kver="$(uname --kernel-release)"
	eselect kernel set linux-$kver
	zcat /proc/config.gz > /usr/src/linux/.config
	echo "EMERGE ZFS !!!"
	emerge $emergeOpts2 =zfs-9999 =zfs-kmod-9999
	sync
	echo "UPDATE EMERGE !!!!!"
	emerge $emergeOpts -b -uDN --with-bdeps=y @world --ask=n
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd'
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd'
	usermod -a -G wheel sysop
	qlist -I | sort | uniq > base.pkgs
	key=$1
	file_name="${key##*/}"
	cat ./package.list | sort | uniq > profile.pkgs
	comm -1 -3 base.pkgs profile.pkgs > tobe.pkgs
	rm profile.pkgs
	rm base.pkgs
	#rm package.list
	echo "EMERGE PROFILE PACKAGES !!!!"
	emerge $emergeOpts $(cat ./tobe.pkgs)
	rm tobe.pkgs
	echo "SETTING SERVICES"
	# install dev keys for gentoo
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import
####USE ZGENHOSTID ON NEW ZPOOLS
	#zgenhostid
	eix-update
	updatedb
}

function profile_settings() {
	key=$1

	# openrc
	case ${key#17.1/*} in
		'hardened'|'desktop/plasma'|'desktop/gnome'|'selinux'|'hardened/selinux')
			echo "configuring common for hardened, plasma and gnome..."
			rc-update add local
			rc-update add zfs-mount boot
			rc-update add zfs-load-key boot
			rc-update add zfs-zed boot
			rc-update add zfs-import boot
			rc-update add autofs
			rc-update add cronie
			rc-update add syslog-ng
			rc-update add ntpd
		;;
	esac

	# systemd
	case ${key#17.1/*} in
		'desktop/plasma/systemd'|'desktop/gnome/systemd'|'systemd')
			echo "configuring systemd..."
			systemctl enable NetworkManager
			systemctl enable zfs.target
			systemctl enable zfs-import
			systemctl enable zfs-import-cache
			systemctl enable zfs-mount
			systemctl enable zfs-import.target
			systemctl enable cronie
			systemctl enable autofs
			systemctl enable ntpd
			# mask resolved and rpcbind (can unmask in the future)
			ln -sf /dev/null /etc/systemd/system/systemd-resolved.service
			ln -sf /dev/null /etc/systemd/system/rpcbind.service

		;;
	esac

	# generic console
	case ${key#17.1/*} in
		'systemd'|'hardened')
			echo "generic console setup..."
		;;
	esac

	# generic desktop
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/gnome')
			echo "generic desktop setup"
			sed -i "/DISPLAYMANAGER/c DISPLAYMANAGER='gdm'" /etc/conf.d/display-manager
		;;
	esac

	# generic openrc desktop
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/gnome')
			echo "configuring openrc common graphical environments: plasma and gnome..."
			emerge --ask --noreplace gui-libs/display-manager-init --ask=n
			rc-update add elogind boot
			rc-update add dbus
			rc-update add display-manager default
		;;
	esac

	# generic systemd desktop
	case ${key#17.1/*} in
		'desktop/plasma/systemd'|'desktop/gnome/systemd')
			echo "configuring systemd common graphical environments: plasma and gnome..."
			systemctl enable gdm.service
		;;
	esac

	# specific cases for any specific variant

	echo "sampling @ ${key#17.1/}"


	# generic plasma
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/plasma/systemd')
			echo "configuring plasma..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=plasmawayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " >  $dir/sysop
			printf "[User]\nSession=plasmawayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# generic gnome
	case ${key#17.1/*} in
		'desktop/gnome'|'desktop/gnome/systemd')
			echo "configuring gnome..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=gnome-wayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " > $dir/sysop
			printf "[User]\nSession=gnome-wayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# specific use cases for individual profiles
	case ${key#17.1/} in
		'desktop/plasma')
			echo "configuring plasma/openrc"
		;;
		'desktop/plasma/systemd')
			echo "configuring plasma/systemd"
		;;
		'desktop/gnome')
			echo "configuring gnome/openrc..."
		;;
		'desktop/gnome/systemd')
			echo "configuring gnome-systemd"
		;;
		'systemd')
			echo "nothing special for systemd"
		;;
		'hardened')
			echo "nothing special for hardened"
		;;
		'selinux')
			echo "selinux not supported"
		;;
		'hardened/selinux')
			echo "hardened/selinux not supported"
		;;
	esac
}


export PYTHONPATH=""
export -f common
export -f profile_settings

# [script] build=*	work=pool/dataset	<optional>boot=(/dev/bootP)		<optional>send=(send / recv IP)	
# [script] boot by itself, will install a boot record & safe-partition for a designated deployment			:: work=pool/dataset boot=/dev/sda
# [script] send, typically by itself 		:: send=host:/pool		work=pool/dataset
# [script] ... in the future work will be able to refer to a remote host:/pool/dataset and a boot drive can be specified, work will be ssh'd inside the resepctive host

echo "[script...]"

# BUILD PROFILE
for x in $@
do
	#echo "before cases $x"
	case "${x}" in
		build=*)
			echo "build..."
			# DESIGNATE BUILD PROFILE
			profile="invalid profile"
			selection="${x#*=}"
			case "${x#*=}" in
				# special cases for strings ending in selinux, and systemd as they can be part of a combination
				'hardened')
					# space at end limits selinux
					profile="17.1/hardened "
				;;
				'systemd')
					profile="17.1/systemd "
				;;
				'plasma')
					profile="17.1/desktop/plasma "
				;;
				'gnome')
					profile="17.1/desktop/gnome "
				;;
				'selinux')
					profile="17.1/selinux "
					echo "${x#*=} is not supported [selinux]"
				;;
				'plasma/systemd')
					profile="17.1/desktop/plasma/systemd "
				;;
				'gnome/systemd')
					profile="17.1/desktop/gnome/systemd "
				;;
				'hardened/selinux')
					profile="17.1/hardened/selinux "
					echo "${x#*=} is not supported [selinux]"
				;;
				*)
					profile="invalid profile"
				;;
			esac
		;;
	esac
done



# DESIGNATE A WORKING DIRECTORY TO 
for x in $@
do
	case "${x}" in
		work=*)
			#? zfs= btrfs= generic= tmpfs=
			directory="$(getZFSMountPoint ${x#*=})"
			dataset="${x#*=}"
		;;
	esac
done

# BOOT, USED FOR NEW OR EXISTING,IF EXISTING, IGNORE SAFE PARTITION.
# use case requires work=

#	NOTHING BEING WRITTEN TO VFAT, RSYNC or wtf ??
#	ZFS NOT INSTANTIATING POOL @SAFE/...
#
#


for x in $@
do
	case "${x}" in
		boot=*)
			# by default safe is the boot pool name, should probably option this....
			# by default all safe partitions are send/recv from g1@safe
			# boot_profile=getG2Profile ${dataset} 
			disk=${x#*=}
			source="./boot"
			safe_src="safe/g1@safe"
			configure_boot_disk ${disk}
			zfs send $(getHostZPool)/g1@safe | pv | zfs recv safe/g1
			boot_install ${disk} ${source} ${safe_src}
			zfs snapshot safe/g1@safe
		;;
	esac
done

# 
for x in $@
do
	case "${x}" in
		deploy)
			check_mounts ${directory}
			clear_fs ${directory}
			get_stage3 ${selection} ${directory}
			zfs_keys ${dataset}
			copymodules ${dataset}
			config_env ${directory}
			config_mngmt ${profile} ${directory}
			chroot ${directory} /bin/bash -c "common ${profile}"
			chroot ${directory} /bin/bash -c "profile_settings ${profile}"
			config_mngmt ${profile} ${directory}
		;;
	esac
done

# SEND, BOOT PROBABLY WONT BE USED WITH THIS MODE, ex. 
for x in $@
do
	case "${x}" in
		send=*)
			
		;;
	esac
done

	check_mounts ${directory}

	#EOF