#!/bin/bash

    # INPUTS    BUILD=(ex.)'hardened'  	- build profile
    #           WORK=chroot offset		- working directory for install, skip if exists (DEPLOY).
	#			BOOT=/dev/sdX			- install to boot device, after generating image
	#			RECV=XXX				- RECV from server remotely, requires the host to be booted through medium, and mounted (ALL F/S) BTRFS+ZFS are block sends
	#			

	#	future features : 	
	#		test to see if pool exists, add new zfs datasets if no dataset, other partition types.
	#		boot medium, 
	#		

	SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
	SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"



function add_efi_entry() 
{

	VERSION=$1
	DATASET=$2
	offset="${3}/boot/EFI/boot/refind.conf"

	POOL="${DATASET%/*}"

	echo "DATASET = $DATASET ;; POOL = $POOL"

	UUID="$(blkid | grep "$POOL" | awk '{print $3}' | tr -d '"')"

	echo "version = $VERSION"
	echo "pool = $POOL"
	echo "uuid = $UUID"

	#offset="$(getZFSMountPoint $DATASET)"

	echo "offset for add_efi_entry = $offset"

	################################# HIGHLY RELATIVE OFFSET !!!!!!!!!!!!!!!!!!!!!!!!
	#offset="$(getZFSMountPoint $DATASET)/boot/EFI/boot/refind.conf"
	################################################################################

	sed -i "/default_selection/c default_selection $DATASET" ${offset}

	echo "offset for add_efi_entry = $offset"

	echo "menuentry \"Gentoo Linux $VERSION $DATASET\"" >> $offset
	echo '{' >> $offset
	echo '	icon /EFI/boot/icons/os_gentoo.png' >> $offset
	echo "	loader /linux/${VERSION#*linux-}/vmlinuz" >> $offset
	echo "	initrd /linux/${VERSION#*linux-}/initramfs" >> $offset
	echo "	options \"$UUID dozfs root=ZFS=$DATASET default delayacct rw\"" >> $offset
	echo '	#disabled' >> $offset
	echo '}' >> $offset

}


function getKVER() 
{

	# coded for ftp accessable directory listing w/ curl and kernel.mirrors

	url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
	kver="$(curl ${url_kernel} | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep '.tar.gz$')"
	kver=${kver%.tar.gz*}
	echo ${kver}

}

function getG2Profile() {

	# assumes that .../amd64/17.X/... ; X will be preceeded by a decimal

	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*.[0-9]/}"
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

# works with FTP and HTTP file access
# works with RSYNC
# works with LOCAL FILE
function mget() 
{

	local url="$(echo "$1" | tr -d '*')"			# source_URL 
	local destination=$2	# destination_FS

	case ${url%://*} in
		# local rsync only
		rsync)	
			rsync -av ${url} ${destination} 
		;;
		# local websync only
		http|ftp)
			wget -r --reject "index.*" --no-verbose --no-parent ${url} -P ${destination}	--show-progress
			mv ${destination}/${url#*://}* ${destination}/
			url=${url#*://}
			url=${url%%/*}
			echo "${url}" 2>&1
			rm ${destination}/${url} -R 
		;;

		# local download only
		ssh)
			host=${url#*://}
			source=${host#*:/}
			host=${host%:/*}

			ssh ${host} "tar cf - /${source}/" --use-compress-program="pigz -p $(nproc)" | pv --timer --rate |  pigz -d -p $(nproc) | tar xf - -C ${destination}/
			mv ${destination}/${source} ${destination}/__temp
			offset=$(echo "$source" | cut -d "/" -f1)
			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;

		# local file move only
		file|*)
			host=${url#*://}
			source=${host#*:/}
			host=${host%:/*}

			#echo "WTF ${url#*://}" 2>&1
			if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
			if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi

			tar cf - /${source} | pv --timer --rate | tar xf - -C ${destination}/
			mv ${destination}/${source} ${destination}/__temp
			
			offset=$(echo "$source" | cut -d "/" -f2)

			rm ${destination}/${offset} -R
			mv ${destination}/__temp/* ${destination}
			rm ${destination}/__temp -R
		;;
	esac
	case ${url%://*} in
		http|ftp|ssh|file|'')

		;;
	esac
}

function setup_boot()	
{

			ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
			kver="$(getKVER)"
			kver="${kver#*linux-}"

			source_url=$1				# can be local or remote pool
			stype=${source_url%://*}	# example : zfs://root@localhost.com:/pool/dataset ; btrfs:///Label/subvolume ; ssh://root@localhost:/path/to/set
			shost=${source_url#*://}	

			# source parameterization
			case ${stype} in
				#	use zfs send if no connection string (local)
				zfs)
					source=${shost#*:/}
					spool=${source%/*}
					sdataset=${source##*/}
					sdataset=${sdataset%@*}
					ssnapshot="$(echo ${source} | grep '@')"
					ssnapshot=${ssnapshot#*@}
					shost=${shost%:*}
					shost="$(echo $shost | grep -v '/' | grep "[[:alnum:]]\+@[[:alnum:]]\+")"
					if [[ -n ${shost} ]]
					then
						spath="$(ssh ${shost} "zfs get mountpoint ${spool}/${sdataset}")"
						spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
						root_path="$(ssh ${shost} "mount | grep ' / ' | grep ${spool}/${sdataset}")"
						root_path="$(echo ${root_path} | awk '{print $1}')"
						if [[ -n ${root_path} ]]; then spath=""; fi
						spath="${spath}/.zfs/snapshot/${ssnapshot}"
					else 
						spath="$(zfs get mountpoint ${spool}/${sdataset})"
						spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
						root_path="$(mount | grep ' / ' | grep ${spool}/${sdataset})"
						root_path="$(echo ${root_path} | awk '{print $1}')"
						if [[ -n ${root_path} ]]; then spath=""; fi
						spath="${spath}/.zfs/snapshot/${ssnapshot}"
					fi
				;;
				#	use btrfs send if ... no connection string
				btrfs)
					source=${shost#*:/}
					spool=${source%/*}			#LABEL
					sdataset=${source##*/}		#SUBVOLUME
					sdataset=${sdataset%@*}
					shost=${shost%:*}
					shost="$(echo $shost | grep -v '/' | grep "[[:alnum:]]\+@[[:alnum:]]\+")"
					if [[ -n ${shost} ]]
					then
						spath="$(ssh ${shost} "blkid | grep ${spool} | grep 'btrfs'")"
						spath="$(echo ${spath} | awk '{print $1}' | tr -d ':')"
						spath="$(ssh ${shost} "mount | grep ${spath}")"
						spath_root="$(echo ${spath} | grep "subvol=/" | head -n 1 | awk '{print $3}')"
						spath_subvol="$(echo ${spath} | grep "subvol=/${sdataset}" | head -n 1 | awk '{print $3}')"
						if [[ -n ${spath_subvol} ]]; then spath=${spath_subvol}; else spath="${spath_root}/${sdataset}"; fi
						sresult="$(ssh ${shost} "btrfs filesystem show ${spath} | grep 'uuid'")"
					else
						spath="$(blkid | grep ${spool} | grep 'btrfs')"
						spath="$(echo ${spath} | awk '{print $1}' | tr -d ':')"
						spath="$(mount | grep ${spath})"
						spath_root="$(echo ${spath} | grep "subvol=/" | head -n 1 | awk '{print $3}')"
						spath_subvol="$(echo ${spath} | grep "subvol=/${sdataset}" | head -n 1 | awk '{print $3}')"
						if [[ -n ${spath_subvol} ]]; then spath=${spath_subvol}; else spath="${spath_root}/${sdataset}"; fi
						sresult="$(btrfs filesystem show ${spath} | grep 'uuid')"
					fi
				;;
				#	use tar + compression & pv to move files between hosts
				ssh)
					source=${shost#*:}
					spool=${source}
					shost=${shost%:*}
					shost="$(echo $shost | grep -v '/' | grep "[[:alnum:]]\+@[[:alnum:]]\+")"
						spath="$(ssh ${shost} test ! -d ${source} || echo ${source})"
				;;
				#	use tar & pv to move files between paths
				ext4|xfs|ntfs)

					# NTFS DOES NOT SUPPORT PERMISSIONS/OWNERSHIP WELL, PLEASE SKIP

					source=${shost#*:}
					spool=${source}
					shost=""
					spath=${source}
				;;
			esac

			destination_url=$2				# DESTINATION
			dtype=${destination_url%://*}	# example :	zfs:///dev/sda:/pool/dataset ; ntfs:///dev/sdX:/mnt/sdX ; config:///path/to/config
			dhost=${destination_url#*://}	

			# destination parameterization	:: TYPE://pool/dataset@snapshot
			case ${dtype} in
				config)
					echo "config ..."
				;;
				zfs)
					destination=${dhost#*:/}
					dpool=${destination%/*}
					ddataset=${destination##*/}
					ddataset=${ddataset%@*}
					dhost="${dhost%:*}"
						dpath="/srv/zfs/${dpool}"
						#dpath="$(echo "${dpath}" | grep 'mountpoint' | awk '{print $3}')"
						#dpath=getZFSMountPoint ${dpool}/${ddataset}
				;;
				btrfs)
					destination=${dhost#*:/}
					dpool=${destination%/*}
					ddataset=${destination##*/}
					ddataset=${ddataset%@*}
					dhost="${dhost%:*}"
					dpath="/srv/btrfs/${dpool}/${ddataset}"

				;;
				ext4|xfs|ntfs)
					destination=${dhost#*:}
					dpool=${destination%/*}
					ddataset=${destination##*/}
					ddataset=${ddataset%@*}
					dhost="${dhost%:*}"
					dpath=${destination}
				;;
			esac

			echo "SOURCE | type = ${stype} ; connect to $shost ; pool/dataset/snapshot = [$spool][$sdataset][$ssnapshot] :: source = ${spath}"
			echo "DESTINATION | type = ${dtype} ; target : $dhost ; pool/dataset/snapshot = [$dpool][$ddataset][$dsnapshot] :: destination =  ${dpath}"
			echo "#########################################################################################################"

			disk=${dhost}

			clear_mounts ${disk}
			sync
			sgdisk -Z ${disk}
			wipefs -af ${disk}
			partprobe
			sync

			sgdisk --new 1:0:+32M -t 1:EF02 ${disk}
			sgdisk --new 2:0:+8G -t 2:EF00 ${disk}
			sgdisk --new 3:0 -t 3:8300 ${disk}


			clear_mounts ${disk}
			partprobe
			sync

			parts="$(ls -d /dev/* | grep "${disk}")"

			wipefs -af "$(echo "${parts}" | grep '.2')"
			wipefs -af "$(echo "${parts}" | grep '.3')"

			mkfs.vfat "$(echo "${parts}" | grep '.2')" -I

			options="-f"

			mount | grep ${disk}
			echo "format user partition { $parts }"

			if [[ ! -d ${dpath} ]]
			then 
				mkdir -p ${dpath}
			fi

			case ${dtype} in
				zfs)
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
						-O mountpoint=${dpath} ${dpool} \
						$(echo "${parts}" | grep '.3')
				;;
				btrfs)
					mount | grep ${disk}
					mkfs.btrfs $(echo "${parts}" | grep '.3') -L ${dpool} -f
					btrfs subvolume create ${dpath}
					mount -t ${dtype} $(echo "${parts}" | grep '.3') ${dpath}
				;;
				xfs)
					mkfs.xfs $(echo "${parts}" | grep '.3') -L ${ddataset} -f
					mount -t ${dtype} $(echo "${parts}" | grep '.3') ${dpath}
				;;
				ntfs)
					mkfs.ntfs $(echo "${parts}" | grep '.3') -L ${ddataset} -f
					mount -t ${dtype} $(echo "${parts}" | grep '.3') ${dpath}
				;;
				ext4)
					mkfs.ext4 $(echo "${parts}" | grep '.3') -L ${ddataset} -F
					mount -t ${dtype} $(echo "${parts}" | grep '.3') ${dpath}
				;;
			esac


###################################################################
#
#	if no disk or config is issued for the boot ... boot=zfs://:/pool/set then DO NOT FORMAT A NEW DISK, ERROR OUT IF F/S is not present locally
#	
#	
#
#	mount and 

			if [[ ${dtype} == ${stype} ]] 
			then
				case ${stype} in
					zfs)
						if [[ -n ${shost} ]]; then	ssh ${shost} zfs send ${source} | pv --timer --rate | zfs recv -F ${destination}
						else 									 zfs send ${source} | pv --timer --rate | zfs recv -F ${destination}
						fi
					;;
					btrfs)
						if [[ -n ${shost} ]]; then	ssh ${shost} btrfs send ${spath} | pv --timer --rate | btrfs receive ${dpath}
						else									 btrfs send ${spath} | pv --timer --rate | btrfs receive ${dpath}
						fi
					;;
				esac

			# compression send
			else 

			# remote source to local destination
				#	precursors for 'rough'
				#if [[ ${dtype} == 'zfs' ]]; then zfs create ${dpool}/${ddataset}; fi

				case ${shost} in
				# local source to local destination
					'')
#						echo "mget ${spath}/ ${dpath%*/}"
	
						echo "mget : ${stype} | ${shost} | ${spath}<  >${dpath}<"
						echo "path = ${dpath}${spath}/"

						url="${stype}://${shost}:${spath}/"
						echo "url(1) = ${url}"
						url=${url#*://}
						echo "url(2) = ${url}"
						url=${url#*:/}
						echo "url(3) = ${url}"

						mget ${spath}/ ${dpath}
	
					;;
					*)

						echo "mget ssh://${shost}:${spath}/ ${dpath}"
						echo "path = ${dpath%*/}${spath}"

						url="ssh://${shost}:${spath}/"
						echo "url(1) = ${url}"
						url=${url#*://}
						echo "url(2) = ${url}"
						url=${url#*:/}
						echo "url(3) = ${url}"


						mget ssh://${shost}:${spath}/ ${dpath}
					;;
				esac

			fi

			mount "$(echo "${parts}" | grep '.2')" /boot

			boot_src="ftp://10.1.0.1/patchfiles/boot/*"

			echo "mget ${boot_src} /boot"

			mget ${boot_src} /boot

			umount /boot



			sleep 30

			$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')

			# pool sees if the pool exists at all, if not, can create, if does, ask to destroy, identify
			#zpool import -a -f 2>/dev/null
			#rpool="$(zpool list $POOL | sed '1d' | awk '{print $1}')" 2>/dev/null						# prints pool, if exists
			#ypool="$(blkid | grep "$POOL" | grep 'zfs_member' | sed 's/.* LABEL=\([^ ]*\).*/\1/' | tr -d '"')"
			#rpart="$(blkid | grep $POOL | sed 's/.*\/dev\/\([^ ]*\).*/\1/' | tr -d ':')"	# prints partition associated with proposed pool

			# part(ition) and label are associated with the proposed install, if they are present, that means the disk must be destroyed.
			#part="$(blkid | grep "${disk}" | grep 'zfs_member')"
			#plabel="$(echo "${part}" | sed 's/.* LABEL=\([^ ]*\).*/\1/' | tr -d '"')"
			#ppart="$(echo "${part}" | sed 's/.*\/dev\/\([^ ]*\).*/\1/' | tr -d ':')"
			#disky="$(blkid | grep ${disk})"
			#disky="$(fdisk -l | grep "${disk}" | awk '{print $2}' | tr -d ':')"
			#rootfs="$(mount | grep ' / ' | awk '{print $1}')"

			# 	boot = (DST) : { /dev/disk-to-write ; ../config.cfg ; $PATH } ... DOESN'T NEED TO EXIST
			# 	work = (SRC) : { pool/dataset [btrfs/zfs] ; $PATH [ext4,...] } 
			# 	PATH = { ext4, ext3, xfs, fuseX, ... }
			#	btrfs.send -> btrfs.recv | config
			#	zfs.send -> zfs.recv | config
			#	btrfs.snapshot (rsync) -> PATH
			#	zfs.snapshot (rsync) -> PATH
			#	PATH -> PATH
			#	PATH -> <CONFIG>

			# ID SRC_TYPE {  }
			# ID DST_TYPE

			#echo "rpool :: $rpool"		#	-n pool exists w/ zfs
			#echo "ypool :: $ypool"		#	-n pool exists on blkid (label)						:: $POOL
			#echo "rpart :: $rpart"		#	-n pool exists on blkid (disk)						:: $POOL
			#echo "ppart :: $ppart"		#	-n disk exists on blkid / has zfs member (disk)		:: boot=(disk)
			#echo "plabel :: $plabel"	#	-n label exists on blkid / has zfs member (label)	:: boot=(disk)	
			
			# logic - 

			#	if $POOL exists in blkid (ypool), attempt to load it to see if it exists afterwords (rpool), otherwise pool is bunkem
			#	if proposed pool ($POOL) exists, must destroy, before working on disk ...
			#	if proposed disk has a pool (part;label) then ask to destroy it ...

			# cases: 

			#	pool is root, cannot be unhinged
			#	pool is stale
			#	pool exists
			#	disk is already configured
			#	disk is missing
			#	
			#	configure disk
			#	install zpool
		

#			if [[ ${dSet%/*} == ${POOL} ]] && [[ ${rootfs#*/} == ${dSet#*/} ]]
#			then
				# the pool is able to be loaded, and must be destroyed
#				echo "$POOL/${dSet#*/} is the ${rootfs} [root file system] ... exiting"
#				exit
#			fi


#			echo "${ypool} == ${rpool} ]] && [[ -n ${ypool}"
#			if [[ ${ypool} == ${rpool} ]] && [[ -n ${ypool} ]]
#			then
				# the pool is able to be loaded, and must be destroyed
#				echo "pool is already available, needs to be destroyed"
#				exit
#			fi

#			echo "-z ${rpool} ]] && [[ -n ${ypool} ]] && [[ ${ypool} == ${POOL}"
#			if [[ -z ${rpool} ]] && [[ -n ${ypool} ]] && [[ ${ypool} == ${POOL} ]]
#			then
				# reminent of an old pool exists, but the disk remains unformatted afterwords
#				echo "${plabel} is a reminent..., reconfigure the disk"
#				clear_mounts ${disk}
#				sgdisk --zap-all ${disk}
#				partprobe
#				fdisk -l | grep ${disk}
				#exit
#			fi

#			echo " -n ${ppart} ]] && [[ ${plabel} != ${POOL}"
#			if [[ -n ${ppart} ]] && [[ ${plabel} != ${POOL} ]] 
#			then
#				if [[ -z ${rpool} ]]
#				then
#					echo "${plabel} is reminent ... you can kill this."
#					exit
#				fi
#				# another pool exists on the claimed disk
#				echo "${plabel} exists on ${ppart} ... not ${POOL}, invalid configuration, must exit."
#				exit
#			fi

#			echo "-z ${disky}"
#			if [[ -z ${disky} ]] 
#			then
				# another pool exists on the claimed disk
#				echo "${disk} is not present"
#				exit
#			fi


			#pdset="${safe_src%@*}"
			#version="$(getKVER ${offset}))"
			#version="$(getKVER)"

			# redefine offset if new pool created
			#offset="$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')"

			#fsType=$(blkid "$(echo "${parts}" | grep '.2')" | awk '{print $4}')
			#fsType=${fsType#=*}
			#fsType="$(echo $fsType | tr -d '"')"
			#fsType=${fsType#TYPE=*}
			#echo "FSTYPE @ $fsType"
			#echo "fsType = $fsType" 2>&1

#			if [ "$fsType" = 'vfat' ]
#			then
#				echo "OFFSET ============ ${offset}"
#				mount -v "$(echo "${parts}" | grep '.2')" ${offset}/boot
#				echo "sending $source to ${offset}/boot"

#
#				ls ${offset}/boot/${dsrc}

#				rm ${offset}/boot/${dsrc} -R

#				echo "${source#*://}"
				#sleep 30

#				echo "${ksrc}${kver} --output $offset/boot/LINUX/"
#				echo "mv ${offset}/boot/LINUX/${ksrc#*://}${kver} ${offset}/boot/LINUX/"

#				wget -r --no-verbose ${ksrc}${kver} -P $offset/boot/LINUX/
#				mv ${offset}/boot/LINUX/${ksrc#*://}${kver} ${offset}/boot/LINUX/
#				tempdir=${ksrc#*://}
#				echo "${tempdir} ... tempdir"
#				tempdir=${tempdir%/kernels*}					
#				echo "${tempdir} ... tempdir"
#				echo "rm ${offset}/boot/LINUX/${tempdir} -R"
#				rm ${offset}/boot/LINUX/${tempdir} -R

#				echo "${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz"
#				curl -L ${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz

#				echo "decompressing modules...  $offset/modules.tar.gz"
#				pv $offset/modules.tar.gz | tar xzf - -C ${offset}
#				rm ${offset}/modules.tar.gz

					# MODIFY FILES
#				echo "adding EFI ENTRY to template location $version ;; $pdset"
#				echo "version = $version, dset = $dset  pdset = $pdset" 2>&1
#					add_efi_entry ${version} ${pdset} ${offset}
			
#				echo "syncing write to boot drive..."
#				sync
#					umount -v ${offset}/boot
#			fi

#			if [ ! "$fsType" = 'vfat' ]
#			then
#				echo "invalid partition"
#			fi

#			if [ -z "$fsType" ]
#			then
#				echo "...no parition detected"
#			fi
		

		#zpool_partition="$(blkid | \grep ${disk} | \grep 'zfs_member')"
		#zpool_partition="${zpool_partition%*:}"
		#zpool_label="$(blkid | grep "${zpool_partition}" | awk '{print $2}' | tr -d '"')"
		#zpool_label="$(echo ${zpool_label#=*} | uniq)"

#		echo "sending over ${dSet}@safe to ${safe_src%@*}" 
#		echo "------------------------------------------------------"
			
#		zfs send ${dSet}@safe | pv | zfs recv ${safe_src%@*}

#		echo "///////////////////////////////////////////////////////"
 
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

function zfs_keys() 
{
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
		#echo "$listing"

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
					#else
						#echo "key not found for $j"
					fi
					#echo "coppied $source to $destination for $j"
				#else
					#echo "nothing to do for $j ..."
				fi
			fi
		done
	done
}


function clear_mounts()
{
	local offset=$1

	#procs="$(lsof ${mountpoint} | sed '1d' | awk '{print $2}' | uniq)" 
	#echo "killing $(echo $procs | wc -l) process(s)"  2>&1
	#for process in ${procs}; do kill -9 ${process}; done
	#echo "umount $mountpoint"

    dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"

	if [[ -n "$(echo $dir | grep '/dev/')" ]]
	then
		dir="${dir}"
	else
		dir="${dir}\/"
	fi

	output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	echo "$output mounts to be removed" 

	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			#echo "umount $mountpoint"
			#read
			umount $mountpoint > /dev/null 2>&1
			#sleep 5

									# \/ ensures that the root reference is not unmounted
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}


	echo "FUCK"

	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	profile=""				#	the build profile of the install
	selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }

	for x in $@
	do
		case "${x}" in
			boot=*)
				_destination=${x#*=}
			;;
			work=*)
				_source=${x#*=}
			;;
		esac
	done

	if [[ -n ${_source} ]] && [[ -n ${_destination} ]]
	then
		setup_boot ${_source} ${_destination}
	fi
