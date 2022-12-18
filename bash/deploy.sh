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
	sudo sh -c 'echo root:D3@dBeefF00d | chpasswd' 2>/dev/null
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:D3@dBeefF00d | chpasswd' 2>/dev/null
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


function buildup()
{
    #echo "getting stage 3"
	local profile=$1
	local offset=$2
	local dSet=$3
	local selection=$4

	#setExists=
	snapshot="$(zfs list -o name -t snapshot | sed '1d' | grep '${dset}')"

	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ ${offset}" 2>&1
	echo "deleting old files (calculating...)" 2>&1
	count="$(find ${offset} | wc -l)"
	if [[ ${count} > 1 ]]
	then
		rm -rv ${offset}* | pv -l -s ${count} 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... ${offset}" 2>&1

	# file method does not work, redress later...
	files="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors http ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	
	case ${serverType%//*} in
		"file:/")
			echo "LOCAL FILE TRANSFER ... " 2>&1
			mget ${filexz#*//} ${offset}

			mget ${fileasc#*//} ${offset}
		;;
		"http:"|"rsync:")
			echo "REMOTE FILE TRANSFER - ${serverType%//*}//" 2>&1
			echo "fetching ${filexz}..." 2>&1
			mget ${filexz} ${offset}
			echo "fetching ${fileasc}..." 2>&1
			mget ${fileasc} ${offset}
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
	mkdir -p ${offset}var/lib/portage/binpkgs
	mkdir -p ${offset}var/lib/portage/distfiles
	mkdir -p ${offset}srv/crypto/
	mkdir -p ${offset}var/lib/portage/repos/gentoo
}


function system()
{
	local pkgs="/package.list"
	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"

	export emergeOpts

	#	PLEASE MOVE THIS IN TO PKGPROCESSOR
	#	
	#	
	#	
	#	
	#	

	#echo "BASIC TOOLS EMERGE !!!!!"
	#emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	#	
	#	
	#	
	#	

	local patch_script="/patches.sh"
	echo "ISSUING WORK AROUNDS"
	sh ${patch_script}

	echo "EMERGE PROFILE PACKAGES !!!!"
	emerge $emergeOpts $(cat "$pkgs")

	#rm ${patch_script}
	#rm ${pkgs}

	emergeOpts="--verbose-conflicts"
	FEATURES="-getbinpkg -buildpkg" emerge $emergeOpts =zfs-9999 --nodeps

	local emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y --backtrack=99 --verbose --tree --verbose-conflicts"
	echo "UPDATE SYSTEM !!!"
	emerge -b -uDN --with-bdeps=y @world --ask=n $emergeOpts

	#	
	#	
	#	
	#	
	#	need an extras-packages install here, like chromium, vscode, etc...
	#	
	#	
	#	
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
	sleep 5

	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
		
}

function pkgProcessor()
{
    local profile=$1
	local offset=$2

	echo $profile 2>&1
	echo $offset 2>&1

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url --silent)"
	echo ":::: $url"
	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url --silent)"
	echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	#
	#
	#	CONVERT THIS TO AN OUTPUT STREAM, DO NOT SAVE TO OFFSET (SHOULD BE INVOKED LOCALLY) ....
	#
	#
	#

	echo "${diffPkgs}" > ${offset}/.package.list
	cat ${offset}/.package.list | sed '/^#/d' | uniq > ${offset}/package.list
	rm ${offset}/.package.list
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

	for x in $@
    do
        #echo "before cases $x"
        case "${x}" in
            build=*)
                _profile="invalid profile"
                selection="${x#*=}"
                case "${x#*=}" in
                    # special cases for strings ending in selinux, and systemd as they can be part of a combination
                    #'musl')
                        # space at end limits selinux	...		NOT SUPPORTED
                    #    _profile="17.0/musl/hardened "
                    #;;
                    'hardened')		    _profile="17.1/hardened "
                    ;;
                    'openrc')			_profile="17.1/openrc"
                    ;;
                    'systemd')			_profile="17.1/systemd "
                    ;;
                    'plasma')           _profile="17.1/desktop/plasma "
                    ;;
                    'gnome')			_profile="17.1/desktop/gnome "
                    ;;
                    'selinux')          _profile="17.1/selinux "
                        				echo "${x#*=} is not supported [selinux]"
                    ;;
                    'plasma/systemd')   _profile="17.1/desktop/plasma/systemd "
                    ;;
                    'gnome/systemd')	_profile="17.1/desktop/gnome/systemd "
                    ;;
                    'hardened/selinux') _profile="17.1/hardened/selinux "
                        				echo "${x#*=} is not supported [selinux]"
                    ;;
                    *)					_profile=""
                    ;;
                esac
            ;;
        esac
    done

	echo ${_profile}

	if [[ -z "${_profile}" ]];then echo "profile does not exist for $selection"; exit; fi

	clear_mounts ${directory}

#	NEEDS A MOUNTS ONLY PORTION.

	mount | grep ${directory}
	buildup ${_profile} ${directory} ${dataset} ${selection}
	mounts ${directory}
	patch_user ${directory} ${_profile}
	patch_sys ${directory} ${_profile}
	patch_portage ${directory} ${_profile}
	zfs_keys ${dataset}
	echo "certificates ?"
	pkgProcessor ${_profile} ${directory}
	patchProcessor ${_profile} ${directory}
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