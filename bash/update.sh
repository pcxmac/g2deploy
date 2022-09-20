
#!/bin/bash

    # INPUTS    
    #           WORK=chroot offset		- update working directory
	#			BOOT=/dev/sdX			- up0date existing image
	#		



	#	future features : 	
	#		test to see if pool exists, add new zfs datasets if no dataset, other partition types.
	#		
	#		


SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"


function getZFSMountPoint (){
	local dataset=$1
	echo "$(zfs get mountpoint $dataset 2>&1 | sed -n 2p | awk '{print $3}')"
}

function getG2Profile() {
	local current="17.1"
	#dataset=$1 
	#mountpoint=getZFSMountPoint $dataset
	local mountpoint=$1
	local result="$(chroot $mountpoint /usr/bin/eselect profile show | tail -n1)"
	result="${result#*/$current/}"
	echo $result
}



# DESIGNATE A WORKING DIRECTORY TO 
for x in $@
do
	case "${x}" in
		work=*)
			#? zfs= btrfs= generic= tmpfs=
			directory="$(getZFSMountPoint ${x#*=})"
			dataset="${x#*=}"
			
		;;
	esac
done

# update
for x in $@
do
	case "${x}" in
		update)
#-----------------------------------------------------
			

			emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"
		
			profile="$(getG2Profile ${directory})"
			#profile="shit"

			echo "PROFILE :: ${profile}"

			check_mounts ${directory}

			mount --bind /var/lib/portage/binpkgs ${directory}/var/lib/portage/binpkgs
			mount --bind /var/lib/portage/distfiles ${directory}/var/lib/portage/distfiles

			patch_files ${directory} ${profile}




			#emerge --sync
			# sync package masks/keywords/usecases etc... (kernel version is regulated through mask)
			#emerge -uDn @world --ask=n --buildpkg=y

			current_kernel="linux-$(uname --kernel-release)"
			latest_kernel="$(eselect kernel list | tail -n 1 | awk '{print $2}')"

			echo "current kernel = ${current_kernel}"
			echo "latest kernel = ${latest_kernel}"

			eselect kernel set ${latest_kernel}


			if [[ ! -f ./src/${latest_kernel}.tar.gz ]]
			then
				zcat /proc/config.gz > /usr/src/${latest_kernel}/.config
				(cd /usr/src/${latest_kernel} ; make -j $(nproc))
				(cd /usr/src/${latest_kernel} ; make modules_install)
				(cd /usr/src/${latest_kernel} ; make install)
				emerge =zfs-kmod-9999 =zfs-9999 --buildpkg=n --ask=n;
				compress /usr/src/${latest_kernel} ./src/${latest_kernel}.tar.gz 
				genkernel --install initramfs --compress-initramfs-type=lz4 --zfs

				pathboot=/boot/LINUX/${latest_kernel#linux-*}
				mkdir ${pathboot} -p

				suffix=${latest_kernel##*-}

				mv /boot/initramfs-${latest_kernel#linux-*}.img ${pathboot}/initramfs
				mv /boot/vmlinuz-${latest_kernel#linux-*} ${pathboot}/vmlinuz
				mv /boot/System.map-${latest_kernel#linux-*} ${pathboot}/System.map-${latest_kernel#linux-*}
				mv /boot/config-${latest_kernel#linux-*} ${pathboot}/config-${latest_kernel#linux-*}
			fi



			echo "editing boot record"
			
			editboot ${latest_kernel#linux-*} ${directory}

			echo "syncing kernel modules for ${latest_kernel#linux-*}"
			
			rsync -c -a -r -l -H -p --delete-before --info=progress2 /lib/modules/${latest_kernel#linux-*} $directory/lib/modules/

			echo "@ ${directory}"
			config_env ${directory}
			chroot ${directory} /usr/bin/emerge --sync
			chroot ${directory} /usr/bin/emerge -b -uDN @world $emergeOpts

			check_mounts ${directory}


		;;
	esac
done

echo "THIS !!!"