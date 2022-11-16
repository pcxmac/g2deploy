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

source ./include.sh

function users()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd' 2>/dev/null
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd' 2>/dev/null
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
	echo "prepfs ~ $offset" 2>&1
	echo "deleting old files (calculating...)" 2>&1
	count="$(find $offset/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $offset/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... $offset" 2>&1

	echo ${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors ${selection} 2>&1
	echo $(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors ${selection}) 2>&1

	files="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/releases.mirrors ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	echo "X = ${serverType%//*} :: $files @ $profile" 2>&1

	case ${serverType%//*} in
		"file:/")
			echo "LOCAL FILE TRANSFER - RSYNCING" 2>&1
			rsync -avP ${filexz#*//} ${offset}
			rsync -avP ${fileasc#*//} ${offset}
		;;
		"http:")
			echo "REMOTE FILE TRANSFER - WGETTING" 2>&1
			wget $filexz	--directory-prefix=${offset}
			wget $fileasc	--directory-prefix=${offset}
		;;
	esac

	fileasc=${fileasc##*/}
	filexz=${filexz##*/}

	gpg --verify $offset/$fileasc
	rm $offset/$fileasc

	echo "decompressing $filexz...@ $offset" 2>&1
	decompress $offset/$filexz $offset
	rm $offset/$filexz
	#sleep 30

    echo "setting up mounts"
	mkdir -p ${offset}/var/lib/portage/binpkgs
	mkdir -p ${offset}/var/lib/portage/distfiles
	mkdir -p ${offset}/srv/crypto/
	mkdir -p ${offset}/var/lib/portage/repos/gentoo
}


function system()
{
	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --binpkg-changed-deps=y"
	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"


	#	PLEASE MOVE THIS IN TO PKGPROCESSOR
	#	
	#	
	#	
	#	
	#	

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	#
	#
	#
	#

	echo "EMERGE PROFILE PACKAGES !!!!"
	pkgs="/package.list"
	emerge $emergeOpts $(cat "$pkgs")

	emergeOpts=""
	FEATURES="-getbinpkg -buildpkg" emerge $emergeOpts =zfs-9999 --nodeps
	
	#echo "SETTING SERVICES"
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import
	eix-update
	updatedb
}

function services()
{
	local lineNum=0
	local service_list=$1

	bash <(curl "${service_list}")
}

function locales()
{

    local key=$1
	locale-gen -A
	eselect locale set en_US.utf8
	emerge-webrsync

	#MOUNT --BIND RESOLVES NEED TO CONTINUALLY SYNC, IN FUTURE USE LOCAL MIRROR
	emerge --sync --ask=n
    echo "reading the news (null)..."
	eselect news read all > /dev/null
	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data
		
	#	{key%/openrc} :: is a for the edgecase 'openrc' where only that string is non existent with in eselect-profile
	eselect profile set default/linux/amd64/${key%/openrc}
	eselect profile show
	sleep 10
}



function pkgProcessor()
{
    local profile=$1
	local offset=$2

	echo $profile 2>&1
	echo $offset 2>&1

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url)"
	echo ":::: $url"
	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url)"
	echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	#
	#
	#	CONVERT THIS TO AN OUTPUT STREAM, DO NOT SAVE TO OFFSET (SHOULD BE INVOKED LOCALLY)
	#
	#
	#

	echo "${diffPkgs}" > ${offset}/package.list
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
                dataset="${x#*=}"
            ;;
        esac
    done

	if [[ -z "${directory}" ]];then echo "Non Existant Work Location for $dataset"; exit; fi

	for x in $@
    do
        #echo "before cases $x"
        case "${x}" in
            build=*)
                echo "build..."
                _profile="invalid profile"
                selection="${x#*=}"
				echo "ZDRAT + ${x#*=}"
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

	if [[ -z "${_profile}" ]];then echo "profile does not exist for $selection"; exit; fi

	clear_mounts ${directory}

#	NEEDS A MOUNTS ONLY PORTION.

	buildup ${_profile} ${directory} ${dataset} ${selection}

	mounts ${directory}

	zfs_keys ${dataset}
	echo "certificates ?"

	pkgProcessor ${_profile} ${directory}

	patches ${directory} ${_profile}

	chroot ${directory} /bin/bash -c "locales ${_profile}"

	install_modules ${directory}

	chroot ${directory} /bin/bash -c "system"

	#chroot ${directory} /bin/bash -c "install_modules"

	chroot ${directory} /bin/bash -c "users ${_profile}"

	services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors http)/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"

	chroot ${directory} /bin/bash -c "services ${services_URL}"

	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key ${dataset}

	clear_mounts ${directory}

	zfs snapshot ${dataset}@safe