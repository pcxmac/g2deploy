#!/bin/bash

    # INPUTS    BUILD=(ex.)'hardened'  
    #           WORK=chroot offset

function add_efi_entry() 
{

	VERSION=$1
	#PROFILE=$2
	DATASET=$2
	POOL="${DATASET%/*}"

	echo "DATASET = $DATASET ;; POOL = $POOL"

	UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"

	echo "version = $VERSION"
	echo "pool = $POOL"
	echo "uuid = $UUID"

	local offset="/tmp/boot/boot/EFI/boot/refind.conf"
	#offset="$(getZFSMountPoint $DATASET)"

	echo "offset for add_efi_entry = $offset"

	################################# HIGHLY RELATIVE OFFSET !!!!!!!!!!!!!!!!!!!!!!!!
	#offset="$(getZFSMountPoint $DATASET)/boot/EFI/boot/refind.conf"
	################################################################################

	sed -i "/default_selection/c default_selection $DATASET" ${offset}

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


function getKVER() 
{
	
	# ADDING PROVISION FOR FINDING MOST RECENT KVER, despite what is installed (universal approach)

		
	
	local selector="$(eselect kernel list | grep '*' | awk '{print $2}')"
	if [[ -n "$selector" ]]
	then
		selector="${selector#linux-*}"
	else
		local softlink="$(readlink /usr/src/linux)"
		if [[ -z "$softlink" ]]
		then
			selector="$(uname --kernel-release)"
		else
			selector="${softlink#linux-*}"
		fi
	fi

	# filter for r* ? ... not here.
	echo "${selector}"
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


function setup_boot()	
{

	# INPUTS : $1 = (DATASET)
	local dSet=$1

	          # by default safe is the boot pool name, should probably option this....
			# by default all safe partitions are send/recv from g1@safe
			# boot_profile=getG2Profile ${dataset} 
	local disk=$2


			#source="./boot"
			source="rsync://192.168.122.108/gentoo-patchfiles/boot"
			safe_src="usb/${dSet#*/}@safe"
			#key="/srv/crypto.zfs.key"
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
			zpool_label="$(blkid | grep "${zpool_partition}" | awk '{print $2}' | tr -d '"')"
			zpool_label="$(echo ${zpool_label#=*} | uniq)"

			#echo "zpool_partition == ${zpool_partition} :::::::::::::"
			#echo "zpool_label == ${zpool_label} :::::::::::::::::"

			echo "sending over ${dSet}@safe to ${safe_src%@*}" 
			echo "------------------------------------------------------"
			
			zfs send ${dSet}@safe | pv | zfs recv ${safe_src%@*}
			#zfs change-key -o keyformat=hex -o keylocation=file://$key ${safe_src%@*}

			echo "///////////////////////////////////////////////////////"

			# ADD DEFAULT BOOT ENTRY
 
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


	target=$3	#pool/dataset	???????????????????????????	 I DONT THINK I NEED THIS VARIABLE
	
	echo "disk = $disk" 2>&1
	echo "source = $source" 2>&1
	echo "target = $target" 2>&1
	
	# filter for snapshots
	pdset="${target%@*}"
	#echo "PDSET = $pdset"
	version="$(getKVER)"
	
	#offset="$(getZFSMountPoint $pdset)"
	offset="/tmp"


	echo "pdset = $pdset" 2>&1
	echo "version = $version" 2>&1
	echo "offset = $offset" 2>&1
	
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

	echo "fsType = $fsType" 2>&1


	if [ "$fsType" = 'vfat' ]
	then
		mount -v ${disk}2 $tmpMount
		#echo "mounting ${disk}2 to $tmpMount"
		# could have used rsync with hash check anyways ...
		#echo "checking for file consistency [ $source $tmpMount]"
		echo "sending $source to $tmpMount"
		rsync -r -l -H -p -c --delete-before --info=progress2 $source $tmpMount
		
		# MODIFY FILES
		echo "adding EFI ENTRY to template location $version ;; $pdset"
		echo "version = $version, dset = $dset  pdset = $pdset" 2>&1

		add_efi_entry ${version} ${pdset}
		
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


function configure_boot_disk() 
{

	disk=$1 #(strip from boot=)

	# prepare_disk /dev/disk 
	# create partition map
	# echo "ignore sr0..."

	lresult="$(ls /dev | grep ${disk##*/} | wc -l)"

	echo $lresult 2>&1

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

	local newSet="usb"

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
		-O mountpoint=/srv/zfs/${newSet} ${newSet} \
		${disk}3

	# create boot entry for safe image
}


    #KVER = what ever genkernel reports
    #KEY - 

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

### NEED A UNIVERSAL TRANSPORT MECHANISM FOR SYNCING ALL FILES. SCP, RSYNC ?
#
#		SYNC() HOST w/ SOURCE
#		SEND TO SOURCE DESTINATION
#		RECV FROM SOURCE DESTINATION
#		COMPRESSION AND ENCRYPTION ARE TRANSPARENT
#		
#
#############################################################################

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

function rSync() {
	local src=$1
	local dst=$2
	echo "rsync from $src to $dst"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 $src $dst
}


    

function zfs_keys() {
	# ALL POOLS ON SYSTEM, FOR GENKERNEL
	# pools="$(zpool list | awk '{print $1}') | sed '1 d')"
	
	# THE POOL BEING DEPLOYED TO ... -- DEPLOYMENT SCRIPT
	#limit pools to just the deployed pool / not valid for genkernel which would attach all pools & datasets
	local dataset=$1
	local offset="$(zfs get mountpoint ${dataset} 2>&1 | sed -n 2p | awk '{print $3}')"

	local pools="$dataset"
	pools="${pools%/*}"
	
	for i in $pools
	do
		# query datasets
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"
		echo "$listing"

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


function users()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd' 2>/dev/null
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd' 2>/dev/null
	echo "home : sysop"
	usermod --home /home/sysop sysop
	echo "wheel : sysop"
	usermod -a -G wheel sysop
	echo "shell : sysop"
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop.sysop ${homedir} -R 2>/dev/null
	echo "homedir"
}

function clear_mounts()
{
	local offset=$1

	procs="$(lsof ${offset} | sed '1d' | awk '{print $2}' | uniq)" 
	echo "killing $(echo $procs | wc -l) process(s)"  2>&1
	for process in ${procs}; do kill -9 ${process}; done

    dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	echo "$output mounts to be removed" 2>&1
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

function buildup()
{
    #echo "getting stage 3"
	local profile=$1
	local offset=$2
	local dSet=$3

	setExists=
	snapshot="$(zfs list -o name -t snapshot | sed '1d' | grep '${dset}')"

	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ $offset"
	echo "deleting old files (calculating...)"
	count="$(find $offset/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $offset/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... $offset"

	files="$(./mirror.sh ../config/releases.mirrors ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	echo "X = ${serverType%//*} :: $files @ $profile"

	case ${serverType%//*} in
		"file:/")
			echo "RSYNCING" 2>&1
			rsync -avP ${filexz#*//} ${offset}
			rsync -avP ${fileasc#*//} ${offset}
		;;
		"http:")
			echo "WGETTING" 2>&1
			wget $filexz	--directory-prefix=${offset}
			wget $fileasc	--directory-prefix=${offset}
		;;
	esac

	fileasc=${fileasc##*/}
	filexz=${filexz##*/}

	gpg --verify $offset/$fileasc
	rm $offset/$fileasc

	echo "decompressing $filexz...@ $offset" 2>&1
	decompress $offset/$filexz $offset
	rm $offset/$filexz
	#sleep 30

    echo "setting up mounts"
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


	echo "attempting to mount binpkgs..."  2>&1
	# this is to build in new packages for future installs, not always present
	mount --bind /var/lib/portage/binpkgs ${offset}/var/lib/portage/binpkgs 
	ls ${offset}/var/lib/portage/binpkgs
}

function system()
{
	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"
	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	echo "EMERGE PROFILE PACKAGES !!!!"
	pkgs="/package.list"
	emerge $emergeOpts $(cat "$pkgs")
	
	#echo "SETTING SERVICES"
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import
	eix-update
	updatedb
}

function services()
{
	local lineNum=0
	local service_list=$1

	bash <(curl "${service_list}")
}

function install_kernel()
{
	local offset=$1

	rsync -ahP --info=progress2 $(./mirror.sh ../config/kernel.mirrors *)/current/ $offset
	archive="$(ls ${offset} | grep '^linux.*.gz$')"
	ksrc=${archive%*.tar.gz}
	pkgV=${archive#linux-*} 
	pkgV=${pkgV%*-gentoo*}

	emergeOpts="--binpkg-respect-use=y --verbose --tree --backtrack=99 --ask=n"
	chroot ${offset} /usr/bin/emerge $emergeOpts --getbinpkg=y =gentoo-sources-${pkgV}

	echo "decompressing kernel... $offset/$archive <<<<<<<<<<"
	pv ${offset}/${archive} | tar xzf - -C ${offset}
	rm ${offset}/${archive}

	echo "decompressing modules...  $offset/${ksrc#*-}/modules.tar.gz"
	pv $offset/${ksrc#*-}/modules.tar.gz | tar xzf - -C ${offset}
	
	rsync -ahP --info=progress2 ${offset}/${ksrc#*-}/ ${offset}/boot/
	rm ${offset}/${ksrc#*-} -R

	echo "selecting kernel... ${ksrc}"
	chroot ${offset} /usr/bin/eselect kernel set ${ksrc}
}

function install_modules()
{
		emergeOpts="--binpkg-respect-use=y --verbose --tree --backtrack=99"
		emerge $emergeOpts --buildpkg=y --getbinpkg=y --onlydeps =zfs-kmod-9999 
		emerge $emergeOpts --buildpkg=n --getbinpkg=n =zfs-kmod-9999 
		emerge $emergeOpts --buildpkg=y --getbinpkg=y --onlydeps =zfs-9999
		emerge $emergeOpts --buildpkg=n --getbinpkg=n =zfs-9999
		emerge $emergeOpts --buildpkg=n --getbinpkg=n app-emulation/virtualbox-modules
}


function patches()
{
    local offset=$1
	local lineNum=0

    echo "patching system files..."
    rsync -avP /var/lib/portage/patchfiles/ ${offset}

	echo "patching make.conf..."
	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf
		fi
	# 																	remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(./mirror.sh ../config/package.mirrors *)/common.conf" | sed 's/ //g' | sed "s/\"/'/g"))

	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf	
		fi
	# 																	    remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(./mirror.sh ../config/package.mirrors *)/${profile}.conf" | sed 's/ //g' | sed "s/\"/'/g"))
}

function locales()
{

	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"
    local key=$1
	locale-gen -A
	eselect locale set en_US.utf8
	emerge-webrsync

	#MOUNT --BIND RESOLVES NEED TO CONTINUALLY SYNC, IN FUTURE USE LOCAL MIRROR
	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
		
	#	{key%/openrc} :: is a for the edgecase 'openrc' where only that string is non existent with in eselect-profile
	eselect profile set default/linux/amd64/${key%/openrc}
}

function certificates()
{
    echo "certs"
}

function pkgProcessor()
{
    local profile=$1
	local offset=$2

	url="$(echo "$(./mirror.sh ../config/package.mirrors *)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url)"
	#echo ":::: $url"
	url="$(echo "$(./mirror.sh ../config/package.mirrors *)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url)"
	#echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	echo "$commonPkgs" 2>&1
	echo "$profilePkgs" 2>&1

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	echo "${diffPkgs}" > ${offset}/package.list
}



# check mount, create new mount ?
export PYTHONPATH=""

export -f users
export -f locales
export -f system
export -f services
export -f install_modules

dataset=""				#	the working dataset of the installation
directory=""			# 	the working directory of the prescribed dataset
profile=""				#	the build profile of the install
selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }

    for x in $@
    do
        case "${x}" in
            work=*)
                #? zfs= btrfs= generic= tmpfs=
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"             
            ;;
        esac
    done

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
                    'musl')
                        # space at end limits selinux
                        profile="17.0/musl/hardened "
                    ;;
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

	for x in $@
    do
        case "${x}" in
            deploy)

				### NEED F/S CONTEXT SENSITIVE

				clear_mounts ${directory}

				buildup ${profile} ${directory} ${dataset}
				zfs_keys ${dataset}
				# certificates ?	
				##############################
				patches ${directory}
				pkgProcessor ${profile} ${directory}
				chroot ${directory} /bin/bash -c "locales ${profile}"
				install_kernel ${directory}


				chroot ${directory} /bin/bash -c "install_modules"
				#	ZFS, VBOX, ... (wireguard and bpf should be in place)
				#
				#
				chroot ${directory} /bin/bash -c "system"
				chroot ${directory} /bin/bash -c "users ${profile}"

				services_URL="$(echo "$(./mirror.sh ../config/package.mirrors * )/${profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"
				#echo "$services_URL"
				
				#sleep 30
				chroot ${directory} /bin/bash -c "services ${services_URL}"
				zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key ${dataset}

				zfs snapshot ${dataset}@safe

				clear_mounts ${directory}

			# potential cleanup items
			#
			#	move binpkgs for client to /tmp as well, disable binpkg building
			#	reflash modules, or separate modules and kernel out...
			#	autofs integration w/ boot drive
			#	clear mounts 
			#

            ;;
        esac
    done

for x in $@
do
    case "${x}" in
        boot=*)
			if [[ -n "${dataset}" ]]
			then
				setup_boot ${dataset}	${x#*=}

			else
				echo "work is undefined"
			fi
        ;;
    esac
done
