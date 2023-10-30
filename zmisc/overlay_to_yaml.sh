#!/bin/bash

SCRIPT_DIR="$(realpath ${BASH_SOURCE:-$0})"
SCRIPT_DIR="${SCRIPT_DIR%/*/${0##*/}*}"

source ${SCRIPT_DIR}/bash/include.sh

# convert the eselect profile listing to yaml output (stdout)
# needs testing for password-required - repos
#   --> need to prune .git suffix and test for valid URL / wget - 404
yamlOut="repositories:/srv/portage/repository/"
title=""
url=""
output="$(eselect repository list | awk '{print $2":"$3}' | tr -d '()' | sed '1d' | grep -v '*')"

#insertKeyValue ${yamlOut} 

for i in ${output}
do
    #yamlOut="$(echo "$yamlOut" | insertKeyValue 'repositories/' "${i}")";
    #echo "$yamlOut"
    
    # make a list item
    i="-$i";
    # comment out value-less keys
    [[ ${i#*:} == '' ]] && { i="#$i"; };
    
    yamlOut="$(printf '%s\n%s' "${yamlOut}" "  ${i}")";
done

echo "${yamlOut}" > ./repos.eselect