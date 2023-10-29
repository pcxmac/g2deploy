#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

# convert the eselect profile listing to yaml output (stdout)

yamlOut="repositories:/srv/portage/repository/"
title=""
url=""
output="$(eselect repository list | awk '{print $2":"$3}' | tr -d '()' | sed '1d' | grep -v '*')"

#insertKeyValue ${yamlOut} 

for i in ${output}
do
    #yamlOut="$(echo "$yamlOut" | insertKeyValue 'repositories/' "${i}")";
    #echo "$yamlOut"
    yamlOut="$(printf '%s\n%s' "${yamlOut}" "  -${i}")";
done

echo "${yamlOut}" > ./repos.eselect