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

function pkg_mngmt() {

	local profile=$1
	local offset=$2

	local commonPkgs="$(cat ./packages/common.pkgs)"
	local profilePkgs="$(cat ./packages/${profile}.pkgs)"
	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	#echo ${allPkgs} > ${offset}/packages_list
	#echo ${iBase} >> ${offset}/packages_list

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	#echo ${diffPkgs} >> ${offset}/packages_list
	#echo "--------------diffPkgs------------------------------" >> ${offset}/packages_list	

	echo "${diffPkgs}" > ${offset}/package.list

}


function getG2Profile() {
	local current="17.1"
	#dataset=$1 
	#mountpoint=getZFSMountPoint $dataset
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*/$current/}"
	echo $result
}

function getHostZPool () {
	local pool="$(mount | grep " / " | awk '{print $1}')"
	pool="${pool%/*}"
	echo ${pool}
}

function getZFSMountPoint (){
	local dataset=$1
	echo "$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
}

function decompress() {

	local src=$1
	local dst=$2

	#echo "SRC = $src	;; DST = $dst"

	# tar -J - bzip2
	# tar -z - gzip
	# tar -x - xz
	
	local compression_type="$(file $src | awk '{print $2}')"
	
	case $compression_type in
	'XZ')
		pv $src | tar xJf - -C $dst
		;;	
	'gzip')
		pv $src | tar xzf - -C $dst
		;;
	esac

}

function compress() {
	local src=$1
	local dst=$2
	local ksize="$(du -sb $src | awk '{print $1}')"
	echo "ksize = $ksize"
	tar cfz - $src | pv -s $ksize  > ${dst}
}

function compress_list() {
	local src=$1
	local dst=$2
	
	#echo "compressing LIST @ $src $dst"
	tar cfz - -T $src | (pv -p --timer --rate --bytes > $dst)
}

function sync() {
	local src=$1
	local dst=$2
	echo "rsync from $src to $dst"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 $src $dst
}

function getKVER() {
	
	local selector="$(eselect kernel list | grep '*' | awk '{print $3}')"
	if [[ -n "$selector" ]]
	then
		echo "$selector"
	else
		local softlink="$(readlink /usr/src/linux)"
		if [[ -z "$softlink" ]]
		then
			echo "$(uname --kernel-release)"
		else
			echo "${softlink#linux-*}"
		fi
	fi
}

# sig_check $directory $list
function sig_check() {
	local srcDirectory=$1
	local validSums="$(cat $2)"
	# verify md5sums and if file exists, echo invalid md5sums, report error or 0
	local cDir=$(pwd)
	cd ${srcDirectory}
	local error=0
	for line in $validSums
	do
		local lineSum="$(echo $line | awk '{print $1}')"
		local lineFile="$(echo $line | awk '{print $2}')"
		if [ ! -f $lineFile ]; then echo "missing file @$lineFile"; error=1;
		else
			local thisSum="$(md5sum $lineFile | awk '{print $1}')"
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
						#echo "copying $source to $destination"
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

	# can use PS AUX to search for 'NAME' (path) for open processes inside the file system, also lsof $offset, 
	# then just kill -9 all associated processes then UMOUNT


	dir="$(echo "$1" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			#echo "umount $mountpoint"
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
	offset="$1"

	mkdir -p ${offset}/var/lib/portage/binpkgs
	mkdir -p ${offset}/var/lib/portage/distfiles
	mkdir -p ${offset}/srv/crypto/
	mkdir -p ${offset}/var/lib/portage/repos/gentoo

	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"

	# MOUNTS
	echo "msize = $mSize"
	mount -t proc proc ${offset}/proc
	mount --rbind /sys ${offset}/sys
	mount --make-rslave ${offset}/sys
	mount --rbind /dev ${offset}/dev
	mount --make-rslave ${offset}/dev
	# because autofs doesn't work right in a chroot ...
	mount -t tmpfs -o size=$mSize tmpfs ${offset}/tmp
	mount -t tmpfs tmpfs ${offset}/var/tmp
	mount -t tmpfs tmpfs ${offset}/run
	#mount --bind /var/lib/portage/binpkgs $1/var/lib/portage/binpkgs
	#mount --bind /var/lib/portage/distfiles $1/var/lib/portage/distfiles
	#mount --bind /usr/src $1/usr/src
	#mount --bind /var/db/repos/gentoo $1/var/db/repos/gentoo

}

function copymodules() {
			# INPUTS : ${x#*=} - dataset
			dataset=$1
			mntpt="$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
			#src=/usr/src/linux
			src="$(getKVER)"
			#echo "src = $src"
			src=/lib/modules/$src
			dst=${mntpt}/lib/modules			
			echo "copying over kernel modules... $src --> $dst"
			mkdir -p $dst
			rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst
}

function compresskernel() {

			# INPUTS : ${x#*=} - dataset
			dataset=$1
			#src="/usr/src/linux-$(getKVER)"
			src="./src/linux-$(getKVER).tar.gz"
			dst="linux-$(getKVER).tar.gz"
			dst="$mntpt/$dst"
			mntpt="$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
			echo "copying over kernel source... $src --> $dst"
			rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst
}


# SEARCHES FOR APPROPRIATE DATASET AND MODIFIES KERNEL AND INITRD LINES TO UPDATE
function editboot() {

			# INPUTS : ${x#*=} - dataset
			local dataset="$1"
			local bootref="/boot/EFI/boot/refind.conf"
			local src="$2"
			# find section in refind.conf
			line_number=$(grep -n "${dataset} " ${bootref}  | cut -f1 -d:)
			if [[ -n "${line_number}" ]]
			then
				billz="/666-"
				menuL=$((line_number-5))
				loadL=$((line_number-2))
				initrdL=$((line_number-1))
				sed -i "${menuL}s|menuentry.*|menuentry \"Gentoo Linux ${src} ${dataset}\" |" ${bootref}
				sed -i "${loadL}s|loader.*|loader \\/linux\\/${src}\\/vmlinuz|" ${bootref}
				sed -i "${initrdL}s|initrd.*|initrd \\/linux\\/${src}\\/initramfs|" ${bootref}
			else
				add_efi_entry ${src} ${dataset}
			fi
			
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

	version="$(getKVER)"

	mkdir -p $cDir/boot/LINUX/TEMP

	mv /boot/config-${version} $cDir/boot/LINUX/TEMP
	mv /boot/System.map-${version} $cDir/boot/LINUX/TEMP
	mv /boot/initramfs-${version}.img $cDir/boot/LINUX/TEMP/initramfs
	mv /boot/vmlinuz-${version} $cDir/boot/LINUX/TEMP/vmlinuz

	tar cfvz $cDir/boot/LINUX/TEMP/modules.tar.gz /lib/modules/${version}
	#decompress $cDir/boot/LINUX/TEMP/modules.tar.gz /lib/modules/${version}

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

	offset="/boot/EFI/boot/refind.conf"
	#offset="$(getZFSMountPoint $DATASET)"

	echo "offset for add_efi_entry = $offset"

	################################# HIGHLY RELATIVE OFFSET !!!!!!!!!!!!!!!!!!!!!!!!
	#offset="$(getZFSMountPoint $DATASET)/boot/EFI/boot/refind.conf"
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
	version="$(getKVER)"
	offset="$(getZFSMountPoint $pdset)"
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
		echo "sending $source to $tmpMount"
		rsync -r -l -H -p -c --delete-before --info=progress2 $source/* $tmpMount
		
		# MODIFY FILES
		echo "adding EFI ENTRY to template location $version ;; $pdset"
		add_efi_entry ${version} ${dset}
		
	fi

	if [ ! "$fsType" = 'vfat' ]
	then
		echo "invalid partition"
	fi

	if [ -z "$fsType" ]
	then
		echo "...no parition detected"
	fi
	echo "syncing write to boot drive..."
	sync
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

function patch_files() {

	local offset=$1
	local profile=$2
	
	rsync -avP ./files.patch/* ${offset}/

	lineNum=0

	# common
	while read line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf
			#echo "$LineNum ***$line***  --> $PREFIX && $SUFFIX"
		fi
	done <./packages/common.conf
			
		# specific
	while read line; do
		((LineNum+=1))
		PREFIX=${line%=*}
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			sed -i "/\$PREFIX/c $line" ${offset}/etc/portage/make.conf	
			#echo "$LineNum ***$line***  --> $PREFIX && $SUFFIX"
		fi
	done <./packages/${profile}.conf
}

function config_etc() {

	local offset=$2
	local profile=$1

	patch_files ${offset} ${profile}

	#tar cf $offset/config.tar -T ./config/files.cfg
	#tar xf $offset/config.tar -C $offset
	echo "compressing to $offset/config.tar"
	compress_list ./config/files.cfg $offset/config.tar
	echo "decompressing $offset/config.tar"
	decompress $offset/config.tar $offset
	rm $offset/config.tar
	
	echo "adding client files..."
	#compress ./files.patch/* ${offset}/patch.tar.gz
	#decompress ${offset}/patch.tar.gz ${offset}
	

	#cp ./root $offset -Rp
	echo "copying home to target @ $offset"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 ./home $offset
	#cp ./home $offset -Rp
	echo "copying root to target @ $offset"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 ./root $offset


	#uses="$(cat ./packages/$profile.conf)"
	#sed -i "/USE/c $uses" $offset/etc/portage/make.conf


}

function release_base_string() {

	str=$1

	case $str in
		"gnome")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
		;;
		"plasma")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
		;;
		"openrc")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-openrc/"
		;;
		"hardened")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/"
		;;
		"systemd")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-systemd/"
		;;
		"gnome/systemd")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
		;;
		"plasma/systemd")
			baseStr="/releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
		;;
		*)
			baseStr="unsupported profile string!"
		;;
	esac

	echo $baseStr

}

function local_stage3() {

	portageDir="/var/lib/portage"
	str=$1		#	(profile string)	
	locationStr="$(release_base_string $str)"
	selectStr="${locationStr#*current-*}"
	selectStr="${selectStr%*/}"

	urlBase="${portageDir}${locationStr}"
	urlCurrent="$(ls $urlBase | grep "$selectStr" | grep -v '.xz.')"

	echo "${urlBase}${urlCurrent}"	
}

function remote_stage3() {

	#	NEED A MODE FOR [ LOCAL RSYNC SERVER ;; THEN MIRROR LIST shuffled ]
	#	return the method + url of the file if exists, use tally of servers located in ./config/release.mirrors
	#	methods for getting remote stage3's: { rsync (rsync://domain.tld/MISC/releases); wget (http://domain.tld/MISC/release) }

	serversList="./config/release.mirrors"
	str=$1		#	(profile string)
	locationStr="$(release_base_string $str)"
	selectStr="${locationStr#*current-*}"
	selectStr="${selectStr%*/}"

	# cycle through mirrors, to find a valid current stage3	
	while read -r server 
	do
		echo "checking $server ..."
		urlBase="$server$locationStr"
		urlCurrent="$(curl -s $urlBase | grep "$selectStr" | sed -e 's/<[^>]*>//g' | grep '^stage3-' | awk '{print $1}' | head -n 1 )"
		if [[ -n "$urlCurrent" ]];
		then 
			urlCurrent="${urlCurrent%.t*}.tar.xz"
			echo "${urlBase}${urlCurrent}"
			exit
		fi
		
	# shuffle the mirror list to alleviate loading the first in line
	done < <(cat ./config/release.mirrors | shuf)

	# NO servers found, otherwise it would have exited before this line... output empty string to indicate error
	if [[ -z $urlCurrent ]];
	then 
		urlBase="no "
		urlCurrent="result !"
		echo ""
	fi
	# no default route
}

function get_stage3() {
	#echo "getting stage 3"
	str=$1
	offset=$2

	local_stage3_url="$(local_stage3 $str)"

	if [ -n "$local_stage3_url" ]
	then
		file=${local_stage3_url##*/}
		#echo "offset = $offset, file = $file"
		rsync -avP ${local_stage3_url} ${offset}
		rsync -avP ${local_stage3_url}.asc ${offset}
	else
		remote_stage3_url="$(remote_stage3 $str)"

		if [ -n "$remote_stage3_url" ]
		then
			file=${remote_stage3_url##*/}
			#echo "offset = $offset, file = $file"
			wget ${remote_stage3_url}	--directory-prefix=${offset}
			wget ${remote_stage3_url}.asc	--directory-prefix=${offset}
		fi
	fi
	
	echo "offset = $offset, file = $file"
	
	gpg --verify $offset/$file.asc
	rm $offset/$file.asc

	echo "decompressing $file...@ $offset"
	decompress $offset/$file $offset
	rm $offset/$file
}


function common() {
	kver=$2
	key=$1
	emergeOpts="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99"

	locale-gen -A
	eselect locale set en_US.utf8
	emerge-webrsync

	echo "SYNC EMERGE !!!!!"
	#MOUNT --BIND RESOLVES NEED TO CONTINUALLY SYNC, IN FUTURE USE LOCAL MIRROR
	emerge $emergeOpts --sync --ask=n
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data



	#	{key%/openrc} :: is a for the edgecase 'openrc' where only that string is non existent with in eselect-profile
	eselect profile set default/linux/amd64/${key%/openrc}

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	echo "BUILDING KERNEL ..."
	ls /linux-${kver}.tar.gz -ailpht
	ls -ail /usr/src
	emerge $emergeOpts =gentoo-sources-${kver%*-gentoo}
	decompress /linux-${kver}.tar.gz /
 	rm /linux-${kver}.tar.gz

	# 
	eselect kernel set linux-${kver}

	############################################# UPDATE AFTER DEPLOY
	#echo "UPDATE EMERGE !!!!!"
	#emerge $emergeOpts -b -uDN --with-bdeps=y @world --ask=n
	
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd'

	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd'
	echo "home : sysop"
	usermod --home /home/sysop sysop
	echo "wheel : sysop"
	usermod -a -G wheel sysop
	echo "shell : sysop"
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop.sysop ${homedir} -R
	echo "homedir"
	

	echo "EMERGE PROFILE PACKAGES !!!!"
	pkgs="/package.list"
	#file_name="${key##*/}"
	emerge $emergeOpts $(cat "$pkgs")
	#rm tobe.pkgs


	# THIS KERNEL MODULE WILL BE OVER WRITTEN BY THE MODULES FROM THE HOST
	echo "EMERGE ZFS !!!"
	\emerge =zfs-9999 =zfs-kmod-9999
	zcat /proc/config.gz > /usr/src/linux/.config
	sync

	echo "SETTING SERVICES"
	# install dev keys for gentoo
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import
	eix-update
	updatedb
}


##########################################################################################################
#
#
#	NEED A SERVICES FILE PER PROFILE. *.services
#
#



function profile_settings() {
	key=$1

	# openrc = ''
	case ${key#17.1*} in
		'/openrc' | '/hardened'|'/desktop/plasma'|'/desktop/gnome'|'/selinux'|'/hardened/selinux')
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
	case ${key#17.1*} in
		'/desktop/plasma/systemd'|'/desktop/gnome/systemd'|'/systemd')
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
	case ${key#17.1*} in
		'/systemd'|'/hardened')
			echo "generic console setup..."
		;;
	esac

	# generic desktop
	case ${key#17.1} in
		'/desktop/plasma'|'/desktop/gnome')
			echo "generic desktop setup"
			sed -i "/DISPLAYMANAGER/c DISPLAYMANAGER='gdm'" /etc/conf.d/display-manager
		;;
	esac

	# generic openrc desktop
	case ${key#17.1*} in
		'/desktop/plasma'|'/desktop/gnome')
			echo "configuring openrc common graphical environments: plasma and gnome..."
			emerge --ask --noreplace gui-libs/display-manager-init --ask=n
			rc-update add elogind boot
			rc-update add dbus
			rc-update add display-manager default
		;;
	esac

	# generic systemd desktop
	case ${key#17.1*} in
		'/desktop/plasma/systemd'|'/desktop/gnome/systemd')
			echo "configuring systemd common graphical environments: plasma and gnome..."
			systemctl enable gdm.service
		;;
	esac

	# specific cases for any specific variant

	echo "sampling @ ${key#17.1/}"


	# generic plasma
	case ${key#17.1*} in
		'/desktop/plasma'|'/desktop/plasma/systemd')
			echo "configuring plasma..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=plasmawayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " >  $dir/sysop
			printf "[User]\nSession=plasmawayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# generic gnome
	case ${key#17.1*} in
		'/desktop/gnome'|'/desktop/gnome/systemd')
			echo "configuring gnome..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=gnome-wayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " > $dir/sysop
			printf "[User]\nSession=gnome-wayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# specific use cases for individual profiles
	case ${key#17.1} in
		'/desktop/plasma')
			echo "configuring plasma/openrc"
		;;
		'/desktop/plasma/systemd')
			echo "configuring plasma/systemd"
		;;
		'/desktop/gnome')
			echo "configuring gnome/openrc..."
		;;
		'/desktop/gnome/systemd')
			echo "configuring gnome-systemd"
		;;
		'/systemd')
			echo "nothing special for systemd"
		;;
		'')
			echo "nothing special for openrc"
		;;
		'/hardened')
			echo "nothing special for hardened"
		;;
		'/selinux')
			echo "selinux not supported"
		;;
		'/hardened/selinux')
			echo "hardened/selinux not supported"
		;;
	esac
}

function update_host() {

	emerge --sync
	# sync package masks/keywords/usecases etc... (kernel version is regulated through mask)
	emerge -uDn @world

	current_kernel="linux-$(uname --kernel-release)"
	latest_kernel="$(eselect kernel list | tail -n 1 | awk '{print $2}')"

	if [[ "$current_kernel" == "$latest_kernel" ]]; then echo "no changes"; exit; fi

	eselect kernel set $(eselect kernel list | tail -n 1 | awk '{print $2}')

	cd /usr/src/linux
	zcat /proc/config.gz > ./.config

	make -j $(nproc);
	make modules_install;
	make install;
	\emerge =zfs-kmod-9999 =zfs-9999;
	genkernel --install initramfs --compress-initramfs-type=lz4 --zfs_keys
	sync

	#<prepfs>
	#<chroot> ${working_directory} /bin/bash
	#	sync config files
	#	emerge --sync
	#	emerge -uDn @world



}

export PYTHONPATH=""
export -f common
export -f profile_settings
export -f getKVER
export -f decompress
export -f getG2Profile

export PROMPT_COMMAND="g2build @ ${directory}"


# [script] build=*	work=pool/dataset	<optional>boot=(/dev/bootP)		<optional>send=(send / recv IP)	
# [script] boot by itself, will install a boot record & safe-partition for a designated deployment			:: work=pool/dataset boot=/dev/sda
# [script] send, typically by itself 		:: send=host:/pool		work=pool/dataset
# [script] ... in the future work will be able to refer to a remote host:/pool/dataset and a boot drive can be specified, work will be ssh'd inside the resepctive host

echo "[script... $(getKVER)]"

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
				'openrc')
					# space at end limits selinux
					profile="17.1/openrc"
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

#	ZFS NOT INSTANTIATING POOL @SAFE/...
#	WORK=SOURCE DATASET
#	NEED TO INSTANTIATE DATASETS like G1 if not present
#	NEED TO HAVE A WAY TO MANAGE KERNEL BOOT SETS in ./BOOT/LINUX 
#	NEED a MAKE.CONF SEDitor w/ things like $(nproc) 
#	NEED more variability for safe dataset and key location. :: MAKE getZFSKEYlocation() function
# 	NEED *UPDATE* FUNCTION to USE 'SYNC' command in /var/lib/portage as well, 	|| UPDATE=~host
#		UPDATE=pool/dataset ...
#		UPDATE needs a watchdog function to kill transactions if they freeze data pulling, reset connection, or timeout for a period then reattempt

	############ NEED A PKG FILE FOR TOOLS. 
#	openrc case is satisfied through string substitution for just ${VAR%/openrc}
#	config_etc mkdir's need to be part of a compressed archive deployment
#	NEED TO CHECK SET LOCALES, SAYS UNSUPPORTED ...
#	
#	CURRENT PROBLEMATIC ; BINARY PACKAGE HOST OVER RSYNC AND SNAPSHOT ACCESS OVER RSYNC.
#	NEED TO UPGRADE BINARY PKG COMPRESSION to lz4 & FORMAT TO GPKG https://wiki.gentoo.org/wiki/Binary_package_guide#Setting_up_a_binary_package_host
#	
#	FOR BINHOST-SSH, add key from server to client ./.ssh/authorized_keys
#		:: make.conf { PORTAGE_BINHOST="ssh://portage@SERVER/var/lib/portage/binpkgs"
#	
#	amd64.packages.server.tld/17.1/desktop/plasma/systemd
#	amd64.packages.server.tld/17.0/hardened

#	>>>>>>> each domain will log requests to different files, each domain will add the package to sigma.PROFILE.pkgs under $/packages/17.X... 
#	GETBINPKG only from clients, BUILD BINPKGS on server only. 
#
#	UPDATE PROCESS : --sync, distfiles+repos+snapshots, update kernel+zfs+other kernel modules (like vbox), merge
#
#	DOM0 callback get host adapter for the container, cycle up to *.*.*.1/32 that should be the 'machine bridge IP, which will host dom-0 calls
#
#	remote install from rescue disk
#	
#		identify: virtualdisk / realdisk, hostIP
#		ssh-copyid
#		ssh-script boot drive config
#		scp over boot contents
#		* NOTE, this script does not parse YAML or more complex configs with multiple disks...
#		
#	
#	
#	g2deploy :
#		work=pool/dataset
#		build=profile
#		deploy	{ execute build for environment, for build=profile }
#		boot=/device
#		update
#	
#	USECASES
#
#		->DEPLOY (boot optional)
#		->UPGRADE (w/ boot, optional)
#		->INSTALL (boot+)
#
#		
#		# create a working environment
#		work=pool/set build=profile deploy || Deploy a BUILD on SET 
#		
#		# upgrade existing working environment
#		work=pool/set upgrade (upgrades kernel, modules, boot files, packages == snapshots on to pool/set@KVER)
#		[ kernel, modules & bootfiles are generated on host, saved in ./boot and deployed to working set ]
#		
#		# build a new boot disk
#			DETECT if boot env exists { look for EFI partition, scan for configuration[refind], check working set (on or off boot disk) }
#			boot=/device work=pool/set 
#			
#		# upgrade existing working environment (no deploy asserted), 	
#			work=pool/dataset 
#			update 
#			
#		# update existing boot environment
#			work=pool/dataset
#			update
#			boot=/device
#	
#			remove /var/db/pkgs & repo
#			
#			
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
			key="/srv/crypto.zfs.key"
			# LOOK FOR ZPOOL PARTITION & VFAT PARTITION, THEN LOOK FOR REFIND/LINUX EXIT OUT OF INSTANTIATION IF PRESENT
			
			zpool import -a -f
			#z_exists="$(blkid | grep "${x}" | grep 'zfs_member')"

			vfat_partition="$(blkid | \grep ${disk} | \grep 'vfat')"
			vrat_partition="${vfat_partition%*:}"
			
			if [[ -z "${vfat_partition}" ]] 
			then
				configure_boot_disk ${disk}
				boot_install ${disk} ${source} ${safe_src}
			fi
			#zfs snapshot safe/g1@safe		## DO NOT HAVE TO ACCOMPLISH, CARRIED THROUGH ZFS-SEND

			zpool_partition="$(blkid | \grep ${disk} | \grep 'zfs_member')"
			zpool_partition="${zpool_partition%*:}"
			zpool_label="$(blkid | grep ${zpool_partition} | awk '{print $2}' | tr -d '"')"
			zpool_label="${zpool_label#=*}"

			echo "sending over $(getHostZPool)/g1@safe to ${safe_src%@*}" 
			zfs send $(getHostZPool)/g1@safe | pv | zfs recv ${safe_src%@*}
			zfs change-key -o keyformat=hex -o keylocation=file://$key ${safe_src%@*}

			# ADD DEFAULT BOOT ENTRY
			
			

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
			compresskernel ${dataset}
			config_env ${directory}
			config_etc ${profile} ${directory}
			pkg_mngmt ${profile} ${directory}
			#cat ${directory}/package.list
			chroot ${directory} /bin/bash -c "common ${profile} $(getKVER)"
			patch_files ${directory} ${profile}
			chroot ${directory} /bin/bash -c "profile_settings ${profile}"
		;;
	esac
done

# update
for x in $@
do
	case "${x}" in
		update | deploy)
		
			profile="$(getG2Profile ${directory})"
			#profile="shit"

			echo "PROFILE :: ${profile}"

			#check_mounts ${directory}
			patch_files ${directory} ${profile}

			echo "help"

#			emerge --sync
			# sync package masks/keywords/usecases etc... (kernel version is regulated through mask)
#			emerge -uDn @world --ask=n

			current_kernel="linux-$(uname --kernel-release)"
			latest_kernel="$(eselect kernel list | tail -n 1 | awk '{print $2}')"

			echo "current kernel = ${current_kernel}"
			echo "latest kernel = ${latest_kernel}"

			eselect kernel set ${latest_kernel}

			if [[ ! -f ./src/${latest_kernel}.tar.gz ]]
			then
				zcat /proc/config.gz > /usr/src/${latest_kernel}/.config
				(cd /usr/src/${latest_kernel} ; make -j $(nproc))
				(cd /usr/src/${latest_kernel} ; make modules_install)
				(cd /usr/src/${latest_kernel} ; make install)
				emerge zfs-kmod zfs;
				compress /usr/src/${latest_kernel} ./src/${latest_kernel}.tar.gz 
				genkernel --install initramfs --compress-initramfs-type=lz4 --zfs
				
				pathboot=/boot/LINUX/${latest_kernel#linux-*}
				mkdir ${pathboot} -p

				suffix=${latest_kernel##*-}

				mv /boot/initramfs-${latest_kernel#linux-*}.img ${pathboot}/initramfs
				mv /boot/vmlinuz-${latest_kernel#linux-*} ${pathboot}/vmlinuz
				mv /boot/System.map-${latest_kernel#linux-*} ${pathboot}/System.map-${latest_kernel#linux-*}
				mv /boot/config-${latest_kernel#linux-*} ${pathboot}/config-${latest_kernel#linux-*}
			fi

			echo "syncing kernel modules for ${latest_kernel#linux-*}"
			
			rsync -c -a -r -l -H -p --delete-before --info=progress2 /lib/modules/${latest_kernel#linux-*} $directory/lib/modules/

			editboot ${dataset} ${latest_kernel#linux-*}
			echo "@ ${directory}"
			config_env ${directory}
			chroot ${directory} /usr/bin/emerge --sync
			chroot ${directory} /usr/bin/emerge -b -uDN --with-bdeps=y @world --ask=n
			check_mounts ${directory}


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
