
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
	#		NEED A STRUCTURE TO CHECK CURRENT BOOT SETTING/VERIFY MODULE INSTALL, THEN RETROFIT TO NEW KERNEL IF APPLICABLE, IF NOT, DONT DO SHIT TO THE KERNEL
	#		
	#	USE = ./update.sh work=pool/set boot=/dev/sdX update

source ./include.sh

function update_runtime() {

	sudo emerge --sync --verbose --backtrack=99 --ask=n;sudo eix-update
	sudo emerge -b -uDN --with-bdeps=y @world --ask=n --binpkg-respect-use=y --binpkg-changed-deps=y
}

export PYTHONPATH=""

	export -f update_runtime

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

			mount ${efi_partition} ${directory}/boot

			patch_files ${directory} ${profile}
			install_kernel ${directory}
			editboot $(getKVER) ${dataset}

			chroot ${directory} /bin/bash -c "update_runtime"

			clear_mounts ${directory}


		;;
	esac
done

echo "THIS !!!"