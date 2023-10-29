#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

# convert the eselect profile listing to yaml output (stdout)

yamlOut=""
title=""
url=""
output="$(sudo eselect repository list | awk '{print $2,$3}')"

insertKeyValue ${yamlOut} 


for i in ${output}
do


done
