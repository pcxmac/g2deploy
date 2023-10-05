#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

	export PYTHONPATH=""

	export -f deployUsers
	export -f deployLocales
	export -f deployServices
	export -f deploySystem
	export -f deployServices
	export -f isHostUp


#	export -f patchProcessor
	export -f getG2Profile

	dataset="";				#	the working dataset of the installation
	directory="";			# 	the working directory of the prescribed dataset
	selection="";			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }

	# verify URL's are accessible, exit out if not.
	checkHosts

    for x in "$@"
    do
        case "${x}" in
            work=*)

				# derive work location type: { zfs ; btrfs ; xfs|ext4|tmpfs }

				_location="${x#*work=}"

				# ZFS = work=pool/dataset		:: zfs list pool/dataset ... if -s, then type=ZFS
				# BTRFS = work=bpool/subvol
				# MISC = /path/to/install/in/

				echo "zfs list ${_location}"

				type="$(zfs list ${_location} | \grep -i "${location}")"
				[[ -n ${type} ]] && { type="ZFS"; }; 
				#type="$((btrfs ...))"
				#[[ -s ${type} ]] && { type="BTRFS"; };
				# if type not defined, assume
				#echo "location = $_location";
				[[ -z ${type} && -d ${_location} ]] && { type="MISC"; };
				# if not a directory, or btrfs/zfs, then it has to be an invalid reference...
				[[ -z ${type} ]] && { type="INVALID"; };

                #? zfs= btrfs= generic= tmpfs=
				directory=$(getZFSMountPoint "${x#*=}")
				if [[ -n ${directory} ]]
				then	
					echo "${directory}..."
        	        dataset="${x#*=}"
					#if [[ -n "$(zfs list -t snapshot | \grep "${dataset}@safe")" ]];then zfs destroy "${dataset}@safe"; echo "deleting ${dataset}@safe";fi
				else
					echo "dataset does not exist, exiting."
					exit
				fi
            ;;
        esac
    done

	echo "DIRECTORY == ${directory}"

	if [[ -z "${directory}" ]];then echo "Non Existent Work Location for ${dataset}"; exit; fi

	for x in "$@"
    do
        case "${x}" in
            build=*)
				_selection="${x#*=}"
				_profile="$(getG2Profile "${x#*=}")"
				echo "PROFILE = ${_profile}"
            ;;
        esac
    done

	if [[ -z "${_profile}" ]];then echo "profile does not exist for ${_selection}"; exit; fi

	# need a URL check before proceeding, ie websever check, rsync server check, ftp, etc...

	clear_mounts "${directory}"
	# in place of generic mounting service (context aware)
	[[ ${type} == "ZFS" ]] && zfs mount ${_location}; 

	printf 'buildup for @ %s', $_selection

	deployBuildup "${_profile}" "${directory}" "${dataset}" "${_selection}"

	echo "patchfiles : user @ ${directory}"
	patchFiles_user "${directory}" ${_profile}
	echo "patchfiles : system"
	patchFiles_sys "${directory}" ${_profile}
	echo "patchfiles : portage"
	patchFiles_portage "${directory}" ${_profile}
	#echo "zfs keys ..."
	#zfs_keys "${dataset}"
	echo "package processor ..."
	pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"
	echo "add patches"
	patchSystem "${_profile}" 'deploy' > "${directory}/patches.sh"
	echo "add services"
	patchSystem "${_profile}" 'services' > "${directory}/services.sh"

	mounts "${directory}"


	# 	-- NOT IMPLIMENTED YET ...

	#	theory of operation , system bootsup, firewall takes over, builds network stack, and triggers a sync on the dom-0
	#	sync on dom-0, will update the host.cfg, all derivative activities should be accurate, firewall will trigger a sync
	#	on any network changes, configs should be immediate, regular file syncs should continue to be periodic.
	#	eBPF will serve as the internetworker of choice for synchronizing host + extra host activities.

	# networking -preworkup -- a prelude for a networking patch script, most likely only on install, but something like this
	# is required to build up the deployment ... thinking.
	#pkgHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:pkgROOT/host")"
	#bldHOST="$(findKeyValue "${SCRIPT_DIR}/config/host.cfg" "server:buildserver/host")"
	#pkgIP="$(getent ahostsv4 ${pkgHOST} | head -n 1 | awk '{print $1}')"
	#bldIP="$(getent ahostsv4 ${bldHOST} | head -n 1 | awk '{print $1}')"
	#sed -i "/${pkgHOST}$/c${pkgIP}\t${pkgHOST}" ${directory}/etc/hosts
	#sed -i "/${bldHOST}$/c${bldIP}\t${bldHOST}" ${directory}/etc/hosts
	################ work around ############################################################################################# 

	#echo $_profile
	#echo $directory

	chroot "${directory}" /bin/bash -c "deployLocales ${_profile}"

	#sleep 30


 	chroot "${directory}" /bin/bash -c "deploySystem"

	chroot "${directory}" /bin/bash -c "deployUsers ${_profile}"
	chroot "${directory}" /bin/bash -c "deployServices"

	#services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/package" http)/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"
	#echo "services URL = ${services_URL}"
	#chroot "${directory}" /bin/bash -c "services ${services_URL}"

	# some usr space patches are required before package build, but are then overwritten, this will reaffirm the patches
	patchFiles_sys "${directory}" "${_profile}"

	#zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key "${dataset}"
	clear_mounts "${directory}"

	#chown root:root "${directory}"
	#zfs snapshot "${dataset}@safe"
