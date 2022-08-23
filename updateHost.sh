#!/bin/bash

emerge --sync

# sync package masks/keywords/usecases etc... (kernel version is regulated through mask)

emerge -uDn @world

current_kernel="linux-$(uname --kernel-release)"
latest_kernel="$(eselect kernel list | tail -n 1 | awk '{print $2}')"

if [[ "$current_kernel" == "$latest_kernel" ]]; then echo "no changes"; fi

eselect kernel set $(eselect kernel list | tail -n 1 | awk '{print $2}')

cd /usr/src/linux

zcat /proc/config.gz > ./.config

make -j $(nproc);
make modules_install;
make install;
emerge zfs-kmod zfs;
genkernel --install initramfs --compress-initramfs-type=lz4 --zfs_keys
sync

<prepfs>
<chroot> ${working_directory} /bin/bash
	sync config files
	emerge --sync
	emerge -uDn @world
	

