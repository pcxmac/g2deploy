#!/bin/bash

source ./include.sh

./sync.sh

for ((x=1;x<8;x++))
do
	work="$(findKeyValue ../config/build.cfg deploy:$x/work)"
	build="$(findKeyValue ../config/build.cfg deploy:$x/build)"
	dset="$(findKeyValue ../config/build.cfg deploy:$x/dset)"

	clear_mounts $work

	zfs destroy $dset -r
	zfs create $dset

	./deploy.sh work=$work build=$build deploy

	./update.sh work=$work update
done