#!/bin/bash

source ./include.sh

./sync.sh

echo "working ..."

for ((x=1;x<8;x++))
do
	work="$(findKeyValue ../config/build.cfg deploy:$x/work)"
	build="$(findKeyValue ../config/build.cfg deploy:$x/build)"
	dset="$(findKeyValue ../config/build.cfg deploy:$x/dset)"

	if [[ -n ${work} ]]
	then
		clear_mounts $work

		echo "destroying old dataset @ $dset, if exists"
		zfs destroy $dset -r 2>/dev/null
		sleep 3
		echo "instituting dataset @ $dset \n"
		zfs create $dset
		sleep 3
		echo "deploying dataset @ $dset \n"
		./deploy.sh work=$work build=$build deploy
		sleep 3
		echo "deploying update :: $dset \n"
		./update.sh work=$work update
		sleep 3
		echo "snapshotting dataset @ $dset...\n"
		zfs snapshot ${dset}@safe
		sleep 3
	fi
done
