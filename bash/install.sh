#!/bin/bash

    # INPUTS    
    #           WORK=chroot offset		- working directory for install, skip if exists (DEPLOY).
	#			BOOT=/dev/sdX			- install to boot device, after generating image
	#			
	#		

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ./include.sh

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
	echo "offset for add_efi_entry = $offset"

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


function setup_boot()	
{
			ksrc="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
			kver="$(getKVER)"
			kver="${kver#*linux-}"

			source_url=$1				# can be local or remote pool
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
					else 
						spath="$(zfs get mountpoint ${spool}/${sdataset})"
						spath="$(echo "${spath}" | grep 'mountpoint' | awk '{print $3}')"
						root_path="$(mount | grep ' / ' | grep ${spool}/${sdataset})"
						root_path="$(echo ${root_path} | awk '{print $1}')"
						if [[ -n ${root_path} ]]; then spath=""; fi
						spath="${spath}/.zfs/snapshot/${ssnapshot}"
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
				ssh)
					source=${shost#*:}
					spool=${source}
					shost=${shost%:*}
					shost="$(echo $shost | grep -v '/' | grep "[[:alnum:]]\+@[[:alnum:]]\+")"
						spath="$(ssh ${shost} test ! -d ${source} || echo ${source})"
				;;
				ext4|xfs|ntfs)
					source=${shost#*:}
					spool=${source}
					shost=""
					spath=${source}
				;;
			esac

			destination_url=$2				# DESTINATION
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

			disk=${dhost}

			clear_mounts ${disk}
			sync
			sgdisk -Z ${disk}
			wipefs -af ${disk}
			partprobe
			sync

			# floating schemas + Oldap = dynamic builds
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
			
			mount | grep ${disk}
			if [[ ! -d ${dpath} ]]
			then 
				mkdir -p ${dpath}
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

			bootDir="${dpath}/${ddataset}/boot"
			
			if [[ ! -d ${bootDir} ]]; then mkdir -p ${bootDir}; fi
			
			mount "$(echo "${parts}" | grep '.2')" ${bootDir}
			boot_src="ftp://10.1.0.1/patchfiles/boot/*"
			mget ${boot_src} ${bootDir}
			kversion=$(getKVER)
			add_efi_entry ${kversion} "${dpool}/${ddataset}" "${dpath}/${ddataset}"
			
			umount ${bootDir}
			
			$(zfs get mountpoint ${safe_src} 2>&1 | sed -n 2p | awk '{print $3}')
 }

#########################################################################################################

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

	echo "synchronizing disks"
	sync
	echo "exiting installer script..."