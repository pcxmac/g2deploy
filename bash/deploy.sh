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

### NEED A UNIVERSAL TRANSPORT MECHANISM FOR SYNCING ALL FILES. SCP, RSYNC ?
#
#		SYNC() HOST w/ SOURCE
#		SEND TO SOURCE DESTINATION
#		RECV FROM SOURCE DESTINATION
#		COMPRESSION AND ENCRYPTION ARE TRANSPARENT
#		
#
#############################################################################

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

#echo "${source}"

function users()
{
	#	Every 'INSTALL (not deployment) || PROFILE' must have a certificate of authenticity, which is used to pull in users
	#	passwords, profile data, and network identity. CERTS must have a large degree of >difficulty<, and are time limited (7 days)
	#	
	#	Certs are maintained from ROOT-Dom-0 
	#	
	#	ROOT-DOM_0/CA --> DOM_0.N/CA (PKI)/signing certificates, ROOT-DOM_0 is air gapped/non-wireless and requires 
	#	manual entries/and manual-hardware based data retention/transmission, ie, it can never touch a network. 
	#	

	usermod -s /bin/zsh root
	sudo sh -c 'echo root:P@$$w0rd | chpasswd' 2>/dev/null
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:P@$$w0rd | chpasswd' 2>/dev/null
	echo "home : sysop"
	usermod --home /home/sysop sysop
	echo "wheel : sysop"
	usermod -a -G wheel sysop
	echo "shell : sysop"
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop:sysop ${homedir} -R 2>/dev/null
	echo "homedir"
}


function buildup()
{
    #echo "getting stage 3"
	local profile=$1
	local offset=$2
	#local dSet=$3
	local selection=$4

	#setExists=
	#snapshot="$(zfs list -o name -t snapshot | sed '1d' | grep '${dSet}')"

	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ ${offset}/" 2>&1
	echo "deleting old files (calculating...)" 2>&1
	count="$(find ${offset}/ | wc -l)"

	if [[ ${count} -gt 1 ]]
	then
		rm -rv ${offset}/* | pv -l -s ${count} 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... ${offset}/" 2>&1

	# file method does not work, redress later...
	files="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors http ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	#echo "${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors http ${selection}" 2>&1
	#echo "FILES >>> ${files}" 2>&1

	case ${serverType%//*} in
		"file:/")
			echo "LOCAL FILE TRANSFER ... " 2>&1
			mget ${filexz#*//} ${offset}/
			mget ${fileasc#*//} ${offset}/
		;;
		"http:"|"rsync:")
			echo "REMOTE FILE TRANSFER - ${serverType%//*}//" 2>&1
			echo "fetching ${filexz}..." 2>&1
			mget ${filexz} ${offset}/
			echo "fetching ${fileasc}..." 2>&1
			mget ${fileasc} ${offset}/
		;;
	esac

	fileasc=${fileasc##*/}
	filexz=${filexz##*/}

	gpg --verify $offset/$fileasc
	rm $offset/$fileasc

	echo "decompressing $filexz...@ $offset" 2>&1
	decompress $offset/$filexz $offset
	rm $offset/$filexz

    echo "setting up mounts"
	mkdir -p ${offset}/var/lib/portage/binpkgs
	mkdir -p ${offset}/var/lib/portage/distfiles
	mkdir -p ${offset}/srv/crypto/
	mkdir -p ${offset}/var/lib/portage/repos/gentoo
}


function system()
{
	local pkgs="/package.list"
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	export emergeOpts

	echo "ISSUING UPDATES"
	emerge $emergeOpts -b -uDN --with-bdeps=y @world --ask=n

	echo "PATCHING UPDATES"
	# INJECT POINT FOR PATCH PROCESSOR
	sh < /patches.sh
	rm /patches.sh

	echo "EMERGE PROFILE PACKAGES"
	emerge ${emergeOpts} $(cat /package.list)
	rm /package.list

	emergeOpts="--verbose-conflicts"
	FEATURES="-getbinpkg -buildpkg" emerge $emergeOpts =zfs-9999 --nodeps



	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"
	echo "POST INSTALL UPDATE !!!"
	emerge -b -uDN --with-bdeps=y @world --ask=n $emergeOpts

	#	
	#	
	#	
	#	
	#	need an extras-packages install here, like chromium, vscode, etc...
	#	
	#	! meta packages will be installed separately, per profile, or via GUI+YAML
	#	or later w/ console manual install
	#	

	#echo "SETTING SERVICES"
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

	eselect news read new

	eix-update
	updatedb
}

function services()
{
	local lineNum=0
	local service_list=$1

	bash <(curl "${service_list}" --silent)
}

function locales()
{

    local key=$1
	locale-gen -A
	eselect locale set en_US.utf8

	#MOUNT --BIND RESOLVES NEED TO CONTINUALLY SYNC, IN FUTURE USE LOCAL MIRROR
	emerge-webrsync

	#	{key%/openrc} :: is a for the edgecase 'openrc' where only that string is non existent with in eselect-profile
	eselect profile set default/linux/amd64/${key%/openrc}
	eselect profile show
	sleep 2

	# 	sync repo, read news and set timezone
	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data

	# update portage, if able
	pv="$(qlist -Iv | \grep 'sys-apps/portage' | \grep -v '9999' | head -n 1)"
	av="$(pquery sys-apps/portage --max 2>/dev/null)"
	if [[ "${av##*-}" != "${pv##*-}" ]]
	then 
		emerge portage --oneshot --ask=n
	fi
		
}

###################################################################################################################################
#
#	need to create pool/set or exit if pool/set does not exist
#
#
#
########################################################3

	# check mount, create new mount ?
	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f services

	export -f system
	export -f patchProcessor
	export -f getG2Profile
	#export -f mirror

	dataset=""				#	the working dataset of the installation
	directory=""			# 	the working directory of the prescribed dataset
	profile=""				#	the build profile of the install
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
					if [[ -n "$(zfs list -t snapshot | \grep "${dataset}@safe")" ]];then zfs destroy ${dataset}@safe; echo "deleting ${dataset}@safe";fi
				else
					echo "dataset does not exist, exiting."
					exit
				fi
            ;;
        esac
    done


	echo "DIRECTORY == ${directory}"

	if [[ -z "${directory}" ]];then echo "Non Existant Work Location for $dataset"; exit; fi

	for x in "$@"
    do

        #echo "before cases $x"
        case "${x}" in
            build=*)
				_selection="${x#*=}"
				_profile="$(getG2Profile ${x#*=})"
				echo "PROFILE = ${_profile}"
            ;;
        esac
    done

	if [[ -z "${_profile}" ]];then echo "profile does not exist for $_selection"; exit; fi
	clear_mounts ${directory}

#	NEEDS A MOUNTS ONLY PORTION.

	#mount | grep ${directory}
	buildup ${_profile} ${directory} ${dataset} ${_selection}
	mounts ${directory}

	patch_user ${directory} ${_profile}
	patch_sys ${directory} ${_profile}
	patch_portage ${directory} ${_profile}

	zfs_keys ${dataset}
	echo "certificates ?"

	pkgProcessor ${_profile} ${directory} > ${directory}/package.list
	patchSystem ${_profile} 'deploy' > ${directory}/patches.sh
	
	chroot ${directory} /bin/bash -c "locales ${_profile}"

	#install_modules ${directory}	--- THIS NEEDS TO BE INTEGRATED IN TO UPDATE & INSTALL, DEPLOY IS USR SPACE ONLY, NOT BOOTENV
 	chroot ${directory} /bin/bash -c "system"
	chroot ${directory} /bin/bash -c "users ${_profile}"
	services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"

	echo "services URL = ${services_URL}"

	#	
	#	Given the Difference in time it takes to build a whole system, there can be inconsistencies with successfully
	#	pulling in a services script. Perhaps a timeout or pre-fetcher is required...
	#	
	#	

	chroot ${directory} /bin/bash -c "services ${services_URL}"
	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key ${dataset}
	clear_mounts ${directory}
	chown root:root ${directory}
	zfs snapshot ${dataset}@safe
