#	systemd needs a different suite of use.files (hardened vs systemd)
#	systemd needs a service setup different from openrc
#
#

## need to add support for integrating the build_disk ...
#  need to support building new kernels on the host env and integrating those in to the new clients
# option = { install=/dev/vdX } ... performs disk geometry and installation on to NEW POOL
# try to mask a lot of the output (like news read all) that clutters output :: option = { verbose=no }

#!/bin/bash
#set -x
# setup resolv.conf and file system...

# ARGS $2 = destination $1= profile (default openrc,current directory)

function zfs_keys() {

	offset=$1

	# ALL POOLS ON SYSTEM, FOR GENKERNEL
	# pools="$(zpool list | awk '{print $1}') | sed '1 d')"

	# THE POOL BEING DEPLOYED TO ... -- DEPLOYMENT SCRIPT
	#limit pools to just the deployed pool / not valid for genkernel which would attach all pools & datasets
	pools="$(cat /proc/mounts | grep "$offset " | awk '{print $1}')"
	pools="${pools%/*}"

	for i in $pools
	do
		# query datasets
		listing="$(zfs list | grep "$i/" | awk '{print $1}')"

		echo "$listing"
		#sleep 5

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
						echo "copying $source to $destination"
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


check_mounts() {

	dir="$(echo "$1" | sed -e 's/[^A-Za-z0-9\\/._-]/_/g')"
	output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint
		do
			umount $mountpoint > /dev/null 2>&1
		done < <(cat /proc/mounts | grep "$dir\/" | awk '{print $2}')
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep "$dir\/" | wc -l)"
	done

}

function clear_fs() {
	# VERIFY ZFS MOUNT IS in DF
	echo "prepfs ~ $1"

	# older inplace delete
	#find $1 -maxdepth 1 ! -wholename $1 ! -wholename './batch.sh' ! -wholename './*.pkgs' ! -wholename './*.txt' ! -name . -exec rm -r "{}" \;

	echo "deleting old files (calculating...)"
	count="$(find $1/ | wc -l)"
	if [[ $count > 1 ]]
	then
		rm -rv $1/* | pv -l -s $count 2>&1 > /dev/null
	else
		echo -e "done "
	fi

	echo "finished clear_fs ... $1"
}

function get_stage3() {

	echo "getting stage 3"

	case $1 in
		"gnome")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"plasma")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"hardened")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-hardened-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"gnome/systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"plasma/systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-desktop-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-desktop-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		*)
			mirror="default"
			file="default"
		;;
	esac

	echo "mirror = $mirror, file = $file"
	wget $mirror$file --directory-prefix=$2
	wget $mirror$file.asc --directory-prefix=$2
	gpg --verify $2/$file.asc
	rm $2/$file.asc

	echo "decompressing $file..."
	tar xf $2/$file -C $2
	rm $2/$file
}

function config_env()
{
	mkdir -p $1/var/lib/portage/binpkgs
	mkdir -p $1/var/lib/portage/distfiles
	mkdir -p $1/srv/crypto/
	mkdir -p $1/var/db/repos/gentoo

	src=/usr/src/linux-$(uname --kernel-release)

	# REQUIRES BEING INVOKED IN CORRECT ROOTFS

	dst=$1/usr/src

	############################################### DEPRICATED IN FAVOR OF UPDATE=POOL/SET
	#echo "copying over kernel source..."
	#rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst
	#dst="$1/lib/modules"
	#src="/lib/modules/$(uname --kernel-release)"
	#echo "copying over kernel modules..."
	#rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst

	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="${mSize}K"
	# MOUNTS
	echo "msize = $mSize"
	mount -t proc proc $1/proc
	mount --rbind /sys $1/sys
	mount --make-rslave $1/sys
	mount --rbind /dev $1/dev
	mount --make-rslave $1/dev
	# because autofs doesn't work right in a chroot ...
	mount -t tmpfs -o size=$mSize tmpfs $1/tmp
	mount -t tmpfs tmpfs $1/var/tmp
	mount -t tmpfs tmpfs $1/run
	mount --bind /var/lib/portage/binpkgs $1/var/lib/portage/binpkgs
	mount --bind /var/lib/portage/distfiles $1/var/lib/portage/distfiles
}

function config_mngmt() {

	offset=$2
	path=$1

	cp ./common.pkgs $offset/package.list

	echo "######################################################################################"

	ls -ail ./packages/$path.pkgs
	echo "what do you see ?"

	cat ./packages/$path.pkgs >> $offset/package.list

	echo "pwd = $pwd"
	tar cfv $offset/config.tar -T ./etc.cfg

	tar xfv $offset/config.tar -C $offset
	rm $offset/config.tar

	cp /root $offset -Rp
	#  attempt to get past having to login twice
	cp /home $offset -Rp

	uses="$(cat ./packages/$path.conf)"
	sed -i "/USE/c $uses" $offset/etc/portage/make.conf

	# need test for this
	cp /etc/zfs/zpool.cache $offset/etc/zfs
}

function profile_settings() {
	key=$1

	# openrc
	case ${key#17.1/*} in
		'hardened'|'desktop/plasma'|'desktop/gnome'|'selinux'|'hardened/selinux')
			echo "configuring common for hardened, plasma and gnome..."
			rc-update add local
			rc-update add zfs-mount boot
			rc-update add zfs-load-key boot
			rc-update add zfs-zed boot
			rc-update add zfs-import boot
			rc-update add autofs
			rc-update add cronie
			rc-update add syslog-ng
			rc-update add ntpd
		;;
	esac

	# systemd
	case ${key#17.1/*} in
		'desktop/plasma/systemd'|'desktop/gnome/systemd'|'systemd')
			echo "configuring systemd..."
			systemctl enable NetworkManager
			systemctl enable zfs.target
			systemctl enable zfs-import
			systemctl enable zfs-import-cache
			systemctl enable zfs-mount
			systemctl enable zfs-import.target
			systemctl enable cronie
			systemctl enable autofs
			systemctl enable ntpd
			# mask resolved and rpcbind (can unmask in the future)
			ln -sf /dev/null /etc/systemd/system/systemd-resolved.service
			ln -sf /dev/null /etc/systemd/system/rpcbind.service

		;;
	esac

	# generic console
	case ${key#17.1/*} in
		'systemd'|'hardened')
			echo "generic console setup..."
		;;
	esac

	# generic desktop
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/gnome')
			echo "generic desktop setup"
			sed -i "/DISPLAYMANAGER/c DISPLAYMANAGER='gdm'" /etc/conf.d/display-manager
		;;
	esac

	# generic openrc desktop
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/gnome')
			echo "configuring openrc common graphical environments: plasma and gnome..."
			emerge --ask --noreplace gui-libs/display-manager-init --ask=n
			rc-update add elogind boot
			rc-update add dbus
			rc-update add display-manager default
		;;
	esac

	# generic systemd desktop
	case ${key#17.1/*} in
		'desktop/plasma/systemd'|'desktop/gnome/systemd')
			echo "configuring systemd common graphical environments: plasma and gnome..."
			systemctl enable gdm.service
		;;
	esac

	# specific cases for any specific variant

	echo "sampling @ ${key#17.1/}"


	# generic plasma
	case ${key#17.1/*} in
		'desktop/plasma'|'desktop/plasma/systemd')
			echo "configuring plasma..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=plasmawayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " >  $dir/sysop
			printf "[User]\nSession=plasmawayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# generic gnome
	case ${key#17.1/*} in
		'desktop/gnome'|'desktop/gnome/systemd')
			echo "configuring gnome..."
			dir="/var/lib/AccountsService/users"
			mkdir -p $dir
			printf "[User]\nSession=gnome-wayland\nIcon=/home/sysop/.face\nSystemAccount=false\n " > $dir/sysop
			printf "[User]\nSession=gnome-wayland\nIcon=/home/root/.face\nSystemAccount=false\n " > $dir/root
		;;
	esac

	# specific use cases for individual profiles
	case ${key#17.1/} in
		'desktop/plasma')
			echo "configuring plasma/openrc"
		;;
		'desktop/plasma/systemd')
			echo "configuring plasma/systemd"
		;;
		'desktop/gnome')
			echo "configuring gnome/openrc..."
		;;
		'desktop/gnome/systemd')
			echo "configuring gnome-systemd"
		;;
		'systemd')
			echo "nothing special for systemd"
		;;
		'hardened')
			echo "nothing special for hardened"
		;;
		'selinux')
			echo "selinux not supported"
		;;
		'hardened/selinux')
			echo "hardened/selinux not supported"
		;;
	esac
}

function update() {

			# INPUTS : ${x#*=} - dataset

			dataset=$1

			# does refind exist ?
			bootref="/boot/EFI/boot/refind.conf"
			#bootref="${x#*=}"
			if [ ! -f $bootref ]; then echo "unable to find $bootref"; exit; fi

			# does dataset exist ?
			# get mountpoint
			mntpt="$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
			if [ -z $mntpt ]; then echo "$dataset does not exist"; exit; fi

			src=/usr/src/linux
			src=$(readlink $src)

			dst=$mntpt/usr/src/$src

			echo "copying over kernel source... /usr/src/$src --> $dst"
			rsync -a -r -l -H -p --delete-before --info=progress2 /usr/src/$src $dst


#			src="/lib/modules/$(uname --kernel-release)"

			src=${src#linux-*}
			modsrc=/lib/modules/$src

			dst=$mntpt$modsrc

			echo "copying over kernel modules... $modsrc --> $dst"
			rsync -a -r -l -H -p --delete-before --info=progress2 $modsrc $dst

			# find section in refind.conf
			line_number=$(grep -n "$dataset " $bootref  | cut -f1 -d:)
			loadL=$((line_number-2))
			initrdL=$((line_number-1))
			echo "line # $line_number , src=  $src"
			grep -n "$dataset " $bootref
			sed -n "${loadL}s/loader.*/loader \\/linux\\/$src\\/vmlinuz/p" $bootref
			sed -n "${initrdL}s/initrd.*/initrd \\/linux\\/$src\\/initramfs/p" $bootref
			sed -i "${loadL}s/loader.*/loader \\/linux\\/$src\\/vmlinuz/" $bootref
			sed -i "${initrdL}s/initrd.*/initrd \\/linux\\/$src\\/initramfs/" $bootref

}



function common() {

	emergeOpts="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99 --exclude=sys-fs/zfs-kmod --exclude=sys-kernel/gentoo-sources"
	emergeOpts2="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99"

	mkdir -p /var/db/repos/gentoo
	emerge-webrsync
	locale-gen -A
	eselect locale set en_US.utf8

	echo "SYNC EMERGE !!!!!"
	emerge $emergeOpts --sync --ask=n

	eselect news read all

	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data

	eselect profile set default/linux/amd64/$1

	echo "BASIC TOOLS EMERGE !!!!!"
	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh tmux app-arch/lz4 elfutils --ask=n

	echo "ZFS EMERGE BUILD DEPS ONLY !!!!!"
	emerge $emergeOpts --onlydeps =zfs-9999 =zfs-kmod-9999
	# seems outmoded ... perhahs redundant ... maybenot ...

	echo "BUILDING KERNEL ..."

	kver="$(uname --kernel-release)"

	eselect kernel set linux-$kver
	zcat /proc/config.gz > /usr/src/linux/.config

	echo "EMERGE ZFS !!!"
	emerge $emergeOpts2 =zfs-9999 =zfs-kmod-9999
	sync

	echo "UPDATE EMERGE !!!!!"
	emerge $emergeOpts -b -uDN --with-bdeps=y @world --ask=n

	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd'

	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd'
	usermod -a -G wheel sysop

	qlist -I | sort | uniq > base.pkgs

	key=$1

	file_name="${key##*/}"

	cat ./package.list | sort | uniq > profile.pkgs
	comm -1 -3 base.pkgs profile.pkgs > tobe.pkgs
	rm profile.pkgs
	rm base.pkgs
	#rm package.list

	echo "EMERGE PROFILE PACKAGES !!!!"
	emerge $emergeOpts $(cat ./tobe.pkgs)
	rm tobe.pkgs

	echo "SETTING SERVICES"

	# install dev keys for gentoo
	wget -O - https://qa-reports.gentoo.org/output/service-keys.gpg | gpg --import

####USE ZGENHOSTID ON NEW ZPOOLS
	#zgenhostid
	eix-update
	updatedb
}

export PYTHONPATH=""
export -f common
export -f profile_settings

# set working directory, default is current folder
offset="$(pwd)"
for x in $@
do
	case "${x}" in
		deploy=*)
			offset="${x#*=}"
			check_mounts $offset
		;;
	esac
done

echo "offset = $offset"

# clear out working directory if set
for x in $@
do
	#echo $x
	case "${x}" in
		clear)
			clear_fs $offset
		;;
	esac
done


# setup working directory with correct files
for x in $@
do
	case "${x}" in
		# if profile is selected
		profile=*)
			# if profile is specified any of...
			case "${x#*=}" in
				hardened*|systemd|plasma*|gnome*|selinux)
					echo "profile = $x"
					echo "exuberant = ${x#*=}"
					get_stage3 ${x#*=} $offset
					echo "running zfs_keys"
					zfs_keys $offset
					config_env $offset
					echo "executing $1"
				;;
			esac
		;;
	esac
done

# update kernel & EFI/boot/refind.conf
# able to be used by itself ... update=POOL/DATASET which corresponds with the mountpoint of a dataset, which
# can be then cross checked in the refind.conf and updated, of course everything is checked before updating ...
# example update=zsys/plasmad

for x in $@
do
	#echo $x
	case "${x}" in

		update=*)
			dataset="${x#*=}"
			update $dataset
		;;
	esac
done


# install packages and configure system
string="invalid profile"
for x in $@
do
	echo "before cases $x"

	case "${x}" in
		profile=*)
			case "${x#*=}" in
				# special cases for strings ending in selinux, and systemd as they can be part of a combination
				'hardened')
					# space at end limits selinux
					string="17.1/hardened "
				;;
				'systemd')
					string="17.1/systemd "
				;;
				'plasma')
					string="17.1/desktop/plasma "
				;;
				'gnome')
					string="17.1/desktop/gnome "
				;;
				'selinux')
					string="17.1/selinux "
					echo "${x#*=} is not supported [selinux]"
				;;
				'plasma/systemd')
					string="17.1/desktop/plasma/systemd "
				;;
				'gnome/systemd')
					string="17.1/desktop/gnome/systemd "
				;;
				'hardened/selinux')
					string="17.1/hardened/selinux "
					echo "${x#*=} is not supported [selinux]"
				;;
			esac

			config_mngmt $string $offset
			chroot $offset /bin/bash -c "common $string"
			chroot $offset /bin/bash -c "profile_settings $string"
			echo "after profile settings..."
		;;


	esac
	echo "after cases ${x}"
done

echo "cleaning up mounts"
check_mounts $offset

