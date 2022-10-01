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
			echo "${host}:/${source} ${destination}" 2>&1
			scp -r ${host}:/${source} ${destination}
		;;
		# local file move only
		file|*)
			#echo "WTF ${url#*://}" 2>&1
			if [[ ! -d "${url#*://}" ]] && [[ ! -f "${url#*://}" ]]; then exit; fi
			if [[ ! -d "${destination}" ]]; then mkdir -p "${destination}"; fi
			rsync -a ${url#*://}	${destination} --info=progress2 
		;;
	esac
}

#					$1=SRC_URL		$2=DST_URL
function copy_user()
{

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
						spath="$(ssh ${shost} "zfs get mountpoint ${source}")"
						spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
					else
						spath="$(zfs get mountpoint ${source})"
						spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
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
						spath="$(ssh ${shost} "mount | grep 'btrfs'")"
						spath="$(echo "${spath}" | grep -i ${sdataset} | awk '{print $3}')"
						sresult="$(ssh ${shost} "btrfs filesystem show ${spath} | grep 'uuid'")"
					else
						spath="$(mount | grep 'btrfs')"
						spath="$(echo "${spath}" | grep -i ${sdataset} | awk '{print $3}')"
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
					source=${shost#*:}
					spool=${source}
					shost=""
					spath=${source}
				;;
			esac

			#				
			# zfs - 		zfs send ${dSet}@safe | pv --timer --rate | zfs recv ${safe_src%@*}
			#				ssh user@host zfs send pool/dataset | pv --timer --rate | zfs recv -F pool/dataset
			#				
			#				create the destination btrfs subvolume
			# btrfs - 		btrfs send /subvol/path | pv --timer --rate | btrfs recv /new/subvol/path
			#				ssh user@host btrfs send /subvol/path | pv --timer --rate | btrfs recv /new/subvol/path

			# ssh -			ssh user@host 'tar czf - ${path}' | pv --timer --rate | tar xvzf - -C ${new_path}

			# * - 			tar czf - ${path} | pv --timer --rate | tar xvzf - -C ${new_path}

			#				block transfers (send/recv) only occur when both strings are the same types { zfs or btrfs }


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
					dhost=""
						dpath="$(zfs get mountpoint ${destination})"
						dpath="$(echo "${dpath}" | grep 'mountpoint' | awk '{print $3}')"
				;;
				btrfs)
					destination=${dhost#*:/}
					dpool=${destination%/*}
					ddataset=${destination##*/}
					ddataset=${ddataset%@*}
					dhost=""
						dpath="$(mount | grep 'btrfs')"
						dpath="$(echo "${dpath}" | grep -i ${ddataset} | awk '{print $3}')"
						dresult="btrfs filesystem show ${dpath} | grep 'uuid')"
				;;
				ext4|xfs|ntfs)
					destination=${dhost#*:}
					dpool=${destination}
					ddataset=""
					dhost=""
					dpath=${destination}
				;;
			esac

			echo "SOURCE | type = ${stype} ; connect to $shost ; pool/dataset/snapshot = [$spool][$sdataset][$ssnapshot] :: source = ${source} | ${spath} | ${sresult}"
			echo "DESTINATION | type = ${dtype} ; connect to $dhost ; pool/dataset/snapshot = [$dpool][$ddataset][] :: destination = ${destination} | ${dpath}"


			# VERIFY SNAPSHOT - ZFS, VERIFY NO NEW RECV DATASET
			#
			#
			#
			#
			#
			

			# block send, local to local or remote to local
			if [[ ${dtype} == ${stype} ]] 
			then
				case ${stype} in
					zfs)
						if [[ -n ${shost} ]] then	ssh ${shost} zfs send ${source} | pv --timer --rate | zfs recv -F ${destination}
						else 						zfs send ${source} | pv --timer --rate | zfs recv ${destination}
						fi
					;;
					btrfs)
						if [[ -n ${shost} ]] then	ssh ${shost} btrfs send ${source} | pv --timer --rate | btrfs recv ${destination}
						else						btrfs send ${source} | pv --timer --rate | btrfs recv ${destination}
						fi
					;;
				esac

			# compression send
			else 
			# remote source to local destination
				case ${shost} in
				# local source to local destination
					'')
						tar czf - ${spath} | pv --timer --rate | tar xvzf - -C ${dpath}
					;;
					*)
						ssh ${shost} 'tar czf - ${spath}' | pv --timer --rate | tar xvzf - -C ${dpath}
					;;
				esac
			fi

}

function setup_boot()	
{
			local src_url=$1
			local dst_url=$2

			#	DISK CONFIGURATION, CONFIG, OR SIMPLE ...
			#	BOOT INSTALL ?		-- mget ...
			#	USER INSTALL ?		-- copy_user
			#	BOOT CONFIG SETUP ?


			#copy_user ${src_url} ${dst_url}

			ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
			kver="$(getKVER)"
			kver="${kver#*linux-}"

			parts="$(ls -d /dev/* | grep "${disk}")"
			options=""

			echo "designate pool name/path:"
			read POOL
			#tobe="$POOL/${dataset}"
			#offset="$(zfs get mountpoint ${POOL}/${dataset} 2>&1 | sed -n 2p | awk '{print $3}')"
			echo "5 second delay"

			#	[TYPE] :// [CONNECTION @ STRING] :/ [SOURCE]
			# SWITCH CASE FOR DESTINATION TYPE ZFS:,BTRFS:,... example: zfs://dev/sda:/pool/dataset
			#															type ://	connection	:/ pool/dataset
			#	connection types for install are local only and ext4,xfs,btrfs,zfs,...
			#					pool  :  dataset  : snapshot
			#	zfs string		[POOL]/[DATASET]@[SNAPSHOT]
			#					pool  :  dataset  
			#	btrfs string	[LABEL]/[SUBVOLUME]
			#				    pool
			#	ext4 string		[FILE/SYSTEM]
			#	connection url = /dev/sdX || config.file (commands list)


			# FORMAT DISK(S)

			clear_mounts ${disk}
#			sgdisk --zap-all ${disk}
			partprobe


			echo "sgdisk --new 1:0:+32M -t 1:EF02 ${disk}" 
#			sgdisk --new 1:0:+32M -t 1:EF02 ${disk}
			echo ""
#			sgdisk --new 2:0:+8G -t 2:EF00 ${disk}
			echo "sgdisk --new 2:0:+8G -t 2:EF00 ${disk}"
#			sgdisk --new 3:0 -t 3:8300 ${disk}
			echo "sgdisk --new 3:0 -t 3:8300 ${disk}"
			mkfs.vfat "$(echo "${parts}" | grep '.2')" -I


			echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
			echo "disks =***${parts}***"
			echo "############################"
			echo "$(echo "${parts}" | grep '.2')"
			echo "$(echo "${parts}" | grep '.3')"

			# FORMAT USER SPACE

			echo "designate pool/dataset = ${POOL}/${dataset}} :: ${offset}"
			pdset="${safe_src%@*}"
			#version="$(getKVER ${offset}))"
			version="$(getKVER)"

			# redefine offset if new pool created
			offset="$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')"

			fsType=$(blkid "$(echo "${parts}" | grep '.2')" | awk '{print $4}')
			fsType=${fsType#=*}
			fsType="$(echo $fsType | tr -d '"')"
			fsType=${fsType#TYPE=*}
			#echo "FSTYPE @ $fsType"
			echo "fsType = $fsType" 2>&1

			#if [ "$fsType" = 'vfat' ]
			#then
				echo "OFFSET ============ ${offset}"
				mount -v "$(echo "${parts}" | grep '.2')" ${offset}/boot
				echo "sending $source to ${offset}/boot"


				ls ${offset}/boot/${dsrc}

				rm ${offset}/boot/${dsrc} -R

				echo "${source#*://}"



			boot_src="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/patchfiles.mirrors *)"
			source="${boot_src}/boot/"
			#source="rsync://192.168.122.108/gentoo-patchfiles/boot/"
			#rsync -r -l -H -p -c --delete-before --info=progress2 $source ${offset}/boot

			mget ${source} -P ${offset}/boot

#			wget -r --no-verbose ${source} -P ${offset}/boot
#			mv ${offset}/boot/${source#*://}* ${offset}/boot/
#			dsrc="${source#*://}"
#			dsrc="${dsrc%%/*}"




			case ${1%//*} in
				# 	rsync ... ex. rsync://dom0-hypokrites.net/templates/plasma/
				'rsync:'|'ftp:'|'http:'|'file:/'|'ssh:')
					mget $1 ${disk_location}
				;;
				#	local path
				*)
					case ${1%%/*} in
						# local path
						''|'file:')
							mget $1 ${disk_location}
						;;
						# POOL
						*)
						# determine if pool exists, and if so, determine type: btrfs or zfs




							case ${disk_location##*/} in
								# file reference
								''|'*')
									echo "this is a singular file reference ${disk_location##*/}"
								;;
								# folder reference
								*)
									echo "this is a reference to a folder ${disk_location##*/}"
								;;
							esac
							case ${type} in
								zfs)
									case ${connection_string} in
										#local to local
										'')
											echo "local to local transfer --zfs"

										;;									
										#remote to local
										*)
											echo "remote to local transfer --zfs"
										;;
									esac
								;;
								btrfs)
									case ${connection_string} in
										#local to local
										'')
											echo "local to local transfer --btrfs"
										;;									
										#remote to local
										*)
											echo "remote to local transfer --btrfs"
										;;										
									esac
								;;
							esac
						;;
					esac
				;;
			esac

			exit



			sleep 30

			$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')

			# pool sees if the pool exists at all, if not, can create, if does, ask to destroy, identify
			zpool import -a -f 2>/dev/null
			rpool="$(zpool list $POOL | sed '1d' | awk '{print $1}')" 2>/dev/null						# prints pool, if exists
			ypool="$(blkid | grep "$POOL" | grep 'zfs_member' | sed 's/.* LABEL=\([^ ]*\).*/\1/' | tr -d '"')"
			rpart="$(blkid | grep $POOL | sed 's/.*\/dev\/\([^ ]*\).*/\1/' | tr -d ':')"	# prints partition associated with proposed pool

			# part(ition) and label are associated with the proposed install, if they are present, that means the disk must be destroyed.
			part="$(blkid | grep "${disk}" | grep 'zfs_member')"
			plabel="$(echo "${part}" | sed 's/.* LABEL=\([^ ]*\).*/\1/' | tr -d '"')"
			ppart="$(echo "${part}" | sed 's/.*\/dev\/\([^ ]*\).*/\1/' | tr -d ':')"
			#disky="$(blkid | grep ${disk})"
			disky="$(fdisk -l | grep "${disk}" | awk '{print $2}' | tr -d ':')"
			rootfs="$(mount | grep ' / ' | awk '{print $1}')"

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

			echo "rpool :: $rpool"		#	-n pool exists w/ zfs
			echo "ypool :: $ypool"		#	-n pool exists on blkid (label)						:: $POOL
			echo "rpart :: $rpart"		#	-n pool exists on blkid (disk)						:: $POOL
			echo "ppart :: $ppart"		#	-n disk exists on blkid / has zfs member (disk)		:: boot=(disk)
			echo "plabel :: $plabel"	#	-n label exists on blkid / has zfs member (label)	:: boot=(disk)	
			
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
		

			if [[ ${dSet%/*} == ${POOL} ]] && [[ ${rootfs#*/} == ${dSet#*/} ]]
			then
				# the pool is able to be loaded, and must be destroyed
				echo "$POOL/${dSet#*/} is the ${rootfs} [root file system] ... exiting"
				exit
			fi


			echo "${ypool} == ${rpool} ]] && [[ -n ${ypool}"
			if [[ ${ypool} == ${rpool} ]] && [[ -n ${ypool} ]]
			then
				# the pool is able to be loaded, and must be destroyed
				echo "pool is already available, needs to be destroyed"
#				exit
			fi

			echo "-z ${rpool} ]] && [[ -n ${ypool} ]] && [[ ${ypool} == ${POOL}"
			if [[ -z ${rpool} ]] && [[ -n ${ypool} ]] && [[ ${ypool} == ${POOL} ]]
			then
				# reminent of an old pool exists, but the disk remains unformatted afterwords
				echo "${plabel} is a reminent..., reconfigure the disk"
				clear_mounts ${disk}
				sgdisk --zap-all ${disk}
				partprobe
				fdisk -l | grep ${disk}
				#exit
			fi

			echo " -n ${ppart} ]] && [[ ${plabel} != ${POOL}"
			if [[ -n ${ppart} ]] && [[ ${plabel} != ${POOL} ]] 
			then
				if [[ -z ${rpool} ]]
				then
					echo "${plabel} is reminent ... you can kill this."
					exit
				fi
				# another pool exists on the claimed disk
				echo "${plabel} exists on ${ppart} ... not ${POOL}, invalid configuration, must exit."
				exit
			fi

			echo "-z ${disky}"
			if [[ -z ${disky} ]] 
			then
				# another pool exists on the claimed disk
				echo "${disk} is not present"
				exit
			fi

	#		clear_mounts ${disk}
	#		sgdisk --zap-all ${disk}
	#		partprobe


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
				-O mountpoint=/srv/zfs/${POOL} ${POOL} \
				$(echo "${parts}" | grep '.3')



			pdset="${safe_src%@*}"
			#version="$(getKVER ${offset}))"
			version="$(getKVER)"

			# redefine offset if new pool created
			offset="$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')"

			fsType=$(blkid "$(echo "${parts}" | grep '.2')" | awk '{print $4}')
			fsType=${fsType#=*}
			fsType="$(echo $fsType | tr -d '"')"
			fsType=${fsType#TYPE=*}
			#echo "FSTYPE @ $fsType"
			echo "fsType = $fsType" 2>&1

			if [ "$fsType" = 'vfat' ]
			then
				echo "OFFSET ============ ${offset}"
				mount -v "$(echo "${parts}" | grep '.2')" ${offset}/boot
				echo "sending $source to ${offset}/boot"


				ls ${offset}/boot/${dsrc}

				rm ${offset}/boot/${dsrc} -R

				echo "${source#*://}"
				#sleep 30

				echo "${ksrc}${kver} --output $offset/boot/LINUX/"
				echo "mv ${offset}/boot/LINUX/${ksrc#*://}${kver} ${offset}/boot/LINUX/"

				wget -r --no-verbose ${ksrc}${kver} -P $offset/boot/LINUX/
				mv ${offset}/boot/LINUX/${ksrc#*://}${kver} ${offset}/boot/LINUX/
				tempdir=${ksrc#*://}
				echo "${tempdir} ... tempdir"
				tempdir=${tempdir%/kernels*}					
				echo "${tempdir} ... tempdir"
				echo "rm ${offset}/boot/LINUX/${tempdir} -R"
				rm ${offset}/boot/LINUX/${tempdir} -R

				echo "${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz"
				curl -L ${ksrc}${kver}/modules.tar.gz --output $offset/modules.tar.gz

				echo "decompressing modules...  $offset/modules.tar.gz"
				pv $offset/modules.tar.gz | tar xzf - -C ${offset}
				rm ${offset}/modules.tar.gz

					# MODIFY FILES
				echo "adding EFI ENTRY to template location $version ;; $pdset"
				echo "version = $version, dset = $dset  pdset = $pdset" 2>&1
					add_efi_entry ${version} ${pdset} ${offset}
			
				echo "syncing write to boot drive..."
				sync
					umount -v ${offset}/boot
			fi

			if [ ! "$fsType" = 'vfat' ]
			then
				echo "invalid partition"
			fi

			if [ -z "$fsType" ]
			then
				echo "...no parition detected"
			fi
		

		#zpool_partition="$(blkid | \grep ${disk} | \grep 'zfs_member')"
		#zpool_partition="${zpool_partition%*:}"
		#zpool_label="$(blkid | grep "${zpool_partition}" | awk '{print $2}' | tr -d '"')"
		#zpool_label="$(echo ${zpool_label#=*} | uniq)"

		echo "sending over ${dSet}@safe to ${safe_src%@*}" 
		echo "------------------------------------------------------"
			
		zfs send ${dSet}@safe | pv | zfs recv ${safe_src%@*}

		echo "///////////////////////////////////////////////////////"
 
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
	echo "$output mounts to be removed" 2>&1
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do

			#echo "umount $mountpoint"
			#read
			umount $mountpoint > /dev/null 2>&1
		
									# \/ ensures that the root reference is not unmounted
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}





# check mount, create new mount ?
#export PYTHONPATH=""

#export -f users
#export -f locales
#export -f system
#export -f services
#export -f install_modules

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

  
#	NEED TO ADD this software to the deployment image, or a link to it through a shared f/s
#	NEED TO ADD AUTOFS COMMON MOUNTS.	/etc/autofs/common.conf
#
#
#
#
#

	for x in $@
	do
		case "${x}" in
			boot=*)
				if [[ -n "${dataset}" ]]
				then



					#echo "BOOT THIS MOTHER FUCKA !"
					setup_boot ${dataset}	${x#*=}

					# REBUILD INITRAMFS, for the ON DISK DATASET ONLY
					# AFTER UPDATE SCRIPT, 


				else
					echo "work is undefined"
				fi
			;;
		esac
	done
