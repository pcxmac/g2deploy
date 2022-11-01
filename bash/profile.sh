#!/bin/bash


# ARGS = work=$

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

function getKVER() 
{
	url_kernel="$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/kernel.mirrors *)"
	kver="$(curl ${url_kernel} | sed -e 's/<[^>]*>//g' | awk '{print $9}' | \grep '.tar.gz$')"
	kver=${kver%.tar.gz*}
	echo ${kver}
}

function zfs_keys() 
{
	local dataset=$1
    local offset=$2
	local pools="$dataset"
	
	for i in $pools
	do
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"

		for j in $listing
		do
			dSet="$j"
			if [ "$dSet" == '-' ]
			then
				format="N/A"
				location="N/A"
				else
				format="$(zfs get keyformat $dSet | awk '{print $3}' | sed -n '2 p')"
				location="$(zfs get keylocation $dSet | awk '{print $3}' | sed -n '2 p')"
			fi

			if [ $format == 'raw' ] || [ $format == 'hex' ]
			then
				location_type="${location%:///*}"
				if [ $location_type == 'file' ]
				then
					source="${location#*//}"
					destination="${source%/*}"
					destination="$offset$destination"
					if test -f "$source"; then
						cp $source $destination
					fi
				fi
			fi
		done
	done
}

function clear_mounts()
{
	local offset=$1
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
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir" | awk '{print $2}')
		output="$(cat /proc/mounts | grep "$dir" | wc -l)"
	done
}

function mounts()
{
    #echo "getting stage 3"
	local offset=$1

	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"

	# MOUNTS
	echo "msize = $mSize"
	mount -t proc proc ${offset}/proc
	mount --rbind /sys ${offset}/sys
	mount --make-rslave ${offset}/sys
	mount --rbind /dev ${offset}/dev
	mount --make-rslave ${offset}/dev
	# because autofs doesn't work right in a chroot ...
	mount -t tmpfs -o size=$mSize tmpfs ${offset}/tmp
	mount -t tmpfs tmpfs ${offset}/var/tmp
	mount -t tmpfs tmpfs ${offset}/run


	echo "attempting to mount binpkgs..."  2>&1
	# this is to build in new packages for future installs, not always present
	mount --bind /var/lib/portage/binpkgs ${offset}/var/lib/portage/binpkgs 
	ls ${offset}/var/lib/portage/binpkgs
}

function pkgProcessor()
{
    local profile=$1
	local offset=$2

	echo $profile 2>&1
	echo $offset 2>&1

	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url)"
	echo ":::: $url"
	url="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors *)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url)"
	echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	echo "${diffPkgs}" > ${offset}/package.list
}

function getG2Profile() {
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*.[0-9]/}"
	echo $result
}

###################################################################################################################################

#   GRAB:
#       profile         get profile from chroot.
#       /etc/           tar cfvz etc.tar.gz
#       <services>      rc-update 1> [hostname].services
#       zfs-keys        (tar cfvz -List , develop list from zfs_keys list)
#       pkg selector    (take globals, diff from profile generated, output to [hostname].pkgs )
#       users			tar cfvz home.tar.gz ; root.tar.gz

#       store values in portage/profiles/[domain]/[hostname]
#       ex. hypokrites.net/dom0 ... subdomains are attached to the hostname
#       ex. happy.printer = hostname, hypokrites.net = domain
#		
#		~/
#			profile.txt
#			etc.tar.gz
#			config.services
#			zfs_keys.tar.gz
#			config.pkgs
#			users.tar.gz
#		
#		WORK=		...working directory
#		PACKAGE=	...
#		INSTALL=


function getSelection() {

	x=$1

	case "${x#*default/linux/amd64/}" in
		"17.1/hardened")				selection='hardened'
		;;
		"17.1/openrc")					selection='openrc'
		;;
		"17.1/systemd")					selection='systemd'
		;;
		"17.1/desktop/plasma")			selection='plasma'
		;;		
		"17.1/desktop/gnome")			selection='gnome'
		;;
		"17.1/selinux")					selection='selinux'
		;;
		"17.1/desktop/plasma/systemd")	selection='plasma/systemd'
		;;	
		"17.1/desktop/gnome/systemd")	selection='gnome/systemd'
		;;
		"17.1/hardened/selinux")		selection='hardened/selinux'
		;;
	esac

}

	export PYTHONPATH=""

	export -f users
	export -f locales
	export -f system
	export -f services
	export -f install_modules

    for x in $@
    do
        case "${x}" in
            work=*)
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"
            ;;
        esac
    done

	if [[ -z ${directory }]]l then exit; fi

	destination="/var/portage/profiles/"

    for x in $@
    do
        case "${x}" in
            package=*)
				profile=getG2Profile ${directory}
				hostname=$(chroot ${directory} /bin/bash -c "hostname")
				domain=$(chroot ${directory} /bin/bash -c "dnsdomainname")
				destination="${destination}/${domain}/${hostname}"
				echo $destination $dataset $domain $hostname $profile

            ;;
        esac
    done

    for x in $@
    do
        case "${x}" in
            install=*)

            ;;
        esac
    done


exit


	local destination=""
	clear_mounts ${directory}
	mounts ${directory}
    local profile = getG2Profile ${directory}
	zfs_keys ${dataset} /var/lib/portage/profiles/${domain}/${hostname}/
	chroot ${directory} /bin/bash -c "users ${_profile}"
	services_URL="$(echo "$(${SCRIPT_DIR}/bash/mirror.sh ${SCRIPT_DIR}/config/package.mirrors * )/${_profile}.services" | sed 's/ //g' | sed "s/\"/'/g")"
	chroot ${directory} /bin/bash -c "services ${services_URL}"
	zfs change-key -o keyformat=hex -o keylocation=file:///srv/crypto/zfs.key ${dataset}
	patches ${directory} ${_profile}
	clear_mounts ${directory}
	ls ${offset}
	zfs snapshot ${dataset}@safe

	# potential cleanup items
	#
	#	move binpkgs for client to /tmp as well, disable binpkg building
	#	reflash modules, or separate modules and kernel out...
	#	autofs integration w/ boot drive
	#	clear mounts 
	#
