#!/bin/bash

# FETCH ENV VARS



# SETUP LXD , assumes already installed, but service not enabled or started

# SETUP NETWORK
	# COPY OVER TEMPLATE FOR DEFAULT

# SETUP STORAGE
	# SETUP DATASET
	# INTEGRATE IN TO LXD


# FETCH IMAGES FROM 'IMAGES:'

distros=(	'debian/10'
			'debian/11'
			'debian/12'
			'opensuse/tumbleweed'
			'gentoo/systemd'
			'gentoo/openrc'
			'fedora/35'
			'archlinux'
			'fedora/35'
			'fedora/36'
			'centos/7'
			'centos/8'
			'centos/9'
			'jammy'
			'xenial'
			'bionic'
			'focal'
			'kinetic'
)

for distro in ${distros[@]}
do
	#test="$(lxc image list images: | grep "$distro " -i | grep -i X86_64 | grep -i CONTAINER | head -n 1)"
	#echo $test
	finger="$(lxc image list images: | grep "$distro " -i | grep -i X86_64 | grep -i CONTAINER | head -n 1 | awk '{print $6}')"
	echo "$distro for $finger"
	lxc image copy images:"$finger" local: --alias "$distro"
	
done
