#!/bin/bash

source ./include.sh

for ((x=1;x<8;x++))
do
	work="$(findKeyValue ../config/build.cfg deploy:$x/work)"
	build="$(findKeyValue ../config/build.cfg deploy:$x/build)"
	options="$(findKeyValue ../config/build.cfg deploy:$x/options)"

	zfs destroy $work -r
	zfs create $work

	./deploy.sh work=$work build=$build $options
done
