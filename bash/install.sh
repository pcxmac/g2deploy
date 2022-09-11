#!/bin/bash

    # INPUTS    BUILD=(ex.)'hardened'  
    #           WORK=chroot offset


    #KVER = what ever genkernel reports
    #KEY - 

function decompress() {

	local src=$1
	local dst=$2

	#echo "SRC = $src	;; DST = $dst"

	# tar -J - bzip2
	# tar -z - gzip
	# tar -x - xz
	
	local compression_type="$(file $src | awk '{print $2}')"
	
	case $compression_type in
	'XZ')
		pv $src | tar xJf - -C $dst
		;;	
	'gzip')
		pv $src | tar xzf - -C $dst
		;;
	esac

}

### NEED A UNIVERSAL TRANSPORT MECHANISM FOR SYNCING ALL FILES. SCP, RSYNC ?
#
#		SYNC() HOST w/ SOURCE
#		SEND TO SOURCE DESTINATION
#		RECV FROM SOURCE DESTINATION
#		COMPRESSION AND ENCRYPTION ARE TRANSPARENT
#		
#
#############################################################################

function compress() {
	local src=$1
	local dst=$2
	local ksize="$(du -sb $src | awk '{print $1}')"
	echo "ksize = $ksize"
	tar cfz - $src | pv -s $ksize  > ${dst}
}

function compress_list() {
	local src=$1
	local dst=$2
	
	#echo "compressing LIST @ $src $dst"
	tar cfz - -T $src | (pv -p --timer --rate --bytes > $dst)
}

function rSync() {
	local src=$1
	local dst=$2
	echo "rsync from $src to $dst"
	rsync -c -a -r -l -H -p --delete-before --info=progress2 $src $dst
}


    for x in $@
    do
        case "${x}" in
            work=*)
                #? zfs= btrfs= generic= tmpfs=
            	directory="$(zfs get mountpoint ${x#*=} 2>&1 | sed -n 2p | awk '{print $3}')"
                dataset="${x#*=}"             
            ;;
        esac
    done

    for x in $@
    do
        #echo "before cases $x"
        case "${x}" in
            build=*)
                echo "build..."
                # DESIGNATE BUILD PROFILE
                profile="invalid profile"

                selection="${x#*=}"


                case "${x#*=}" in
                    # special cases for strings ending in selinux, and systemd as they can be part of a combination
                    'musl')
                        # space at end limits selinux
                        profile="17.0/musl/hardened "
                    ;;
                    'hardened')
                        # space at end limits selinux
                        profile="17.1/hardened "
                    ;;
                    'openrc')
                        # space at end limits selinux
                        profile="17.1/openrc"
                    ;;
                    'systemd')
                        profile="17.1/systemd "
                    ;;
                    'plasma')
                        profile="17.1/desktop/plasma "
                    ;;
                    'gnome')
                        profile="17.1/desktop/gnome "
                    ;;
                    'selinux')
                        profile="17.1/selinux "
                        echo "${x#*=} is not supported [selinux]"
                    ;;
                    'plasma/systemd')
                        profile="17.1/desktop/plasma/systemd "
                    ;;
                    'gnome/systemd')
                        profile="17.1/desktop/gnome/systemd "
                    ;;
                    'hardened/selinux')
                        profile="17.1/hardened/selinux "
                        echo "${x#*=} is not supported [selinux]"
                    ;;
                    *)
                        profile="invalid profile"
                    ;;
                esac
            ;;
        esac
    done

function zfs_keys() {
	# ALL POOLS ON SYSTEM, FOR GENKERNEL
	# pools="$(zpool list | awk '{print $1}') | sed '1 d')"
	
	# THE POOL BEING DEPLOYED TO ... -- DEPLOYMENT SCRIPT
	#limit pools to just the deployed pool / not valid for genkernel which would attach all pools & datasets
	local dataset=$1
	local offset="$(zfs get mountpoint ${dataset} 2>&1 | sed -n 2p | awk '{print $3}')"

	local pools="$dataset"
	pools="${pools%/*}"
	
	for i in $pools
	do
		# query datasets
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"
		echo "$listing"

		for j in $listing
		do
			#dSet="$(zpool get bootfs $i | awk '{print $3}' | sed -n '2 p')"
			dSet="$j"
			if [ "$dSet" == '-' ]
			then
				format="N/A"
				location="N/A"
				else
				format="$(zfs get keyformat $dSet | awk '{print $3}' | sed -n '2 p')"
				location="$(zfs get keylocation $dSet | awk '{print $3}' | sed -n '2 p')"
			fi
			# if format == raw or hex & location is a valid file ... if not a valid file , complain
			# ie, not none or passphrase, indicating no key or passphrase, thus implying partition or keyfile type
			if [ $format == 'raw' ] || [ $format == 'hex' ]
			then
				# possible locations are : http/s, file:///, prompt, pkcs11:
				# only concerned with file:///
				location_type="${location%:///*}"
				if [ $location_type == 'file' ]
				then
					# if not, then probably https:/// ....
					# put key file in to initramfs
					source="${location#*//}"
					destination="${source%/*}"
					destination="$offset$destination"
					mkdir -p $destination
					if test -f "$source"; then
						#echo "copying $source to $destination"
						cp $source $destination
					else
						echo "key not found for $j"
					fi
					echo "coppied $source to $destination for $j"
				else
					echo "nothing to do for $j ..."
				fi
			fi
		done
	done
}


function users()
{
	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd'
	# CYCLE THROUGH USERS ?
	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd'
	echo "home : sysop"
	usermod --home /home/sysop sysop
	echo "wheel : sysop"
	usermod -a -G wheel sysop
	echo "shell : sysop"
	usermod --shell /bin/zsh sysop
	homedir="$(eval echo ~sysop)"
	chown sysop.sysop ${homedir} -R
	echo "homedir"
}

function buildup()
{
    #echo "getting stage 3"
	local profile=$1
	local offset=$2

	procs="$(lsof ${offset} | sed '1d' | awk '{print $2}' | uniq)" 
	echo "killing $(echo $procs | wc -l) process(s)"  2>&1
	for process in ${procs}; do kill -9 ${process}; done

    dir="$(echo "$offset" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	echo "$output mounts to be removed" 2>&1
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			#echo "umount $mountpoint"
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir\/" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	done

	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ $offset"
	echo "deleting old files (calculating...)"
	count="$(find $offset/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $offset/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi
	echo "finished clear_fs ... $offset"

	files="$(./mirror.sh ../config/releases.mirrors ${selection})"
	filexz="$(echo "${files}" | grep '.xz$')"
	fileasc="$(echo "${files}" | grep '.asc$')"
	serverType="${filexz%//*}"

	echo "X = ${serverType%//*} :: $files @ $profile"

	case ${serverType%//*} in
		"file:/")
			echo "RSYNCING" 2>&1
			rsync -avP ${filexz#*//} ${offset}
			rsync -avP ${fileasc#*//} ${offset}
		;;
		"http:")
			echo "WGETTING" 2>&1
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

function system()
{
	emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"
	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh pv tmux app-arch/lz4 elfutils --ask=n

	echo "EMERGE PROFILE PACKAGES !!!!"
	pkgs="/package.list"
	emerge $emergeOpts $(cat "$pkgs")
	
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

function install_kernel()
{
	local offset=$1

	rsync -ahP --info=progress2 $(./mirror.sh ../config/kernel.mirrors *)/current/ $offset
	archive="$(ls ${offset} | grep '^linux.*.gz$')"
	ksrc=${archive%*.tar.gz}

	echo "decompressing kernel... $offset/$archive <<<<<<<<<<"
	pv ${offset}/${archive} | tar xzf - -C ${offset}
	rm ${offset}/${archive}

	echo "decompressing modules...  $offset/${ksrc#*-}/modules.tar.gz"
	pv $offset/${ksrc#*-}/modules.tar.gz | tar xzf - -C ${offset}
	
	rsync -ahP --info=progress2 ${offset}/${ksrc#*-}/ ${offset}/boot/
	rm ${offset}/${ksrc#*-} -R

	echo "selecting kernel... ${ksrc}"
	chroot ${offset} /usr/bin/eselect kernel set ${ksrc}
}

function install_modules()
{
		emergeOpts="--binpkg-respect-use=y --verbose --tree --backtrack=99"
		emerge $emergeOpts --buildpkg=y --getbinpkg=y --onlydeps =zfs-kmod-9999 
		emerge $emergeOpts --buildpkg=n --getbinpkg=n =zfs-kmod-9999 
		emerge $emergeOpts --buildpkg=y --getbinpkg=y --onlydeps =zfs-9999
		emerge $emergeOpts --buildpkg=n --getbinpkg=n =zfs-9999
}


function patches()
{
    local offset=$1
	local lineNum=0

    echo "patching system files..."
    rsync -avP /var/lib/portage/patchfiles/ ${offset}

	echo "patching make.conf..."
	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf
		fi
	# 																	remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(./mirror.sh ../config/package.mirrors *)/common.conf" | sed 's/ //g' | sed "s/\"/'/g"))

	while read line; do
		echo "LINE = $line"
		((LineNum+=1))
		PREFIX=${line%=*}
		echo "PREFIX = $PREFIX"
		SUFFIX=${line#*=}
		if [[ -n $line ]]
		then
			echo "WHAT ?"
			sed -i "/$PREFIX/c $line" ${offset}/etc/portage/make.conf	
		fi
	# 																	    remove :    WHITE SPACE    DOUBLE->SINGLE QUOTES
	done < <(curl $(echo "$(./mirror.sh ../config/package.mirrors *)/${profile}.conf" | sed 's/ //g' | sed "s/\"/'/g"))
}

function locales()
{

	#emergeOpts="--buildpkg=n --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"
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
}

function certificates()
{
    echo "certs"
}

function pkgProcessor()
{
    local profile=$1
	local offset=$2

	url="$(echo "$(./mirror.sh ../config/package.mirrors *)/common.pkgs" | sed 's/ //g')"
	commonPkgs="$(curl $url)"
	#echo ":::: $url"
	url="$(echo "$(./mirror.sh ../config/package.mirrors *)/${profile}.pkgs" | sed 's/ //g')"
	profilePkgs="$(curl $url)"
	#echo ":::: $url"

	local allPkgs="$(echo -e "${commonPkgs}\n${profilePkgs}" | uniq | sort)"

	echo "$commonPkgs" 2>&1
	echo "$profilePkgs" 2>&1

	local iBase="$(chroot ${offset} /usr/bin/qlist -I)"
	iBase="$(echo "${iBase}" | uniq | sort)"

	local diffPkgs="$(comm -1 -3 <(echo "${iBase}") <(echo "${allPkgs}"))"

	echo "${diffPkgs}" > ${offset}/package.list
}

# check mount, create new mount ?
export PYTHONPATH=""

export -f users
export -f locales
export -f system
export -f services
export -f install_modules

	### NEED F/S CONTEXT SENSITIVE
    buildup ${profile} ${directory}
    zfs_keys ${dataset}	
	##############################
	patches ${directory}
	pkgProcessor ${profile} ${directory}
    chroot ${directory} /bin/bash -c "locales ${profile}"
	install_kernel ${directory}
	chroot ${directory} /bin/bash -c "install_modules"
	chroot ${directory} /bin/bash -c "system"
	chroot ${directory} /bin/bash -c "users ${profile}"
	services_URL="$(./mirror.sh ../config/package.mirrors *)/${profile}.services" | sed 's/ //g' | sed "s/\"/'/g"
	chroot ${directory} /bin/bash -c "services ${services_URL}"

# potential cleanup items
#
#	move binpkgs for client to /tmp as well, disable binpkg building
#	reflash modules
#