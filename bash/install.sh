# MOST OF THIS WILL PROBABLY TURN IN TO A PTYHON SCRIPT EVENTUALLY. TOO MUCH VARIABILITY WITH DATA STRUCTURES FOR BASH.

#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function generateYAML() {

source="${1:?}"
destination="${2:?}"

#
#	conops : 
#	
#	(in)		source			:	
#	(in)		destination		:	
#	(implied)	kernel			:	to be selectable
#	(n/a)		disks			:	yaml config in, config=*)
#	
#	
#	

	kver="$(getKVER)"
	kver="${kver#*linux-}"

	source_url="${1:?}"				# can be local or remote pool

	stype=${source_url%://*}	# example : zfs://root@localhost.com:/pool/dataset ; btrfs:///Label/subvolume ; ssh://root@localhost:/path/to/set
	shost=${source_url#*://}	

	case "${stype,,}" in
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
				sprofile="$(ssh ${shost} "eselect profile show | tail -n1 | sed 's/ //g'")"
			else 
				spath="$(zfs get mountpoint ${spool}/${sdataset})"
				spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
				root_path="$(mount | grep ' / ' | grep ${spool}/${sdataset})"
				root_path="$(echo ${root_path} | awk '{print $1}')"
				if [[ -n ${root_path} ]]; then spath=""; fi
				spath="${spath}/.zfs/snapshot/${ssnapshot}"
				sprofile="$(eselect profile show | tail -n1 | sed 's/ //g')"
			fi
		;;
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
				sprofile="$(ssh ${shost} "eselect profile show | tail -n1 | sed 's/ //g'")"
			else
				spath="$(blkid | grep ${spool} | grep 'btrfs')"
				spath="$(echo ${spath} | awk '{print $1}' | tr -d ':')"
				spath="$(mount | grep ${spath})"
				spath_root="$(echo ${spath} | grep "subvol=/" | head -n 1 | awk '{print $3}')"
				spath_subvol="$(echo ${spath} | grep "subvol=/${sdataset}" | head -n 1 | awk '{print $3}')"
				if [[ -n ${spath_subvol} ]]; then spath=${spath_subvol}; else spath="${spath_root}/${sdataset}"; fi
				sprofile="$(eselect profile show | tail -n1 | sed 's/ //g')"
			fi
		;;
		ssh)
			source=${shost#*:}
			spool=${source}
			shost=${shost%:*}
			shost="$(echo $shost | grep -v '/' | grep "[[:alnum:]]\+@[[:alnum:]]\+")"
				spath="$(ssh ${shost} test ! -d ${source} || echo ${source})"
			sprofile="$(ssh ${shost} "eselect profile show | tail -n1 | sed 's/ //g'")"
		;;
		ext4|xfs|ntfs)
			source=${shost#*:}
			spool=${source}
			shost=""
			spath=${source}
			sprofile="$(chroot ${spath} "/usr/bin/eselect profile show | tail -n1 | sed 's/ //g'")"
		;;
	esac

	destination_url="${2:?}"				# DESTINATION

	dtype=${destination_url%://*}	# example :	zfs:///dev/sda:/pool/dataset ; ntfs:///dev/sdX:/mnt/sdX ; config:///path/to/config
	dhost=${destination_url#*://}	

	case "${dtype,,}" in
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

	disk="$(echo ${dhost} | grep '^/dev/')"

	# this can be turned in to a case/switch, perhaps do this after disk prep, add key_insert function
	# function insertKeyValue "path:zzz/to/key" "second_key:value" --> path:zzz/to/key/second_key:value

	partClassifier="${disk##*/sd*}"
	if [[ -n ${partClassifier} ]]
	then
		pmod="p"
	else
		pmod=""
	fi

	#echo "${disk} | dhost = ${dhost}"

# generate YAML output
	std_o="# Install Config for @ ${dhost}:$(tStamp)\n"
	std_o="${std_o}install: ${dpool}/${ddataset}\n"
	std_o="${std_o}  disks: \n"
	std_o="${std_o}    - ${disk}${pmod}3\n"
	std_o="${std_o}    pool: ${dpool}\n"
	std_o="${std_o}    dataset: ${ddataset}\n"
	std_o="${std_o}    path: ${dpath}\n"
	std_o="${std_o}    format: zfs\n"
	std_o="${std_o}    compression: lz4\n"
	std_o="${std_o}    encryption: aes-gcm-256\n"
	std_o="${std_o}      key: /srv/crypto/zfs.key\n"
	std_o="${std_o}  source: ${spool}/${sdataset}@${ssnapshot}\n"
	std_o="${std_o}    host: ${shost}\n"
	std_o="${std_o}    pool: ${spool}\n"
	std_o="${std_o}    dataset: ${sdataset}\n"
	std_o="${std_o}    snapshot: ${ssnapshot}\n"
	std_o="${std_o}    format: ${stype}\n"
	std_o="${std_o}  kernel: ${kver}\n"
	std_o="${std_o}  boot: EFI\n"
	std_o="${std_o}    partition: ${disk}${pmod}2\n"
	std_o="${std_o}    loader: refind\n"
	std_o="${std_o}  swap: file\n"
	std_o="${std_o}    location: ${dpool}/swap\n"
	std_o="${std_o}    format: 'zfs dataset, no CoW'\n"
	std_o="${std_o}  profile: ${sprofile}\n"

	echo -e "${std_o}" 2>&1

}

function prepare_disks() {

	# inject YAML

	local vYAML="${1:?}"

	# prepare_disks only supports one disk right now, further work to findkeyValue (list properties), and the following code required.
	local disk="$(findKeyValue "${vYAML}" install/disks/-)"
	local dpath="$(findKeyValue "${vYAML}" install/disks/path)"
	local dtype="$(findKeyValue "${vYAML}" install/disks/format)"
	local dpool="$(findKeyValue "${vYAML}" install/disks/pool)"
	local boot_partition="$(findKeyValue "${vYAML}" install/boot/partition)"

	install_partition=${disk#*-}
	disk="$(echo ${install_partition%[0-9]*})"	# only supports one disk at the moment, with no mappable partitioning
	dpath="${dpath}/${ddataset}"

	#echo "disk = ${disk} | boot -> ${boot_partition} | part -> ${install_partition} | dpath = ${dpath} | dtype = ${dtype}" 2>&1

	clear_mounts ${disk}
	sync
	for wipe in $(ls /dev | grep "${disk#*/dev/}")
	do
		wipefs -af /dev/${wipe}
	done

	sgdisk -Z ${disk}

	partprobe
	sync

	sgdisk --new 1:0:+32M -t 1:EF02 ${disk}
	sgdisk --new 2:0:+8G -t 2:EF00 ${disk}
	sgdisk --new 3:0 -t 3:8300 ${disk}

	clear_mounts ${disk}

	partprobe
	sync

	mkfs.vfat "${boot_partition}" -I

	if [[ ! -d ${dpath} && ${dtype} != "zfs" ]]
	then 
		mkdir -p ${dpath}
	elif [[ -d ${dpath} && ${dtype} == "zfs" ]]
	then
		rm ${dpath} -R
	fi

	case "${dtype,,}" in
		zfs)
			options="-f"

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
				-O mountpoint="${dpath}" "${dpool}" \
				"${install_partition}"
		;;
		btrfs)
			mount | grep "${disk}"
			mkfs.btrfs "$(echo "${disk}" | grep '.3')" -L "${dpool}" -f
			btrfs subvolume create "${dpath}"
			mount -t "${dtype}" "$(echo "${disk}" | grep '.3')" "${dpath}"
		;;
		xfs)
			mkfs.xfs "$(echo "${disk}" | grep '.3')" -L "${ddataset}" -f
			mount -t "${dtype}" "$(echo "${disk}" | grep '.3')" "${dpath}"
		;;
		ntfs)
			mkfs.ntfs "$(echo "${disk}" | grep '.3')" -L "${ddataset}" -f
			mount -t "${dtype}" "$(echo "${disk}" | grep '.3')" "${dpath}"
		;;
		ext4)
			mkfs.ext4 "$(echo "${disk}" | grep '.3')" -L "${ddataset}" -F
			mount -t "${dtype}" "$(echo "${disk}" | grep '.3')" "${dpath}"
		;;
	esac
	
}

function setup_boot() {

	local disk="$(findKeyValue "${vYAML}" install/disks/-)"
	local ddataset="$(findKeyValue "${vYAML}" install/disks/dataset)"
	local dpath="$(findKeyValue "${vYAML}" install/disks/path)"
	local boot_src="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles ftp)/boot/*"
	local boot_partition="$(findKeyValue "${vYAML}" install/boot/partition)"

	local dstDir="${dpath}/${ddataset}"
	# temporary type of assignment, list not handled currently
	disk=${disk#*-}

	mount "${boot_partition}" "${dstDir}/boot"
	mget "${boot_src}" "${dstDir}/boot"
	install_modules "${dstDir}"					# ZFS ONLY !!!! # POSITS IN TO SCRIPTDIR ... MGET BREAKS IF THIS IS BEFORE THE PARENT, APPARENTLY MGET NEEDS AN EMPTY FOLDER...
	umount "${dstDir}/boot"
}

function modify_boot() {

	local vYAML="${1:?}"

	local boot_partition="$(findKeyValue "${vYAML}" install/boot/partition)"
	local dpool="$(findKeyValue "${vYAML}" install/disks/pool)"
	local kversion="$(findKeyValue "${vYAML}" install/kernel)"
	local ddataset="$(findKeyValue "${vYAML}" install/disks/dataset)"
	local dpath="$(findKeyValue "${vYAML}" install/disks/path)"
	local dstDir="${dpath}/${ddataset}"

	mount "${boot_partition}" "${dstDir}/boot"	
	editboot "${kversion}" "${dpool}/${ddataset}" "${dstDir}"
	umount "${dstDir}/boot"
}

function install_system() {

	# FIGURED FOR ZFS CURRENTLY / ONLY

	#ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors ftp)"
	# incongriguous method sequence, a compromise, tbd

	local vYAML="${1:?}"

	local install="$(findKeyValue "${vYAML}" install)"
	local dpool="$(findKeyValue "${vYAML}" install/disks/pool)"
	local ddataset="$(findKeyValue "${vYAML}" install/disks/dataset)"
	local dpath="$(findKeyValue "${vYAML}" install/disks/path)"
	local dtype="$(findKeyValue "${vYAML}" install/disks/format)"
	local kversion="$(findKeyValue "${vYAML}" install/kernel)"
	local disk="$(findKeyValue "${vYAML}" install/disks/-)"
	local boot_src="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/mirrors/patchfiles ftp)/boot/*"

	# (currently zfs) pool/dataset@snapshot ... needs to change to dpath, in yaml. ... install:(pool/dataset) ... not path
	local destination="${dpool}/${ddataset}"

	local spath="$(findKeyValue "${vYAML}" install/source)"
	local stype="$(findKeyValue "${vYAML}" install/source/format)"
	local shost="$(findKeyValue "${vYAML}" install/source/host)"

	disk=${disk#*-}

	#echo -e "$vYAML"
	echo "installing ${spath} to ${install}"
	echo "------------------------------------------"

	if [[ ${dtype,,} == "${stype,,}" ]] 
	then
		case "${stype,,}" in
			zfs)
				if [[ -n ${shost} ]]; then	ssh "${shost}" zfs send ${spath} | pv | zfs recv -F "${destination}"
				else 									 zfs send "${spath}" | pv | zfs recv -F "${destination}"
				fi
			;;
			btrfs)
				if [[ -n ${shost} ]]; then	ssh "${shost}" btrfs send ${spath} | pv | btrfs receive "${dpath}"
				else									 btrfs send "${spath}" | pv | btrfs receive "${dpath}"
				fi
			;;
		esac
	else 
		case "${shost,,}" in
			'')
				url="${stype}://${shost}:${spath}/"
				url=${url#*://}
				url=${url#*:/}
				mget ${spath}/ ${dpath}
			;;
			*)
				url="ssh://${shost}:${spath}/"
				url=${url#*://}
				url=${url#*:/}
				mget ssh://${shost}:${spath}/ ${dpath}
			;;
		esac
	fi
 }

	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	profile=""				#	the build profile of the install
	selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }

	for x in "$@"
	do
		case "${x,,}" in
			work=*)
				_source=${x#*=}
			;;
			init)
				selection="init"
			;;
			add)
				selection="add"
			;;
		esac
	done

	for x in "$@"
	do
		case "${x,,}" in
			boot=*)
				_destination=${x#*=}
				vYAML="$(generateYAML ${_source} ${_destination})"

				# determine if adding to an existing pool... or not.
				if [[ "${selection,,}" == "init" ]]
				then
					prepare_disks "${vYAML}"
					install_system "${vYAML}"
					setup_boot "${vYAML}"
					echo "modifying boot record ..."
					modify_boot "${vYAML}"
				fi 
				if [[ "${selection,,}" == "add" ]]
				then
					install_system "${vYAML}"
					echo "modifying boot record ..."
					modify_boot "${vYAML}"

					# solve - mv: cannot move '/srv/zfs/test/plasma/boot/LINUX//pkg.hypokrites.me/kernels/current/6.1.1-gentoo/' to '/srv/zfs/test/plasma/boot/LINUX/6.1.1-gentoo': Directory not empty

				fi	
			;;
		esac
	done

	for x in "$@"
	do
		case "${x,,}" in
			config)
				vYAML="$(generateYAML ${_source} ${_destination})"
				echo -e "${vYAML}"
				echo "------------------------------------------"
				#echo "$(findKeyValue "${vYAML}" install/disks/path)"
			;;
		esac
	done


	echo "synchronizing disks"
	sync
	echo "exiting installer script..."
