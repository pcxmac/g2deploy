#!/bin/bash

    source ./include.sh

   	_s="http:80 ftp:21 rsync:873"
	
    printf "checking hosts: (%s)\n" "${_config}"

	while read -r line; do


        echo "---------@ $line-----------"
        
        for i in $(printf '%s\n' ${_s})
        do
            _port="${i#*:}"
            proto="${i%:*}"
            _description="${_serve%::*}"
            _result="$(isHostUp ${line} ${_port})"
            _retval="$(printf "${colB} %s ${colB}" '[' "${_result}" ']')"
            printf "\t %-30s : %5s %s %s\n" "server:$line" "${_port}" "$_retval" "$proto"

            # 										filter for color
            _result="$(printf '%s\n'\t\t"${_result}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g")"

        done


	done < <(cat "../config/mirrors/hosts"  | sed 's/#.*$//' | sed '/^[[:space:]]*$/d')