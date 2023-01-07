#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

function users()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PXCW0rd | chpasswd' 2>/dev/null
	useradd sysop
	sudo sh -c 'echo sysop:@PXCW0rd | chpasswd' 2>/dev/null
	usermod --home /home/sysop sysop
	usermod -a -G wheel,portage sysop
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop:sysop "${homedir}" -R 2>/dev/null
}

function buildup()
{

	local offset="${2:?}"
	local selection="${4:?}"

	count="$(find "${offset}/" | wc -l)"

	if [[ ${count} -gt 1 ]]
	then
		rm -rv ${offset:?}/* | pv -l -s "${count}" > /dev/null
	else
		echo -e "done "
	fi

	files="$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/releases" http "${selection}")"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	case ${serverType%//*} in
		"file:/")
			mget "${filexz#*//}" "${offset}/"
			mget "${fileasc#*//}" "${offset}/"
		;;
		"http:"|"rsync:")
			mget "${filexz}" "${offset}/"
			mget "${fileasc}" "${offset}/"
		;;
	esac

	fileasc="${fileasc##*/}"
	filexz="${filexz##*/}"

	gpg --verify "${offset}/${fileasc}"
	rm ${offset}/${fileasc}

	decompress "${offset}/${filexz}" "${offset}"
	rm ${offset}/${filexz}

	mkdir -p "${offset}/var/lib/portage/binpkgs"
	mkdir -p "${offset}/var/lib/portage/distfiles"
	mkdir -p "${offset}/srv/crypto/"
	mkdir -p "${offset}/var/lib/portage/repos/gentoo"
}

function system()
{
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	echo "ISSUING UPDATES"
	emerge ${emergeOpts} -b -uDN --with-bdeps=y @world --ask=n

	echo "PATCHING UPDATES"
	sh < /patches.sh
	rm /patches.sh

	echo "EMERGE PROFILE PACKAGES"
	emerge ${emergeOpts} $(cat /package.list)
	rm /package.list

	echo "EMERGE ZED FILE SYSTEM"
	emergeOpts="--verbose-conflicts"
	FEATURES="-getbinpkg -buildpkg"
	emerge ${emergeOpts} =zfs-9999 --nodeps

	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"
	echo "POST INSTALL UPDATE !!!"
	emerge -b -uDN --with-bdeps=y @world --ask=n ${emergeOpts}

	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

	eselect news read new

	eix-update
	updatedb
}

function services()
{
	local service_list="${1:?}"
	bash <(curl "${service_list}" --silent)
}

function locales()
{

    local key="${1:?}"
	locale-gen -A
	eselect locale set en_US.utf8

	emerge-webrsync

	eselect profile set default/linux/amd64/${key%/openrc}
	eselect profile show
	sleep 2

	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data

	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"
	if [[ "${av##*-}" != "${pv##*-}" ]]
	then 
		emerge portage --oneshot --ask=n
	fi
		
}

	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f services

	export -f system
	export -f patchProcessor
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

	buildup "${_profile}" "${directory}" "${dataset}" "${_selection}"
	mounts "${directory}"

	patchFiles_user "${directory}" "${_profile}"
	patchFiles_sys "${directory}" "${_profile}"
	patchFiles_portage "${directory}" "${_profile}"

	zfs_keys "${dataset}"

	pkgProcessor "${_profile}" "${directory}" > "${directory}/package.list"
	patchSystem "${_profile}" 'deploy' > "${directory}/patches.sh"

	chroot "${directory}" /bin/bash -c "locales ${_profile}"

 	chroot "${directory}" /bin/bash -c "system"
	chroot "${directory}" /bin/bash -c "users ${_profile}"
	services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh "${SCRIPT_DIR}/config/mirrors/package" http)/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"

	echo "services URL = ${services_URL}"

	chroot "${directory}" /bin/bash -c "services ${services_URL}"
	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key "${dataset}"
	clear_mounts "${directory}"
	chown root:root "${directory}"
	zfs snapshot "${dataset}@safe"
