
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

profile="$(getG2Profile ${directory})"
emergeOpts="--buildpkg=y --getbinpkg=y --binpkg-respect-use=y --verbose --tree --backtrack=99"		

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

if [[ ! -d ${directory} ]];then exit; fi

clear_mounts ${directory}
mounts ${directory}

for x in $@
do
	case "${x}" in
		bootpart=*)
			efi_part="${x#*=}"
			type_part="$(blkid ${efi_part})"
			if [[ ${type_part} == *"TYPE=\"vfat\""* ]];
			then
				echo "update boot ! @ ${efi_part}}"
				# IS THIS WORKING ?? NOT UPDATING BOOT RECORD ON DIFFERENT SETS
				mount ${efi_partition} ${directory}/boot
				editboot $(getKVER) ${dataset}
				install_modules ${directory}
			else
				echo "no mas"
			fi
		;;
	esac
done

#sleep 30

# update
for x in $@
do
	case "${x}" in
		update)
			patches ${directory} ${profile}
			chroot ${directory} /bin/bash -c "update_runtime"
		;;
	esac
done

clear_mounts ${directory}