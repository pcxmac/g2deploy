#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function generateYAML() {

source="${1:?}"
destination="${2:?}"

#	examples... (of what will be generated, and eventually be accepted through the arg config=*)
#	
#	install:test/plasma-plasma_old
#	disks:ZFS
#		- /dev/sda3
#		- /dev/sdb3
#		- /dev/sdc3
#		pool:test
#		dataset:plasma
#		format:raidz
#		compression:lz4
#		encryption:aes-192-gcm
#			-key:password
#	kernel:6.1.1-gentoo
#	boot:EFI
#		- /dev/sda2
#	swap:file
#		location:test/swap
#	profile:plasma/systemd
#	bootloader:refind
#	
#	
#	install:test/g2-hardened
#	disks:BTRFS
#		- /dev/sda
#		subvol:g2
#		compression:lzo
#	kernel:6.0.11-gentoo
#	boot:EFI
#		- /dev/sdb2
#	swap:partition
#		location:/dev/sdb1
#	profile:hardened
#	bootloader:grub
#		

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

	case ${stype} in
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

# generate YAML output
	std_o="# Install Config for @ ${dhost}:$(tStamp)\n"
	std_o="${std_o}install:${dpool}/${ddataset}-${sdataset}\n"
	std_o="${std_o} disks:ZFS\n"
	std_o="${std_o}  - ${disk}3\n"
	std_o="${std_o}  pool:${dpool}\n"
	std_o="${std_o}  dataset:${ddataset}\n"
	std_o="${std_o}  format:\n"
	std_o="${std_o}  compression:lz4\n"
	std_o="${std_o}  encryption:aes-gcm-256\n"
	std_o="${std_o}  key:/srv/crypto/zfs.key\n"
	std_o="${std_o} kernel:6.1.1-gentoo\n"
	std_o="${std_o} boot:EFI\n"
	std_o="${std_o}  partition:${disk}2\n"
	std_o="${std_o} swap:file\n"
	std_o="${std_o}  location:${dpool}/swap\n"
	std_o="${std_o}  format:funnyBone\n"
	std_o="${std_o} profile:${sprofile}\n"
	std_o="${std_o} bootloader:refind\n"

	echo -e "${std_o}" 2>&1

}

function prepare_disks() {

	# inject YAML

	local disk=
	local dpath=
	local dtype=

	#local disk="${1:?}"
	#local dpath="${2:?}"
	#local dtype="${3:?}"

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

	parts="$(ls -d /dev/* | grep "${disk}")"
	sync

	clear_mounts ${disk}

	partprobe
	sync
	mkfs.vfat "$(echo "${parts}" | grep '.2')" -I

	if [[ ! -d ${dpath} && ${dtype} != "zfs" ]]
	then 
		mkdir -p ${dpath}
	elif [[ -d ${dpath} && ${dtype} == "zfs" ]]
	then
		rm ${dpath} -R
	fi

	case ${dtype} in
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
				"$(echo "${parts}" | grep '.3')"
		;;
		btrfs)
			mount | grep "${disk}"
			mkfs.btrfs "$(echo "${parts}" | grep '.3')" -L "${dpool}" -f
			btrfs subvolume create "${dpath}"
			mount -t "${dtype}" "$(echo "${parts}" | grep '.3')" "${dpath}"
		;;
		xfs)
			mkfs.xfs "$(echo "${parts}" | grep '.3')" -L "${ddataset}" -f
			mount -t "${dtype}" "$(echo "${parts}" | grep '.3')" "${dpath}"
		;;
		ntfs)
			mkfs.ntfs "$(echo "${parts}" | grep '.3')" -L "${ddataset}" -f
			mount -t "${dtype}" "$(echo "${parts}" | grep '.3')" "${dpath}"
		;;
		ext4)
			mkfs.ext4 "$(echo "${parts}" | grep '.3')" -L "${ddataset}" -F
			mount -t "${dtype}" "$(echo "${parts}" | grep '.3')" "${dpath}"
		;;
	esac
	
}

function setup_boot()	
{
	#ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors ftp)"
	# incongriguous method sequence, a compromise, tbd

	yaml="${1:?}"

	local source
	local destination
	local spath
	local stype
	local shost
	local dpath
	local dtype
	local dpool
	local ddataset
	local kversion
	local dstDir
	local disk
	local url
	local boot_src="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/patchfiles.mirrors ftp)/boot/*"


	if [[ -n "${disk}" ]]
	then
		prepare_disks "${disk}" "${dpath}" "${dtype}" 
	fi

	if [[ ${dtype} == "${stype}" ]] 
	then
		case ${stype} in
			zfs)
				if [[ -n ${shost} ]]; then	ssh "${shost}" zfs send ${source} | pv | zfs recv -F "${destination}"
				else 									 zfs send "${source}" | pv | zfs recv -F "${destination}"
				fi
			;;
			btrfs)
				if [[ -n ${shost} ]]; then	ssh "${shost}" btrfs send ${spath} | pv | btrfs receive "${dpath}"
				else									 btrfs send "${spath}" | pv | btrfs receive "${dpath}"
				fi
			;;
		esac
	else 
		case ${shost} in
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

	dstDir="${dpath}/${ddataset}"

	if [[ -n "${disk}" ]]
	then
			
		mount "$(echo "${parts}" | grep '.2')" "${dstDir}/boot"
		mget "${boot_src}" "${dstDir}/boot"
		install_modules "${dstDir}"					# ZFS ONLY !!!! # POSITS IN TO SCRIPTDIR ... MGET BREAKS IF THIS IS BEFORE THE PARENT, APPARENTLY MGET NEEDS AN EMPTY FOLDER...
		echo "mget "${boot_src}" "${dstDir}/boot""
		kversion=$(getKVER)
		kversion=${kversion#*linux-}
		editboot "${kversion}" "${dpool}/${ddataset}"
		umount "${dstDir}/boot"
	fi
 }


	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	profile=""				#	the build profile of the install
	selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }



	for x in "$@"
	do
		case "${x}" in
			work=*)
				_source=${x#*=}
			;;
		esac
	done

	for x in "$@"
	do
		case "${x}" in
			boot=*)
				_destination=${x#*=}

				#yaml="$(generateYAML ${_source} ${_destination})"

				#echo "$(findKeyValue <(printf '%s\n' "${yaml}") install/disks pool)"

	#			echo "$(findKeyValue ../config/host.cfg "server/profile" test)"

				#echo -e "${yaml}"

				setup_boot ${_source} ${_destination}
			;;

			config=*)
				echo "config = ${config}"
			;;
			# NSFW
			#add=*) 
			#	_destination=${x#*=}
			#	add_to ${_source} ${_destination}
			##;;
		esac
	done


	echo "synchronizing disks"
	sync
	echo "exiting installer script..."
