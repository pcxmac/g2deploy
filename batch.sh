#	systemd needs a different suite of use.files (hardened vs systemd)
#	systemd needs a service setup different from openrc
#
#

#!/bin/bash

# setup resolv.conf and file system...

# ARGS $2 = destination $1= profile (default openrc,current directory)

#sleep 10

check_mounts() {
	#echo "check mounts ~ $1"
	directory="$1"
	output="$(cat /proc/mounts | grep $directory | wc -l)"
	#echo "initial output = $output"
	while [[ "$output" != 0 ]]
	do
		#cycle=0
		while read -r mountpoint; do
		#	((cycle++))
			umount $mountpoint > /dev/null 2>&1
		done < <(awk '{print $2}' < /proc/mounts | grep "^$directory")
		#echo "cycles = $cycle"
		output="$(cat /proc/mounts | grep $directory | wc -l)"
		#echo "mounts left, $output"
		sleep 1
	done
}

function prep_fs() {
	echo "prepfs ~ $1"
	#offset=$(pwd)
	#cd $1
	find $1 -maxdepth 1 ! -wholename $1 ! -wholename './batch.sh' ! -wholename './*.pkgs' ! -wholename './*.txt' ! -name . -exec rm -r "{}" \;
	echo "finished prepfs ... $1"
	#find $1 -maxdepth 1 ! -wholename $1 ! -wholename './batch.sh' ! -wholename './*.pkgs' ! -wholename './*.txt' ! -name .
}

function get_stage3() {

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
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-openrc/"
			file="$(curl -s $mirror | grep 'stage3-amd64-openrc' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		"systemd")
			mirror="mirror.bytemark.co.uk/gentoo//releases/amd64/autobuilds/current-stage3-amd64-systemd/"
			file="$(curl -s $mirror | grep 'stage3-amd64-systemd' | head -1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')"
			file="${file%.xz*}.xz"
		;;
		*)
			mirror="default"
			file="default"
		;;
	esac

	echo "mirror = $mirror, file = $file"
	wget $mirror$file --directory-prefix=$2
	echo "decompressing $file..."
	tar xf $2/$file -C $2
	rm $2/$file 
}

function config_env() {

	mkdir -p $1/var/lib/portage/binpkgs
	mkdir -p $1/var/lib/portage/distfiles
	mkdir -p $1/srv/crypto/
	mkdir -p $1/var/db/repos/gentoo

	#src=/usr/src/$(eselect kernel list | grep '*' | awk '{print $3}')
	src=/usr/src/linux-$(uname --kernel-release)

	# REQUIRES BEING INVOKED IN CORRECT ROOTFS

	dst=$1/usr/src

	#ls -ail $dst
	#pwd $dst
	#echo "#######################################################################################"
	#sleep 20
	#echo "rsync -r -l -H -p --delete-before --progress $src $dst"

	rsync -a -r -l -H -p --delete-before --info=progress2 $src $dst

	# OFFSET TO CURRENT WORKING DIRECTORY ,ADD SUPPORT FOR $1 ARG;/....
	#offset="$(pwd)"
	#offset="$(pwd $1)"
	#mSize="$(awk '$3=="kB"{$2=$2/1024^2;$3="GB";} 1' /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	mSize="$(cat /proc/meminfo | column -t | grep 'MemFree' | awk '{print $2}')"
	#mSize="${mSize%%.*}"
	#mSize=$(expr $mSize / 2)
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
	#mount -t nfs earth.hypokrites.me:/gentoo-distfiles $(pwd)/var/lib/portage/distfiles || echo "unable to mount distfiles !"
	#mount -t nfs earth.hypokrites.me:/gentoo-pkgs $(pwd)/var/lib/portage/binpkgs || echo "unable to mount binpkgs !"
	## RUN
	#mount -t nfs 192.168.2.200:/gentoo-distfiles $(pwd)/var/lib/portage/distfiles || echo "unable to mount distfiles !"
	#mount -t nfs 192.168.2.200:/gentoo-pkgs $(pwd)/var/lib/portage/binpkgs || echo "unable to mount binpkgs !"
	mount --bind /var/lib/portage/binpkgs $1/var/lib/portage/binpkgs
	mount --bind /var/lib/portage/distfiles $1/var/lib/portage/distfiles
}

function config_mngmt() {
	key=$1
	key=${key##*/}
	offset=$2

	#cp ./$key.pkgs $offset/$key.pkgs
	# add profile specific packages to the package list. $key + common.pkgs
	cp ./common.pkgs $offset/package.list
	cat ./$key.pkgs >> $offset/package.list

	tar cfv config.tar -T ./etc.cfg
	mv ./config.tar $offset
	cp /root $offset -Rp
}

function profile_settings() {
	key=$1

	case ${key##*/} in
		hardened|plasma|gnome)
			echo "configuring common for hardened, plasma and gnome..."
			sleep 5
			cp /root/bastion.start /etc/local.d/bastion.start
			rc-update add local
			rc-update add zfs-mount
			rc-update add zfs-load-key boot
			rc-update add zfs-zed
			rc-update add zfs-import boot
			rc-update add autofs
			rc-update add cronie
			rc-update add syslog-ng
		;;
		systemd)
			echo "configuring systemd..."
			sleep 5
			systemctl enable zfs.target
			systemctl enable zfs-import-cache
			systemctl enable zfs-mount
			systemctl enable zfs-import.target
			systemctl enable cronie
			systemctl enable autofs
		;;
		plasma|gnome)
			echo "configuring common for graphical environments: plasma and gnome..."
			sleep 5
			rc-update add display-manager default
			rc-update add dbus
		;;
		plasma)
			echo "configuring plasma..."
			sed -i "/DISPLAYMANAGER/c DISPLAYMANAGER='sddm'" /etc/conf.d/display-manager
		;;
		gnome)
			echo "configuring gnome..."
			rc-update add elogind boot
			emerge --ask --noreplace gui-libs/display-manager-init
			sed -i "/DISPLAYMANAGER/c DISPLAYMANAGER='gdm'" /etc/conf.d/display-manager
		;;
		selinux)

		;;
		*)
			echo "default settings ?"
		;;
	esac
}

function common() {

	tar xfv config.tar
	rm config.tar

	emergeOpts="--usepkg --binpkg-respect-use=y --verbose --tree --backtrack=99"

	mkdir -p /var/db/repos/gentoo
	emerge-webrsync
	locale-gen -A
	eselect locale set en_US.utf8

	df /

	echo "which device /??"
	sleep 5

	emerge $emergeOpts --sync --ask=n

	eselect news read all

	echo "America/Los_Angeles" > /etc/timezone
	emerge --config sys-libs/timezone-data

	eselect profile set default/linux/amd64/$1

	emerge $emergeOpts gentoolkit eix mlocate genkernel sudo zsh tmux app-arch/lz4 elfutils --ask=n
	emerge $emergeOpts --onlydeps =zfs-9999 =zfs-kmod-9999 --exclude=sys-kernel/gentoo-sources
	emerge $emergeOpts -b -uDN --with-bdeps=y @world --ask=n --exclude=sys-kernel/gentoo-sources

	usermod -s /bin/zsh root
	sudo sh -c 'echo root:@PCXmacR00t | chpasswd'

	useradd sysop
	sudo sh -c 'echo sysop:@PCXmacSy$ | chpasswd'

	echo "BUILDING KERNEL ..."

	kver="$(uname --kernel-release)"

	eselect kernel set linux-$kver
	zcat /proc/config.gz > /usr/src/linux/.config

	cd /usr/src/linux
	emerge =zfs-9999 =zfs-kmod-9999 --exclude=sys-kernel/gentoo-sources
	sync
	cd /

	eix-update
	updatedb

	qlist -I | sort | uniq > base.pkgs

	key=$1
	#emerge $emergeOpts $(cat ./${key##*/}.list)

	file_name="${key##*/}"

	echo "$(pwd)"
	ls
	echo ls | grep $file_name
	echo "##############################################################"
	sleep 30

	cat ./package.list | sort | uniq > profile.pkgs
	comm -1 -3 base.pkgs profile.pkgs > tobe.pkgs
	rm profile.pkgs
	rm base.pkgs
	#rm package.list

	emerge $emergeOpts $(cat ./tobe.pkgs)
	rm tobe.pkgs

	echo "SETTING SERVICES"

	rm /etc/hostid
	zgenhostid

}

export PYTHONPATH=""
#offset=$(pwd)
#echo "ENTERING CHROOT ..."
#chroot $offset /bin/bash <<"EOT"

export -f common
export -f profile_settings

# set working directory, default is current folder
offset="$(pwd)"
for x in $@
do
	case "${x}" in
		deploy=*)
			offset="${x#*=}"
		;;
	esac
done
echo "offset = $offset"
#sleep 10
# clear out working directory if set
for x in $@
do
	#echo $x
	case "${x}" in
		clear)
			check_mounts $offset
			prep_fs $offset
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
				hardened|systemd|plasma|gnome|selinux)
					#cd $offset
					#echo "profile = $x"
					get_stage3 ${x#*=} $offset
					config_env $offset
					echo "executing $1"
				;;
			esac
		;;
	esac
done



# install packages and configure system
string="invalid profile"
for x in $@
do
	case "${x}" in
		profile=*)
			case "${x#*=}" in
				hardened)
					# space at end limits selinux
					string="17.1/hardened "
				;;
				systemd)
					string="17.1/systemd "
				;;
				plasma)
					string="17.1/desktop/plasma "
				;;
				gnome)
					string="17.1/desktop/gnome "
				;;
				selinux)
					echo "selinux is not a $string"
					exit
				;;
				*)
					echo "$string, exiting ..."
					exit
				;;
			esac
			# deploy
				#cd $offset
				config_mngmt $string $offset
				chroot $offset /bin/bash -c "common $string"
				chroot $offset /bin/bash -c "profile_settings $string"

		;;
	esac
done



echo "cleaning up mounts"
check_mounts $offset


#		aufs)
#			echo "aufs =1"
#		;;
#		aufs\=*)
#			aufs=1
#			echo "${x#*=}"
#		;;

