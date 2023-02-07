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

#	export -f patchProcessor
	export -f getG2Profile

	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	selection=""			# 	the precursor for the profile, ie musl --> 17.0/musl/hardened { selection --> profile }
		
    for x in "$@"
    do
        case "${x}" in
            work=*)
                #? zfs= btrfs= generic= tmpfs=
				directory=$(getZFSMountPoint "${x#*=}")
				if [[ -n ${directory} ]]
				then	
					echo "${directory}..."
        	        dataset="${x#*=}"
					if [[ -n "$(zfs list -t snapshot | \grep "${dataset}@safe")" ]];then zfs destroy "${dataset}@safe"; echo "deleting ${dataset}@safe";fi
				else
					echo "dataset does not exist, exiting."
					exit
				fi
            ;;
        esac
    done

	echo "DIRECTORY == ${directory}"

	if [[ -z "${directory}" ]];then echo "Non Existant Work Location for ${dataset}"; exit; fi

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

	clear_mounts "${directory}"

	deployBuildup "${_profile}" "${directory}" "${dataset}" "${_selection}"
	mounts "${directory}"

	patchFiles_user "${directory}" "${_profile}"
	patchFiles_portage "${directory}" "${_profile}"
	patchFiles_sys "${directory}" "${_profile}"

	ls ${directory}/usr/lib64/* -ail

	zfs_keys "${dataset}"

	pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"

	patchSystem "${_profile}" 'deploy' > "${directory}/patches.sh"
	patchSystem "${_profile}" 'services' > "${directory}/services.sh"

	chroot "${directory}" /bin/bash -c "deployLocales ${_profile}"
 	chroot "${directory}" /bin/bash -c "deploySystem"

	chroot "${directory}" /bin/bash -c "deployUsers ${_profile}"
	chroot "${directory}" /bin/bash -c "deployServices"

	#services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/package" http)/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"
	#echo "services URL = ${services_URL}"
	#chroot "${directory}" /bin/bash -c "services ${services_URL}"

	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key "${dataset}"
	clear_mounts "${directory}"
	chown root:root "${directory}"
	zfs snapshot "${dataset}@safe"
