
#!/bin/bash
SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

    # INPUTS    
    #           WORK=chroot offset		- update working directory
	#			BOOT=
	#		
	#	mounts + binpkgs,
	#	update patched files
	#	update kernel (only modules installed, kernel source could be added later, optionally)
	#	update modules
	#	update boot spec
	#	update run time
	#	unmounts
	#
	#
	#	future features : 	
	#		test to see if pool exists, add new zfs datasets if no dataset, other partition types.
	#		
	#		
	#	USE = ./update.sh work=pool/set boot=/dev/sdX update

source ./include.sh

# DESIGNATE A WORKING DIRECTORY TO 
for x in $@
do
	case "${x}" in
		work=*)
			directory="$(getZFSMountPoint ${x#*=})"
			dataset="${x#*=}"
			
		;;
	esac
done

for x in $@
do
	case "${x}" in
		boot=*)
			efi_partition="${x#*=}"		
		;;
	esac
done

# update
for x in $@
do
	case "${x}" in
		update)
#-----------------------------------------------------
			clear_mounts ${directory}
			mounts ${directory}

			emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"		
			profile="$(getG2Profile ${directory})"
			echo "PROFILE :: ${profile}"

			patch_files ${directory} ${profile}

			install_kernel ${directory}

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